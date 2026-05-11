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
}
