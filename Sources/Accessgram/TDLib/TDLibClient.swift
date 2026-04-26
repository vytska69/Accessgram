import Foundation
import CTDLib

// MARK: - TDLib Client

/// Thread-safe actor that wraps the TDLib JSON API.
actor TDLibClient {
    private let clientId: Int32
    private var updateHandlers: [(TDUpdate) async -> Void] = []
    private var pendingRequests: [String: CheckedContinuation<[String: Any], Error>] = [:]
    private var reqCounter: Int64 = 0
    private var receiveTask: Task<Void, Never>?

    init() {
        self.clientId = td_create_client_id()
    }

    deinit {
        receiveTask?.cancel()
    }

    // MARK: - Lifecycle

    func start() {
        receiveTask = Task.detached(priority: .userInitiated) { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let raw = td_receive(1.0) {
                    let json = String(cString: raw)
                    await self.handleRaw(json)
                }
            }
        }
    }

    func addUpdateHandler(_ handler: @escaping (TDUpdate) async -> Void) {
        updateHandlers.append(handler)
    }

    // MARK: - Raw Send/Receive

    func sendRaw(_ type: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        let extra = nextExtra()
        var obj: [String: Any] = ["@type": type, "@extra": extra]
        obj.merge(params) { _, new in new }

        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: []),
              let jsonStr = String(data: data, encoding: .utf8) else {
            throw TDError.encodingFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[extra] = continuation
            td_send(clientId, jsonStr)
        }
    }

    private func handleRaw(_ json: String) async {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if let extra = obj["@extra"] as? String,
           let continuation = pendingRequests.removeValue(forKey: extra) {
            if (obj["@type"] as? String) == "error" {
                let code = obj["code"] as? Int ?? 0
                let msg  = obj["message"] as? String ?? "Unknown TDLib error"
                continuation.resume(throwing: TDError.api(code: code, message: msg))
            } else {
                continuation.resume(returning: obj)
            }
            return
        }

        if let update = TDUpdate(json: obj) {
            for handler in updateHandlers {
                await handler(update)
            }
        }
    }

    private func nextExtra() -> String {
        reqCounter += 1
        return "req_\(reqCounter)"
    }

    // MARK: - TDLib Setup

    /// Call once after creating the client.
    func setParameters(apiId: Int, apiHash: String) async {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let base    = support.appendingPathComponent("Accessgram")
        let dbPath  = base.appendingPathComponent("td_db").path
        let files   = base.appendingPathComponent("files").path

        try? FileManager.default.createDirectory(atPath: dbPath, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: files, withIntermediateDirectories: true)

        _ = try? await sendRaw("setTdlibParameters", params: [
            "use_message_database": true,
            "use_secret_chats":     false,
            "api_id":               apiId,
            "api_hash":             apiHash,
            "system_language_code": Locale.current.language.languageCode?.identifier ?? "en",
            "device_model":         "Mac",
            "application_version":  Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "database_directory":   dbPath,
            "files_directory":      files
        ])
    }

    // MARK: - Auth

    func setPhoneNumber(_ phone: String) async throws {
        _ = try await sendRaw("setAuthenticationPhoneNumber", params: [
            "phone_number": phone,
            "settings": [
                "@type":                      "phoneNumberAuthenticationSettings",
                "allow_flash_call":           false,
                "allow_missed_call":          false,
                "is_current_phone_number":    false,
                "allow_sms_retriever_api":    false
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

    // MARK: - Chats

    func loadChatList(limit: Int = 20) async throws {
        _ = try await sendRaw("loadChats", params: [
            "chat_list": ["@type": "chatListMain"],
            "limit":     limit
        ])
    }

    func getChat(id: Int64) async throws -> [String: Any] {
        try await sendRaw("getChat", params: ["chat_id": id])
    }

    func getChatHistory(chatId: Int64, fromId: Int64 = 0, limit: Int = 50) async throws -> [[String: Any]] {
        let resp = try await sendRaw("getChatHistory", params: [
            "chat_id":         chatId,
            "from_message_id": fromId,
            "offset":          0,
            "limit":           limit,
            "only_local":      false
        ])
        return resp["messages"] as? [[String: Any]] ?? []
    }

    func sendTextMessage(chatId: Int64, text: String, replyToId: Int64? = nil) async throws {
        var params: [String: Any] = [
            "chat_id": chatId,
            "input_message_content": [
                "@type": "inputMessageText",
                "text": [
                    "@type":    "formattedText",
                    "text":     text,
                    "entities": []
                ],
                "clear_draft": true
            ]
        ]
        if let rid = replyToId {
            params["reply_to"] = ["@type": "inputMessageReplyToMessage", "message_id": rid]
        }
        _ = try await sendRaw("sendMessage", params: params)
    }

    func viewMessages(chatId: Int64, ids: [Int64]) async {
        _ = try? await sendRaw("viewMessages", params: [
            "chat_id":     chatId,
            "message_ids": ids,
            "force_read":  true
        ])
    }

    func deleteMessage(chatId: Int64, messageId: Int64, forAll: Bool) async throws {
        _ = try await sendRaw("deleteMessages", params: [
            "chat_id":     chatId,
            "message_ids": [messageId],
            "revoke":      forAll
        ])
    }

    func getUser(id: Int64) async throws -> [String: Any] {
        try await sendRaw("getUser", params: ["user_id": id])
    }
}

// MARK: - Errors

enum TDError: LocalizedError {
    case encodingFailed
    case api(code: Int, message: String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .encodingFailed:           return "Failed to encode request"
        case .api(_, let m):            return m
        case .timeout:                  return "Request timed out"
        }
    }
}
