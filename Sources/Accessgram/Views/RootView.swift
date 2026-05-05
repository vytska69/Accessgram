import SwiftUI

struct RootView: View {
    @Environment(AppViewModel.self) private var app

    var body: some View {
        Group {
            switch app.authState {
            case .launching:
                ProgressView("Connecting…")
                    .accessibilityLabel("Connecting to Telegram")
                    .frame(width: 360, height: 240)

            case .waitingForPhone:
                AuthView()
                    .frame(width: 420, height: 480)

            case .waitingForCode(let phone):
                CodeEntryView(phoneNumber: phone)
                    .frame(width: 420, height: 480)

            case .waitingForPassword:
                PasswordView()
                    .frame(width: 420, height: 480)

            case .ready:
                MainView()
                    .frame(minWidth: 860, minHeight: 600)

            case .error(let msg):
                ErrorView(message: msg)
                    .frame(width: 420, height: 300)
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { app.errorMessage != nil },
                set: { if !$0 { app.errorMessage = nil } }
            ),
            actions: { Button("OK") { app.errorMessage = nil } },
            message: { Text(app.errorMessage ?? "") }
        )
    }
}

// MARK: - Error View

private struct ErrorView: View {
    let message: String
    @Environment(AppViewModel.self) private var app

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            Text("Connection Error")
                .font(.title2.bold())

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Try Again") {
                Task { await app.boot() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Try connecting again")
        }
        .padding(40)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Connection error: \(message). Button: Try Again.")
    }
}
