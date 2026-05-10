import Foundation

@MainActor
final class AuthService {
    static let shared = AuthService()

    enum SendAuthorizationStatus {
        case allowed
        case blocked
        case unknown
    }

    private let keychain = KeychainStore.shared
    private let api = ConversoxAPI()
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

    func probeSendAuthorization(using session: PersistedSession) async -> SendAuthorizationStatus {
        do {
            let _: ConversoxHTTPResponse<Data> = try await api.postJSONNoContent(
                .send,
                body: [String: String](),
                session: session,
                timeout: 10
            )
            return .allowed
        } catch let error as ConversoxError {
            if error.httpStatus == 401 || error.backendError == "unauthorized" || error.backendError == "not_authenticated" {
                return .blocked
            }
            return .allowed
        } catch {
            return .unknown
        }
    }

    private func resolveUserProfile(using session: PersistedSession) async throws -> UserProfile {
        do {
            let response: ConversoxHTTPResponse<MeResponse> = try await api.getJSON(.me, session: session, timeout: 10)
            return response.value.asUserProfile(authSource: session.authSource)
        } catch let error as ConversoxError where error.httpStatus == 404 {
            // /api/me.php is a required server follow-up. Until it exists, validate the key
            // through the Conversox API and use a constrained local profile.
            let _: ConversoxHTTPResponse<ChatListResponse> = try await api.getJSON(
                .chats,
                queryItems: [URLQueryItem(name: "_t", value: String(Int(Date().timeIntervalSince1970)))],
                session: session,
                timeout: 10
            )
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
