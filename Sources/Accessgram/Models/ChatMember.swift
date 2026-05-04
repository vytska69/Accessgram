import Foundation

struct ChatMember: Identifiable {
    let id: Int64
    let name: String
    let role: Role

    enum Role {
        case owner, admin, member

        init(statusType: String) {
            switch statusType {
            case "chatMemberStatusCreator": self = .owner
            case "chatMemberStatusAdministrator": self = .admin
            default: self = .member
            }
        }

        var label: String {
            switch self {
            case .owner: return "Owner"
            case .admin: return "Admin"
            case .member: return ""
            }
        }
    }
}
