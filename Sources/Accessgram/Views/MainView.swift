import SwiftUI

@MainActor
struct MainView: View {
    @Environment(AppViewModel.self) private var app
    @State private var selectedChatId: Int64?
    @State private var showSettings = false
    @State private var showNewChat = false

    var body: some View {
        let selectedChat = selectedChatId.flatMap { id in
            app.chatListViewModel?.chats.first { $0.id == id }
        }
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 260, ideal: 310, max: 400)
        } detail: {
            detailContent(for: selectedChat)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environment(app)
        }
        .sheet(isPresented: $showNewChat) {
            NewChatView(selectedChatId: $selectedChatId).environment(app)
        }
        .task {
            guard app.chatListViewModel == nil else { return }
            let vm = ChatListViewModel(client: app.client)
            app.chatListViewModel = vm
            await app.client.addUpdateHandler { update in
                await MainActor.run { vm.handleUpdate(update) }
            }
            await vm.loadInitial()
        }
    }

    @ViewBuilder
    private var sidebarContent: some View {
        if let vm = app.chatListViewModel {
            ChatListView(
                viewModel: vm,
                selectedChatId: $selectedChatId,
                onCompose: { showNewChat = true }
            )
        } else {
            ProgressView("Loading chats…")
                .accessibilityLabel("Loading conversations")
        }
    }

    @ViewBuilder
    private func detailContent(for chat: Chat?) -> some View {
        if let chat {
            ChatView(chat: chat, client: app.client)
                .id(chat.id)
        } else {
            ContentUnavailableView(
                "No Chat Selected",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Choose a conversation from the sidebar")
            )
            .accessibilityLabel("No chat selected. Open the sidebar and choose a conversation.")
        }
    }
}
