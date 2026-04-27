import SwiftUI

struct CredentialsView: View {
    @Environment(AppViewModel.self) private var app
    @State private var apiIdText = ""
    @State private var apiHash = ""
    @State private var isBusy = false
    @FocusState private var focus: Field?

    private enum Field { case apiId, apiHash }

    private var apiIdValid: Bool { Int(apiIdText.trimmingCharacters(in: .whitespaces)) != nil }
    private var canSubmit: Bool { apiIdValid && !apiHash.trimmingCharacters(in: .whitespaces).isEmpty && !isBusy }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("API Credentials")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)

            Text("Get your api_id and api_hash from my.telegram.org/apps.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Link("Open my.telegram.org", destination: URL(string: "https://my.telegram.org/apps")!)
                .font(.callout)
                .accessibilityHint("Opens Telegram's developer portal in your browser")

            VStack(alignment: .leading, spacing: 8) {
                Text("App api_id")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("12345", text: $apiIdText)
                    .textFieldStyle(.roundedBorder)
                    .focused($focus, equals: .apiId)
                    .onSubmit { focus = .apiHash }
                    .frame(maxWidth: 280)
                    .accessibilityLabel("App api_id")
                    .accessibilityHint("Numeric identifier from my.telegram.org/apps")
                    .accessibilityValue(apiIdText.isEmpty ? "empty" : apiIdText)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("App api_hash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("0123456789abcdef…", text: $apiHash)
                    .textFieldStyle(.roundedBorder)
                    .focused($focus, equals: .apiHash)
                    .onSubmit { if canSubmit { submit() } }
                    .frame(maxWidth: 280)
                    .accessibilityLabel("App api_hash")
                    .accessibilityHint("Hash string from my.telegram.org/apps")
                    .accessibilityValue(apiHash.isEmpty ? "empty" : "entered")
            }

            Button(action: submit) {
                Group {
                    if isBusy {
                        ProgressView().progressViewStyle(.circular).scaleEffect(0.8)
                    } else {
                        Text("Save & Connect").frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: 280)
            .disabled(!canSubmit)
            .accessibilityLabel(isBusy ? "Connecting" : "Save credentials and connect")
        }
        .padding(48)
        .onAppear { focus = .apiId }
    }

    private func submit() {
        let trimmedId = apiIdText.trimmingCharacters(in: .whitespaces)
        let trimmedHash = apiHash.trimmingCharacters(in: .whitespaces)
        guard let numericId = Int(trimmedId), !trimmedHash.isEmpty, !isBusy else { return }
        isBusy = true
        Task {
            await app.saveCredentials(apiId: numericId, apiHash: trimmedHash)
            isBusy = false
        }
    }
}
