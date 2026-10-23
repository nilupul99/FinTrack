import SwiftUI

struct ProfileScreen: View {
    let userName: String
    @Binding var isAuthenticated: Bool
    @Binding var authRoute: AuthRoute

    var body: some View {
        NavigationStack {
            List {
                ProfileHeaderSection(userName: userName)

                Section {
                    Button(role: .destructive) {
                        isAuthenticated = false
                        authRoute = .login
                        Task {
                            await SupabaseAuthService.shared.signOut()
                            await NotificationManager.shared.scheduleSignOutNotification()
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ProfileHeaderSection: View {
    let userName: String

    var body: some View {
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
    }
}
