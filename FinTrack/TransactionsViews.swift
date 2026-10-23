import SwiftUI
import VisionKit
import Vision
import PhotosUI
import AVFoundation
import UIKit
import CoreData

struct CategoryPicker: View {
    @Binding var category: String
    @AppStorage("customCategories") private var storedCategories = ""
    @State private var isAddingCategory = false
    @State private var newCategory = ""

    private let defaultCategories = ["Food", "Transport", "Bills", "Salary"]

    private var categories: [String] {
        var values = defaultCategories
        values.append(contentsOf: storedCategories.split(separator: "|").map(String.init))
        if values.contains(category) == false, category.isEmpty == false {
            values.append(category)
        }
        return Array(NSOrderedSet(array: values)) as? [String] ?? defaultCategories
    }

    var body: some View {
        Picker("Category", selection: $category) {
            ForEach(categories, id: \.self) { value in
                Text(value).tag(value)
            }
        }

        Button {
            newCategory = ""
            isAddingCategory = true
        } label: {
            Label("Add Category", systemImage: "plus.circle")
        }
        .alert("Add Category", isPresented: $isAddingCategory) {
            TextField("Category Name", text: $newCategory)
            Button("Add", action: addCategory)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Create a category to use in transactions, budgets, and goals.")
        }
    }

    private func addCategory() {
        let trimmedCategory = newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCategory.isEmpty == false else { return }

        var values = storedCategories.split(separator: "|").map(String.init)
        if values.contains(where: { $0.caseInsensitiveCompare(trimmedCategory) == .orderedSame }) == false,
           defaultCategories.contains(where: { $0.caseInsensitiveCompare(trimmedCategory) == .orderedSame }) == false {
            values.append(trimmedCategory)
            storedCategories = values.joined(separator: "|")
        }
        category = trimmedCategory
    }
}

