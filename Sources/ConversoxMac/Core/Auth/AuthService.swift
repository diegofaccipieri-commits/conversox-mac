import Foundation

@MainActor
final class AuthService {
    static let shared = AuthService()

    private let keychain = KeychainStore.shared
    private let httpClient = HTTPClient()
    private let sessionKey = "conversox.session"

    private init() {}

    func signIn(apiKey: String, authSource: String) async throws -> PersistedSession {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw AuthError.missingAPIKey }

        let source = authSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? AppConfig.shared.defaultAuthSource
            : authSource.trimmingCharacters(in: .whitespacesAndNewlines)

        let bootstrap = PersistedSession(
            apiKey: trimmedKey,
            authSource: source,
            user: UserProfile(
                id: "api",
                name: "Conversox API",
                email: "api@system",
                tenant: source,
                role: "api",
                connections: []
            )
        )

        let session = PersistedSession(
            apiKey: trimmedKey,
            authSource: source,
            user: try await resolveUserProfile(using: bootstrap)
        )
        try save(session)
        return session
    }

    func restoreSession() throws -> PersistedSession? {
        guard let data = try keychain.get(for: sessionKey) else { return nil }
        return try JSONDecoder().decode(PersistedSession.self, from: data)
    }

    func logout(_ session: PersistedSession?) async {
        keychain.delete(for: sessionKey)
    }

    private func resolveUserProfile(using session: PersistedSession) async throws -> UserProfile {
        do {
            let me: MeResponse = try await httpClient.request("/api/me.php", session: session)
            return me.asUserProfile(authSource: session.authSource)
        } catch APIError.httpStatus(404, _) {
            // /api/me.php is a required server follow-up. Until it exists, validate the key
            // through the Conversox API and use a constrained local profile.
            let _: ChatListResponse = try await httpClient.request("/Conversox/api/chats.php?_t=\(Int(Date().timeIntervalSince1970))", session: session)
            return session.user
        }
    }

    private func save(_ session: PersistedSession) throws {
        let data = try JSONEncoder().encode(session)
        try keychain.set(data, for: sessionKey)
    }
}

enum AuthError: Error {
    case missingAPIKey
}
