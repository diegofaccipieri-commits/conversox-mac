import Foundation

@MainActor
enum AppBootstrap {
    static func bootstrap(sessionStore: SessionStore, chatsViewModel: ChatsViewModel) async {
        await NotificationPermissionManager.shared.requestAuthorizationIfNeeded()
        await sessionStore.restoreSessionIfAvailable()

        guard sessionStore.state == .signedIn else { return }

        await chatsViewModel.startRealtime()
    }
}
