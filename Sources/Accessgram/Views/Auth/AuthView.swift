import SwiftUI

struct AuthView: View {
    @Environment(AppViewModel.self) private var app
    @State private var countryCode = "+"
    @State private var phoneNumber = ""
    @State private var isBusy = false
    @FocusState private var focus: Field?

    private enum Field { case countryCode, phoneNumber }

    private var fullNumber: String { countryCode + phoneNumber }
    private var canSubmit: Bool {
        countryCode.count >= 2 && !phoneNumber.isEmpty && !isBusy
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 52))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("Sign in to Telegram")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)

            Text("Enter your country code and phone number.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                TextField("+1", text: $countryCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .focused($focus, equals: .countryCode)
                    .frame(width: 72)
                    .multilineTextAlignment(.center)
                    .onSubmit { focus = .phoneNumber }
                    .accessibilityLabel("Country code")
                    .accessibilityHint("For example plus 370 for Lithuania")
                    .onChange(of: countryCode) { _, v in
                        if !v.hasPrefix("+") { countryCode = "+" + v.filter(\.isNumber) }
                    }

                TextField("612 34567", text: $phoneNumber)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .focused($focus, equals: .phoneNumber)
                    .frame(maxWidth: .infinity)
                    .onSubmit { submit() }
                    .accessibilityLabel("Phone number")
                    .accessibilityHint("Enter phone number without country code")
            }

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
            .frame(maxWidth: .infinity)
            .disabled(!canSubmit)
            .accessibilityLabel(isBusy ? "Sending verification code" : "Continue")
            .accessibilityHint("Sends a verification code to your phone")
        }
        .padding(40)
        .onAppear { focus = .countryCode }
    }

    private func submit() {
        guard canSubmit else { return }
        isBusy = true
        Task {
            await app.submitPhone(fullNumber)
            isBusy = false
        }
    }
}
