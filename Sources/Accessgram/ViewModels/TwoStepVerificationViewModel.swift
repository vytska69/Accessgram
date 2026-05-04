import Foundation
import Observation

@Observable
@MainActor
final class TwoStepVerificationViewModel {
    var hasPassword = false
    var hint = ""
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var successMessage: String?

    private let client: TDLibClient

    init(client: TDLibClient) {
        self.client = client
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let state = try? await client.getPasswordState() else { return }
        hasPassword = state["has_password"] as? Bool ?? false
        hint = state["password_hint"] as? String ?? ""
    }

    func applyPassword(old: String, new: String, newHint: String) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await client.setPassword(oldPassword: old, newPassword: new, newHint: newHint)
            successMessage = new.isEmpty ? "Two-step verification disabled." : "Password updated successfully."
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
