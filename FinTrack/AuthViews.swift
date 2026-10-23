import SwiftUI
import CoreData
import LocalAuthentication

struct AuthFlowView: View {
    @Binding var authRoute: AuthRoute
    @Binding var isAuthenticated: Bool
    @Binding var currentUserName: String
    let viewContext: NSManagedObjectContext

    var body: some View {
        switch authRoute {
        case .welcome:
            WelcomeScreen(authRoute: $authRoute)
        case .login:
            LoginScreen(
                authRoute: $authRoute,
                isAuthenticated: $isAuthenticated,
                currentUserName: $currentUserName,
                viewContext: viewContext
            )
        case .signUp:
            SignUpScreen(
                authRoute: $authRoute,
                isAuthenticated: $isAuthenticated,
                currentUserName: $currentUserName,
                viewContext: viewContext
            )
        case .faceID:
            FaceIDScreen(
                authRoute: $authRoute,
                isAuthenticated: $isAuthenticated,
                currentUserName: $currentUserName,
                viewContext: viewContext
            )
        }
    }
}

struct WelcomeScreen: View {
    @Binding var authRoute: AuthRoute

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer(minLength: 32)

                VStack(spacing: 18) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 92, weight: .semibold))
                        .foregroundStyle(.blue.gradient)
                        .symbolRenderingMode(.hierarchical)

                    VStack(spacing: 10) {
                        Text("FinTrack")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("A clear, secure way to track spending, budgets, receipts, goals, and financial insight.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(spacing: 14) {
                    Button { authRoute = .login } label: {
                        Label("Log In", systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button { authRoute = .signUp } label: {
                        Label("Create Account", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button { authRoute = .faceID } label: {
                        Label("Continue with Face ID", systemImage: "faceid")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.top, 4)
                }

                Spacer(minLength: 24)
            }
            .padding(24)
            .background(AuthBackground())
        }
    }
}

struct LoginScreen: View {
    @Binding var authRoute: AuthRoute
    @Binding var isAuthenticated: Bool
    @Binding var currentUserName: String
    let viewContext: NSManagedObjectContext
    @State private var email = ""
    @State private var password = ""
    @State private var alertMessage = ""
    @State private var isShowingAlert = false
    @AppStorage("activeUserEmail") private var activeUserEmail = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    AuthHeader(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "Welcome Back",
                        subtitle: "Log in to review your spending, budgets, receipts, and goals."
                    )

                    VStack(spacing: 16) {
                        AuthTextField(title: "Email", text: $email, systemImage: "envelope")
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)

                        AuthSecureField(title: "Password", text: $password)

                        Button { Task { await authenticateUser() } } label: {
                            Label("Log In", systemImage: "arrow.right.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

//                        Button { authRoute = .faceID } label: {
//                            Label("Use Face ID", systemImage: "faceid")
//                        }
//                        .font(.subheadline.weight(.semibold))
                    }
                    .padding(20)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .blue.opacity(0.10), radius: 24, x: 0, y: 12)

                    HStack(spacing: 4) {
                        Text("New to FinTrack?")
                            .foregroundStyle(.secondary)
                        Button("Create Account") { authRoute = .signUp }
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
            .background(AuthBackground())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Welcome") { authRoute = .welcome }
                }
            }
            .alert("Login Failed", isPresented: $isShowingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func authenticateUser() async {
        let normalizedEmail = email.normalizedEmail

        guard normalizedEmail.isEmpty == false, password.isEmpty == false else {
            showAlert("Enter your email and password.")
            return
        }

        do {
            let user = try await SupabaseAuthService.shared.signIn(
                email: normalizedEmail,
                password: password
            )
            completeSignIn(name: user.displayName, email: user.email, method: "password")
        } catch {
            showAlert(error.localizedDescription)
        }
    }

    private func completeSignIn(name: String, email: String, method: String) {
        currentUserName = name
        activeUserEmail = email
        isAuthenticated = true
        Task {
            let signInTime = Date.now.formatted(date: .omitted, time: .shortened)
            await NotificationManager.shared.scheduleSignInNotification(
                body: "You signed in with \(method) at \(signInTime)."
            )
        }
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        isShowingAlert = true
    }
}

struct SignUpScreen: View {
    @Binding var authRoute: AuthRoute
    @Binding var isAuthenticated: Bool
    @Binding var currentUserName: String
    let viewContext: NSManagedObjectContext
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @AppStorage("activeUserEmail") private var activeUserEmail = ""
    @State private var isShowingAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    AuthHeader(
                        systemImage: "wallet.pass.fill",
                        title: "Create Account",
                        subtitle: "Start with a secure profile for your financial activity."
                    )

                    VStack(spacing: 16) {
                        AuthTextField(title: "Full Name", text: $name, systemImage: "person")
                        AuthTextField(title: "Email", text: $email, systemImage: "envelope")
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        AuthSecureField(title: "Password", text: $password)

                        Button { Task { await createAccount() } } label: {
                            Label("Create Account", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(20)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .blue.opacity(0.10), radius: 24, x: 0, y: 12)

                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(.secondary)
                        Button("Log In") { authRoute = .login }
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
            .background(AuthBackground())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Welcome") { authRoute = .welcome }
                }
            }
            .alert(alertTitle, isPresented: $isShowingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func createAccount() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = email.normalizedEmail

        guard trimmedName.isEmpty == false, normalizedEmail.isEmpty == false, password.isEmpty == false else {
            showAlert(title: "Missing Details", message: "Enter your name, email, and password.")
            return
        }

        do {
            let result = try await SupabaseAuthService.shared.signUp(
                name: trimmedName,
                email: normalizedEmail,
                password: password
            )

            guard result.isSignedIn else {
                showAlert(
                    title: "Confirm Your Email",
                    message: "Your Supabase account was created. Confirm your email, then log in."
                )
                authRoute = .login
                return
            }

            currentUserName = result.user.displayName
            activeUserEmail = result.user.email
            isAuthenticated = true
            await NotificationManager.shared.scheduleSignInNotification(
                body: "Your account is ready. Start by adding your first transaction."
            )
        } catch {
            showAlert(title: "Sign Up Failed", message: error.localizedDescription)
        }
    }

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        isShowingAlert = true
    }
}

