import SwiftUI

struct CodeEntryView: View {
    let phoneNumber: String
    @Environment(AppViewModel.self) private var app
    @State private var code = ""
    @State private var isBusy = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("Enter the Code")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)

            Text("A verification code was sent to \(phoneNumber)")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Verification code sent to \(phoneNumber)")

            TextField("11111", text: $code)
                .textFieldStyle(.roundedBorder)
                .font(.largeTitle.monospacedDigit())
                .multilineTextAlignment(.center)
                .focused($fieldFocused)
                .onSubmit { submit() }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Verification code")
                .accessibilityHint("Enter the verification code sent to your phone")
                .accessibilityValue(code.isEmpty ? "empty" : code.map { String($0) }.joined(separator: " "))

            Button(action: submit) {
                Group {
                    if isBusy {
                        ProgressView().progressViewStyle(.circular).scaleEffect(0.8)
                    } else {
                        Text("Verify").frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(code.isEmpty || isBusy)
            .accessibilityLabel(isBusy ? "Verifying code" : "Verify code")

            Button("Wrong number?") {
                Task { try? await app.client.logOut() }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .accessibilityHint("Go back and enter a different phone number")
        }
        .padding(48)
        .onAppear { fieldFocused = true }
    }

    private func submit() {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isBusy else { return }
        isBusy = true
        Task {
            await app.submitCode(trimmed)
            isBusy = false
        }
    }
}

// MARK: - Password View

struct PasswordView: View {
    @Environment(AppViewModel.self) private var app
    @State private var password = ""
    @State private var isBusy = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "key.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("Two-Step Verification")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)

            Text("Enter your two-step verification password.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onSubmit { submit() }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Two-step verification password")
                .accessibilityHint("Enter your Telegram two-step verification password")

            Button(action: submit) {
                Group {
                    if isBusy {
                        ProgressView().progressViewStyle(.circular).scaleEffect(0.8)
                    } else {
                        Text("Continue").frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(password.isEmpty || isBusy)
            .accessibilityLabel(isBusy ? "Signing in" : "Continue")
        }
        .padding(48)
        .onAppear { fieldFocused = true }
    }

    private func submit() {
        guard !password.isEmpty, !isBusy else { return }
        isBusy = true
        Task {
            await app.submitPassword(password)
            isBusy = false
        }
    }
}
