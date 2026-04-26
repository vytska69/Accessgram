import SwiftUI

struct MainView: View {
    @Environment(AppViewModel.self) private var app
    @State private var chatListVM: ChatListViewModel?
    @State private var selectedChatId: Int64?

    private var selectedChat: Chat? {
        guard let id = selectedChatId else { return nil }
        return chatListVM?.chats.first { $0.id == id }
    }

    var body: some View {
        NavigationSplitView {
            Group {
                if let vm = chatListVM {
                    ChatListView(viewModel: vm, selectedChatId: $selectedChatId)
                } else {
                    ProgressView("Loading chats…")
                        .accessibilityLabel("Loading conversations")
                }
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 310, max: 400)
        } detail: {
            if let chat = selectedChat {
                ChatView(chat: chat, client: app.client)
                    .id(chat.id)  // force remount when chat changes
            } else {
                ContentUnavailableView(
                    "No Chat Selected",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Choose a conversation from the sidebar")
                )
                .accessibilityLabel("No chat selected. Open the sidebar and choose a conversation.")
            }
        }
        .task {
            guard chatListVM == nil else { return }
            let vm = ChatListViewModel(client: app.client)
            chatListVM = vm
            await app.client.addUpdateHandler { update in
                await MainActor.run { vm.handleUpdate(update) }
            }
            await vm.loadInitial()
        }
    }
}
