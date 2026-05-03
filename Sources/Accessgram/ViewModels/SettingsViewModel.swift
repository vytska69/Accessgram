import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var myName = ""
    var myHandle = ""
    var myPhone = ""
    var myBio = ""

    var notifSettings: [NotificationScope: ScopeNotificationSettings] = [:]
    var privacyValues: [PrivacySetting: PrivacyValue] = [:]
    var sessions: [TGSession] = []

    var isLoading = false
    var errorMessage: String?

    private let client: TDLibClient

    init(client: TDLibClient) {
        self.client = client
    }

    // MARK: - Load

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadMe() }
            group.addTask { await self.loadNotifications() }
            group.addTask { await self.loadPrivacy() }
            group.addTask { await self.loadSessions() }
        }
    }

    private func loadMe() async {
        guard let me = try? await client.getMe() else { return }
        myName = [me["first_name"] as? String, me["last_name"] as? String]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        myHandle = (me["usernames"] as? [String: Any]).flatMap {
            ($0["active_usernames"] as? [String])?.first
        }.map { "@\($0)" } ?? ""
        myPhone = me["phone_number"] as? String ?? ""
        if let id = me["id"] as? Int64,
           let full = try? await client.getUserFullInfo(userId: id) {
            myBio = (full["bio"] as? [String: Any])?["text"] as? String ?? ""
        }
    }

    private func loadNotifications() async {
        for scope in NotificationScope.allCases {
            if let s = try? await client.getScopeNotificationSettings(scope: scope) {
                notifSettings[scope] = s
            }
        }
    }

    private func loadPrivacy() async {
        let keys: [PrivacySetting] = [.lastSeen, .profilePhoto, .calls, .groupInvites, .forwards]
        for key in keys {
            if let v = try? await client.getPrivacySettingRules(setting: key) {
                privacyValues[key] = v
            }
        }
    }

    func loadSessions() async {
        sessions = (try? await client.getActiveSessions()) ?? []
    }

    // MARK: - Notifications

    func setNotification(scope: NotificationScope, muted: Bool? = nil, preview: Bool? = nil, sound: Bool? = nil) async {
        guard var s = notifSettings[scope] else { return }
        if let v = muted { s.muted = v }
        if let v = preview { s.showPreview = v }
        if let v = sound { s.soundEnabled = v }
        notifSettings[scope] = s
        do {
            try await client.setScopeNotificationSettings(
                scope: scope,
                muted: s.muted,
                showPreview: s.showPreview,
                soundEnabled: s.soundEnabled
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Privacy

    func setPrivacy(setting: PrivacySetting, value: PrivacyValue) async {
        privacyValues[setting] = value
        do {
            try await client.setPrivacySettingRules(setting: setting, value: value)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sessions

    func terminateSession(_ session: TGSession) async {
        do {
            try await client.terminateSession(id: session.id)
            sessions.removeAll { $0.id == session.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func terminateAllOther() async {
        do {
            try await client.terminateAllOtherSessions()
            sessions = sessions.filter { $0.isCurrent }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