struct TransactionsScreen: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("activeUserEmail") private var activeUserEmail = ""
    @State private var isShowingExpense = false
    @State private var isShowingIncome = false
    @State private var isShowingReceiptScanner = false
    @FetchRequest private var savedTransactions: FetchedResults<NSManagedObject>

    init() {
        _savedTransactions = FetchRequest(fetchRequest: makeTransactionFetchRequest(), animation: .default)
    }

    private var transactions: [NSManagedObject] {
        savedTransactions.filter { $0.value(forKey: "userEmail") as? String == activeUserEmail }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { isShowingExpense = true } label: {
                        Label("Add Expense", systemImage: "minus.circle.fill")
                    }
                    Button { isShowingIncome = true } label: {
                        Label("Add Income", systemImage: "plus.circle.fill")
                    }
                    Button { isShowingReceiptScanner = true } label: {
                        Label("Scan Receipt", systemImage: "doc.viewfinder")
                    }
                }

                Section("Recent") {
                    if transactions.isEmpty {
                        ContentUnavailableView(
                            "No Transactions",
                            systemImage: "tray",
                            description: Text("Add an income or expense to start tracking your finances.")
                        )
                    } else {
                        ForEach(transactions, id: \.objectID) { transaction in
                            NavigationLink {
                                EditTransactionScreen(
                                    transaction: transaction,
                                    userEmail: activeUserEmail
                                )
                            } label: {
                                TransactionRow(transaction: TransactionRowData(managedObject: transaction))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Transactions")
            .sheet(isPresented: $isShowingExpense) {
                AddTransactionScreen(kind: .expense)
            }
            .sheet(isPresented: $isShowingIncome) {
                AddTransactionScreen(kind: .income)
            }
            .sheet(isPresented: $isShowingReceiptScanner) {
                ReceiptScannerScreen()
            }
        }
    }
}

struct AddTransactionScreen: View {
    enum TransactionKind: String {
        case expense = "Expense"
        case income = "Income"
    }

    let kind: TransactionKind
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("activeUserEmail") private var activeUserEmail = ""
    @State private var title = ""
    @State private var amount = ""
    @State private var category = "Food"
    @State private var notes = ""
    @State private var isShowingValidationAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    CategoryPicker(category: $category)
                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Add \(kind.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") { dismiss() }
//                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveTransaction)
                }
            }
            .alert("Enter a title and a valid amount.", isPresented: $isShowingValidationAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    private func saveTransaction() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            trimmedTitle.isEmpty == false,
            let enteredAmount = Double(amount),
            enteredAmount > 0,
            activeUserEmail.isEmpty == false
        else {
            isShowingValidationAlert = true
            return
        }

        let transaction = NSEntityDescription.insertNewObject(forEntityName: "Transaction", into: viewContext)
        transaction.setValue(trimmedTitle, forKey: "title")
        transaction.setValue(category, forKey: "category")
        transaction.setValue(kind == .expense ? -enteredAmount : enteredAmount, forKey: "amount")
        transaction.setValue(Date(), forKey: "createdAt")
        transaction.setValue(activeUserEmail, forKey: "userEmail")

        do {
            let newlyAchievedGoals = markNewlyAchievedGoals(
                in: viewContext,
                userEmail: activeUserEmail
            )
            try viewContext.save()
            let reachedBudgetLimit = kind == .expense && didReachBudgetLimit(
                for: category,
                addedExpense: enteredAmount
            )

            Task {
                if reachedBudgetLimit {
                    await NotificationManager.shared.scheduleBudgetWarning(category: category)
                }

                for goalTitle in newlyAchievedGoals {
                    await NotificationManager.shared.scheduleNotification(
                        title: "Goal achieved",
                        body: "You achieved your \(goalTitle) goal.",
                        secondsFromNow: 2
                    )
                }
            }
            dismiss()
        } catch {
            viewContext.rollback()
            isShowingValidationAlert = true
        }
    }

    private func didReachBudgetLimit(for category: String, addedExpense: Double) -> Bool {
        let budgetRequest = NSFetchRequest<NSManagedObject>(entityName: "Budget")
        budgetRequest.fetchLimit = 1
        budgetRequest.predicate = NSPredicate(
            format: "userEmail == %@ AND category == %@",
            activeUserEmail,
            category
        )

        guard let budget = try? viewContext.fetch(budgetRequest).first,
              let limit = budget.value(forKey: "limit") as? Double,
              limit > 0 else {
            return false
        }

        let transactionRequest = NSFetchRequest<NSManagedObject>(entityName: "Transaction")
        transactionRequest.predicate = NSPredicate(
            format: "userEmail == %@ AND category == %@",
            activeUserEmail,
            category
        )

        let spent = (try? viewContext.fetch(transactionRequest))?.reduce(0) { total, transaction in
            let amount = transaction.value(forKey: "amount") as? Double ?? 0
            return total + (amount < 0 ? -amount : 0)
        } ?? 0

        return spent >= limit && spent - addedExpense < limit
    }
}


struct EditTransactionScreen: View {
    let transaction: NSManagedObject
    let userEmail: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var title: String
    @State private var amount: String
    @State private var category: String
    @State private var isExpense: Bool
    @State private var isShowingValidationAlert = false

    init(transaction: NSManagedObject, userEmail: String) {
        self.transaction = transaction
        self.userEmail = userEmail

        let storedAmount = transaction.value(forKey: "amount") as? Double ?? 0
        _title = State(initialValue: transaction.value(forKey: "title") as? String ?? "")
        _amount = State(initialValue: String(format: "%.2f", abs(storedAmount)))
        _category = State(initialValue: transaction.value(forKey: "category") as? String ?? "Food")
        _isExpense = State(initialValue: storedAmount < 0)
    }

    var body: some View {
        Form {
            Section("Transaction") {
                Picker("Type", selection: $isExpense) {
                    Text("Expense").tag(true)
                    Text("Income").tag(false)
                }
                .pickerStyle(.segmented)

                TextField("Title", text: $title)
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                CategoryPicker(category: $category)
            }

            Section {
                Button("Delete Transaction", role: .destructive, action: deleteTransaction)
            }
        }
        .navigationTitle("Edit Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: saveTransaction)
            }
        }
        .alert("Enter a title and a valid amount.", isPresented: $isShowingValidationAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    private func saveTransaction() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedTitle.isEmpty == false, let enteredAmount = Double(amount), enteredAmount > 0 else {
            isShowingValidationAlert = true
            return
        }

        transaction.setValue(trimmedTitle, forKey: "title")
        transaction.setValue(category, forKey: "category")
        transaction.setValue(isExpense ? -enteredAmount : enteredAmount, forKey: "amount")

        do {
            let newlyAchievedGoals = markNewlyAchievedGoals(
                in: viewContext,
                userEmail: userEmail
            )
            try viewContext.save()
            scheduleGoalNotifications(for: newlyAchievedGoals)
            dismiss()
        } catch {
            viewContext.rollback()
            isShowingValidationAlert = true
        }
    }

