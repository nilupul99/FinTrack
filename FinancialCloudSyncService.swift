import Foundation
import CoreData
import Network

@MainActor
final class FinancialCloudSyncService {
    static let shared = FinancialCloudSyncService()

    private enum RecordType: String, CaseIterable {
        case transaction
        case budget
        case goal
        case recurring

        static let managedObjectTypes: [RecordType] = [.transaction, .budget, .goal]

        var entityName: String? {
            switch self {
            case .transaction: "Transaction"
            case .budget: "Budget"
            case .goal: "Goal"
            case .recurring: nil
            }
        }
    }

    private enum SyncError: LocalizedError {
        case server(status: Int, message: String)

        var errorDescription: String? {
            switch self {
            case let .server(status, message):
                "Supabase \(status): \(message)"
            }
        }
    }

    private struct Payload: Codable {
        let title: String?
        let category: String?
        let amount: Double?
        let limit: Double?
        let target: Double?
        let isAchieved: Bool?
        let cadence: String?
        let isExpense: Bool?
        let recurringID: String?
        let createdAt: TimeInterval?
    }

    private struct DeletionFingerprint: Codable, Hashable {
        let recordType: String
        let title: String?
        let category: String?
        let amount: Double?
        let createdAt: TimeInterval?
    }

    private struct CloudRecord: Codable {
        let id: String
        let userID: String
        let recordType: String
        let payload: Payload
        let isDeleted: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case userID = "user_id"
            case recordType = "record_type"
            case payload
            case isDeleted = "is_deleted"
        }

