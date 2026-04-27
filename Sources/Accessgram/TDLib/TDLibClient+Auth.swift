import Foundation

extension TDLibClient {

    func setPhoneNumber(_ phone: String) async throws {
        _ = try await sendRaw("setAuthenticationPhoneNumber", params: [
            "phone_number": phone,
            "settings": [
                "@type": "phoneNumberAuthenticationSettings",
                "allow_flash_call": false,
                "allow_missed_call": false,
                "is_current_phone_number": false,
                "allow_sms_retriever_api": false
            ]
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
}
