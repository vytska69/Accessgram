import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class ChatViewModel {
    var chat: Chat
    var messages: [Message] = []
    var draftText = ""
    var replyToMessage: Message?
    var isLoading = false
    var isSending = false
    var isLoadingMore = false
    var hasMoreMessages = true
    var errorMessage: String?

    // Editing
    var editingMessage: Message?
    var editText = ""

    // Forwarding
    var showForwardSheet = false
    var forwardSourceMessages: [Message] = []

    // Search
    var showSearch = false
    var searchQuery = ""
    var searchResults: [Message] = []

    // Pinned
    var pinnedMessage: Message?

    // Downloaded file paths keyed by TDLib file id
    var downloadedPaths: [Int32: String] = [:]

    let client: TDLibClient

    init(chat: Chat, client: TDLibClient) {
        self.chat = chat
        self.client = client
    }

    // MARK: - Load Messages

    func loadMessages() async {
        isLoading = true
        defer { isLoading = false }
        do {
            var raw = try await client.getChatHistory(chatId: chat.id, limit: 50)
            if raw.count < 10 {
                // TDLib may not have history cached yet; wait and retry once
                try? await Task.sleep(nanoseconds: 700_000_000)
                let retry = try await client.getChatHistory(chatId: chat.id, limit: 50)
                if retry.count > raw.count { raw = retry }
            }
            let loaded = raw.compactMap { TDMessage(json: $0) }.map { Message(tdMessage: $0) }.reversed() as [Message]
            messages = await resolveSenderNames(for: loaded)
            hasMoreMessages = raw.count >= 50
            let ids = messages.map { $0.id }
            await client.viewMessages(chatId: chat.id, ids: ids)
            await loadPinnedMessage()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadOlderMessages() async {
        guard !isLoadingMore, hasMoreMessages, let oldest = messages.first else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let raw = try await client.getChatHistory(chatId: chat.id, fromId: oldest.id, limit: 50)
            let olderRaw = raw.compactMap { TDMessage(json: $0) }.map { Message(tdMessage: $0) }.reversed() as [Message]
            let older = await resolveSenderNames(for: olderRaw)
            if older.isEmpty {
                hasMoreMessages = false
            } else {
                messages.insert(contentsOf: older, at: 0)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPinnedMessage() async {
        guard chat.pinnedMessageId != 0 else { return }
        guard let raw = try? await client.getMessage(chatId: chat.id, messageId: chat.pinnedMessageId),
              let tdMsg = TDMessage(json: raw) else { return }
        pinnedMessage = Message(tdMessage: tdMsg)
    }

    // MARK: - Send

    func sendMessage() async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftText = ""
        isSending = true
        defer { isSending = false }
        do {
            try await client.sendTextMessage(chatId: chat.id, text: text, replyToId: replyToMessage?.id)
            replyToMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            draftText = text
        }
    }

    // MARK: - Reply / Delete / Copy

    func startReply(to message: Message) { replyToMessage = message }
    func cancelReply() { replyToMessage = nil }

    func deleteMessage(_ message: Message, forAll: Bool) async {
        do {
            try await client.deleteMessage(chatId: chat.id, messageId: message.id, forAll: forAll)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyText(of message: Message) {
        if case .text(let t) = message.content {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(t, forType: .string)
        }
    }

    // MARK: - File Download

    func localPath(for file: TDFile) -> String? {
        file.localPath ?? downloadedPaths[file.id]
    }

    func downloadFile(_ file: TDFile) async {
        guard !file.isDownloaded, downloadedPaths[file.id] == nil, file.id != 0 else { return }
        if let path = try? await client.downloadFile(fileId: file.id) {
            downloadedPaths[file.id] = path
        }
    }

    func openFile(at path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    // MARK: - Update Handling

    func handleUpdate(_ update: TDUpdate) {
        switch update {
        case .newMessage(let tdMsg) where tdMsg.chatId == chat.id:
            let rawMsg = Message(tdMessage: tdMsg)
            Task {
                let msg = await resolveSenderName(for: rawMsg)
                messages.append(msg)
                announceNewMessage(msg)
            }

        case .messageSendSucceeded(let tdMsg, let oldId) where tdMsg.chatId == chat.id:
            let msg = Message(tdMessage: tdMsg)
            if let i = messages.firstIndex(where: { $0.id == oldId }) {
                messages[i] = msg
            } else {
                messages.append(msg)
            }

        case .messageSendFailed(let chatId, let oldId, let err) where chatId == chat.id:
            messages.removeAll { $0.id == oldId }
            errorMessage = err

        case .messagesDeleted(let chatId, let ids) where chatId == chat.id:
            messages.removeAll { ids.contains($0.id) }

        case .messageEdited(let chatId, let messageId) where chatId == chat.id:
            Task { await refreshMessage(id: messageId) }

        case .messageReactionsChanged(let chatId, let messageId) where chatId == chat.id:
            Task { await refreshMessage(id: messageId) }

        case .chatReadOutbox(let chatId, let lastId) where chatId == chat.id:
            for i in messages.indices where messages[i].isOutgoing && messages[i].id <= lastId {
                messages[i].isRead = true
            }

        case .chatPinnedMessageChanged(let chatId, let msgId) where chatId == chat.id:
            chat.pinnedMessageId = msgId
            Task { await loadPinnedMessage() }

        case .fileUpdated(let fileId, let path):
            if let path { downloadedPaths[fileId] = path }

        default:
            break
        }
    }

    private func refreshMessage(id: Int64) async {
        guard let raw = try? await client.getMessage(chatId: chat.id, messageId: id),
              let tdMsg = TDMessage(json: raw) else { return }
        let updated = Message(tdMessage: tdMsg)
        if let i = messages.firstIndex(where: { $0.id == id }) {
            messages[i] = updated
        }
    }

    // MARK: - Sender Name Resolution

    private func resolveSenderNames(for msgs: [Message]) async -> [Message] {
        var result = msgs
        var nameCache: [Int64: String] = [:]
        for i in result.indices {
            guard !result[i].isOutgoing, case .user(let uid) = result[i].sender else { continue }
            if let name = nameCache[uid] {
                result[i].senderName = name
            } else {
                let name = await fetchUserName(id: uid)
                nameCache[uid] = name
                result[i].senderName = name
            }
        }
        return result
    }

    private func resolveSenderName(for msg: Message) async -> Message {
        var result = msg
        guard !result.isOutgoing, case .user(let uid) = result.sender else { return result }
        result.senderName = await fetchUserName(id: uid)
        return result
    }

    private func fetchUserName(id: Int64) async -> String {
        guard let user = try? await client.getUser(id: id) else { return "" }
        let first = user["first_name"] as? String ?? ""
        let last = user["last_name"] as? String ?? ""
        return [first, last].filter { !$0.isEmpty }.joined(separator: " ")
    }

    // MARK: - VoiceOver

    private func announceNewMessage(_ message: Message) {
        guard !message.isOutgoing else { return }
        NSAccessibility.post(
            element: NSApp as AnyObject,
            notification: .announcementRequested,
            userInfo: [
                NSAccessibility.NotificationUserInfoKey.announcement: message.fullAccessibilityLabel as NSString,
                NSAccessibility.NotificationUserInfoKey.priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }
}
