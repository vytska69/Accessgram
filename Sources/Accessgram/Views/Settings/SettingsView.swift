import SwiftUI

struct SettingsView: View {
    @Environment(AppViewModel.self) private var app
    @State private var showLogOutConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .accessibilityAddTraits(.isHeader)

            Divider()

            List {
                Section("Notifications") {
                    Label("Notifications are managed by macOS", systemImage: "bell")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                Section("Privacy") {
                    Link(destination: URL(string: "https://telegram.org/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    .accessibilityHint("Opens Telegram's privacy policy in your browser")
                }

                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Build", systemImage: "hammer")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    Link(destination: URL(string: "https://github.com/vytska69/Accessgram")!) {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showLogOutConfirm = true
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                    .accessibilityHint("Sign out of your Telegram account")
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 340, height: 440)
        .confirmationDialog("Log out of Telegram?", isPresented: $showLogOutConfirm, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) {
                Task { await app.logOut() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
