import CTDLib
import Foundation

// MARK: - TDLib Client

/// Thread-safe actor that wraps the TDLib JSON API.
actor TDLibClient {
    private let clientId: Int32
    private var updateHandlers: [(TDUpdate) async -> Void] = []
    private var pendingRequests: [String: CheckedContinuation<[String: Any], Error>] = [:]
    private var reqCounter: Int64 = 0
    private var receiveTask: Task<Void, Never>?

    init() {
        clientId = td_create_client_id()
        // Suppress TDLib internal logs (fatal errors only)
        _ = td_execute("{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":0}")
    }

    deinit {
        receiveTask?.cancel()
    }

    // MARK: - Lifecycle

    func start() {
        guard receiveTask == nil else { return }
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
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
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
           let cont = pendingRequests.removeValue(forKey: extra) {
            if (obj["@type"] as? String) == "error" {
                cont.resume(throwing: TDError.api(
                    code: obj["code"] as? Int ?? 0,
                    message: obj["message"] as? String ?? "Unknown TDLib error"
                ))
            } else {
                cont.resume(returning: obj)
            }
            return
        }
        if let update = TDUpdate(json: obj) {
            for handler in updateHandlers { await handler(update) }
        }
    }

    private func nextExtra() -> String {
        reqCounter += 1
        return "req_\(reqCounter)"
    }

    // MARK: - Setup

    func setParameters(apiId: Int, apiHash: String, useTestDc: Bool = false) async throws {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let base = support.appendingPathComponent(useTestDc ? "Accessgram-test" : "Accessgram")
        let dbPath = base.appendingPathComponent("td_db").path
        let filesPath = base.appendingPathComponent("files").path
        try FileManager.default.createDirectory(atPath: dbPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: filesPath, withIntermediateDirectories: true)
        let osVer = ProcessInfo.processInfo.operatingSystemVersion
        let sysVersion = "\(osVer.majorVersion).\(osVer.minorVersion).\(osVer.patchVersion)"
        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let extra = nextExtra()
        let req = TDSetParametersPayload(
            extra: extra,
            useTestDc: useTestDc,
            databaseDirectory: dbPath,
            filesDirectory: filesPath,
            apiId: apiId,
            apiHash: apiHash,
            systemLanguageCode: langCode,
            systemVersion: sysVersion,
            applicationVersion: appVersion
        )
        guard let data = try? JSONEncoder().encode(req),
              let jsonStr = String(data: data, encoding: .utf8) else {
            throw TDError.encodingFailed
        }
        _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[String: Any], Error>) in
            pendingRequests[extra] = cont
            td_send(clientId, jsonStr)
        }
    }
}

// MARK: - setTdlibParameters payload (Codable guarantees true/false for booleans)

private struct TDSetParametersPayload: Encodable {
    var type = "setTdlibParameters"
    var extra: String
    var useTestDc: Bool
    var databaseDirectory: String
    var filesDirectory: String
    var useFileDatabase = true
    var useChatInfoDatabase = true
    var useMessageDatabase = true
    var useSecretChats = false
    var apiId: Int
    var apiHash: String
    var systemLanguageCode: String
    var deviceModel = "Mac"
    var systemVersion: String
    var applicationVersion: String

    enum CodingKeys: String, CodingKey {
        case type = "@type"
        case extra = "@extra"
        case useTestDc = "use_test_dc"
        case databaseDirectory = "database_directory"
        case filesDirectory = "files_directory"
        case useFileDatabase = "use_file_database"
        case useChatInfoDatabase = "use_chat_info_database"
        case useMessageDatabase = "use_message_database"
        case useSecretChats = "use_secret_chats"
        case apiId = "api_id"
        case apiHash = "api_hash"
        case systemLanguageCode = "system_language_code"
        case deviceModel = "device_model"
        case systemVersion = "system_version"
        case applicationVersion = "application_version"
    }
}

// MARK: - Errors

enum TDError: LocalizedError {
    case encodingFailed
    case api(code: Int, message: String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode request"
        case .api(_, let m): return m
        case .timeout: return "Request timed out"
        }
    }
}
