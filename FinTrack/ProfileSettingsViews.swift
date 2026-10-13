import SwiftUI

struct ProfileScreen: View {
    let userName: String
    @Binding var isAuthenticated: Bool
    @Binding var authRoute: AuthRoute

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 58))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userName.isEmpty ? "FinTrack User" : userName)
                                .font(.title3.bold())
                            Text("Personal finance dashboard")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Account") {
                    NavigationLink { NotificationsScreen() } label: {
                        Label("Notifications", systemImage: "bell.badge.fill")
                    }
                    NavigationLink { SettingsScreen() } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        isAuthenticated = false
                        authRoute = .login
                        Task {
                            await NotificationManager.shared.scheduleNotification(
                                title: "FinTrack signed out",
                                body: "Your finance dashboard was locked.",
                                secondsFromNow: 1
                            )
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

struct NotificationsScreen: View {
    @AppStorage("signInNotificationsEnabled") private var signInNotificationsEnabled = true
    @AppStorage("budgetNotificationsEnabled") private var budgetNotificationsEnabled = true
    @AppStorage("recurringNotificationsEnabled") private var recurringNotificationsEnabled = true

    var body: some View {
        List {
            Section("Alerts") {
                Toggle("Sign-in notifications", isOn: $signInNotificationsEnabled)
                Toggle("Budget warnings", isOn: $budgetNotificationsEnabled)
                Toggle("Recurring reminders", isOn: $recurringNotificationsEnabled)
            }

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
    }
}

struct SettingsScreen: View {
    @AppStorage("currencyCode") private var currencyCode = "USD"
    @AppStorage("insightsAPIURL") private var insightsAPIURL = ""
    @AppStorage("faceIDEnabled") private var faceIDEnabled = true
    @AppStorage("receiptScanningEnabled") private var receiptScanningEnabled = true

    private let currencies = ["USD", "LKR", "GBP", "EUR", "AUD", "CAD", "INR", "JPY"]

    var body: some View {
        Form {
            Section("Security") {
                Toggle("Face ID", isOn: $faceIDEnabled)
                Toggle("Receipt scanning", isOn: $receiptScanningEnabled)
            }

            Section("Currency") {
                Picker("App Currency", selection: $currencyCode) {
                    ForEach(currencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                HStack {
                    Text("Preview")
                    Spacer()
                    CurrencyText(amount: 12460.75)
                        .foregroundStyle(.secondary)
                }
            }

            Section("API Insights") {
                TextField("https://api.example.com/insights", text: $insightsAPIURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                Text("Leave blank to use sample insights while the prototype API is not connected.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}