        /// Older Supabase schemas permit transaction, budget, and goal records
        /// only. Recurring schedules are therefore stored as marked transaction
        /// records while retaining their schedule-specific payload fields.
        var isRecurringSchedule: Bool {
            recordType == RecordType.recurring.rawValue || (
                recordType == RecordType.transaction.rawValue &&
                payload.cadence != nil &&
                payload.isExpense != nil &&
                payload.recurringID == nil
            )
        }
    }

    private var context: NSManagedObjectContext?
    private var userID = ""
    private let pendingDeletionDefaultsPrefix = "financialPendingDeletions."
    private let deletionFingerprintDefaultsPrefix = "financialDeletionFingerprints."
    private var userEmail = ""
    private var deletionObserver: NSObjectProtocol?
    private var didSaveObserver: NSObjectProtocol?
    private var dirtyKeys = Set<String>()
    private var deletedKeys = Set<String>()
    private var deletionFingerprints = Set<DeletionFingerprint>()
    private var hasPerformedInitialUpload = false
    private var isApplyingRemoteChanges = false
    private var isRecordingLocalChanges = false
    private var isSynchronizing = false
    private var isSyncQueued = false
    private var pathMonitor: NWPathMonitor?
    private let pathMonitorQueue = DispatchQueue(label: "FinTrack.FinancialCloudSync")
    private var realtime: FinancialRealtimeListener?

    private init() {}

    func start(
        context: NSManagedObjectContext,
        userID: String,
        userEmail: String
    ) {
        guard userID.isEmpty == false, userEmail.isEmpty == false else { return }

        stop()
        self.context = context
        self.userID = userID
        self.userEmail = userEmail
        deletedKeys = persistedDeletionKeys(for: userID)
        deletionFingerprints = persistedDeletionFingerprints(for: userID)
        installSaveObserver(for: context)
        installNetworkMonitor()
        normalizeLocalRecords(in: context)
        realtime = FinancialRealtimeListener(
            userID: userID,
            accessToken: SupabaseAuthService.shared.currentAccessToken ?? "",
            onChange: { [weak self] in
                Task { @MainActor in
                    await self?.synchronize()
                }
            }
        )
        realtime?.connect()
        Task { await synchronize() }
    }

    func stop() {
        if let deletionObserver {
            NotificationCenter.default.removeObserver(deletionObserver)
        }
        if let didSaveObserver {
            NotificationCenter.default.removeObserver(didSaveObserver)
        }
        deletionObserver = nil
        didSaveObserver = nil
        realtime?.disconnect()
        realtime = nil
        pathMonitor?.cancel()
        pathMonitor = nil
        context = nil
        userID = ""
        userEmail = ""
        dirtyKeys.removeAll()
        deletedKeys.removeAll()
        hasPerformedInitialUpload = false
    }

    /// Retains a remote deletion key before Core Data invalidates the object's values.
    func prepareForDeletion(_ object: NSManagedObject) {
        guard isApplyingRemoteChanges == false else { return }
        recordDeletion(for: object)
    }

    func synchronize() async {
        if isSynchronizing {
            isSyncQueued = true
            return
        }

        guard
            let context,
            userID.isEmpty == false,
            let token = SupabaseAuthService.shared.currentAccessToken
        else {
            return
        }

        isSynchronizing = true
        defer {
            isSynchronizing = false
            if isSyncQueued {
                isSyncQueued = false
                Task {
                    await synchronize()
                }
            }
        }

        do {
            let recordsToUpload = allLocalRecords(in: context)
            hasPerformedInitialUpload = true

            if context.hasChanges {
                try context.save()
            }

            let pendingDeletes = deletedKeys
            try await upload(recordsToUpload, token: token)
            try await deleteRemoteRecords(for: pendingDeletes, token: token)
            dirtyKeys.subtract(recordsToUpload.map(recordKey))

            var remoteRecords = try await fetchRemoteRecords(token: token)

            let fingerprintMatches = remoteRecords.filter { record in
                deletionFingerprints.contains { fingerprint in
                    fingerprintMatchesRecord(fingerprint, record: record)
                }
            }
            if fingerprintMatches.isEmpty == false {
                let fingerprintDeleteKeys = Set(fingerprintMatches.map(recordKey))
                deletedKeys.formUnion(fingerprintDeleteKeys)
                persistDeletionKeys()
                try await deleteRemoteRecords(for: fingerprintDeleteKeys, token: token)
                remoteRecords = try await fetchRemoteRecords(token: token)
            }

            let pendingDeletionIDs = Set(
                deletedKeys.compactMap { $0.split(separator: ":", maxSplits: 1).last.map(String.init) }
            )
            let undeletedIDs = Set(remoteRecords.map(\.id)).intersection(pendingDeletionIDs)
            guard undeletedIDs.isEmpty else {
                throw SyncError.server(
                    status: 409,
                    message: "Supabase still contains a transaction requested for deletion."
                )
            }
            deletedKeys.subtract(pendingDeletes)
            deletedKeys.subtract(fingerprintMatches.map(recordKey))
            deletionFingerprints.removeAll()
            persistDeletionKeys()
            persistDeletionFingerprints()
            let tombstoneKeys = Set(
                remoteRecords
                    .filter(\.isDeleted)
                    .map(recordKey)
            )
            let tombstoneRecords = remoteRecords.filter(\.isDeleted)
            apply(tombstoneRecords, in: context)
            if tombstoneKeys.isEmpty == false {
                try await deleteRemoteRecords(for: tombstoneKeys, token: token)
            }
            apply(remoteRecords.filter { $0.isDeleted == false }, in: context)
            UserDefaults.standard.set(
                "Last synced \(Date.now.formatted(date: .omitted, time: .shortened))",
                forKey: "financialSyncStatus"
            )
        } catch {
            UserDefaults.standard.set(
                "Sync error: \(error.localizedDescription)",
                forKey: "financialSyncStatus"
            )
        }
    }

    private func installNetworkMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                await self?.synchronize()
            }
        }
        pathMonitor = monitor
        monitor.start(queue: pathMonitorQueue)
    }

    private func installSaveObserver(for context: NSManagedObjectContext) {
        deletionObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: context,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.recordDeletedObjects(from: notification)
            }
        }

        didSaveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: context,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.synchronize()
            }
        }
    }

    private func recordDeletedObjects(from notification: Notification) {
        guard isApplyingRemoteChanges == false else { return }

        let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
        for object in deletedObjects {
            recordDeletion(for: object)
        }
    }

    private func recordDeletion(for object: NSManagedObject) {
        guard let type = recordType(for: object) else { return }

        if let cloudID = object.value(forKey: "cloudID") as? String,
           cloudID.isEmpty == false {
            deletedKeys.insert("\(type.rawValue):\(cloudID)")
            persistDeletionKeys()
            return
        }

        deletionFingerprints.insert(
            DeletionFingerprint(
                recordType: type.rawValue,
                title: object.value(forKey: "title") as? String,
                category: object.value(forKey: "category") as? String,
                amount: object.value(forKey: "amount") as? Double,
                createdAt: (object.value(forKey: "createdAt") as? Date)?.timeIntervalSince1970
            )
        )
        persistDeletionFingerprints()
    }

    private func persistedDeletionKeys(for userID: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: pendingDeletionDefaultsPrefix + userID) ?? [])
    }

    private func persistDeletionKeys() {
        guard userID.isEmpty == false else { return }
        UserDefaults.standard.set(
            Array(deletedKeys),
            forKey: pendingDeletionDefaultsPrefix + userID
        )
    }

    private func persistedDeletionFingerprints(for userID: String) -> Set<DeletionFingerprint> {
        guard
            let data = UserDefaults.standard.data(
                forKey: deletionFingerprintDefaultsPrefix + userID
            ),
            let fingerprints = try? JSONDecoder().decode([DeletionFingerprint].self, from: data)
        else {
            return []
        }
        return Set(fingerprints)
    }

    private func persistDeletionFingerprints() {
        guard
            userID.isEmpty == false,
            let data = try? JSONEncoder().encode(Array(deletionFingerprints))
        else {
            return
        }
        UserDefaults.standard.set(data, forKey: deletionFingerprintDefaultsPrefix + userID)
    }

    private func normalizeLocalRecords(in context: NSManagedObjectContext) {
        var changed = false
        for type in RecordType.managedObjectTypes {
            guard let entityName = type.entityName else { continue }
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.predicate = NSPredicate(format: "userEmail == %@", userEmail)
            for object in (try? context.fetch(request)) ?? [] {
                if (object.value(forKey: "cloudID") as? String)?.isEmpty != false {
                    object.setValue(UUID().uuidString, forKey: "cloudID")
                    changed = true
                }
                if object.value(forKey: "updatedAt") as? Date == nil {
                    object.setValue(Date(), forKey: "updatedAt")
                    changed = true
                }
                if let cloudID = object.value(forKey: "cloudID") as? String {
                    dirtyKeys.insert("\(type.rawValue):\(cloudID)")
                }
            }
        }

        if changed {
            try? context.save()
        }
    }

    private func allLocalRecords(in context: NSManagedObjectContext) -> [CloudRecord] {
        let managedObjectRecords = RecordType.managedObjectTypes.flatMap { type -> [CloudRecord] in
            guard let entityName = type.entityName else { return [] }
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.predicate = NSPredicate(format: "userEmail == %@", userEmail)
            return ((try? context.fetch(request)) ?? []).compactMap { cloudRecord(for: $0, type: type) }
        }

        return managedObjectRecords + recurringCloudRecords()
    }

    private func recurringCloudRecords() -> [CloudRecord] {
        RecurringTransactionStore
            .load(from: UserDefaults.standard.string(forKey: "recurringTransactions") ?? "")
            .filter { $0.userEmail == userEmail }
            .map { recurring in
                CloudRecord(
                    id: recurring.id.uuidString,
                    userID: userID,
                    // Keep compatibility with the current financial_records
                    // record_type check constraint in Supabase.
                    recordType: RecordType.transaction.rawValue,
                    payload: Payload(
                        title: recurring.name,
                        category: recurring.category,
                        // Match normal transaction storage: expenses are
                        // negative and income is positive.
                        amount: recurring.signedAmount,
                        limit: nil,
                        target: nil,
                        isAchieved: nil,
                        cadence: recurring.cadence,
                        isExpense: recurring.isExpense,
                        recurringID: nil,
                        createdAt: recurring.createdAt.timeIntervalSince1970
                    ),
                    isDeleted: false
                )
            }
    }

    func prepareForRecurringDeletion(_ recurring: RecurringTransactionData) {
        deletedKeys.insert("\(RecordType.transaction.rawValue):\(recurring.id.uuidString)")
        persistDeletionKeys()
    }

    private func localRecords(for keys: Set<String>, in context: NSManagedObjectContext) -> [CloudRecord] {
        keys.compactMap { key in
            let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
            guard
                parts.count == 2,
                let type = RecordType(rawValue: parts[0]),
                let entityName = type.entityName
            else {
                return nil
            }
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.fetchLimit = 1
            request.predicate = NSPredicate(
                format: "userEmail == %@ AND cloudID == %@",
                userEmail,
                parts[1]
            )
            guard let object = (try? context.fetch(request))?.first else { return nil }
            return cloudRecord(for: object, type: type)
        }
    }

    private func cloudRecord(for object: NSManagedObject, type: RecordType) -> CloudRecord? {
        let cloudID: String
        if let savedCloudID = object.value(forKey: "cloudID") as? String,
           savedCloudID.isEmpty == false {
            cloudID = savedCloudID
        } else {
            cloudID = UUID().uuidString
            object.setValue(cloudID, forKey: "cloudID")
            object.setValue(Date(), forKey: "updatedAt")
        }

        let payload: Payload
        switch type {
        case .transaction:
            payload = Payload(
                title: object.value(forKey: "title") as? String,
                category: object.value(forKey: "category") as? String,
                amount: object.value(forKey: "amount") as? Double,
                limit: nil,
                target: nil,
                isAchieved: nil,
                cadence: nil,
                isExpense: nil,
                recurringID: object.value(forKey: "recurringID") as? String,
                createdAt: (object.value(forKey: "createdAt") as? Date)?.timeIntervalSince1970
            )
        case .budget:
            payload = Payload(
                title: nil,
                category: object.value(forKey: "category") as? String,
                amount: nil,
                limit: object.value(forKey: "limit") as? Double,
                target: nil,
                isAchieved: nil,
                cadence: nil,
                isExpense: nil,
                recurringID: nil,
                createdAt: (object.value(forKey: "createdAt") as? Date)?.timeIntervalSince1970
            )
        case .goal:
            payload = Payload(
                title: object.value(forKey: "title") as? String,
                category: object.value(forKey: "category") as? String,
                amount: nil,
                limit: nil,
                target: object.value(forKey: "target") as? Double,
                isAchieved: object.value(forKey: "isAchieved") as? Bool,
                cadence: nil,
                isExpense: nil,
                recurringID: nil,
                createdAt: (object.value(forKey: "createdAt") as? Date)?.timeIntervalSince1970
            )
        case .recurring:
            return nil
        }

        return CloudRecord(
            id: cloudID,
            userID: userID,
            recordType: type.rawValue,
            payload: payload,
            isDeleted: false
        )
    }

    private func tombstoneRecord(for key: String) -> CloudRecord? {
        let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return CloudRecord(
            id: parts[1],
            userID: userID,
            recordType: parts[0],
            payload: Payload(
                title: nil,
                category: nil,
                amount: nil,
                limit: nil,
                target: nil,
                isAchieved: nil,
                cadence: nil,
                isExpense: nil,
                recurringID: nil,
                createdAt: nil
            ),
            isDeleted: true
        )
    }

    private func apply(_ records: [CloudRecord], in context: NSManagedObjectContext) {
        guard records.isEmpty == false else { return }
        isApplyingRemoteChanges = true
        defer { isApplyingRemoteChanges = false }

        applyRecurringRecords(records.filter(\.isRecurringSchedule))

        for record in records where record.userID == userID && record.isRecurringSchedule == false {
            guard
                let type = RecordType(rawValue: record.recordType),
                let entityName = type.entityName
            else {
                continue
            }
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.fetchLimit = 1
            request.predicate = NSPredicate(
                format: "userEmail == %@ AND cloudID == %@",
                userEmail,
                record.id
            )
            let existing = try? context.fetch(request).first

            if record.isDeleted {
                if let existing { context.delete(existing) }
                continue
            }

            let object = existing ?? NSEntityDescription.insertNewObject(
                forEntityName: entityName,
                into: context
            )
            object.setValue(record.id, forKey: "cloudID")
            object.setValue(userEmail, forKey: "userEmail")
            object.setValue(Date(), forKey: "updatedAt")
            object.setValue(Date(timeIntervalSince1970: record.payload.createdAt ?? Date().timeIntervalSince1970), forKey: "createdAt")
            object.setValue(record.payload.category, forKey: "category")

            switch type {
            case .transaction:
                object.setValue(record.payload.title, forKey: "title")
                object.setValue(record.payload.amount ?? 0, forKey: "amount")
                object.setValue(record.payload.recurringID, forKey: "recurringID")
            case .budget:
                object.setValue(record.payload.limit ?? 0, forKey: "limit")
            case .goal:
                object.setValue(record.payload.title, forKey: "title")
                object.setValue(record.payload.target ?? 0, forKey: "target")
                object.setValue(record.payload.isAchieved ?? false, forKey: "isAchieved")
            case .recurring:
                continue
            }
        }

        try? context.save()
    }

    private func applyRecurringRecords(_ records: [CloudRecord]) {
        guard records.isEmpty == false else { return }

        var schedules = RecurringTransactionStore.load(
            from: UserDefaults.standard.string(forKey: "recurringTransactions") ?? ""
        )
        let scheduleIDs = Set(
            records.compactMap { UUID(uuidString: $0.id) }
        )
        schedules.removeAll { schedule in
            schedule.userEmail == userEmail && scheduleIDs.contains(schedule.id)
        }

        for record in records where record.userID == userID && record.isDeleted == false {
            guard
                let id = UUID(uuidString: record.id),
                let title = record.payload.title,
                let category = record.payload.category,
                let amount = record.payload.amount,
                let cadence = record.payload.cadence,
                let isExpense = record.payload.isExpense
            else {
                continue
            }

            schedules.append(
                RecurringTransactionData(
                    id: id,
                    userEmail: userEmail,
                    name: title,
                    category: category,
                    amount: abs(amount),
                    cadence: cadence,
                    isExpense: isExpense,
                    createdAt: Date(
                        timeIntervalSince1970: record.payload.createdAt ?? Date().timeIntervalSince1970
                    )
                )
            )
        }

        UserDefaults.standard.set(
            RecurringTransactionStore.encode(schedules),
            forKey: "recurringTransactions"
        )
    }

    private func fetchRemoteRecords(token: String) async throws -> [CloudRecord] {
        var components = URLComponents(
            url: SupabaseAuthService.shared.baseURL.appendingPathComponent("rest/v1/financial_records"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userID)"),
            URLQueryItem(name: "select", value: "*")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(SupabaseAuthService.shared.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SyncError.server(
                status: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8) ?? "No error details returned."
            )
        }
        return try JSONDecoder().decode([CloudRecord].self, from: data)
    }

    private func upload(_ records: [CloudRecord], token: String) async throws {
        guard records.isEmpty == false else { return }
        var components = URLComponents(
            url: SupabaseAuthService.shared.baseURL.appendingPathComponent("rest/v1/financial_records"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "on_conflict", value: "user_id,id")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(SupabaseAuthService.shared.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(records)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SyncError.server(
                status: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8) ?? "No error details returned."
            )
        }
    }

    private func deleteRemoteRecords(for keys: Set<String>, token: String) async throws {
        for key in keys {
            let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }

            var components = URLComponents(
                url: SupabaseAuthService.shared.baseURL.appendingPathComponent("rest/v1/financial_records"),
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = [
                URLQueryItem(name: "user_id", value: "eq.\(userID)"),
                URLQueryItem(name: "id", value: "eq.\(parts[1])")
            ]

            var request = URLRequest(url: components.url!)
            request.httpMethod = "DELETE"
            request.setValue(SupabaseAuthService.shared.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw SyncError.server(
                    status: httpResponse.statusCode,
                    message: String(data: data, encoding: .utf8) ?? "No error details returned."
                )
            }
        }
    }

    private func recordType(for object: NSManagedObject) -> RecordType? {
        RecordType.allCases.first { $0.entityName == object.entity.name }
    }

    private func belongsToActiveUser(_ object: NSManagedObject) -> Bool {
        object.value(forKey: "userEmail") as? String == userEmail
    }

    private func fingerprintMatchesRecord(
        _ fingerprint: DeletionFingerprint,
        record: CloudRecord
    ) -> Bool {
        guard fingerprint.recordType == record.recordType,
              fingerprint.title == record.payload.title,
              fingerprint.category == record.payload.category,
              fingerprint.amount == record.payload.amount
        else {
            return false
        }

        switch (fingerprint.createdAt, record.payload.createdAt) {
        case let (localDate?, remoteDate?):
            return abs(localDate - remoteDate) < 0.01
        case (nil, nil):
            return true
        default:
            return false
        }
    }

    private func recordKey(_ record: CloudRecord) -> String {
        "\(record.recordType):\(record.id)"
    }
}

