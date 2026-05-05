import Foundation

extension TDLibClient {

    func setPhoneNumber(_ phone: String) async throws {
        _ = try await sendRaw("setAuthenticationPhoneNumber", params: [
            "phone_number": phone
        ])
    }

    func checkCode(_ code: String) async throws {
        _ = try await sendRaw("checkAuthenticationCode", params: ["code": code])
    }

    func checkPassword(_ password: String) async throws {
        _ = try await sendRaw("checkAuthenticationPassword", params: ["password": password])
    }

    func logOut() async throws {
        _ = try await sendRaw("logOut")
    }

    func getMe() async throws -> [String: Any] {
        try await sendRaw("getMe")
    }

    func getUser(id: Int64) async throws -> [String: Any] {
        try await sendRaw("getUser", params: ["user_id": id])
    }

    func getUserFullInfo(userId: Int64) async throws -> [String: Any] {
        try await sendRaw("getUserFullInfo", params: ["user_id": userId])
    }

    func getPasswordState() async throws -> [String: Any] {
        try await sendRaw("getPasswordState")
    }

    func setPassword(
        oldPassword: String,
        newPassword: String,
        newHint: String,
        setRecoveryEmail: Bool = false,
        newEmail: String = ""
    ) async throws {
        _ = try await sendRaw("setPassword", params: [
            "old_password": oldPassword,
            "new_password": newPassword,
            "new_hint": newHint,
            "set_recovery_email_address": setRecoveryEmail,
            "new_recovery_email_address": newEmail
        ])
    }

    func registerDevice(apnsToken: Data, isSandbox: Bool) async throws {
        let hexToken = apnsToken.map { String(format: "%02x", $0) }.joined()
        _ = try await sendRaw("registerDevice", params: [
            "device_token": [
                "@type": "deviceTokenApplePush",
                "device_token": hexToken,
                "is_app_sandbox": isSandbox
            ],
            "other_user_ids": []
        ])
    }

    func processPushNotification(payload: String) async throws {
        _ = try await sendRaw("processPushNotification", params: ["payload": payload])
    }

    func getBlockedMessageSenders(offset: Int = 0, limit: Int = 20) async throws -> [MessageSender] {
        let resp = try await sendRaw("getBlockedMessageSenders", params: [
            "block_list": ["@type": "blockListMain"],
            "offset": offset,
            "limit": limit
        ])
        let senders = resp["senders"] as? [[String: Any]] ?? []
        return senders.map { MessageSender(json: $0) }
    }
}
