import Foundation

// MARK: - Authorization State

enum AuthorizationState {
    case waitTdlibParameters
    case waitPhoneNumber
    case waitCode
    case waitPassword
    case ready
    case closed

    init(type: String) {
        switch type {
        case "authorizationStateWaitTdlibParameters": self = .waitTdlibParameters
        case "authorizationStateWaitPhoneNumber":     self = .waitPhoneNumber
        case "authorizationStateWaitCode":            self = .waitCode
        case "authorizationStateWaitPassword":        self = .waitPassword
        case "authorizationStateReady":               self = .ready
        default:                                      self = .closed
        }
    }
}

// MARK: - Message Content

enum MessageContent {
    case text(String)
    case photo(caption: String, hasSpoiler: Bool)
    case video(caption: String, duration: Int)
    case audio(title: String, performer: String, duration: Int)
    case document(fileName: String, caption: String)
    case sticker(emoji: String)
    case voice(duration: Int)
    case videoNote(duration: Int)
    case location(latitude: Double, longitude: Double)
    case contact(firstName: String, lastName: String, phone: String)
    case poll(question: String)
    case unknown(type: String)

    init(json: [String: Any]) {
        let type = json["@type"] as? String ?? ""
        switch type {
        case "messageText":
            let text = (json["text"] as? [String: Any])?["text"] as? String ?? ""
            self = .text(text)
        case "messagePhoto":
            let caption = ((json["caption"] as? [String: Any])?["text"] as? String) ?? ""
            self = .photo(caption: caption, hasSpoiler: json["has_spoiler"] as? Bool ?? false)
        case "messageVideo":
            let caption = ((json["caption"] as? [String: Any])?["text"] as? String) ?? ""
            let dur = (json["video"] as? [String: Any])?["duration"] as? Int ?? 0
            self = .video(caption: caption, duration: dur)
        case "messageAudio":
            let audio = json["audio"] as? [String: Any] ?? [:]
            self = .audio(
                title: audio["title"] as? String ?? "",
                performer: audio["performer"] as? String ?? "",
                duration: audio["duration"] as? Int ?? 0
            )
        case "messageDocument":
            let doc = json["document"] as? [String: Any] ?? [:]
            let caption = ((json["caption"] as? [String: Any])?["text"] as? String) ?? ""
            self = .document(fileName: doc["file_name"] as? String ?? "File", caption: caption)
        case "messageSticker":
            let emoji = (json["sticker"] as? [String: Any])?["emoji"] as? String ?? ""
            self = .sticker(emoji: emoji)
        case "messageVoiceNote":
            let dur = (json["voice_note"] as? [String: Any])?["duration"] as? Int ?? 0
            self = .voice(duration: dur)
        case "messageVideoNote":
            let dur = (json["video_note"] as? [String: Any])?["duration"] as? Int ?? 0
            self = .videoNote(duration: dur)
        case "messageLocation":
            let loc = json["location"] as? [String: Any] ?? [:]
            self = .location(latitude: loc["latitude"] as? Double ?? 0,
                             longitude: loc["longitude"] as? Double ?? 0)
        case "messageContact":
            let c = json["contact"] as? [String: Any] ?? [:]
            self = .contact(firstName: c["first_name"] as? String ?? "",
                            lastName: c["last_name"] as? String ?? "",
                            phone: c["phone_number"] as? String ?? "")
        case "messagePoll":
            let q = ((json["poll"] as? [String: Any])?["question"] as? [String: Any])?["text"] as? String ?? ""
            self = .poll(question: q)
        default:
            self = .unknown(type: type)
        }
    }

    // Human-readable description read by VoiceOver
    var accessibilityDescription: String {
        switch self {
        case .text(let t):                     return t
        case .photo(let cap, let spoiler):
            let base = spoiler ? "Photo with spoiler" : "Photo"
            return cap.isEmpty ? base : "\(base): \(cap)"
        case .video(let cap, let dur):
            return "Video, \(formatDuration(dur))" + (cap.isEmpty ? "" : ": \(cap)")
        case .audio(let t, let p, let dur):
            let who = [t, p].filter { !$0.isEmpty }.joined(separator: " by ")
            return who.isEmpty ? "Audio, \(formatDuration(dur))" : "\(who), \(formatDuration(dur))"
        case .document(let name, let cap):
            return "File: \(name)" + (cap.isEmpty ? "" : ": \(cap)")
        case .sticker(let emoji):              return "\(emoji) sticker"
        case .voice(let dur):                  return "Voice message, \(formatDuration(dur))"
        case .videoNote(let dur):              return "Video message, \(formatDuration(dur))"
        case .location(let lat, let lon):
            return String(format: "Location: %.4f, %.4f", lat, lon)
        case .contact(let f, let l, let p):
            let name = [f, l].filter { !$0.isEmpty }.joined(separator: " ")
            return "Contact: \(name), \(p)"
        case .poll(let q):                     return "Poll: \(q)"
        case .unknown(let t):                  return "Unsupported message (\(t))"
        }
    }

    var previewText: String {
        switch self {
        case .text(let t):     return t
        case .photo:           return "📷 Photo"
        case .video:           return "🎥 Video"
        case .audio:           return "🎵 Audio"
        case .document(let n, _): return "📎 \(n)"
        case .sticker(let e): return "\(e) Sticker"
        case .voice:           return "🎤 Voice message"
        case .videoNote:       return "⭕ Video message"
        case .location:        return "📍 Location"
        case .contact:         return "👤 Contact"
        case .poll(let q):    return "📊 \(q)"
        case .unknown:         return "Message"
        }
    }
}

