import Foundation
import Observation

@Observable
@MainActor
final class ChatListViewModel {
    var chats: [Chat] = []
    var isLoading = false
    var searchQuery = ""
    var errorMessage: String?

    var filteredChats: [Chat] {
        if searchQuery.isEmpty { return chats }
        return chats.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private let client: TDLibClient
    private var userCache: [Int64: User] = [:]

    init(client: TDLibClient) {
        self.client = client
    }

    // MARK: - Load

    func loadInitial() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await client.loadChatList(limit: 30)
        } catch {
            errorMessage = error.localizedDescription
        }
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

        case .chatPosition:
            break  // ordering handled by bringToTop for now

        default:
            break
        }
    }

    func addOrUpdate(from json: [String: Any]) {
        guard let chat = Chat(json: json) else { return }
        if let i = index(for: chat.id) {
            // Preserve updated unread counts etc. if already loaded
            var merged = chat
            merged.unreadCount = max(chat.unreadCount, chats[i].unreadCount)
            chats[i] = merged
        } else {
            chats.append(chat)
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
