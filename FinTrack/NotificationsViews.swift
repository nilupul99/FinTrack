import SwiftUI

struct NotificationsScreen: View {
    @AppStorage("signInNotificationsEnabled") private var signInNotificationsEnabled = true
    @AppStorage("budgetNotificationsEnabled") private var budgetNotificationsEnabled = true
    @AppStorage("recurringNotificationsEnabled") private var recurringNotificationsEnabled = true

    var body: some View {
        List {
            NotificationAlertSettings(
                signInNotificationsEnabled: $signInNotificationsEnabled,
                budgetNotificationsEnabled: $budgetNotificationsEnabled,
                recurringNotificationsEnabled: $recurringNotificationsEnabled
            )

            Section {
                Button {
                    Task {
                        await NotificationManager.shared.scheduleNotification(
                            title: "FinTrack reminder",
                            body: "Review your budget and recent transactions.",
                            secondsFromNow: 3
                        )
                    }
                } label: {
                    Label("Send Test Notification", systemImage: "paperplane.fill")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarBackButtonHidden(true)
    }
}

struct NotificationAlertSettings: View {
    @Binding var signInNotificationsEnabled: Bool
    @Binding var budgetNotificationsEnabled: Bool
    @Binding var recurringNotificationsEnabled: Bool

    var body: some View {
        Section("Alerts") {
            Toggle("Sign-in notifications", isOn: $signInNotificationsEnabled)
            Toggle("Budget warnings", isOn: $budgetNotificationsEnabled)
            Toggle("Recurring reminders", isOn: $recurringNotificationsEnabled)
        }
    }
}
