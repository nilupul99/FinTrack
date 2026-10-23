import SwiftUI

struct NotificationsScreen: View {
    @AppStorage("activeUserEmail") private var activeUserEmail = ""
    @State private var notifications: [StoredNotification] = []

    var body: some View {
        List {
            if notifications.isEmpty {
                ContentUnavailableView(
                    "No Notifications Yet",
                    systemImage: "bell.slash",
                    description: Text("Your sign-in, budget, and recurring reminders will appear here.")
                )
            } else {
                Section("Recent") {
                    ForEach(notifications) { notification in
                        NotificationHistoryRow(
                            title: notification.title,
                            message: notification.message,
                            date: notification.createdAt
                        )
                    }
                }

                Section {
                    Button("Clear Notification History", role: .destructive) {
                        InAppNotificationStore.removeAll(for: activeUserEmail)
                        reloadNotifications()
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            reloadNotifications()
        }
    }

    private func reloadNotifications() {
        notifications = InAppNotificationStore.notifications(for: activeUserEmail)
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

struct NotificationHistoryRow: View {
    let title: String
    let message: String
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(date, format: .dateTime.day().month().year().hour().minute())
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