    private func deleteTransaction() {
        viewContext.delete(transaction)

        do {
            _ = markNewlyAchievedGoals(in: viewContext, userEmail: userEmail)
            try viewContext.save()
            dismiss()
        } catch {
            viewContext.rollback()
            isShowingValidationAlert = true
        }
    }

    private func scheduleGoalNotifications(for goalTitles: [String]) {
        Task {
            for goalTitle in goalTitles {
                await NotificationManager.shared.scheduleNotification(
                    title: "Goal achieved",
                    body: "You achieved your \(goalTitle) goal.",
                    secondsFromNow: 1
                )
            }
        }
    }
}


struct RecurringTransactionsScreen: View {
    @AppStorage("activeUserEmail") private var activeUserEmail = ""
    @AppStorage("recurringTransactions") private var encodedRecurringTransactions = ""
    @State private var isShowingAddRecurring = false

    private var recurringTransactions: [RecurringTransactionData] {
        RecurringTransactionStore.load(from: encodedRecurringTransactions).filter {
            $0.userEmail == activeUserEmail
        }
    }

    var body: some View {
        List {
            if recurringTransactions.isEmpty {
                ContentUnavailableView(
                    "No Recurring Transactions",
                    systemImage: "repeat",
                    description: Text("Add a recurring transaction to see it here.")
                )
            } else {
                ForEach(recurringTransactions) { transaction in
                    RecurringRow(
                        title: transaction.name,
                        cadence: "\(transaction.cadence) • \(transaction.category)",
                        amount: transaction.signedAmount,
                        icon: "repeat.circle.fill",
                        tint: transaction.isExpense ? .orange : .green
                    )
                }
            }
        }
        .navigationTitle("Recurring")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isShowingAddRecurring = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Recurring Transaction")
            }
        }
        .sheet(isPresented: $isShowingAddRecurring) {
            AddRecurringTransactionScreen()
        }
    }
}

struct AddRecurringTransactionScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("activeUserEmail") private var activeUserEmail = ""
    @AppStorage("recurringTransactions") private var encodedRecurringTransactions = ""
    @State private var name = ""
    @State private var amount = ""
    @State private var category = "Bills"
    @State private var cadence = "Monthly"
    @State private var isExpense = true
    @State private var isShowingValidationAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Recurring Transaction") {
                    Toggle("Expense", isOn: $isExpense)
                    TextField("Name", text: $name)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    CategoryPicker(category: $category)
                    Picker("Repeats", selection: $cadence) {
                        Text("Weekly").tag("Weekly")
                        Text("Monthly").tag("Monthly")
                        Text("Yearly").tag("Yearly")
                    }
                }
            }
            .navigationTitle("Add Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveRecurringTransaction)
                }
            }
            .alert("Enter a name and a valid amount.", isPresented: $isShowingValidationAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    private func saveRecurringTransaction() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            trimmedName.isEmpty == false,
            let enteredAmount = Double(amount),
            enteredAmount > 0,
            activeUserEmail.isEmpty == false
        else {
            isShowingValidationAlert = true
            return
        }

        let transaction = NSEntityDescription.insertNewObject(
            forEntityName: "Transaction",
            into: viewContext
        )
        transaction.setValue(trimmedName, forKey: "title")
        transaction.setValue(category, forKey: "category")
        transaction.setValue(isExpense ? -enteredAmount : enteredAmount, forKey: "amount")
        transaction.setValue(Date(), forKey: "createdAt")
        transaction.setValue(activeUserEmail, forKey: "userEmail")

        do {
            let newlyAchievedGoals = markNewlyAchievedGoals(
                in: viewContext,
                userEmail: activeUserEmail
            )
            try viewContext.save()

            var savedRecurringTransactions = RecurringTransactionStore.load(
                from: encodedRecurringTransactions
            )
            savedRecurringTransactions.append(
                RecurringTransactionData(
                    id: UUID(),
                    userEmail: activeUserEmail,
                    name: trimmedName,
                    category: category,
                    amount: enteredAmount,
                    cadence: cadence,
                    isExpense: isExpense,
                    createdAt: .now
                )
            )
            encodedRecurringTransactions = RecurringTransactionStore.encode(savedRecurringTransactions)

            Task {
                await NotificationManager.shared.scheduleRecurringReminder(
                    name: trimmedName,
                    cadence: cadence
                )

                for goalTitle in newlyAchievedGoals {
                    await NotificationManager.shared.scheduleNotification(
                        title: "Goal achieved",
                        body: "You achieved your \(goalTitle) goal.",
                        secondsFromNow: 2
                    )
                }
            }
            dismiss()
        } catch {
            viewContext.rollback()
            isShowingValidationAlert = true
        }
    }
}

