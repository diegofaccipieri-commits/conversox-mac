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

    private let authService = AuthService.shared

    func restoreSessionIfAvailable() async {
        do {
            guard let restored = try authService.restoreSession() else {
                state = .signedOut
                return
            }

            session = restored
            state = .signedIn
        } catch {
            state = .signedOut
            lastError = "Não foi possível restaurar sessão."
        }
    }

    func signIn(apiKey: String, authSource: String) async {
        do {
            let newSession = try await authService.signIn(apiKey: apiKey, authSource: authSource)
            session = newSession
            state = .signedIn
        } catch {
            lastError = "Falha ao validar X-API-Key."
        }
    }

    func signOut() async {
        await authService.logout(session)
        session = nil
        state = .signedOut
    }
}
