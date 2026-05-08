import SwiftUI

@main
struct ConversoxMacApp: App {
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var chatsViewModel = ChatsViewModel()

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
    }
}