private final class FinancialRealtimeListener {
    private let userID: String
    private let accessToken: String
    private let onChange: @Sendable () -> Void
    private var socket: URLSessionWebSocketTask?

    init(userID: String, accessToken: String, onChange: @escaping @Sendable () -> Void) {
        self.userID = userID
        self.accessToken = accessToken
        self.onChange = onChange
    }

    func connect() {
        guard accessToken.isEmpty == false else { return }
        let projectURL = SupabaseAuthService.shared.baseURL.absoluteString
            .replacingOccurrences(of: "https://", with: "wss://")
        guard let url = URL(string: "\(projectURL)/realtime/v1/websocket?apikey=\(SupabaseAuthService.shared.anonKey)&vsn=1.0.0") else {
            return
        }

        socket = URLSession.shared.webSocketTask(with: url)
        socket?.resume()
        joinChannel()
        receive()
    }

    func disconnect() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    private func joinChannel() {
        let payload: [String: Any] = [
            "config": [
                "broadcast": ["self": false],
                "presence": ["key": ""],
                "postgres_changes": [[
                    "event": "*",
                    "schema": "public",
                    "table": "financial_records",
                    "filter": "user_id=eq.\(userID)"
                ]]
            ],
            "access_token": accessToken
        ]
        let message: [Any] = [NSNull(), "1", "realtime:public:financial_records", "phx_join", payload]
        guard
            let data = try? JSONSerialization.data(withJSONObject: message),
            let string = String(data: data, encoding: .utf8)
        else { return }
        socket?.send(.string(string)) { _ in }
    }

    private func receive() {
        socket?.receive { [weak self] result in
            guard let self else { return }
            if case let .success(message) = result,
               case let .string(string) = message,
               string.contains("postgres_changes") {
                self.onChange()
            }
            self.receive()
        }
    }
}
