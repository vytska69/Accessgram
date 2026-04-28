import Foundation
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
    var chatListViewModel: ChatListViewModel?

    private let apiId: Int = 23618133
    private let apiHash: String = "421fd1c66ea61e98d93734fe729f6181"

    let client: TDLibClient

    init() {
        self.client = TDLibClient()
        Task { await self.boot() }
    }

    func boot() async {
        await client.addUpdateHandler { [weak self] update in
            await self?.handleUpdate(update)
        }
        await client.start()
    }

    private func handleUpdate(_ update: TDUpdate) async {
        switch update {
        case .authorizationState(let state):
            if case .waitTdlibParameters = state {
                do {
                    try await client.setParameters(apiId: apiId, apiHash: apiHash)
                } catch {
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
        case .waitTdlibParameters:
            authState = .launching
        case .waitPhoneNumber:
            authState = .waitingForPhone
        case .waitCode:
            if case .waitingForCode = authState { break }
            authState = .waitingForCode(phone: "")
        case .waitPassword:
            authState = .waitingForPassword
        case .ready:
            authState = .ready
        case .closed:
            authState = .launching
        }
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
