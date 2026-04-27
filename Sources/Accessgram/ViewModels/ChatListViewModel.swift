import Foundation
import Observation

@Observable
@MainActor
final class ChatListViewModel {
    var chats: [Chat] = []
    var isLoading = false
    var searchQuery = ""
    var folders: [ChatFolder] = []
    var activeFolderId: Int?
    var errorMessage: String?

    var filteredChats: [Chat] {
        if searchQuery.isEmpty { return chats }
        return chats.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
    }

    private let client: TDLibClient

    init(client: TDLibClient) {
        self.client = client
    }

    // MARK: - Load

    func loadInitial() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await client.loadChatList(limit: 50)
            await loadFolders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadFolders() async {
        guard let raw = try? await client.getChatFolders() else { return }
        folders = raw.map { ChatFolder(json: $0) }
    }

    // MARK: - Update Handling

    func handleUpdate(_ update: TDUpdate) {
        switch update {
        case .newMessage(let msg):
            bringToTop(chatId: msg.chatId)

        case .chatLastMessage(let chatId, let tdMsg):
            guard let i = index(for: chatId) else { return }
            chats[i].lastMessage = tdMsg.map { Message(tdMessage: $0) }

        case .chatReadInbox(let chatId, _, let unread):
            guard let i = index(for: chatId) else { return }
            chats[i].unreadCount = unread

        case .chatNotificationSettingsChanged(let chatId, let muted):
            guard let i = index(for: chatId) else { return }
            chats[i].isMuted = muted

        case .chatIsMarkedAsUnreadChanged(let chatId, let marked):
            guard let i = index(for: chatId) else { return }
            chats[i].isMarkedAsUnread = marked

        case .chatPinnedMessageChanged(let chatId, let msgId):
            guard let i = index(for: chatId) else { return }
            chats[i].pinnedMessageId = msgId

        default:
            break
        }
    }

    func addOrUpdate(from json: [String: Any]) {
        guard let chat = Chat(json: json) else { return }
        if let i = index(for: chat.id) {
            var merged = chat
            merged.unreadCount = max(chat.unreadCount, chats[i].unreadCount)
            merged.isMuted = chats[i].isMuted
            chats[i] = merged
        } else {
            chats.append(chat)
        }
    }

    // MARK: - Actions

    func archiveChat(_ chat: Chat) async {
        do {
            try await client.archiveChat(chatId: chat.id)
            chats.removeAll { $0.id == chat.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePinned(_ chat: Chat) async {
        do {
            try await client.toggleChatIsPinned(chatId: chat.id, isPinned: !chat.isPinned)
            if let i = index(for: chat.id) {
                chats[i].isPinned.toggle()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleMuted(_ chat: Chat) async {
        do {
            let muteFor = chat.isMuted ? 0 : 2_147_483_647
            try await client.muteChat(chatId: chat.id, muteFor: muteFor)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleMarkedUnread(_ chat: Chat) async {
        do {
            try await client.toggleChatIsMarkedAsUnread(chatId: chat.id, isMarked: !chat.isMarkedAsUnread)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func index(for chatId: Int64) -> Int? {
        chats.firstIndex { $0.id == chatId }
    }

    private func bringToTop(chatId: Int64) {
        guard let i = index(for: chatId), i > 0 else { return }
        let chat = chats.remove(at: i)
        chats.insert(chat, at: 0)
    }
}
