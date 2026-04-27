import Foundation

extension TDLibClient {

    func loadChatList(limit: Int = 20) async throws {
        _ = try await sendRaw("loadChats", params: [
            "chat_list": ["@type": "chatListMain"],
            "limit": limit
        ])
    }

    func getChat(id: Int64) async throws -> [String: Any] {
        try await sendRaw("getChat", params: ["chat_id": id])
    }

    func getChatHistory(chatId: Int64, fromId: Int64 = 0, limit: Int = 50) async throws -> [[String: Any]] {
        let resp = try await sendRaw("getChatHistory", params: [
            "chat_id": chatId,
            "from_message_id": fromId,
            "offset": 0,
            "limit": limit,
            "only_local": false
        ])
        return resp["messages"] as? [[String: Any]] ?? []
    }

    func getMessage(chatId: Int64, messageId: Int64) async throws -> [String: Any] {
        try await sendRaw("getMessage", params: ["chat_id": chatId, "message_id": messageId])
    }

    func sendTextMessage(chatId: Int64, text: String, replyToId: Int64? = nil) async throws {
        var params: [String: Any] = [
            "chat_id": chatId,
            "input_message_content": [
                "@type": "inputMessageText",
                "text": ["@type": "formattedText", "text": text, "entities": []],
                "clear_draft": true
            ]
        ]
        if let rid = replyToId {
            params["reply_to"] = ["@type": "inputMessageReplyToMessage", "message_id": rid]
        }
        _ = try await sendRaw("sendMessage", params: params)
    }

    func editMessageText(chatId: Int64, messageId: Int64, text: String) async throws {
        _ = try await sendRaw("editMessageText", params: [
            "chat_id": chatId,
            "message_id": messageId,
            "input_message_content": [
                "@type": "inputMessageText",
                "text": ["@type": "formattedText", "text": text, "entities": []],
                "clear_draft": false
            ]
        ])
    }

    func forwardMessages(toChatId: Int64, fromChatId: Int64, messageIds: [Int64]) async throws {
        _ = try await sendRaw("forwardMessages", params: [
            "chat_id": toChatId,
            "from_chat_id": fromChatId,
            "message_ids": messageIds,
            "send_copy": false,
            "remove_caption": false
        ])
    }

    func viewMessages(chatId: Int64, ids: [Int64]) async {
        _ = try? await sendRaw("viewMessages", params: [
            "chat_id": chatId,
            "message_ids": ids,
            "force_read": true
        ])
    }

    func deleteMessage(chatId: Int64, messageId: Int64, forAll: Bool) async throws {
        _ = try await sendRaw("deleteMessages", params: [
            "chat_id": chatId,
            "message_ids": [messageId],
            "revoke": forAll
        ])
    }

    func searchChatMessages(chatId: Int64, query: String, limit: Int = 20) async throws -> [[String: Any]] {
        let resp = try await sendRaw("searchChatMessages", params: [
            "chat_id": chatId,
            "query": query,
            "limit": limit,
            "from_message_id": 0,
            "offset": 0
        ])
        return resp["messages"] as? [[String: Any]] ?? []
    }

    func pinChatMessage(chatId: Int64, messageId: Int64, onlyForSelf: Bool = false) async throws {
        _ = try await sendRaw("pinChatMessage", params: [
            "chat_id": chatId,
            "message_id": messageId,
            "disable_notification": false,
            "only_for_self": onlyForSelf
        ])
    }

    func unpinChatMessage(chatId: Int64, messageId: Int64) async throws {
        _ = try await sendRaw("unpinChatMessage", params: [
            "chat_id": chatId,
            "message_id": messageId
        ])
    }

    func addMessageReaction(chatId: Int64, messageId: Int64, emoji: String) async throws {
        _ = try await sendRaw("addMessageReaction", params: [
            "chat_id": chatId,
            "message_id": messageId,
            "reaction_type": ["@type": "reactionTypeEmoji", "emoji": emoji],
            "is_big": false,
            "update_recent_reactions": true
        ])
    }

    func removeMessageReaction(chatId: Int64, messageId: Int64, emoji: String) async throws {
        _ = try await sendRaw("removeMessageReaction", params: [
            "chat_id": chatId,
            "message_id": messageId,
            "reaction_type": ["@type": "reactionTypeEmoji", "emoji": emoji]
        ])
    }

    func getSupergroupFullInfo(supergroupId: Int64) async throws -> [String: Any] {
        try await sendRaw("getSupergroupFullInfo", params: ["supergroup_id": supergroupId])
    }

    func getBasicGroupFullInfo(groupId: Int64) async throws -> [String: Any] {
        try await sendRaw("getBasicGroupFullInfo", params: ["basic_group_id": groupId])
    }
}
