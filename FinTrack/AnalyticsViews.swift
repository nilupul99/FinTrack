import SwiftUI

struct AnalyticsScreen: View {
    @State private var insights: [FinancialInsight] = []
    @State private var isLoading = false
    @AppStorage("insightsAPIURL") private var insightsAPIURL = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AnalyticsSummaryGrid()

                    Button { loadInsights() } label: {
                        Label("Refresh API Insights", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isLoading)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(insights) { insight in
                            InsightCard(insight: insight)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Analytics")
            .task {
                if insights.isEmpty {
                    loadInsights()
                }
            }
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
    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                AnalyticsMetricCard(title: "Cash Flow", value: "+2.4K", icon: "waveform.path.ecg", tint: .green)
                AnalyticsMetricCard(title: "Top Spend", value: "Food", icon: "fork.knife", tint: .orange)
            }
            GridRow {
                AnalyticsMetricCard(title: "Savings", value: "18%", icon: "arrow.up.forward", tint: .blue)
                AnalyticsMetricCard(title: "Risk", value: "Low", icon: "shield.fill", tint: .purple)
            }
        }
    }
}

struct AnalyticsMetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let tint: Color

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
