import Foundation
import Security

struct SignUpResult: Sendable {
    let user: AuthenticatedUser
    let isSignedIn: Bool
}

struct AuthenticatedUser: Decodable, Sendable {
    let email: String
    private let name: String?

    enum CodingKeys: String, CodingKey {
        case email
        case userMetadata = "user_metadata"
    }

    private enum MetadataKeys: String, CodingKey {
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = try container.decode(String.self, forKey: .email)

        if let metadata = try? container.nestedContainer(
            keyedBy: MetadataKeys.self,
            forKey: .userMetadata
        ) {
            name = try? metadata.decode(String.self, forKey: .name)
        } else {
            name = nil
        }
    }

    var displayName: String {
        name ?? email
    }
}

enum SupabaseAuthError: LocalizedError {
    case invalidResponse
    case missingSession
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The authentication service returned an invalid response."
        case .missingSession:
            "Your account was created, but you need to confirm your email before signing in."
        case let .server(message):
            message
        }
    }
}

struct SupabaseAuthService {
    static let shared = SupabaseAuthService()

    private let baseURL = URL(string: "https://lgspwlcdhugqvuchgmyx.supabase.co")!
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxn" +
        "c3B3bGNkaHVncXZ1Y2hnbXl4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2NzM1MzMsImV4cCI6MjEwODI0OTUzM30." +
        "w29yTsSB4Q5V65VHUZ118I46s2gkcXqlqaAe0Se4x70"

    var hasSavedSession: Bool {
        SecureSessionStore.load() != nil
    }

    func signUp(name: String, email: String, password: String) async throws -> SignUpResult {
        let request = SignUpRequest(email: email, password: password, data: ["name": name])
        let response: AuthResponse = try await send(
            path: "auth/v1/signup",
            method: "POST",
            body: request
        )

        guard let user = response.user else {
            throw SupabaseAuthError.invalidResponse
        }

        if let session = response.session {
            try SecureSessionStore.save(session)
            return SignUpResult(user: user, isSignedIn: true)
        }

        return SignUpResult(user: user, isSignedIn: false)
    }

    func signIn(email: String, password: String) async throws -> AuthenticatedUser {
        let request = SignInRequest(email: email, password: password)
        let response: AuthResponse = try await send(
            path: "auth/v1/token?grant_type=password",
            method: "POST",
            body: request
        )

        guard let user = response.user, let session = response.session else {
            throw SupabaseAuthError.missingSession
        }

        try SecureSessionStore.save(session)
        return user
    }

    func restoreSession() async -> AuthenticatedUser? {
        guard SecureSessionStore.load() != nil else {
            return nil
        }

        do {
            let response: AuthResponse = try await send(
                path: "auth/v1/token?grant_type=refresh_token",
                method: "POST",
                body: RefreshRequest(refreshToken: SecureSessionStore.load()?.refreshToken ?? "")
            )
            guard let user = response.user, let session = response.session else {
                SecureSessionStore.clear()
                return nil
            }

            try SecureSessionStore.save(session)
            return user
        } catch {
            SecureSessionStore.clear()
            return nil
        }
    }

    func signOut() async {
        guard let session = SecureSessionStore.load() else {
            return
        }

        var request = makeRequest(path: "auth/v1/logout", method: "POST")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: request)
        SecureSessionStore.clear()
    }

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body
    ) async throws -> Response {
        var request = makeRequest(path: path, method: method)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let failure = try? JSONDecoder().decode(AuthFailure.self, from: data)
            throw SupabaseAuthError.server(
                failure?.message ?? "Authentication failed. Please check your details and try again."
            )
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func makeRequest(path: String, method: String) -> URLRequest {
        let url = URL(string: "\(baseURL.absoluteString)/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}

private struct SignUpRequest: Encodable {
    let email: String
    let password: String
    let data: [String: String]
}

private struct SignInRequest: Encodable {
    let email: String
    let password: String
}

private struct RefreshRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct AuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let user: AuthenticatedUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }

    var session: SecureSession? {
        guard let accessToken, let refreshToken else {
            return nil
        }
        return SecureSession(accessToken: accessToken, refreshToken: refreshToken)
    }
}

private struct AuthFailure: Decodable {
    let message: String?

    enum CodingKeys: String, CodingKey {
        case message
        case msg
        case error
        case errorDescription = "error_description"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .msg)
            ?? container.decodeIfPresent(String.self, forKey: .error)
            ?? container.decodeIfPresent(String.self, forKey: .errorDescription)
    }
}

private struct SecureSession: Codable {
    let accessToken: String
    let refreshToken: String
}

private enum SecureSessionStore {
    private static let service = "com.nilupul.FinTrack"
    private static let account = "supabase-session"

    static func save(_ session: SecureSession) throws {
        let data = try JSONEncoder().encode(session)
        clear()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw SupabaseAuthError.server("Could not securely store your sign-in session.")
        }
    }

    static func load() -> SecureSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(SecureSession.self, from: data)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
