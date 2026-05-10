import Foundation

@MainActor
final class SessionStore: ObservableObject {
    enum State {
        case loading
        case signedOut
        case signedIn
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var session: PersistedSession?
    @Published var lastError: String?
    @Published var sessionNotice: String?

    private let authService = AuthService.shared

    func restoreSessionIfAvailable() async {
        do {
            guard let restored = try authService.restoreSession() else {
                state = .signedOut
                return
            }

            session = restored
            state = .signedIn
            sessionNotice = await sendAuthorizationNotice(for: restored)
        } catch {
            state = .signedOut
            lastError = "Não foi possível restaurar sessão."
            sessionNotice = nil
        }
    }

    func signIn(apiKey: String, authSource: String) async {
        do {
            let newSession = try await authService.signIn(apiKey: apiKey, authSource: authSource)
            session = newSession
            state = .signedIn
            lastError = nil
            sessionNotice = await sendAuthorizationNotice(for: newSession)
        } catch let error as ConversoxError {
            lastError = "\(error.userMessage) \(error.recommendedAction)"
            sessionNotice = nil
        } catch {
            lastError = "Falha ao validar X-API-Key."
            sessionNotice = nil
        }
    }

    func signOut() async {
        await authService.logout(session)
        session = nil
        state = .signedOut
        sessionNotice = nil
    }

    private func sendAuthorizationNotice(for session: PersistedSession) async -> String? {
        switch await authService.probeSendAuthorization(using: session) {
        case .allowed:
            return nil
        case .blocked:
            return "A chave atual consegue listar chats, mas o backend está negando envio em send.php para essa X-API-Key."
        case .unknown:
            return "Nao foi possivel validar agora se esta X-API-Key tem permissao de envio."
        }
    }
}
