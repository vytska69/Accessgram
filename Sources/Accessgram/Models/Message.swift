import Foundation

struct Message: Identifiable, Hashable {
    let id: Int64
    let chatId: Int64
    var sender: MessageSender
    var senderName: String
    var content: MessageContent
    var date: Date
    var isOutgoing: Bool
    var isRead: Bool
    var canBeRepliedTo: Bool
    var canBeForwarded: Bool
    var canBeDeleted: Bool
    var editDate: Date?

    // MARK: - Accessors

    var timeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    var accessibilityPreview: String {
        let who = isOutgoing ? "You" : senderName
        return "\(who): \(content.previewText)"
    }

    /// Full label read by VoiceOver when focus lands on a message bubble.
    var fullAccessibilityLabel: String {
        var parts: [String] = []
        parts.append(isOutgoing ? "You" : senderName)
        parts.append(content.accessibilityDescription)
        parts.append("at \(timeString)")
        if isOutgoing && isRead { parts.append("Read") }
        if editDate != nil { parts.append("Edited") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

    // MARK: - Init from TDMessage

    init(tdMessage: TDMessage, senderName: String = "") {
        self.id = tdMessage.id
        self.chatId = tdMessage.chatId
        self.sender = tdMessage.sender
        self.senderName = senderName
        self.content = tdMessage.content
        self.date = Date(timeIntervalSince1970: TimeInterval(tdMessage.date))
        self.isOutgoing = tdMessage.isOutgoing
        self.isRead = false
        self.canBeRepliedTo = true
        self.canBeForwarded = tdMessage.canBeForwarded
        self.canBeDeleted = tdMessage.canBeDeletedForAll
        self.editDate = nil
    }
}