struct ReceiptTextRecognizer {
    static func analyze(images: [UIImage]) throws -> ReceiptScanResult {
        var lines: [String] = []
        for image in images {
            lines.append(contentsOf: try recognizedLines(in: image))
        }

        let recognizedText = lines.joined(separator: "\n")
        return ReceiptScanResult(
            merchant: merchant(from: lines),
            total: total(from: lines),
            date: .now,
            itemCount: lines.count,
            recognizedText: recognizedText
        )
    }

    private static func recognizedLines(in image: UIImage) throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap {
            $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
    }

    private static func merchant(from lines: [String]) -> String {
        lines.first { line in
            let lowercased = line.lowercased()
            return line.rangeOfCharacter(from: .letters) != nil &&
                !lowercased.contains("total") &&
                !lowercased.contains("subtotal") &&
                !lowercased.contains("tax")
        } ?? "Scanned Receipt"
    }

    private static func total(from lines: [String]) -> Double {
        let preferredLines = lines.filter {
            let lowercased = $0.lowercased()
            return lowercased.contains("total") ||
                lowercased.contains("amount due") ||
                lowercased.contains("balance")
        }

        let preferredAmounts = preferredLines.flatMap(amounts(in:))

        // A total line can also contain an item count. Its final monetary
        // value is the bill total, for example: "Items 3  Total LKR 2,450.00".
        if let preferredTotal = preferredAmounts.last {
            return preferredTotal
        }

        return lines
            .flatMap(amounts(in:))
            .max() ?? 0
    }

    private nonisolated static func amounts(in text: String) -> [Double] {
        let pattern = #"(?<![0-9])([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{2})?|[0-9]+(?:\.[0-9]{2})?)(?![0-9])"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard let amountRange = Range(match.range(at: 1), in: text) else {
                return nil
            }

            return Double(text[amountRange].replacingOccurrences(of: ",", with: ""))
        }
    }
}

struct ReceiptScannerScreen: View {
    @State private var reviewScan: ReceiptScanResult?
    @State private var isShowingScanner = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isAnalyzing = false
    @State private var isShowingAnalysisError = false
    @State private var isShowingCameraAccessAlert = false

    var body: some View {
        NavigationStack {
            if let reviewScan {
                ReceiptConfirmationScreen(scan: reviewScan)
            } else {
                VStack(spacing: 24) {
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 74))
                    .foregroundStyle(.blue)
                    .frame(width: 130, height: 130)
                    .background(Color.blue.opacity(0.10))
                    .clipShape(Circle())

                VStack(spacing: 8) {
                    Text("Scan Receipt")
                        .font(.largeTitle.bold())
                    Text("Use VisionKit to capture a receipt and confirm the transaction details before saving.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: openCamera) {
                    Label(
                        isAnalyzing ? "Identifying Receipt" : "Open Camera",
                        systemImage: "camera.viewfinder"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAnalyzing)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose from Gallery", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isAnalyzing)

                if isAnalyzing {
                    ProgressView("Reading receipt values with Vision")
                }
            }
            .padding(24)
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingScanner) {
                DocumentCameraView { images in
                    Task {
                        await processReceiptImages(images)
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newPhoto in
                guard let newPhoto else { return }

                Task {
                    guard let data = try? await newPhoto.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        isShowingAnalysisError = true
                        return
                    }
                    await processReceiptImages([image])
                    selectedPhoto = nil
                }
            }
            .alert("Could Not Read Receipt", isPresented: $isShowingAnalysisError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Try scanning the receipt again in better lighting.")
            }
            .alert("Camera Access Needed", isPresented: $isShowingCameraAccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Allow camera access in Settings to scan a receipt, or select a receipt image from your gallery.")
            }
            }
        }
    }

