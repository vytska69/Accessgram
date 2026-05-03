import Foundation

// MARK: - Notification Scopes

enum NotificationScope: String, CaseIterable {
    case privateChats = "notificationSettingsScopePrivateChats"
    case groupChats = "notificationSettingsScopeGroupChats"
    case channelChats = "notificationSettingsScopeChannelChats"

    var label: String {
        switch self {
        case .privateChats: return "Private Chats"
        case .groupChats: return "Groups"
        case .channelChats: return "Channels"
        }
    }
}

struct ScopeNotificationSettings {
    var muted: Bool
    var showPreview: Bool
    var soundEnabled: Bool

    init(json: [String: Any]) {
        muted = (json["mute_for"] as? Int ?? 0) > 0
        showPreview = json["show_preview"] as? Bool ?? true
        soundEnabled = (json["sound_id"] as? Int ?? 1) != 0
    }
}

// MARK: - Privacy Rule

enum PrivacyValue: String, CaseIterable, Identifiable {
    case everybody = "userPrivacySettingRuleAllowAll"
    case contacts = "userPrivacySettingRuleAllowContacts"
    case nobody = "userPrivacySettingRuleRestrictAll"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .everybody: return "Everybody"
        case .contacts: return "My Contacts"
        case .nobody: return "Nobody"
        }
    }
}

enum PrivacySetting: String {
    case lastSeen = "userPrivacySettingShowStatus"
    case profilePhoto = "userPrivacySettingShowProfilePhoto"
    case calls = "userPrivacySettingAllowCalls"
    case groupInvites = "userPrivacySettingAllowChatInvites"
    case forwards = "userPrivacySettingShowLinkInForwardedMessages"

    var label: String {
        switch self {
        case .lastSeen: return "Last Seen & Online"
        case .profilePhoto: return "Profile Photo"
        case .calls: return "Calls"
        case .groupInvites: return "Group & Channel Invites"
        case .forwards:     return "Forwarded Messages"
        }
    }
}

// MARK: - Session

struct TGSession: Identifiable {
    let id: Int64
    let isCurrent: Bool
    let deviceModel: String
    let platform: String
    let appName: String
    let appVersion: String
    let country: String
    let lastActiveDate: Int

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int64 else { return nil }
        self.id = id
        isCurrent = json["is_current"] as? Bool ?? false
        deviceModel = json["device_model"] as? String ?? ""
        platform = json["platform"] as? String ?? ""
        appName = json["application_name"] as? String ?? ""
        appVersion = json["application_version"] as? String ?? ""
        country = json["country"] as? String ?? ""
        lastActiveDate = json["last_active_date"] as? Int ?? 0
    }

    var displayName: String { "\(appName) \(appVersion)" }
    var deviceInfo: String { [deviceModel, platform].filter { !$0.isEmpty }.joined(separator: ", ") }

    var lastActiveString: String {
        let date = Date(timeIntervalSince1970: TimeInterval(lastActiveDate))
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .full
        return isCurrent ? "This device" : fmt.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - TDLibClient extensions

extension TDLibClient {

    // MARK: Notifications

    func getScopeNotificationSettings(scope: NotificationScope) async throws -> ScopeNotificationSettings {
        let resp = try await sendRaw("getScopeNotificationSettings", params: [
            "scope": ["@type": scope.rawValue]
        ])
        return ScopeNotificationSettings(json: resp)
    }

    func setScopeNotificationSettings(
        scope: NotificationScope,
        muted: Bool,
        showPreview: Bool,
        soundEnabled: Bool
    ) async throws {
        _ = try await sendRaw("setScopeNotificationSettings", params: [
            "scope": ["@type": scope.rawValue],
            "notification_settings": [
                "@type": "scopeNotificationSettings",
                "mute_for": muted ? 2_147_483_647 : 0,
                "sound_id": soundEnabled ? 1 : 0,
                "show_preview": showPreview,
                "use_default_mute_for": false,
                "use_default_sound": false,
                "use_default_show_preview": false
            ]
        ])
    }

    // MARK: Privacy

    func getPrivacySettingRules(setting: PrivacySetting) async throws -> PrivacyValue {
        let resp = try await sendRaw("getUserPrivacySettingRules", params: [
            "setting": ["@type": setting.rawValue]
        ])
        let rules = resp["rules"] as? [[String: Any]] ?? []
        let firstType = rules.first?["@type"] as? String ?? ""
        return PrivacyValue(rawValue: firstType) ?? .everybody
    }

    func setPrivacySettingRules(setting: PrivacySetting, value: PrivacyValue) async throws {
        _ = try await sendRaw("setUserPrivacySettingRules", params: [
            "setting": ["@type": setting.rawValue],
            "rules": ["rules": [["@type": value.rawValue]]]
        ])
    }

    // MARK: Sessions

    func getActiveSessions() async throws -> [TGSession] {
        let resp = try await sendRaw("getActiveSessions")
        let arr = resp["sessions"] as? [[String: Any]] ?? []
        return arr.compactMap { TGSession(json: $0) }
    }

    func terminateSession(id: Int64) async throws {
        _ = try await sendRaw("terminateSession", params: ["session_id": id])
    }

    func terminateAllOtherSessions() async throws {
        _ = try await sendRaw("terminateAllOtherSessions")
    }
}
