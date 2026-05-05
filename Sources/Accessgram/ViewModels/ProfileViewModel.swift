import Foundation
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    var displayName = ""
    var username: String?
    var phone = ""
    var bio = ""
    var status = ""
    var memberCount: Int?
    var description = ""
    var isLoading = false
    var isMuted = false
    var isBlocked = false
    var errorMessage: String?

    var slowModeDelay: Int?
    var members: [ChatMember] = []
    var isLoadingMembers = false
    var hasMoreMembers = false

    private var chatId: Int64 = 0
    private var userId: Int64 = 0
    private var chatType: ChatType = .private(userId: 0)
    private var cachedBasicGroupMembers: [[String: Any]] = []

    private let client: TDLibClient

    init(client: TDLibClient) {
        self.client = client
    }

    func loadUser(id: Int64, chatId: Int64, isMuted: Bool) async {
        self.chatId = chatId
        self.userId = id
        self.isMuted = isMuted
        isLoading = true
        defer { isLoading = false }
        guard let userJSON = try? await client.getUser(id: id) else { return }
        let first = userJSON["first_name"] as? String ?? ""
        let last = userJSON["last_name"] as? String ?? ""
        displayName = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        phone = userJSON["phone_number"] as? String ?? ""
        username = (userJSON["usernames"] as? [String: Any])?["editable_username"] as? String
        let statusJSON = userJSON["status"] as? [String: Any] ?? [:]
        status = UserStatus(json: statusJSON).description
        if let fullJSON = try? await client.getUserFullInfo(userId: id) {
            bio = (fullJSON["bio"] as? [String: Any])?["text"] as? String ?? ""
            isBlocked = fullJSON["is_blocked"] as? Bool ?? false
        }
    }

    func loadGroup(chatId: Int64, type: ChatType, isMuted: Bool) async {
        self.chatId = chatId
        self.chatType = type
        self.isMuted = isMuted
        isLoading = true
        defer { isLoading = false }
        switch type {
        case .supergroup(let sgId, _):
            await loadSupergroup(id: sgId)
        case .basicGroup(let bgId):
            await loadBasicGroup(id: bgId)
        default:
            break
        }
    }

    private func loadSupergroup(id: Int64) async {
        if let full = try? await client.getSupergroupFullInfo(supergroupId: id) {
            description = (full["description"] as? String) ?? ""
            memberCount = full["member_count"] as? Int
            let delay = full["slow_mode_delay"] as? Int ?? 0
            slowModeDelay = delay > 0 ? delay : nil
        }
    }

    private func loadBasicGroup(id: Int64) async {
        if let full = try? await client.getBasicGroupFullInfo(groupId: id) {
            let rawMembers = full["members"] as? [[String: Any]] ?? []
            memberCount = rawMembers.count
            cachedBasicGroupMembers = rawMembers
        }
    }

    // MARK: - Members

    func loadMembers() async {
        guard members.isEmpty, !isLoadingMembers else { return }
        isLoadingMembers = true
        defer { isLoadingMembers = false }
        switch chatType {
        case .supergroup(let sgId, _):
            await fetchSupergroupMembers(supergroupId: sgId, offset: 0)
        case .basicGroup:
            members = await resolveMembers(from: cachedBasicGroupMembers)
            hasMoreMembers = false
        default:
            break
        }
    }

    func loadMoreMembers() async {
        guard case .supergroup(let sgId, _) = chatType, hasMoreMembers, !isLoadingMembers else { return }
        isLoadingMembers = true
        defer { isLoadingMembers = false }
        await fetchSupergroupMembers(supergroupId: sgId, offset: members.count)
    }

    private func fetchSupergroupMembers(supergroupId: Int64, offset: Int) async {
        guard let raw = try? await client.getSupergroupMembers(
            supergroupId: supergroupId, offset: offset, limit: 50
        ) else { return }
        let newMembers = await resolveMembers(from: raw)
        if offset == 0 {
            members = newMembers
        } else {
            members.append(contentsOf: newMembers)
        }
        hasMoreMembers = raw.count == 50
    }

    private func resolveMembers(from raw: [[String: Any]]) async -> [ChatMember] {
        var result: [ChatMember] = []
        for memberJSON in raw {
            guard let senderJSON = memberJSON["member_id"] as? [String: Any],
                  case .user(let uid) = MessageSender(json: senderJSON),
                  let userJSON = try? await client.getUser(id: uid) else { continue }
            let first = userJSON["first_name"] as? String ?? ""
            let last = userJSON["last_name"] as? String ?? ""
            let name = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
            let statusType = (memberJSON["status"] as? [String: Any])?["@type"] as? String ?? ""
            let memberName = name.isEmpty ? "Unknown" : name
            result.append(ChatMember(id: uid, name: memberName, role: .init(statusType: statusType)))
        }
        return result
    }

    // MARK: - Actions

    func muteFor(seconds: Int) async {
        do {
            try await client.muteChat(chatId: chatId, muteFor: seconds)
            isMuted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unmute() async {
        do {
            try await client.muteChat(chatId: chatId, muteFor: 0)
            isMuted = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleBlock() async {
        do {
            if isBlocked {
                try await client.unblockUser(userId: userId)
            } else {
                try await client.blockUser(userId: userId)
            }
            isBlocked.toggle()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leaveChat() async throws {
        try await client.leaveChat(chatId: chatId)
    }
}
