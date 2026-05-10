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
        Group {
            if activeTab == .settings {
                settingsLayout
            } else {
                NavigationSplitView(
                    sidebar: {
                        sidebar
                            .navigationSplitViewColumnWidth(min: 270, ideal: 320, max: 420)
                    },
                    detail: {
                        detailContent(for: selectedChat)
                    }
                )
            }
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

    // MARK: - Settings Layout

    private var settingsLayout: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            SettingsView().environment(app)
        }
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
        Button(action: { activeTab = tab }, label: {
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
        })
        .buttonStyle(.plain)
        .accessibilityLabel(badge > 0 ? "\(label), \(badge) unread" : label)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .keyboardShortcut(shortcut(for: tab), modifiers: .command)
    }

    private func shortcut(for tab: MainTab) -> KeyEquivalent {
        switch tab {
        case .messages: return "1"
        case .contacts: return "2"
        case .settings: return "3"
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .messages:
            ChatListView(
                viewModel: app.chatListViewModel,
                selectedChatId: $selectedChatId,
                onCompose: { showNewChat = true },
                onSavedMessages: {
                    Task {
                        guard app.myUserId != 0 else { return }
                        if let chat = try? await app.client.createPrivateChat(userId: app.myUserId) {
                            if let chatId = chat["id"] as? Int64 {
                                selectedChatId = chatId
                            }
                        }
                    }
                }
            )
        case .contacts:
            ContactsView(activeTab: $activeTab, selectedChatId: $selectedChatId)
                .environment(app)
        case .settings:
            EmptyView()
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private func detailContent(for chat: Chat?) -> some View {
        switch activeTab {
        case .messages, .contacts:
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
        case .settings:
            EmptyView()
        }
    }
}
