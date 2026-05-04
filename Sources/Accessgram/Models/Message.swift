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
    var editDate: Date?
    var canBeRepliedTo: Bool
    var canBeForwarded: Bool
    var canBeDeleted: Bool
    var replyToMessageId: Int64?
    var replyQuoteText: String?
    var forwardOriginName: String?
    var reactions: [MessageReaction]

    // MARK: - Computed

    var timeString: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let fmt = DateFormatter()
            fmt.timeStyle = .short
            return fmt.string(from: date)
        } else if cal.isDateInYesterday(date) {
            let fmt = DateFormatter()
            fmt.timeStyle = .short
            return "Yesterday, \(fmt.string(from: date))"
        } else {
            let fmt = DateFormatter()
            let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
            if days < 7 {
                fmt.dateFormat = "EEE, HH:mm"
            } else {
                fmt.dateStyle = .short
                fmt.timeStyle = .short
            }
            return fmt.string(from: date)
        }
    }

    var accessibilityPreview: String {
        "\(isOutgoing ? "You" : senderName): \(content.previewText)"
    }

    var fullAccessibilityLabel: String {
        var parts: [String] = []
        parts.append(isOutgoing ? "You" : senderName)
        if let fwd = forwardOriginName { parts.append("Forwarded from \(fwd)") }
        parts.append(content.accessibilityDescription)
        parts.append("at \(timeString)")
        if isOutgoing && isRead { parts.append("Read") }
        if editDate != nil { parts.append("Edited") }
        if !reactions.isEmpty {
            let summary = reactions.map { "\($0.emoji) \($0.count)" }.joined(separator: ", ")
            parts.append("Reactions: \(summary)")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

    // MARK: - Init

    init(tdMessage: TDMessage, senderName: String = "") {
        id = tdMessage.id
        chatId = tdMessage.chatId
        sender = tdMessage.sender
        self.senderName = senderName
        content = tdMessage.content
        date = Date(timeIntervalSince1970: TimeInterval(tdMessage.date))
        isOutgoing = tdMessage.isOutgoing
        isRead = false
        canBeRepliedTo = true
        canBeForwarded = tdMessage.canBeForwarded
        canBeDeleted = tdMessage.canBeDeletedForAll
        editDate = nil
        replyToMessageId = tdMessage.replyToMessageId
        replyQuoteText = tdMessage.replyQuoteText
        forwardOriginName = tdMessage.forwardOriginName
        reactions = tdMessage.reactions
    }
}
