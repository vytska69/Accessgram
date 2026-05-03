import SwiftUI

struct SettingsView: View {
    @Environment(AppViewModel.self) private var app
    @State private var vm: SettingsViewModel?
    @State private var showLogOutConfirm = false
    @State private var showTerminateAllConfirm = false

    var body: some View {
        Group {
            if let vm {
                loadedView(vm: vm)
            } else {
                ProgressView("Loading…")
                    .frame(width: 420, height: 520)
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
            // Header
            Text("Settings")
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .accessibilityAddTraits(.isHeader)

            Divider()

            List {
                profileSection(vm: vm)
                notificationsSection(vm: vm)
                privacySection(vm: vm)
                sessionsSection(vm: vm)
                aboutSection
                logOutSection
            }
            .listStyle(.inset)
        }
        .frame(width: 420, height: 620)
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .confirmationDialog("Log out of Telegram?", isPresented: $showLogOutConfirm, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) { Task { await app.logOut() } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Terminate all other sessions?", isPresented: $showTerminateAllConfirm, titleVisibility: .visible) {
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

    // MARK: - Notifications

    @ViewBuilder
    private func notificationsSection(vm: SettingsViewModel) -> some View {
        Section("Notifications") {
            ForEach(NotificationScope.allCases, id: \.self) { scope in
                if let s = vm.notifSettings[scope] {
                    DisclosureGroup {
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
                    } label: {
                        HStack {
                            Label(scope.label, systemImage: s.muted ? "bell.slash" : "bell")
                            Spacer()
                            Text(s.muted ? "Muted" : "On")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("\(scope.label), \(s.muted ? "muted" : "on")")
                }
            }
        }
    }

    // MARK: - Privacy

    @ViewBuilder
    private func privacySection(vm: SettingsViewModel) -> some View {
        Section("Privacy") {
            let settings: [PrivacySetting] = [.lastSeen, .profilePhoto, .calls, .groupInvites, .forwards]
            ForEach(settings, id: \.self) { key in
                HStack {
                    Text(key.label)
                    Spacer()
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

    // MARK: - Sessions

    @ViewBuilder
    private func sessionsSection(vm: SettingsViewModel) -> some View {
        Section {
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
                        Button(role: .destructive) {
                            Task { await vm.terminateSession(session) }
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.red)
                        }
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
                Button(role: .destructive) {
                    showTerminateAllConfirm = true
                } label: {
                    Label("Terminate All Other Sessions", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
            }
        } header: {
            HStack {
                Text("Active Sessions")
                Spacer()
                Button { Task { await vm.loadSessions() } } label: {
                    Image(systemName: "arrow.clockwise").font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh sessions")
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
        }
    }

    // MARK: - Log Out

    private var logOutSection: some View {
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
}
