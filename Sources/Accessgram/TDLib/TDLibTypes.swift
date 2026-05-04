import Foundation

// MARK: - Authorization State

enum AuthorizationState: Equatable {
    case waitTdlibParameters, waitEncryptionKey, waitPhoneNumber, waitCode, waitPassword, ready, closed

    init(type: String) {
        switch type {
        case "authorizationStateWaitTdlibParameters": self = .waitTdlibParameters
        case "authorizationStateWaitEncryptionKey": self = .waitEncryptionKey
        case "authorizationStateWaitPhoneNumber": self = .waitPhoneNumber
        case "authorizationStateWaitCode": self = .waitCode
        case "authorizationStateWaitPassword": self = .waitPassword
        case "authorizationStateReady": self = .ready
        default: self = .closed
        }
    }
}

// MARK: - TDFile

struct TDFile {
    let id: Int32
    let localPath: String?
    let size: Int

    var isDownloaded: Bool { localPath != nil }

    init(json: [String: Any]) {
        id = json["id"] as? Int32 ?? 0
        let local = json["local"] as? [String: Any] ?? [:]
        let path = local["path"] as? String ?? ""
        let done = local["is_downloading_completed"] as? Bool ?? false
        localPath = (done && !path.isEmpty) ? path : nil
        size = json["size"] as? Int ?? 0
    }
}

// MARK: - Message Reaction

struct MessageReaction: Hashable {
    let emoji: String
    let count: Int
    let isChosen: Bool

    init(json: [String: Any]) {
        emoji = (json["type"] as? [String: Any])?["emoji"] as? String ?? ""
        count = json["total_count"] as? Int ?? 0
        isChosen = json["chosen_order"] != nil
    }
}

// MARK: - Chat Folder

struct ChatFolder: Identifiable, Hashable {
    let id: Int
    let title: String

    init(json: [String: Any]) {
        id = json["id"] as? Int ?? 0
        title = json["title"] as? String ?? ""
    }
}

// MARK: - Message Content

enum MessageContent {
    case text(String)
    case photo(caption: String, hasSpoiler: Bool, file: TDFile?)
    case video(caption: String, duration: Int, file: TDFile?)
    case audio(title: String, performer: String, duration: Int, file: TDFile?)
    case document(fileName: String, caption: String, mimeType: String, file: TDFile?)
    case sticker(emoji: String)
    case voice(duration: Int, file: TDFile?)
    case videoNote(duration: Int, file: TDFile?)
    case location(latitude: Double, longitude: Double)
    case contact(firstName: String, lastName: String, phone: String)
    case poll(question: String)
    case animation(caption: String, duration: Int, file: TDFile?)
    case dice(emoji: String, value: Int)
    case animatedEmoji(emoji: String)
    case service(text: String)
    case unknown(type: String)