    private func openCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isShowingScanner = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        isShowingScanner = true
                    } else {
                        isShowingCameraAccessAlert = true
                    }
                }
            }
        case .denied, .restricted:
            isShowingCameraAccessAlert = true
        @unknown default:
            isShowingCameraAccessAlert = true
        }
    }

    private func processReceiptImages(_ images: [UIImage]) async {
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            reviewScan = try ReceiptTextRecognizer.analyze(images: images)
        } catch {
            isShowingAnalysisError = true
        }
    }
}

struct ReceiptConfirmationScreen: View {
    let scan: ReceiptScanResult
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("activeUserEmail") private var activeUserEmail = ""
    @State private var merchant: String
    @State private var total: String
    @State private var category = "Food"
    @State private var isShowingValidationAlert = false

    init(scan: ReceiptScanResult) {
        self.scan = scan
        _merchant = State(initialValue: scan.merchant)
        _total = State(initialValue: scan.total == 0 ? "" : String(format: "%.2f", scan.total))
    }

    var body: some View {
        Form {
            Section("Review Transaction") {
                Text("The detected total will be saved as an expense. You can edit any field before saving.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("Merchant", text: $merchant)
                    TextField("Total", text: $total)
                        .keyboardType(.decimalPad)
                    CategoryPicker(category: $category)
                    Text(scan.date, format: .dateTime.month().day().year())
                    Text("\(scan.itemCount) text lines identified by Vision")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if scan.recognizedText.isEmpty == false {
                    Section("Recognized Receipt Text") {
                        Text(scan.recognizedText)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Review Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Expense", action: saveTransaction)
                }
            }
            .alert("Enter a merchant and valid total.", isPresented: $isShowingValidationAlert) {
                Button("OK", role: .cancel) { }
            }
    }

    private func saveTransaction() {
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedMerchant.isEmpty == false,
              let enteredTotal = Double(total),
              enteredTotal > 0,
              activeUserEmail.isEmpty == false else {
            isShowingValidationAlert = true
            return
        }

        let transaction = NSEntityDescription.insertNewObject(
            forEntityName: "Transaction",
            into: viewContext
        )
        transaction.setValue(trimmedMerchant, forKey: "title")
        transaction.setValue(category, forKey: "category")
        transaction.setValue(-enteredTotal, forKey: "amount")
        transaction.setValue(scan.date, forKey: "createdAt")
        transaction.setValue(activeUserEmail, forKey: "userEmail")

        do {
            let newlyAchievedGoals = markNewlyAchievedGoals(
                in: viewContext,
                userEmail: activeUserEmail
            )
            try viewContext.save()

            Task {
                for goalTitle in newlyAchievedGoals {
                    await NotificationManager.shared.scheduleNotification(
                        title: "Goal achieved",
                        body: "You achieved your \(goalTitle) goal.",
                        secondsFromNow: 1
                    )
                }
            }
            dismiss()
        } catch {
            viewContext.rollback()
            isShowingValidationAlert = true
        }
    }
}

struct DocumentCameraView: UIViewControllerRepresentable {
    let onComplete: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) { }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: ([UIImage]) -> Void
        let dismiss: DismissAction

        init(onComplete: @escaping ([UIImage]) -> Void, dismiss: DismissAction) {
            self.onComplete = onComplete
            self.dismiss = dismiss
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            onComplete(images)
            dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            dismiss()
        }
    }
}
