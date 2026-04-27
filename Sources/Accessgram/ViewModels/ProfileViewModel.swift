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

    private let client: TDLibClient

    init(client: TDLibClient) {
        self.client = client
    }

    func loadUser(id: Int64) async {
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
        }
    }

    func loadGroup(chatId: Int64, type: ChatType) async {
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
        }
    }

    private func loadBasicGroup(id: Int64) async {
        if let full = try? await client.getBasicGroupFullInfo(groupId: id) {
            memberCount = (full["members"] as? [[String: Any]])?.count
        }
    }
}
