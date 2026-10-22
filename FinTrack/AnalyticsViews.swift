import SwiftUI
import CoreData

struct AnalyticsScreen: View {
    @AppStorage("activeUserEmail") private var activeUserEmail = ""
    @AppStorage("insightsAPIURL") private var insightsAPIURL = ""
    @State private var insights: [FinancialInsight] = []
    @State private var isLoading = false
    @FetchRequest private var savedTransactions: FetchedResults<NSManagedObject>

    init() {
        _savedTransactions = FetchRequest(fetchRequest: makeTransactionFetchRequest(), animation: .default)
    }

    private var transactions: [NSManagedObject] {
        savedTransactions.filter { $0.value(forKey: "userEmail") as? String == activeUserEmail }
    }

    private var income: Double {
        transactions.reduce(0) { $0 + max($1.value(forKey: "amount") as? Double ?? 0, 0) }
    }

    private var expenses: Double {
        transactions.reduce(0) { $0 + min($1.value(forKey: "amount") as? Double ?? 0, 0) * -1 }
    }

    private var topSpendCategory: String {
        let expenses = transactions.filter { ($0.value(forKey: "amount") as? Double ?? 0) < 0 }
        return Dictionary(grouping: expenses) { $0.value(forKey: "category") as? String ?? "Other" }
            .max { $0.value.count < $1.value.count }?
            .key ?? "—"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AnalyticsSummaryGrid(
                        cashFlow: income - expenses,
                        topSpend: topSpendCategory,
                        savingsRate: income == 0 ? 0 : (income - expenses) / income
                    )

                    if insightsAPIURL.isEmpty == false {
                        Button { loadInsights() } label: {
                            Label("Refresh API Insights", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isLoading)
                    }

                    if insights.isEmpty == false {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(insights) { insight in
                                InsightCard(insight: insight)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Analytics")
        }
    }

    private func loadInsights() {
        isLoading = true
        Task {
            let service = InsightsService(apiURLString: insightsAPIURL)
            let result = await service.fetchInsights()
            await MainActor.run {
                insights = result
                isLoading = false
            }
        }
    }
}

struct AnalyticsSummaryGrid: View {
    let cashFlow: Double
    let topSpend: String
    let savingsRate: Double

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                AnalyticsMetricCard(title: "Cash Flow", amount: cashFlow, icon: "waveform.path.ecg", tint: cashFlow >= 0 ? .green : .orange)
                AnalyticsMetricCard(title: "Top Spend", value: topSpend, icon: "fork.knife", tint: .orange)
            }
            GridRow {
                AnalyticsMetricCard(title: "Savings", value: savingsRate.formatted(.percent.precision(.fractionLength(0))), icon: "arrow.up.forward", tint: .blue)
                AnalyticsMetricCard(title: "Transactions", value: "Live", icon: "chart.bar.fill", tint: .purple)
            }
        }
    }
}

struct AnalyticsMetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let tint: Color

    init(title: LocalizedStringKey, value: String, icon: String, tint: Color) {
        self.title = title
        self.value = value
        self.icon = icon
        self.tint = tint
    }

    init(title: LocalizedStringKey, amount: Double, icon: String, tint: Color) {
        self.init(title: title, value: amount.formatted(.number.precision(.fractionLength(2))), icon: icon, tint: tint)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct InsightCard: View {
    let insight: FinancialInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.systemImage)
                .foregroundStyle(insight.tint)
                .frame(width: 38, height: 38)
                .background(insight.tint.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(insight.title)
                    .font(.headline)
                Text(insight.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