    init(json: [String: Any]) {
        switch json["@type"] as? String ?? "" {
        case "messageText":
            self = .text((json["text"] as? [String: Any])?["text"] as? String ?? "")
        case "messagePhoto":
            let cap = ((json["caption"] as? [String: Any])?["text"] as? String) ?? ""
            let sizes = (json["photo"] as? [String: Any])?["sizes"] as? [[String: Any]] ?? []
            let photoFile = (sizes.last?["photo"] as? [String: Any]).map { TDFile(json: $0) }
            self = .photo(caption: cap, hasSpoiler: json["has_spoiler"] as? Bool ?? false, file: photoFile)
        case "messageVideo":
            let vid = json["video"] as? [String: Any] ?? [:]
            let vidCap = ((json["caption"] as? [String: Any])?["text"] as? String) ?? ""
            let vidFile = (vid["video"] as? [String: Any]).map { TDFile(json: $0) }
            self = .video(caption: vidCap, duration: vid["duration"] as? Int ?? 0, file: vidFile)
        case "messageAudio":
            let audio = json["audio"] as? [String: Any] ?? [:]
            self = .audio(
                title: audio["title"] as? String ?? "",
                performer: audio["performer"] as? String ?? "",
                duration: audio["duration"] as? Int ?? 0,
                file: (audio["audio"] as? [String: Any]).map { TDFile(json: $0) }
            )
        case "messageDocument":
            let doc = json["document"] as? [String: Any] ?? [:]
            let docCap = ((json["caption"] as? [String: Any])?["text"] as? String) ?? ""
            self = .document(
                fileName: doc["file_name"] as? String ?? "File",
                caption: docCap,
                mimeType: doc["mime_type"] as? String ?? "",
                file: (doc["document"] as? [String: Any]).map { TDFile(json: $0) }
            )
        case "messageSticker":
            self = .sticker(emoji: (json["sticker"] as? [String: Any])?["emoji"] as? String ?? "")
        case "messageVoiceNote":
            let vn = json["voice_note"] as? [String: Any] ?? [:]
            let vnFile = (vn["voice"] as? [String: Any]).map { TDFile(json: $0) }
            self = .voice(duration: vn["duration"] as? Int ?? 0, file: vnFile)
        case "messageVideoNote":
            let vvn = json["video_note"] as? [String: Any] ?? [:]
            let vvnFile = (vvn["video"] as? [String: Any]).map { TDFile(json: $0) }
            self = .videoNote(duration: vvn["duration"] as? Int ?? 0, file: vvnFile)
        case "messageLocation":
            let loc = json["location"] as? [String: Any] ?? [:]
            self = .location(latitude: loc["latitude"] as? Double ?? 0, longitude: loc["longitude"] as? Double ?? 0)
        case "messageContact":
            let c = json["contact"] as? [String: Any] ?? [:]
            self = .contact(
                firstName: c["first_name"] as? String ?? "",
                lastName: c["last_name"] as? String ?? "",
                phone: c["phone_number"] as? String ?? ""
            )
        case "messagePoll":
            let q = ((json["poll"] as? [String: Any])?["question"] as? [String: Any])?["text"] as? String ?? ""
            self = .poll(question: q)
        case "messageAnimation":
            let anim = json["animation"] as? [String: Any] ?? [:]
            let animCap = ((json["caption"] as? [String: Any])?["text"] as? String) ?? ""
            let animFile = (anim["animation"] as? [String: Any]).map { TDFile(json: $0) }
            self = .animation(caption: animCap, duration: anim["duration"] as? Int ?? 0, file: animFile)
        case "messageDice":
            self = .dice(
                emoji: json["emoji"] as? String ?? "🎲",
                value: json["value"] as? Int ?? 0
            )
        case "messageAnimatedEmoji":
            let e = (json["animated_emoji"] as? [String: Any]).flatMap {
                ($0["sticker"] as? [String: Any])?["emoji"] as? String
            } ?? json["emoji"] as? String ?? "?"
            self = .animatedEmoji(emoji: e)
        case "messageChatChangeTitle":
            self = .service(text: "Changed the title to \"\(json["title"] as? String ?? "")\"")
        case "messageChatAddMembers":
            self = .service(text: "Members were added")
        case "messageChatDeleteMember":
            self = .service(text: "Left the group")
        case "messageChatJoinByLink", "messageChatJoinByRequest":
            self = .service(text: "Joined the group")
        case "messagePinMessage":
            self = .service(text: "Pinned a message")
        case "messageBasicGroupChatCreate", "messageSupergroupChatCreate":
            self = .service(text: "Created the group")
        case "messageChatUpgradeFrom", "messageChatUpgradeTo":
            self = .service(text: "Group was upgraded")
        case "messageScreenshotTaken":
            self = .service(text: "Took a screenshot")
        case "messageChatSetMessageAutoDeleteTime":
            self = .service(text: "Auto-delete timer changed")
        case "messageGiftedPremium", "messagePremiumGiftCode":
            self = .service(text: "Gifted Telegram Premium")
        case "messageExpiredPhoto", "messageExpiredVideo", "messageExpiredVideoNote", "messageExpiredVoiceNote":
            self = .service(text: "Self-destructed media")
        default:
            self = .unknown(type: json["@type"] as? String ?? "unknown")
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .text(let t): return t
        case .photo(let cap, let spoiler, _):
            return (spoiler ? "Photo with spoiler" : "Photo") + (cap.isEmpty ? "" : ": \(cap)")
        case .video(let cap, let dur, _):
            return "Video, \(tdFormatDuration(dur))" + (cap.isEmpty ? "" : ": \(cap)")
        case .audio(let t, let p, let dur, _):
            let who = [t, p].filter { !$0.isEmpty }.joined(separator: " by ")
            return who.isEmpty ? "Audio, \(tdFormatDuration(dur))" : "\(who), \(tdFormatDuration(dur))"
        case .document(let name, let cap, _, _):
            return "File: \(name)" + (cap.isEmpty ? "" : ": \(cap)")
        case .sticker(let e): return "\(e) sticker"
        case .voice(let dur, _): return "Voice message, \(tdFormatDuration(dur))"
        case .videoNote(let dur, _): return "Video message, \(tdFormatDuration(dur))"
        case .location(let lat, let lon): return String(format: "Location: %.4f, %.4f", lat, lon)
        case .contact(let f, let l, let p):
            return "Contact: \([f, l].filter { !$0.isEmpty }.joined(separator: " ")), \(p)"
        case .poll(let q): return "Poll: \(q)"
        case .animation(let cap, let dur, _):
            return "GIF, \(tdFormatDuration(dur))" + (cap.isEmpty ? "" : ": \(cap)")
        case .dice(let emoji, let value):
            return value > 0 ? "Dice \(emoji), result: \(value)" : "Dice \(emoji)"
        case .animatedEmoji(let e): return "\(e) sticker"
        case .service(let t): return t
        case .unknown(let t): return "Unsupported message (\(t))"
        }
    }