// MARK: - Sender

enum MessageSender {
    case user(id: Int64)
    case chat(id: Int64)

    init(json: [String: Any]) {
        switch json["@type"] as? String {
        case "messageSenderUser": self = .user(id: json["user_id"] as? Int64 ?? 0)
        case "messageSenderChat": self = .chat(id: json["chat_id"] as? Int64 ?? 0)
        default:                  self = .user(id: 0)
        }
    }
}

// MARK: - Raw TDLib Message

struct TDMessage {
    let id: Int64
    let chatId: Int64
    let sender: MessageSender
    let date: Int32
    let content: MessageContent
    let isOutgoing: Bool
    let canBeForwarded: Bool
    let canBeDeletedForAll: Bool

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int64,
              let chatId = json["chat_id"] as? Int64 else { return nil }
        self.id = id
        self.chatId = chatId
        self.date = json["date"] as? Int32 ?? 0
        self.isOutgoing = json["is_outgoing"] as? Bool ?? false
        self.canBeForwarded = json["can_be_forwarded"] as? Bool ?? false
        self.canBeDeletedForAll = json["can_be_deleted_for_all_users"] as? Bool ?? false
        self.sender = MessageSender(json: json["sender_id"] as? [String: Any] ?? [:])
        self.content = MessageContent(json: json["content"] as? [String: Any] ?? [:])
    }
}

// MARK: - User Status

enum UserStatus {
    case online
    case offline(lastSeen: Int32)
    case recently
    case lastWeek
    case lastMonth
    case unknown

    var description: String {
        switch self {
        case .online:              return "Online"
        case .offline(let d):
            let date = Date(timeIntervalSince1970: TimeInterval(d))
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .full
            return "Last seen \(f.localizedString(for: date, relativeTo: Date()))"
        case .recently:            return "Last seen recently"
        case .lastWeek:            return "Last seen last week"
        case .lastMonth:           return "Last seen last month"
        case .unknown:             return ""
        }
    }
}

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
    case chatPosition(chatId: Int64)
    case userStatus(userId: Int64, status: UserStatus)
    case unknown(type: String)

    init?(json: [String: Any]) {
        guard let type = json["@type"] as? String else { return nil }
        switch type {
        case "updateAuthorizationState":
            guard let stateJSON = json["authorization_state"] as? [String: Any],
                  let stateType = stateJSON["@type"] as? String else { return nil }
            self = .authorizationState(AuthorizationState(type: stateType))

        case "updateNewMessage":
            guard let msgJSON = json["message"] as? [String: Any],
                  let msg = TDMessage(json: msgJSON) else { return nil }
            self = .newMessage(msg)

        case "updateMessageContent":
            let chatId = json["chat_id"] as? Int64 ?? 0
            let msgId  = json["message_id"] as? Int64 ?? 0
            self = .messageEdited(chatId: chatId, messageId: msgId)

        case "updateDeleteMessages":
            let chatId = json["chat_id"] as? Int64 ?? 0
            let ids    = json["message_ids"] as? [Int64] ?? []
            self = .messagesDeleted(chatId: chatId, ids: ids)

        case "updateMessageSendSucceeded":
            guard let msgJSON = json["message"] as? [String: Any],
                  let msg = TDMessage(json: msgJSON) else { return nil }
            let oldId = json["old_message_id"] as? Int64 ?? 0
            self = .messageSendSucceeded(message: msg, oldId: oldId)

        case "updateMessageSendFailed":
            guard let msgJSON = json["message"] as? [String: Any],
                  let msg = TDMessage(json: msgJSON) else { return nil }
            let oldId = json["old_message_id"] as? Int64 ?? 0
            let err   = (json["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
            self = .messageSendFailed(chatId: msg.chatId, oldId: oldId, error: err)

        case "updateChatLastMessage":
            let chatId = json["chat_id"] as? Int64 ?? 0
            let msg = (json["last_message"] as? [String: Any]).flatMap { TDMessage(json: $0) }
            self = .chatLastMessage(chatId: chatId, message: msg)

        case "updateChatReadInbox":
            let chatId  = json["chat_id"] as? Int64 ?? 0
            let lastId  = json["last_read_inbox_message_id"] as? Int64 ?? 0
            let unread  = json["unread_count"] as? Int ?? 0
            self = .chatReadInbox(chatId: chatId, lastReadId: lastId, unreadCount: unread)

        case "updateChatPosition":
            let chatId = json["chat_id"] as? Int64 ?? 0
            self = .chatPosition(chatId: chatId)

        case "updateUserStatus":
            let userId = json["user_id"] as? Int64 ?? 0
            let statusJSON = json["status"] as? [String: Any] ?? [:]
            let status: UserStatus
            switch statusJSON["@type"] as? String {
            case "userStatusOnline":       status = .online
            case "userStatusOffline":      status = .offline(lastSeen: statusJSON["was_online"] as? Int32 ?? 0)
            case "userStatusRecently":     status = .recently
            case "userStatusLastWeek":     status = .lastWeek
            case "userStatusLastMonth":    status = .lastMonth
            default:                       status = .unknown
            }
            self = .userStatus(userId: userId, status: status)

        default:
            self = .unknown(type: type)
        }
    }
}

// MARK: - Helpers

private func formatDuration(_ seconds: Int) -> String {
    if seconds < 60 { return "\(seconds)s" }
    let m = seconds / 60, s = seconds % 60
    return "\(m):\(String(format: "%02d", s))"
}
