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
    var errorMessage: String?

    private let client: TDLibClient

    init(chat: Chat, client: TDLibClient) {
        self.chat = chat
        self.client = client
    }

    // MARK: - Load Messages

    func loadMessages() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let jsonMsgs = try await client.getChatHistory(chatId: chat.id, limit: 50)
            let loaded = jsonMsgs.compactMap { TDMessage(json: $0) }
                                 .map { Message(tdMessage: $0) }
            messages = loaded.reversed()

            let ids = loaded.map { $0.id }
            await client.viewMessages(chatId: chat.id, ids: ids)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Send

    func sendMessage() async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftText = ""
        isSending = true
        defer { isSending = false }
        do {
            try await client.sendTextMessage(
                chatId: chat.id,
                text: text,
                replyToId: replyToMessage?.id
            )
            replyToMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            draftText = text  // restore draft on failure
        }
    }

    // MARK: - Reply / Delete

    func startReply(to message: Message) {
        replyToMessage = message
    }

    func cancelReply() {
        replyToMessage = nil
    }

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

    // MARK: - Update Handling

    func handleUpdate(_ update: TDUpdate) {
        switch update {
        case .newMessage(let tdMsg) where tdMsg.chatId == chat.id:
            let msg = Message(tdMessage: tdMsg)
            messages.append(msg)
            announceNewMessage(msg)

        case .messageSendSucceeded(let tdMsg, let oldId) where tdMsg.chatId == chat.id:
            let msg = Message(tdMessage: tdMsg)
            if let i = messages.firstIndex(where: { $0.id == oldId }) {
                messages[i] = msg
            } else {
                messages.append(msg)
            }

        case .messageSendFailed(let chatId, let oldId, let err) where chatId == chat.id:
            if let i = messages.firstIndex(where: { $0.id == oldId }) {
                messages.remove(at: i)
            }
            errorMessage = err

        case .messagesDeleted(let chatId, let ids) where chatId == chat.id:
            messages.removeAll { ids.contains($0.id) }

        default:
            break
        }
    }

    // MARK: - VoiceOver Announcement

    private func announceNewMessage(_ message: Message) {
        guard !message.isOutgoing else { return }
        let text = message.fullAccessibilityLabel
        NSAccessibility.post(
            element: NSApp as AnyObject,
            notification: .announcementRequested,
            userInfo: [
                NSAccessibility.NotificationUserInfoKey.announcement: text as NSString,
                NSAccessibility.NotificationUserInfoKey.priority:
                    NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }
}
