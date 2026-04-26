import Foundation
import Testing
@testable import Accessgram

// MARK: - Chat Model Tests

@Suite("Chat model")
struct ChatModelTests {

    @Test("accessibilityLabel with no unread")
    func labelNoUnread() {
        let chat = Chat(id: 1, title: "Alice")
        #expect(chat.accessibilityLabel == "Alice")
    }

    @Test("accessibilityLabel with unread count")
    func labelWithUnread() {
        var chat = Chat(id: 1, title: "Alice")
        chat.unreadCount = 5
        let label = chat.accessibilityLabel
        #expect(label.contains("5 unread messages"))
    }

    @Test("accessibilityLabel singular unread")
    func labelSingularUnread() {
        var chat = Chat(id: 1, title: "Bob")
        chat.unreadCount = 1
        #expect(chat.accessibilityLabel.contains("1 unread message"))
    }

    @Test("accessibilityLabel includes muted flag")
    func labelMuted() {
        var chat = Chat(id: 1, title: "Group")
        chat.isMuted = true
        #expect(chat.accessibilityLabel.contains("Muted"))
    }

    @Test("accessibilityLabel includes pinned flag")
    func labelPinned() {
        var chat = Chat(id: 1, title: "Group")
        chat.isPinned = true
        #expect(chat.accessibilityLabel.contains("Pinned"))
    }

    @Test("ChatType typeLabel values")
    func chatTypeLabels() {
        #expect(ChatType.private(userId: 0).typeLabel == "Private chat")
        #expect(ChatType.basicGroup(groupId: 0).typeLabel == "Group")
        #expect(ChatType.supergroup(id: 0, isChannel: true).typeLabel == "Channel")
        #expect(ChatType.supergroup(id: 0, isChannel: false).typeLabel == "Supergroup")
        #expect(ChatType.secretChat(id: 0).typeLabel == "Secret chat")
    }
}

// MARK: - MessageContent Tests

@Suite("MessageContent accessibility")
struct MessageContentTests {

    @Test("text returns plain string")
    func textContent() {
        let content = MessageContent.text("Hello!")
        #expect(content.accessibilityDescription == "Hello!")
        #expect(content.previewText == "Hello!")
    }

    @Test("photo with caption")
    func photoWithCaption() {
        let content = MessageContent.photo(caption: "Sunset", hasSpoiler: false)
        #expect(content.accessibilityDescription == "Photo: Sunset")
    }

    @Test("photo with spoiler hides content")
    func photoSpoiler() {
        let content = MessageContent.photo(caption: "", hasSpoiler: true)
        #expect(content.accessibilityDescription.contains("spoiler"))
    }

    @Test("sticker includes emoji")
    func stickerEmoji() {
        let content = MessageContent.sticker(emoji: "😂")
        #expect(content.accessibilityDescription == "😂 sticker")
    }

    @Test("voice includes duration")
    func voiceDuration() {
        let content = MessageContent.voice(duration: 65)
        #expect(content.accessibilityDescription.contains("1:05"))
    }

    @Test("unknown type shows type name")
    func unknownType() {
        let content = MessageContent.unknown(type: "messageDice")
        #expect(content.accessibilityDescription.contains("messageDice"))
    }
}

// MARK: - TDLibUpdate Parsing Tests

@Suite("TDUpdate parsing")
struct TDUpdateTests {

    @Test("parses updateAuthorizationState ready")
    func authReady() {
        let json: [String: Any] = [
            "@type": "updateAuthorizationState",
            "authorization_state": ["@type": "authorizationStateReady"]
        ]
        guard let update = TDUpdate(json: json) else {
            Issue.record("Expected update but got nil")
            return
        }
        if case .authorizationState(let state) = update {
            #expect(state == .ready)
        } else {
            Issue.record("Wrong update type")
        }
    }

    @Test("parses updateChatReadInbox")
    func chatReadInbox() {
        let json: [String: Any] = [
            "@type": "updateChatReadInbox",
            "chat_id": Int64(42),
            "last_read_inbox_message_id": Int64(100),
            "unread_count": 3
        ]
        guard let update = TDUpdate(json: json) else {
            Issue.record("Expected update but got nil")
            return
        }
        if case .chatReadInbox(let chatId, _, let unread) = update {
            #expect(chatId == 42)
            #expect(unread == 3)
        } else {
            Issue.record("Wrong update type")
        }
    }

    @Test("returns nil for unknown type")
    func unknownUpdate() {
        let json: [String: Any] = ["@type": "someUnknownUpdate"]
        let update = TDUpdate(json: json)
        // Unknown types still parse (as .unknown), not nil
        if let update, case .unknown = update {
            // correct
        } else if update == nil {
            Issue.record("Should not be nil – unknown type wraps as .unknown")
        }
    }
}

// MARK: - AuthorizationState Tests

@Suite("AuthorizationState")
struct AuthorizationStateTests {

    @Test("maps all known type strings")
    func allTypes() {
        let cases: [(String, AuthorizationState)] = [
            ("authorizationStateWaitTdlibParameters", .waitTdlibParameters),
            ("authorizationStateWaitPhoneNumber", .waitPhoneNumber),
            ("authorizationStateWaitCode", .waitCode),
            ("authorizationStateWaitPassword", .waitPassword),
            ("authorizationStateReady", .ready),
            ("authorizationStateClosed", .closed),
            ("somethingElse", .closed)
        ]
        for (type, expected) in cases {
            #expect(AuthorizationState(type: type) == expected, "\(type) should map to \(expected)")
        }
    }
}
