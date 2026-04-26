import Foundation

struct Chat: Identifiable, Hashable {
    let id: Int64
    var title: String
    var type: ChatType
    var lastMessage: Message?
    var unreadCount: Int
    var unreadMentionCount: Int
    var isMuted: Bool
    var isPinned: Bool

    // MARK: - Accessibility

    var accessibilityLabel: String {
        var parts = [title]
        if unreadCount > 0 {
            parts.append(unreadCount == 1 ? "1 unread message" : "\(unreadCount) unread messages")
        }
        if unreadMentionCount > 0 {
            parts.append("\(unreadMentionCount) mentions")
        }
        if let last = lastMessage {
            parts.append("Last: \(last.accessibilityPreview)")
        }
        if isMuted   { parts.append("Muted") }
        if isPinned  { parts.append("Pinned") }
        return parts.joined(separator: ", ")
    }

    var lastMessagePreview: String { lastMessage?.content.previewText ?? "" }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Chat, rhs: Chat) -> Bool { lhs.id == rhs.id }

    // MARK: - Init

    init(id: Int64, title: String, type: ChatType = .private(userId: 0)) {
        self.id = id; self.title = title; self.type = type
        self.lastMessage = nil; self.unreadCount = 0; self.unreadMentionCount = 0
        self.isMuted = false; self.isPinned = false
    }

    init?(json: [String: Any]) {
        guard let id    = json["id"] as? Int64,
              let title = json["title"] as? String else { return nil }
        self.id                = id
        self.title             = title
        self.type              = ChatType(json: json["type"] as? [String: Any] ?? [:])
        self.unreadCount       = json["unread_count"] as? Int ?? 0
        self.unreadMentionCount = json["unread_mention_count"] as? Int ?? 0
        self.isMuted           = false
        self.isPinned          = false
        if let msgJSON = json["last_message"] as? [String: Any],
           let tdMsg   = TDMessage(json: msgJSON) {
            self.lastMessage = Message(tdMessage: tdMsg)
        } else {
            self.lastMessage = nil
        }
    }
}

// MARK: - Chat Type

enum ChatType {
    case `private`(userId: Int64)
    case basicGroup(groupId: Int64)
    case supergroup(id: Int64, isChannel: Bool)
    case secretChat(id: Int32)

    init(json: [String: Any]) {
        switch json["@type"] as? String {
        case "chatTypePrivate":     self = .private(userId: json["user_id"] as? Int64 ?? 0)
        case "chatTypeBasicGroup":  self = .basicGroup(groupId: json["basic_group_id"] as? Int64 ?? 0)
        case "chatTypeSupergroup":
            self = .supergroup(id: json["supergroup_id"] as? Int64 ?? 0,
                               isChannel: json["is_channel"] as? Bool ?? false)
        case "chatTypeSecret":      self = .secretChat(id: json["secret_chat_id"] as? Int32 ?? 0)
        default:                    self = .private(userId: 0)
        }
    }

    var isGroup: Bool {
        switch self {
        case .basicGroup, .supergroup(_, false): return true
        default: return false
        }
    }

    var isChannel: Bool {
        if case .supergroup(_, true) = self { return true }
        return false
    }

    var typeLabel: String {
        switch self {
        case .private:              return "Private chat"
        case .basicGroup:           return "Group"
        case .supergroup(_, true):  return "Channel"
        case .supergroup(_, false): return "Supergroup"
        case .secretChat:           return "Secret chat"
        }
    }
}
