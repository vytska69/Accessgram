import SwiftUI

struct AuthView: View {
    @Environment(AppViewModel.self) private var app
    @State private var phoneNumber = ""
    @State private var isBusy = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("Sign in to Telegram")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)

            Text("Enter your phone number with country code to receive a verification code.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("+1 234 567 8900", text: $phoneNumber)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .focused($fieldFocused)
                .onSubmit { submit() }
                .frame(maxWidth: 280)
                .accessibilityLabel("Phone number")
                .accessibilityHint("Enter your phone number including country code, for example plus 1 234 567 8900")
                .accessibilityValue(phoneNumber.isEmpty ? "empty" : phoneNumber)

            Button(action: submit) {
                Group {
                    if isBusy {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: 280)
            .disabled(phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)
            .accessibilityLabel(isBusy ? "Sending verification code" : "Continue")
            .accessibilityHint("Sends a verification code to your phone")
        }
        .padding(48)
        .onAppear { fieldFocused = true }
    }

    private func submit() {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isBusy else { return }
        isBusy = true
        Task {
            await app.submitPhone(trimmed)
            isBusy = false
        }
    }
}