    var previewText: String {
        switch self {
        case .text(let t): return t
        case .photo: return "📷 Photo"
        case .video: return "🎥 Video"
        case .audio: return "🎵 Audio"
        case .document(let n, _, _, _): return "📎 \(n)"
        case .sticker(let e): return "\(e) Sticker"
        case .voice: return "🎤 Voice message"
        case .videoNote: return "⭕ Video message"
        case .location: return "📍 Location"
        case .contact: return "👤 Contact"
        case .poll(let q): return "📊 \(q)"
        case .animation: return "🎞 GIF"
        case .dice(let e, _): return "\(e) Dice"
        case .animatedEmoji(let e): return e
        case .service(let t): return t
        case .unknown: return "Message"
        }
    }
}

// MARK: - Message Sender

enum MessageSender {
    case user(id: Int64)
    case chat(id: Int64)

    init(json: [String: Any]) {
        switch json["@type"] as? String {
        case "messageSenderUser": self = .user(id: json["user_id"] as? Int64 ?? 0)
        case "messageSenderChat": self = .chat(id: json["chat_id"] as? Int64 ?? 0)
        default: self = .user(id: 0)
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
    let replyToMessageId: Int64?
    let replyQuoteText: String?
    let forwardOriginName: String?
    let reactions: [MessageReaction]

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int64, let chatId = json["chat_id"] as? Int64 else { return nil }
        self.id = id
        self.chatId = chatId
        date = json["date"] as? Int32 ?? 0
        isOutgoing = json["is_outgoing"] as? Bool ?? false
        canBeForwarded = json["can_be_forwarded"] as? Bool ?? false
        canBeDeletedForAll = json["can_be_deleted_for_all_users"] as? Bool ?? false
        sender = MessageSender(json: json["sender_id"] as? [String: Any] ?? [:])
        content = MessageContent(json: json["content"] as? [String: Any] ?? [:])
        let replyTo = json["reply_to"] as? [String: Any]
        if replyTo?["@type"] as? String == "messageReplyToMessage" {
            replyToMessageId = replyTo?["message_id"] as? Int64
            replyQuoteText = (replyTo?["quote"] as? [String: Any])?["text"] as? String
        } else {
            replyToMessageId = nil
            replyQuoteText = nil
        }
        if let fwd = json["forward_info"] as? [String: Any],
           let origin = fwd["origin"] as? [String: Any] {
            switch origin["@type"] as? String {
            case "messageOriginHiddenUser":
                forwardOriginName = origin["sender_name"] as? String ?? "Forwarded"
            case "messageOriginChannel":
                forwardOriginName = origin["title"] as? String ?? "Forwarded"
            default:
                forwardOriginName = "Forwarded message"
            }
        } else {
            forwardOriginName = nil
        }
        let reactionsList = ((json["interaction_info"] as? [String: Any])?["reactions"]
            as? [String: Any])?["reactions"] as? [[String: Any]] ?? []
        reactions = reactionsList.map { MessageReaction(json: $0) }.filter { !$0.emoji.isEmpty }
    }
}

// MARK: - User Status

enum UserStatus {
    case online, recently, lastWeek, lastMonth, unknown
    case offline(lastSeen: Int32)

    init(json: [String: Any]) {
        switch json["@type"] as? String {
        case "userStatusOnline": self = .online
        case "userStatusOffline": self = .offline(lastSeen: json["was_online"] as? Int32 ?? 0)
        case "userStatusRecently": self = .recently
        case "userStatusLastWeek": self = .lastWeek
        case "userStatusLastMonth": self = .lastMonth
        default: self = .unknown
        }
    }

    var description: String {
        switch self {
        case .online: return "Online"
        case .offline(let d):
            let fmt = RelativeDateTimeFormatter()
            fmt.unitsStyle = .full
            let date = Date(timeIntervalSince1970: TimeInterval(d))
            return "Last seen \(fmt.localizedString(for: date, relativeTo: Date()))"
        case .recently: return "Last seen recently"
        case .lastWeek: return "Last seen last week"
        case .lastMonth: return "Last seen last month"
        case .unknown: return ""
        }
    }
}

// MARK: - Duration helper

func tdFormatDuration(_ seconds: Int) -> String {
    "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
}
