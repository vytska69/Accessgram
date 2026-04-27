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

    // Telegram Desktop's public test credentials — connects to test DC only.
    // Never use these on production servers.
    private let apiId: Int = 17349
    private let apiHash: String = "344583e45741c457fe1862106095a5eb"

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
        await client.setParameters(apiId: apiId, apiHash: apiHash, useTestDc: true)
    }

    private func handleUpdate(_ update: TDUpdate) async {
        switch update {
        case .authorizationState(let state):
            await MainActor.run { applyAuthState(state) }
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
