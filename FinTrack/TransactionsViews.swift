import SwiftUI
import VisionKit
import UIKit
import CoreData

struct TransactionsScreen: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("activeUserEmail") private var activeUserEmail = ""
    @State private var isShowingExpense = false
    @State private var isShowingIncome = false
    @State private var isShowingReceiptScanner = false
    @State private var receiptScan: ReceiptScanResult?
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
                ReceiptScannerScreen(scanResult: $receiptScan)
            }
            .sheet(item: $receiptScan) { scan in
                ReceiptConfirmationScreen(scan: scan)
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
                    Picker("Category", selection: $category) {
                        Text("Food").tag("Food")
                        Text("Transport").tag("Transport")
                        Text("Bills").tag("Bills")
                        Text("Salary").tag("Salary")
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Add \(kind.rawValue)")
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
                Picker("Category", selection: $category) {
                    Text("Food").tag("Food")
                    Text("Transport").tag("Transport")
                    Text("Bills").tag("Bills")
                    Text("Salary").tag("Salary")
                }
            }

            Section {
                Button("Delete Transaction", role: .destructive, action: deleteTransaction)
            }
        }
        .navigationTitle("Edit Transaction")
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
    @State private var isShowingAddRecurring = false

    var body: some View {
        List {
            ContentUnavailableView(
                "No Recurring Transactions",
                systemImage: "repeat",
                description: Text("Add a recurring transaction to see it here.")
            )
        }
        .navigationTitle("Recurring")
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
    @State private var name = ""
    @State private var amount = ""
    @State private var cadence = "Monthly"
    @State private var isExpense = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Recurring Transaction") {
                    Toggle("Expense", isOn: $isExpense)
                    TextField("Name", text: $name)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    Picker("Repeats", selection: $cadence) {
                        Text("Weekly").tag("Weekly")
                        Text("Monthly").tag("Monthly")
                        Text("Yearly").tag("Yearly")
                    }
                }
            }
            .navigationTitle("Add Recurring")
            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") { dismiss() }
//                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

                        guard trimmedName.isEmpty == false else { return }

                        Task {
                            await NotificationManager.shared.scheduleRecurringReminder(
                                name: trimmedName,
                                cadence: cadence
                            )
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ReceiptScannerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var scanResult: ReceiptScanResult?
    @State private var isShowingScanner = false

    var body: some View {
        NavigationStack {
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

                Button { isShowingScanner = true } label: {
                    Label("Open Camera", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Use Sample Receipt") {
                    scanResult = ReceiptScanResult(merchant: "Market Fresh", total: 42.70, date: Date(), itemCount: 1)
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(24)
            .navigationTitle("Scan Receipt")
            .sheet(isPresented: $isShowingScanner) {
                DocumentCameraView { pages in
                    scanResult = ReceiptScanResult(merchant: "Scanned Receipt", total: 0, date: Date(), itemCount: pages)
                    dismiss()
                }
            }
        }
    }
}

struct ReceiptConfirmationScreen: View {
    let scan: ReceiptScanResult
    @Environment(\.dismiss) private var dismiss
    @State private var merchant: String
    @State private var total: String

    init(scan: ReceiptScanResult) {
        self.scan = scan
        _merchant = State(initialValue: scan.merchant)
        _total = State(initialValue: scan.total == 0 ? "" : String(format: "%.2f", scan.total))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Receipt Confirmation") {
                    TextField("Merchant", text: $merchant)
                    TextField("Total", text: $total)
                        .keyboardType(.decimalPad)
                    Text(scan.date, format: .dateTime.month().day().year())
                    Text("Pages scanned: \(scan.itemCount)")
                }
            }
            .navigationTitle("Confirm Receipt")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dismiss() }
                }
            }
        }
    }
}

struct DocumentCameraView: UIViewControllerRepresentable {
    let onComplete: (Int) -> Void
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
        let onComplete: (Int) -> Void
        let dismiss: DismissAction

        init(onComplete: @escaping (Int) -> Void, dismiss: DismissAction) {
            self.onComplete = onComplete
            self.dismiss = dismiss
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onComplete(scan.pageCount)
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
