import Foundation

struct User: Identifiable {
    let id: Int64
    var firstName: String
    var lastName: String
    var username: String?
    var phone: String
    var status: UserStatus
    var isBot: Bool
    var isContact: Bool

    var displayName: String {
        let full = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        if !full.isEmpty { return full }
        if let u = username { return "@\(u)" }
        return phone.isEmpty ? "Unknown" : phone
    }

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int64 else { return nil }
        self.id = id
        self.firstName = json["first_name"] as? String ?? ""
        self.lastName = json["last_name"] as? String ?? ""
        self.username = (json["usernames"] as? [String: Any])?["editable_username"] as? String
        self.phone = json["phone_number"] as? String ?? ""
        self.isContact = json["is_contact"] as? Bool ?? false
        self.isBot = (json["type"] as? [String: Any])?["@type"] as? String == "userTypeBot"
        self.status = .unknown
    }
}
