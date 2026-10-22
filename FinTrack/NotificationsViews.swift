import SwiftUI

struct NotificationsScreen: View {
    @AppStorage("signInNotificationsEnabled") private var signInNotificationsEnabled = true
    @AppStorage("budgetNotificationsEnabled") private var budgetNotificationsEnabled = true
    @AppStorage("recurringNotificationsEnabled") private var recurringNotificationsEnabled = true

    var body: some View {
        List {
            Section("Active Alerts") {
                if signInNotificationsEnabled {
                    NotificationMessageRow(
                        title: "Sign-in alerts",
                        message: "You will be notified when your account is signed in or out.",
                        systemImage: "person.badge.key.fill",
                        tint: .blue
                    )
                }

                if budgetNotificationsEnabled {
                    NotificationMessageRow(
                        title: "Budget warnings",
                        message: "You will be notified when an expense reaches a budget limit.",
                        systemImage: "chart.pie.fill",
                        tint: .orange
                    )
                }

                if recurringNotificationsEnabled {
                    NotificationMessageRow(
                        title: "Recurring reminders",
                        message: "You will be reminded about recurring transactions and payments.",
                        systemImage: "repeat.circle.fill",
                        tint: .purple
                    )
                }

                if !signInNotificationsEnabled &&
                    !budgetNotificationsEnabled &&
                    !recurringNotificationsEnabled {
                    ContentUnavailableView(
                        "No Alerts Enabled",
                        systemImage: "bell.slash",
                        description: Text("Turn on notification alerts in Settings to see them here.")
                    )
                }
            }


        }
        .navigationTitle("Notifications")
        .navigationBarBackButtonHidden(true)
    }
}

struct NotificationSettingsSection: View {
    @Binding var signInNotificationsEnabled: Bool
    @Binding var budgetNotificationsEnabled: Bool
    @Binding var recurringNotificationsEnabled: Bool

    var body: some View {
        Section("Notifications") {
            Toggle("Sign-in notifications", isOn: $signInNotificationsEnabled)
            Toggle("Budget warnings", isOn: $budgetNotificationsEnabled)
            Toggle("Recurring reminders", isOn: $recurringNotificationsEnabled)
        }
    }
}

struct NotificationMessageRow: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
