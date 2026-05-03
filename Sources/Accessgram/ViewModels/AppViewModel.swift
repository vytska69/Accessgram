import Foundation
import AppKit
import Observation

// MARK: - Auth State

enum AuthState: Equatable {
    case launching
    case waitingForPhone
    case waitingForCode(phone: String)
    case waitingForPassword
    case ready
    case error(String)
}

// MARK: - App ViewModel

@Observable
@MainActor
final class AppViewModel {
    var authState: AuthState = .launching
    var errorMessage: String?
    let chatListViewModel: ChatListViewModel

    private let apiId: Int = 23618133
    private let apiHash: String = "421fd1c66ea61e98d93734fe729f6181"

    let client: TDLibClient

    init() {
        Log.clear()
        Log.write("App init")
        let c = TDLibClient()
        self.client = c
        self.chatListViewModel = ChatListViewModel(client: c)
        Task { await self.boot() }
    }

    func boot() async {
        Log.write("boot() start")
        // Register chat list handler first so it catches updateNewChat from local cache.
        let clvm = chatListViewModel
        await client.addUpdateHandler { update in
            await MainActor.run { clvm.handleUpdate(update) }
        }
        await client.addUpdateHandler { [weak self] update in
            await self?.handleUpdate(update)
        }
        await client.addUpdateHandler { [weak self] update in
            await self?.handleNotification(update)
        }
        await client.start()
        Log.write("boot() receive loop started")
    }

    private func handleUpdate(_ update: TDUpdate) async {
        switch update {
        case .authorizationState(let state):
            Log.write("authorizationState → \(state)")
            if case .waitTdlibParameters = state {
                Log.write("sending setTdlibParameters")
                do {
                    try await client.setParameters(apiId: apiId, apiHash: apiHash)
                    Log.write("setParameters sent ok")
                } catch {
                    Log.write("setParameters error: \(error)")
                    authState = .error(error.localizedDescription)
                }
            }
            applyAuthState(state)
        default:
            break
        }
    }

    private func applyAuthState(_ state: AuthorizationState) {
        switch state {
        case .waitTdlibParameters, .waitEncryptionKey:
            authState = .launching
        case .waitPhoneNumber:
            authState = .waitingForPhone
        case .waitCode:
            if case .waitingForCode = authState { break }
            authState = .waitingForCode(phone: "")
        case .waitPassword:
            authState = .waitingForPassword
        case .ready:
            if case .ready = authState { break }
            authState = .ready
            Task { await chatListViewModel.loadInitial() }
        case .closed:
            authState = .launching
        }
    }

    // MARK: - Background Notifications

    private func handleNotification(_ update: TDUpdate) async {
        guard case .newMessage(let msg) = update else { return }
        guard !msg.isOutgoing else { return }
        guard !NSApp.isActive else { return }

        let chat = chatListViewModel.chats.first { $0.id == msg.chatId }
        guard let chat, !chat.isMuted else { return }

        let title = chat.title
        var body  = msg.content.previewText

        // Prepend sender name in group chats
        if chat.type.isGroup || chat.type.isChannel, case .user(let uid) = msg.sender {
            if let user = try? await client.getUser(id: uid) {
                let first = user["first_name"] as? String ?? ""
                let last  = user["last_name"]  as? String ?? ""
                let name  = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
                if !name.isEmpty { body = "\(name): \(body)" }
            }
        }

        NotificationService.shared.send(chatId: msg.chatId, title: title, body: body)
    }

    // MARK: - Auth Actions

    func submitPhone(_ phone: String) async {
        do {
            try await client.setPhoneNumber(phone)
            authState = .waitingForCode(phone: phone)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitCode(_ code: String) async {
        do {
            try await client.checkCode(code)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitPassword(_ password: String) async {
        do {
            try await client.checkPassword(password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logOut() async {
        do {
            try await client.logOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
