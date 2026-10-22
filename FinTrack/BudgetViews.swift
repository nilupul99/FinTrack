import SwiftUI
import CoreData

struct BudgetScreen: View {
    @AppStorage("activeUserEmail") private var activeUserEmail = ""
    @FetchRequest private var savedTransactions: FetchedResults<NSManagedObject>

    init() {
        _savedTransactions = FetchRequest(fetchRequest: makeTransactionFetchRequest(), animation: .default)
    }

    private var categoryTotals: [(name: String, amount: Double)] {
        let expenses = savedTransactions.filter {
            ($0.value(forKey: "userEmail") as? String == activeUserEmail) &&
            ($0.value(forKey: "amount") as? Double ?? 0) < 0
        }

        let totals: [(name: String, amount: Double)] = Dictionary(grouping: expenses) {
            $0.value(forKey: "category") as? String ?? "Other"
        }
        .map { name, transactions in
            (name: name, amount: transactions.reduce(0) { $0 + abs($1.value(forKey: "amount") as? Double ?? 0) })
        }

        return totals.sorted { left, right in
            left.amount > right.amount
        }
    }

    private var totalSpent: Double {
        categoryTotals.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SpendingSummaryCard(spent: totalSpent)
                    Text("Expense Categories")
                        .font(.headline)

                    if categoryTotals.isEmpty {
                        ContentUnavailableView(
                            "No Expenses Yet",
                            systemImage: "chart.pie",
                            description: Text("Add an expense transaction to see your budget breakdown.")
                        )
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(categoryTotals, id: \.name) { category in
                                BudgetCategoryRow(
                                    name: category.name,
                                    spent: category.amount,
                                    share: totalSpent == 0 ? 0 : category.amount / totalSpent,
                                    tint: tint(for: category.name),
                                    icon: icon(for: category.name)
                                )
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Budget")
        }
    }

    private func tint(for category: String) -> Color {
        switch category {
        case "Food": .orange
        case "Transport": .blue
        case "Bills": .purple
        default: .pink
        }
    }

    private func icon(for category: String) -> String {
        switch category {
        case "Food": "fork.knife"
        case "Transport": "car.fill"
        case "Bills": "bolt.fill"
        default: "tag.fill"
        }
    }
}

struct BudgetCategoryRow: View {
    let name: String
    let spent: Double
    let share: Double
    let tint: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.headline)
                    CurrencyText(amount: spent)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(share, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.bold())
                    .foregroundStyle(tint)
            }

            ProgressView(value: share)
                .tint(tint)
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
