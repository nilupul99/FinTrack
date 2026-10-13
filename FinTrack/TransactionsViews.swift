import SwiftUI
import VisionKit
import UIKit

struct TransactionsScreen: View {
    @State private var isShowingExpense = false
    @State private var isShowingIncome = false
    @State private var isShowingReceiptScanner = false
    @State private var receiptScan: ReceiptScanResult?

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
                    ForEach(SampleData.transactions) { transaction in
                        TransactionRow(transaction: transaction)
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
    @State private var title = ""
    @State private var amount = ""
    @State private var category = "Food"
    @State private var notes = ""

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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await NotificationManager.shared.scheduleNotification(
                                title: "Transaction added",
                                body: "Your \(kind.rawValue.lowercased()) was added to FinTrack.",
                                secondsFromNow: 1
                            )
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RecurringTransactionsScreen: View {
    @State private var isShowingAddRecurring = false

    var body: some View {
        List {
            Section("Upcoming") {
                RecurringRow(title: "Netflix", cadence: "Monthly", amount: -15.99, icon: "play.tv.fill", tint: .red)
                RecurringRow(title: "Rent", cadence: "Monthly", amount: -1200, icon: "house.fill", tint: .blue)
                RecurringRow(title: "Salary", cadence: "Monthly", amount: 2850, icon: "banknote.fill", tint: .green)
            }
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await NotificationManager.shared.scheduleNotification(
                                title: "Recurring reminder set",
                                body: "FinTrack will remind you about this recurring transaction.",
                                secondsFromNow: 2
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
