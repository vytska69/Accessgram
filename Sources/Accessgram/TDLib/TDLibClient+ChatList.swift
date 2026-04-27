import Foundation

extension TDLibClient {

    func toggleChatIsPinned(chatId: Int64, isPinned: Bool) async throws {
        _ = try await sendRaw("toggleChatIsPinned", params: [
            "chat_list": ["@type": "chatListMain"],
            "chat_id": chatId,
            "is_pinned": isPinned
        ])
    }

    func toggleChatIsMarkedAsUnread(chatId: Int64, isMarked: Bool) async throws {
        _ = try await sendRaw("toggleChatIsMarkedAsUnread", params: [
            "chat_id": chatId,
            "is_marked_as_unread": isMarked
        ])
    }

    func muteChat(chatId: Int64, muteFor: Int) async throws {
        _ = try await sendRaw("setChatNotificationSettings", params: [
            "chat_id": chatId,
            "notification_settings": [
                "@type": "chatNotificationSettings",
                "use_default_mute_for": false,
                "mute_for": muteFor
            ]
        ])
    }

    func archiveChat(chatId: Int64) async throws {
        _ = try await sendRaw("addChatToList", params: [
            "chat_id": chatId,
            "chat_list": ["@type": "chatListArchive"]
        ])
    }

    func unarchiveChat(chatId: Int64) async throws {
        _ = try await sendRaw("addChatToList", params: [
            "chat_id": chatId,
            "chat_list": ["@type": "chatListMain"]
        ])
    }

    func getChatFolders() async throws -> [[String: Any]] {
        let resp = try await sendRaw("getChatFolderInfo")
        return resp["folders"] as? [[String: Any]] ?? []
    }

    func getContacts() async throws -> [Int64] {
        let resp = try await sendRaw("getContacts")
        return resp["user_ids"] as? [Int64] ?? []
    }

    func createPrivateChat(userId: Int64) async throws -> [String: Any] {
        try await sendRaw("createPrivateChat", params: ["user_id": userId, "force": true])
    }

    func downloadFile(fileId: Int32) async throws -> String? {
        let resp = try await sendRaw("downloadFile", params: [
            "file_id": fileId,
            "priority": 1,
            "offset": 0,
            "limit": 0,
            "synchronous": true
        ])
        let local = resp["local"] as? [String: Any] ?? [:]
        let path = local["path"] as? String ?? ""
        let done = local["is_downloading_completed"] as? Bool ?? false
        return (done && !path.isEmpty) ? path : nil
    }

    func sendDocument(chatId: Int64, filePath: String, caption: String, replyToId: Int64? = nil) async throws {
        var params: [String: Any] = [
            "chat_id": chatId,
            "input_message_content": [
                "@type": "inputMessageDocument",
                "document": ["@type": "inputFileLocal", "path": filePath],
                "caption": ["@type": "formattedText", "text": caption, "entities": []]
            ]
        ]
        if let rid = replyToId {
            params["reply_to"] = ["@type": "inputMessageReplyToMessage", "message_id": rid]
        }
        _ = try await sendRaw("sendMessage", params: params)
    }

    func sendPhoto(chatId: Int64, filePath: String, caption: String, replyToId: Int64? = nil) async throws {
        var params: [String: Any] = [
            "chat_id": chatId,
            "input_message_content": [
                "@type": "inputMessagePhoto",
                "photo": ["@type": "inputFileLocal", "path": filePath],
                "caption": ["@type": "formattedText", "text": caption, "entities": []]
            ]
        ]
        if let rid = replyToId {
            params["reply_to"] = ["@type": "inputMessageReplyToMessage", "message_id": rid]
        }
        _ = try await sendRaw("sendMessage", params: params)
    }
}
