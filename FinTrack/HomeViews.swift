import SwiftUI
import CoreData

@MainActor
struct HomeScreen: View {
    let userName: String
    @AppStorage("activeUserEmail") private var activeUserEmail = ""
    @FetchRequest private var savedTransactions: FetchedResults<NSManagedObject>
    init(userName: String) {
        self.userName = userName
        _savedTransactions = FetchRequest(fetchRequest: makeTransactionFetchRequest(), animation: .default)
    }

    private var transactions: [NSManagedObject] {
        savedTransactions.filter { $0.value(forKey: "userEmail") as? String == activeUserEmail }
    }

    private var income: Double {
        transactions.reduce(0) { $0 + max($1.value(forKey: "amount") as? Double ?? 0, 0) }
    }

    private var spent: Double {
        transactions.reduce(0) { $0 + min($1.value(forKey: "amount") as? Double ?? 0, 0) * -1 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeHeader(userName: userName)
                    BalanceCard(balance: income - spent, income: income, spent: spent)
                    QuickActionsRow()
                    SpendingSummaryCard(spent: spent)
                    RecentTransactionsSection(transactions: transactions.map(TransactionRowData.init(managedObject:)))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct HomeHeader: View {
    let userName: String

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Good Morning")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(userName.isEmpty ? "FinTrack User" : userName)
                    .font(.largeTitle.bold())
            }

            Spacer()

            NavigationLink {
                NotificationsScreen()
            } label: {
                Image(systemName: "bell.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(.background)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Notifications")
        }
    }
}

struct BalanceCard: View {
    let balance: Double
    let income: Double
    let spent: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total Balance")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                    CurrencyText(amount: balance)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))
            }

            HStack(spacing: 14) {
                BalanceMetric(title: "Income", amount: income, systemImage: "arrow.down.left.circle.fill", tint: .green)
                BalanceMetric(title: "Spent", amount: spent, systemImage: "arrow.up.right.circle.fill", tint: .orange)
            }
        }
        .padding(22)
        .background(LinearGradient(colors: [Color.blue, Color(red: 0.0, green: 0.42, blue: 0.95)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .blue.opacity(0.25), radius: 22, x: 0, y: 12)
    }
}

struct BalanceMetric: View {
    let title: LocalizedStringKey
    let amount: Double
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                CurrencyText(amount: amount)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct QuickActionsRow: View {
    @AppStorage("receiptScanningEnabled") private var receiptScanningEnabled = true

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink { AddTransactionScreen(kind: .expense) } label: {
                QuickActionContent(title: "Expense", systemImage: "minus.circle.fill")
            }
            NavigationLink { AddTransactionScreen(kind: .income) } label: {
                QuickActionContent(title: "Income", systemImage: "plus.circle.fill")
            }
            NavigationLink { RecurringTransactionsScreen() } label: {
                QuickActionContent(title: "Recurring", systemImage: "repeat.circle.fill")
            }
            if receiptScanningEnabled {
                NavigationLink { ReceiptScannerScreen() } label: {
                    QuickActionContent(title: "Receipt", systemImage: "doc.viewfinder")
                }
            }
        }
    }
}

struct QuickActionContent: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.12))
                .clipShape(Circle())
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .foregroundStyle(.blue)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct SpendingSummaryCard: View {
    let spent: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Expenses")
                .font(.headline)
            CurrencyText(amount: spent)
                .font(.title2.bold())
            Text(spent == 0 ? "Add an expense to begin tracking." : "Based on your saved transactions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct RecentTransactionsSection: View {
    let transactions: [TransactionRowData]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") { TransactionsScreen() }
                    .font(.subheadline.weight(.semibold))
            }

            if transactions.isEmpty {
                ContentUnavailableView(
                    "No Transactions Yet",
                    systemImage: "tray",
                    description: Text("Your activity will appear here after you add a transaction.")
                )
                .padding()
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(transactions) { transaction in
                        TransactionRow(transaction: transaction)

                        if transaction.id != transactions.last?.id {
                            Divider()
                                .padding(.leading, 58)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }
}
