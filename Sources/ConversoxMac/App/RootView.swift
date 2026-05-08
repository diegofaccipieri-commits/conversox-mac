import SwiftUI

struct RootView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var chatsViewModel: ChatsViewModel

    var body: some View {
        Group {
            switch sessionStore.state {
            case .loading:
                ProgressView("Carregando sessão...")
            case .signedOut:
                SignInView()
            case .signedIn:
                ChatListView()
                    .task {
                        await chatsViewModel.loadInitialChatsIfNeeded()
                    }
            }
        }
    }
}
