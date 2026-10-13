import SwiftUI

struct GoalsScreen: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GoalCard(title: "Emergency Fund", saved: 3200, target: 5000, icon: "shield.lefthalf.filled")
                    GoalCard(title: "Vacation", saved: 850, target: 2000, icon: "airplane.departure")
                    GoalCard(title: "New Laptop", saved: 600, target: 1500, icon: "laptopcomputer")
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Goals")
        }
    }
}

struct GoalCard: View {
    let title: String
    let saved: Double
    let target: Double
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    HStack(spacing: 3) {
                        CurrencyText(amount: saved)
                        Text("saved")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            ProgressView(value: saved / target)
                .tint(.blue)
            HStack(spacing: 3) {
                Text("Target:")
                CurrencyText(amount: target)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
