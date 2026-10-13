import SwiftUI

struct HomeScreen: View {
    let userName: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeHeader(userName: userName)
                    BalanceCard()
                    QuickActionsRow()
                    BudgetProgressCard()
                    RecurringSummaryCard()
                    RecentTransactionsSection(transactions: SampleData.transactions)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
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

            Image(systemName: "person.crop.circle")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 44, height: 44)
                .background(.background)
                .clipShape(Circle())
        }
    }
}

struct BalanceCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total Balance")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                    CurrencyText(amount: 12460.75)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))
            }

            HStack(spacing: 14) {
                BalanceMetric(title: "Income", amount: 4280, systemImage: "arrow.down.left.circle.fill", tint: .green)
                BalanceMetric(title: "Spent", amount: 1840, systemImage: "arrow.up.right.circle.fill", tint: .orange)
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
            NavigationLink { ReceiptScannerScreen(scanResult: .constant(nil)) } label: {
                QuickActionContent(title: "Receipt", systemImage: "doc.viewfinder")
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

struct BudgetProgressCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly Budget")
                        .font(.headline)
                    HStack(spacing: 3) {
                        CurrencyText(amount: 1840)
                        Text("of")
                        CurrencyText(amount: 2500)
                        Text("spent")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text("74%")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }

            ProgressView(value: 0.74)
                .tint(.blue)
                .scaleEffect(x: 1, y: 1.6, anchor: .center)

            HStack {
                Label("On track", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Spacer()
                CurrencyText(amount: 660)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))
        }
        .padding(18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct RecurringSummaryCard: View {
    var body: some View {
        NavigationLink {
            RecurringTransactionsScreen()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "repeat.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 48, height: 48)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recurring Transactions")
                        .font(.headline)
                    Text("3 upcoming this month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
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
