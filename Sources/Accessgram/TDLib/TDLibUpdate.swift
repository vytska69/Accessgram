import Foundation

// MARK: - TDLib Updates

enum TDUpdate {
    case authorizationState(AuthorizationState)
    case newMessage(TDMessage)
    case messageEdited(chatId: Int64, messageId: Int64)
    case messagesDeleted(chatId: Int64, ids: [Int64])
    case messageSendSucceeded(message: TDMessage, oldId: Int64)
    case messageSendFailed(chatId: Int64, oldId: Int64, error: String)
    case chatLastMessage(chatId: Int64, message: TDMessage?)
    case chatReadInbox(chatId: Int64, lastReadId: Int64, unreadCount: Int)
    case chatReadOutbox(chatId: Int64, lastReadOutboxId: Int64)
    case chatPosition(chatId: Int64)
    case chatPinnedMessageChanged(chatId: Int64, pinnedMessageId: Int64)
    case chatNotificationSettingsChanged(chatId: Int64, isMuted: Bool)
    case chatIsMarkedAsUnreadChanged(chatId: Int64, isMarked: Bool)
    case updateChat(chatJSON: [String: Any])
    case messageReactionsChanged(chatId: Int64, messageId: Int64)
    case fileUpdated(fileId: Int32, localPath: String?)
    case userStatus(userId: Int64, status: UserStatus)
    case unknown(type: String)

    init?(json: [String: Any]) {
        guard let type = json["@type"] as? String else { return nil }
        if let u = Self.parseMessage(type: type, json: json) { self = u; return }
        if let u = Self.parseChat(type: type, json: json) { self = u; return }
        if let u = Self.parseUser(type: type, json: json) { self = u; return }
        self = .unknown(type: type)
    }

    private static func parseMessage(type: String, json: [String: Any]) -> Self? {
        switch type {
        case "updateAuthorizationState":
            guard let s = json["authorization_state"] as? [String: Any],
                  let t = s["@type"] as? String else { return nil }
            return .authorizationState(AuthorizationState(type: t))
        case "updateNewMessage":
            guard let m = json["message"] as? [String: Any],
                  let msg = TDMessage(json: m) else { return nil }
            return .newMessage(msg)
        case "updateMessageContent":
            return .messageEdited(
                chatId: json["chat_id"] as? Int64 ?? 0,
                messageId: json["message_id"] as? Int64 ?? 0
            )
        case "updateDeleteMessages":
            return .messagesDeleted(
                chatId: json["chat_id"] as? Int64 ?? 0,
                ids: json["message_ids"] as? [Int64] ?? []
            )
        case "updateMessageSendSucceeded":
            guard let m = json["message"] as? [String: Any],
                  let msg = TDMessage(json: m) else { return nil }
            return .messageSendSucceeded(message: msg, oldId: json["old_message_id"] as? Int64 ?? 0)
        case "updateMessageSendFailed":
            guard let m = json["message"] as? [String: Any],
                  let msg = TDMessage(json: m) else { return nil }
            let err = (json["error"] as? [String: Any])?["message"] as? String ?? "Send failed"
            return .messageSendFailed(chatId: msg.chatId, oldId: json["old_message_id"] as? Int64 ?? 0, error: err)
        case "updateMessageInteractionInfo":
            return .messageReactionsChanged(
                chatId: json["chat_id"] as? Int64 ?? 0,
                messageId: json["message_id"] as? Int64 ?? 0
            )
        case "updateFile":
            guard let f = json["file"] as? [String: Any] else { return nil }
            let fileId = f["id"] as? Int32 ?? 0
            let local = f["local"] as? [String: Any] ?? [:]
            let path = local["path"] as? String ?? ""
            let done = local["is_downloading_completed"] as? Bool ?? false
            return .fileUpdated(fileId: fileId, localPath: (done && !path.isEmpty) ? path : nil)
        default:
            return nil
        }
    }

    private static func parseChat(type: String, json: [String: Any]) -> Self? {
        switch type {
        case "updateChatLastMessage":
            let msg = (json["last_message"] as? [String: Any]).flatMap { TDMessage(json: $0) }
            return .chatLastMessage(chatId: json["chat_id"] as? Int64 ?? 0, message: msg)
        case "updateChatReadInbox":
            return .chatReadInbox(
                chatId: json["chat_id"] as? Int64 ?? 0,
                lastReadId: json["last_read_inbox_message_id"] as? Int64 ?? 0,
                unreadCount: json["unread_count"] as? Int ?? 0
            )
        case "updateChatReadOutbox":
            return .chatReadOutbox(
                chatId: json["chat_id"] as? Int64 ?? 0,
                lastReadOutboxId: json["last_read_outbox_message_id"] as? Int64 ?? 0
            )
        case "updateChatPosition":
            return .chatPosition(chatId: json["chat_id"] as? Int64 ?? 0)
        case "updateChatPinnedMessage":
            return .chatPinnedMessageChanged(
                chatId: json["chat_id"] as? Int64 ?? 0,
                pinnedMessageId: json["pinned_message_id"] as? Int64 ?? 0
            )
        case "updateChatNotificationSettings":
            let s = json["notification_settings"] as? [String: Any] ?? [:]
            let muted = (s["mute_for"] as? Int ?? 0) > 0
            return .chatNotificationSettingsChanged(chatId: json["chat_id"] as? Int64 ?? 0, isMuted: muted)
        case "updateChatIsMarkedAsUnread":
            return .chatIsMarkedAsUnreadChanged(
                chatId: json["chat_id"] as? Int64 ?? 0,
                isMarked: json["is_marked_as_unread"] as? Bool ?? false
            )
        case "updateNewChat":
            guard let chat = json["chat"] as? [String: Any] else { return nil }
            return .updateChat(chatJSON: chat)
        case "updateChat":
            guard let chat = json["chat"] as? [String: Any] else { return nil }
            return .updateChat(chatJSON: chat)
        default:
            return nil
        }
    }

    private static func parseUser(type: String, json: [String: Any]) -> Self? {
        guard type == "updateUserStatus" else { return nil }
        return .userStatus(
            userId: json["user_id"] as? Int64 ?? 0,
            status: UserStatus(json: json["status"] as? [String: Any] ?? [:])
        )
    }
}
