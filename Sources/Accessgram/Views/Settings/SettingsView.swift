import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(AppViewModel.self) private var app
    @State private var vm: SettingsViewModel?
    @State private var showLogOutConfirm = false
    @State private var showTerminateAllConfirm = false
    @State private var showBlockedUsers = false
    @State private var showTwoStepVerification = false
    @State private var privacyExceptionSetting: PrivacySetting?

    var body: some View {
        Group {
            if let vm {
                loadedView(vm: vm)
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            let model = SettingsViewModel(client: app.client)
            vm = model
            await model.loadAll()
        }
    }

    // MARK: - Main

    @ViewBuilder
    private func loadedView(vm: SettingsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                profileSection(vm: vm)
                generalSection
                notificationsSection(vm: vm)
                privacySection(vm: vm)
                sessionsSection(vm: vm)
                aboutSection
                logOutSection
            }
            .listStyle(.inset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(
            "Error",
            isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            ),
            actions: { Button("OK") { vm.errorMessage = nil } },
            message: { Text(vm.errorMessage ?? "") }
        )
        .sheet(isPresented: $showBlockedUsers) {
            BlockedUsersView(client: app.client)
        }
        .sheet(isPresented: $showTwoStepVerification) {
            NavigationStack {
                TwoStepVerificationView(client: app.client)
            }
            .frame(minWidth: 380, minHeight: 480)
        }
        .sheet(item: $privacyExceptionSetting) { setting in
            NavigationStack {
                PrivacyExceptionsView(setting: setting, client: app.client)
            }
            .frame(minWidth: 380, minHeight: 420)
        }
        .confirmationDialog("Log out of Telegram?", isPresented: $showLogOutConfirm, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) { Task { await app.logOut() } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Terminate all other sessions?",
            isPresented: $showTerminateAllConfirm,
            titleVisibility: .visible
        ) {
            Button("Terminate All", role: .destructive) { Task { await vm.terminateAllOther() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Profile

    @ViewBuilder
    private func profileSection(vm: SettingsViewModel) -> some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    if !vm.myName.isEmpty {
                        Text(vm.myName).font(.headline)
                    }
                    if !vm.myHandle.isEmpty {
                        Text(vm.myHandle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if !vm.myPhone.isEmpty {
                        Text("+\(vm.myPhone)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if !vm.myBio.isEmpty {
                        Text(vm.myBio).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel([vm.myName, vm.myHandle, vm.myPhone.isEmpty ? "" : "+\(vm.myPhone)"]
                .filter { !$0.isEmpty }.joined(separator: ", "))
        }
    }

    // MARK: - General

    private var generalSection: some View {
        let prefs = AppPreferences.shared
        return Section(
            header: HStack {
                Text("General")
                Spacer()
                if prefs.iCloudAvailable {
                    Label("iCloud", systemImage: "icloud")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Local only")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            },
            footer: Text(prefs.iCloudAvailable
                 ? "Preferences are synced across your devices via iCloud."
                 : "Sign into iCloud in System Settings to sync preferences across devices.")
        ) {
            Toggle("Show Format Bar", isOn: Binding(
                get: { prefs.showFormatBar },
                set: { prefs.showFormatBar = $0 }
            ))
            .accessibilityLabel("Show rich text format bar in composer")

            Toggle("Compact Chat List", isOn: Binding(
                get: { prefs.compactChatList },
                set: { prefs.compactChatList = $0 }
            ))
            .accessibilityLabel("Use compact density for chat list rows")

            Toggle("Sound on New Message", isOn: Binding(
                get: { prefs.playSoundOnMessage },
                set: { prefs.playSoundOnMessage = $0 }
            ))
            .accessibilityLabel("Play a sound when a new message arrives")

            Toggle("Jump to Latest on Open", isOn: Binding(
                get: { prefs.jumpToLatestOnOpen },
                set: { prefs.jumpToLatestOnOpen = $0 }
            ))
            .accessibilityLabel("Scroll to the newest message when opening a chat")
        }
    }

    // MARK: - Notifications

    @ViewBuilder
    private func notificationsSection(vm: SettingsViewModel) -> some View {
        Section("Notifications") {
            ForEach(NotificationScope.allCases, id: \.self) { scope in
                if let s = vm.notifSettings[scope] {
                    DisclosureGroup(content: {
                        Toggle("Mute", isOn: Binding(
                            get: { s.muted },
                            set: { v in Task { await vm.setNotification(scope: scope, muted: v) } }
                        ))
                        Toggle("Show Preview", isOn: Binding(
                            get: { s.showPreview },
                            set: { v in Task { await vm.setNotification(scope: scope, preview: v) } }
                        ))
                        Toggle("Sound", isOn: Binding(
                            get: { s.soundEnabled },
                            set: { v in Task { await vm.setNotification(scope: scope, sound: v) } }
                        ))
                    }, label: {
                        HStack {
                            Label(scope.label, systemImage: s.muted ? "bell.slash" : "bell")
                            Spacer()
                            Text(s.muted ? "Muted" : "On")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    })
                    .accessibilityLabel("\(scope.label), \(s.muted ? "muted" : "on")")
                }
            }
        }
    }

    // MARK: - Privacy

    @ViewBuilder
    private func privacySection(vm: SettingsViewModel) -> some View {
        Section("Privacy") {
            Button(action: { showTwoStepVerification = true }, label: {
                Label("Two-Step Verification", systemImage: "lock.shield")
            })
            .accessibilityLabel("Manage two-step verification password")
            Button(action: { showBlockedUsers = true }, label: {
                Label("Blocked Users", systemImage: "hand.raised")
            })
            .accessibilityLabel("View blocked users")
            let settings: [PrivacySetting] = [.lastSeen, .profilePhoto, .calls, .groupInvites, .forwards]
            ForEach(settings, id: \.self) { key in
                HStack {
                    Text(key.label)
                    Spacer()
                    Button(action: { privacyExceptionSetting = key }, label: {
                        Image(systemName: "person.2.badge.gearshape")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    })
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit exceptions for \(key.label)")
                    Picker("", selection: Binding(
                        get: { vm.privacyValues[key] ?? .everybody },
                        set: { v in Task { await vm.setPrivacy(setting: key, value: v) } }
                    )) {
                        ForEach(PrivacyValue.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 130)
                    .accessibilityLabel("\(key.label): \(vm.privacyValues[key]?.label ?? "Everybody")")
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
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
            Link(destination: URL(string: "https://telegram.org/privacy")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            Button(action: { NSWorkspace.shared.activateFileViewerSelecting([Log.fileURL]) }, label: {
                Label("Reveal Logs in Finder", systemImage: "doc.text.magnifyingglass")
            })
            .accessibilityHint("Opens ~/Library/Logs/Accessgram/ in Finder")
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(Log.fileURL.path, forType: .string)
            }, label: {
                Label("Copy Log Path", systemImage: "doc.on.clipboard")
            })
            .accessibilityHint("Copies the log file path to clipboard")
        }
    }

    // MARK: - Log Out

    private var logOutSection: some View {
        Section {
            Button(role: .destructive, action: { showLogOutConfirm = true }, label: {
                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.red)
            })
            .accessibilityHint("Sign out of your Telegram account")
        }
    }
}

// MARK: - Sessions section (extension to keep struct body under type_body_length limit)

private extension SettingsView {
    @ViewBuilder
    func sessionsSection(vm: SettingsViewModel) -> some View {
        Section(header: HStack {
            Text("Active Sessions")
            Spacer()
            Button(action: { Task { await vm.loadSessions() } }, label: {
                Image(systemName: "arrow.clockwise").font(.caption)
            })
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh sessions")
        }) {
            ForEach(vm.sessions) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(session.displayName).font(.headline)
                            if session.isCurrent {
                                Text("Current")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(session.deviceInfo).font(.caption).foregroundStyle(.secondary)
                        Text(session.lastActiveString).font(.caption2).foregroundStyle(.secondary)
                        if !session.country.isEmpty {
                            Text(session.country).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if !session.isCurrent {
                        Button(role: .destructive, action: { Task { await vm.terminateSession(session) } }, label: {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.red)
                        })
                        .buttonStyle(.plain)
                        .accessibilityLabel("Terminate session \(session.displayName)")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel([
                    session.displayName,
                    session.deviceInfo,
                    session.lastActiveString,
                    session.isCurrent ? "Current device" : ""
                ].filter { !$0.isEmpty }.joined(separator: ", "))
            }

            if vm.sessions.filter({ !$0.isCurrent }).count > 1 {
                Button(role: .destructive, action: { showTerminateAllConfirm = true }, label: {
                    Label("Terminate All Other Sessions", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                })
            }
        }
    }
}
