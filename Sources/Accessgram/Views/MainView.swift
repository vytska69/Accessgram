import SwiftUI

enum MainTab: String, CaseIterable {
    case messages, contacts, settings
}

@MainActor
struct MainView: View {
    @Environment(AppViewModel.self) private var app
    @State private var activeTab: MainTab = .messages
    @State private var selectedChatId: Int64?
    @State private var showNewChat = false

    private var totalUnread: Int {
        app.chatListViewModel.chats.reduce(0) { $0 + $1.unreadCount }
    }

    var body: some View {
        let selectedChat = selectedChatId.flatMap { id in
            app.chatListViewModel.chats.first { $0.id == id }
        }
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 270, ideal: 320, max: 420)
        } detail: {
            detailContent(for: selectedChat)
        }
        .sheet(isPresented: $showNewChat) {
            NewChatView(selectedChatId: $selectedChatId).environment(app)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NotificationService.openChatNotification)
        ) { note in
            if let chatId = note.userInfo?["chat_id"] as? Int64 {
                activeTab = .messages
                selectedChatId = chatId
            }
        }
        .task { }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(
                tab: .messages,
                icon: "bubble.left.and.bubble.right.fill",
                label: "Messages",
                badge: totalUnread
            )
            tabButton(
                tab: .contacts,
                icon: "person.2.fill",
                label: "Contacts"
            )
            tabButton(
                tab: .settings,
                icon: "gearshape.fill",
                label: "Settings"
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.bar)
    }

    @ViewBuilder
    private func tabButton(tab: MainTab, icon: String, label: String, badge: Int = 0) -> some View {
        let selected = activeTab == tab
        Button {
            activeTab = tab
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Color.accentColor : .secondary)
                        .frame(width: 28, height: 28)
                    if badge > 0 {
                        Text(badge > 99 ? "99+" : "\(badge)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                            .offset(x: 10, y: -6)
                    }
                }
                Text(label)
                    .font(.system(size: 10, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badge > 0 ? "\(label), \(badge) unread" : label)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .keyboardShortcut(tab == .messages ? "1" : tab == .contacts ? "2" : "3", modifiers: .command)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .messages:
            ChatListView(
                viewModel: app.chatListViewModel,
                selectedChatId: $selectedChatId,
                onCompose: { showNewChat = true }
            )
        case .contacts:
            ContactsView(selectedChatId: $selectedChatId)
                .environment(app)
        case .settings:
            SettingsView()
                .environment(app)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private func detailContent(for chat: Chat?) -> some View {
        switch activeTab {
        case .messages:
            if let chat {
                ChatView(chat: chat, client: app.client)
                    .id(chat.id)
            } else {
                ContentUnavailableView(
                    "No Chat Selected",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Choose a conversation from the sidebar")
                )
                .accessibilityLabel("No chat selected. Choose a conversation from the sidebar.")
            }
        case .contacts:
            ContentUnavailableView(
                "Open a Conversation",
                systemImage: "person.2",
                description: Text("Select a contact to start chatting")
            )
            .accessibilityLabel("Select a contact from the sidebar to open a conversation.")
        case .settings:
            ContentUnavailableView(
                "Settings",
                systemImage: "gearshape",
                description: Text("Adjust your Telegram settings in the sidebar")
            )
            .accessibilityLabel("Adjust your settings in the sidebar.")
        }
    }
}
