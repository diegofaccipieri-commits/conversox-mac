import SwiftUI

@main
struct ConversoxMacApp: App {
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var chatsViewModel = ChatsViewModel()
    @StateObject private var updater = UpdaterManager.shared

    var body: some Scene {
        WindowGroup("Conversox") {
            RootView()
                .environmentObject(sessionStore)
                .environmentObject(chatsViewModel)
                .frame(minWidth: 980, minHeight: 700)
                .task {
                    await AppBootstrap.bootstrap(sessionStore: sessionStore, chatsViewModel: chatsViewModel)
                }
                .onOpenURL { url in
                    handleDeepLink(url, chatsViewModel: chatsViewModel)
                }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Buscar atualizações…") {
                    updater.checkForUpdates()
                }
                .keyboardShortcut("U", modifiers: [.command])
            }
        }
    }

    private func handleDeepLink(_ url: URL, chatsViewModel: ChatsViewModel) {
        let scheme = url.scheme?.lowercased()
        guard scheme == "conversox" || scheme == "conversoxmac" else { return }
        let host = url.host?.lowercased() ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        if host == "chat" {
            let code = pathComponents.first
                ?? URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "code" })?.value
            guard let code, !code.isEmpty else { return }
            Task { await chatsViewModel.openChatByCode(code) }
        }
    }
}
