import Foundation

extension ChatViewModel {

    // MARK: - Edit

    func startEditing(_ message: Message) {
        guard message.isOutgoing else { return }
        if case .text(let t) = message.content {
            editingMessage = message
            editText = t
        }
    }

    func cancelEditing() {
        editingMessage = nil
        editText = ""
    }

    func submitEdit() async {
        guard let msg = editingMessage else { return }
        let text = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            try await client.editMessageText(chatId: chat.id, messageId: msg.id, text: text)
            cancelEditing()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Forward

    func startForward(_ message: Message) {
        forwardSourceMessages = [message]
        showForwardSheet = true
    }

    func forwardTo(chat targetChat: Chat) async {
        let ids = forwardSourceMessages.map { $0.id }
        guard !ids.isEmpty else { return }
        do {
            try await client.forwardMessages(
                toChatId: targetChat.id,
                fromChatId: chat.id,
                messageIds: ids
            )
            forwardSourceMessages = []
            showForwardSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reactions

    func addReaction(emoji: String, to message: Message) async {
        do {
            try await client.addMessageReaction(chatId: chat.id, messageId: message.id, emoji: emoji)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeReaction(emoji: String, from message: Message) async {
        do {
            try await client.removeMessageReaction(chatId: chat.id, messageId: message.id, emoji: emoji)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Pin

    func pinMessage(_ message: Message) async {
        do {
            try await client.pinChatMessage(chatId: chat.id, messageId: message.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unpinMessage(_ message: Message) async {
        do {
            try await client.unpinChatMessage(chatId: chat.id, messageId: message.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Attachment

    func sendAttachment(url: URL) async {
        let ext = url.pathExtension.lowercased()
        let imageExts = ["jpg", "jpeg", "png", "heic", "gif", "webp"]
        let date = scheduledDate
        scheduledDate = nil
        do {
            if imageExts.contains(ext) {
                try await client.sendPhoto(chatId: chat.id, filePath: url.path, caption: "", scheduledDate: date)
            } else {
                try await client.sendDocument(chatId: chat.id, filePath: url.path, caption: "", scheduledDate: date)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Search

    func runSearch() async {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { searchResults = []; return }
        do {
            let raw = try await client.searchChatMessages(chatId: chat.id, query: q)
            searchResults = raw.compactMap { TDMessage(json: $0) }.map { Message(tdMessage: $0) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