struct FaceIDScreen: View {
    @Binding var authRoute: AuthRoute
    @Binding var isAuthenticated: Bool
    @Binding var currentUserName: String
    let viewContext: NSManagedObjectContext
    @AppStorage("activeUserEmail") private var activeUserEmail = ""
    @State private var statusMessage = "Use Face ID or your device passcode to unlock FinTrack."
    @State private var isAuthenticating = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 40)

                Image(systemName: "faceid")
                    .font(.system(size: 86, weight: .regular))
                    .foregroundStyle(.blue)
                    .frame(width: 138, height: 138)
                    .background(Color.blue.opacity(0.10))
                    .clipShape(Circle())

                VStack(spacing: 10) {
                    Text("Face ID")
                        .font(.largeTitle.bold())
                    Text(statusMessage)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button { authenticateWithFaceID() } label: {
                    Label(isAuthenticating ? "Authenticating" : "Unlock FinTrack", systemImage: "lock.open.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAuthenticating)

                Button("Use Password Instead") { authRoute = .login }
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 24)
            }
            .padding(24)
            .background(AuthBackground())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Welcome") { authRoute = .welcome }
                }
            }
        }
    }

    private func authenticateWithFaceID() {
        isAuthenticating = true
        statusMessage = "Checking your saved session..."

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isAuthenticating = false
            statusMessage = error?.localizedDescription ?? "Face ID is not available on this device."
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your FinTrack finance dashboard.") { success, authenticationError in
            Task { @MainActor in
                guard success else {
                    isAuthenticating = false
                    statusMessage = authenticationError?.localizedDescription ?? "Authentication failed. Try again."
                    return
                }

                guard let user = await SupabaseAuthService.shared.restoreSession() else {
                    isAuthenticating = false
                    statusMessage = "Log in with your password once before using Face ID."
                    return
                }

                currentUserName = user.displayName
                activeUserEmail = user.email
                isAuthenticated = true
                isAuthenticating = false
                let signInTime = Date.now.formatted(date: .omitted, time: .shortened)
                await NotificationManager.shared.scheduleSignInNotification(
                    body: "You signed in with Face ID at \(signInTime)."
                )
            }
        }
    }
}
