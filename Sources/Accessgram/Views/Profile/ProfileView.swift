import SwiftUI

@MainActor
struct ProfileView: View {
    let chat: Chat
    @Environment(AppViewModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ProfileViewModel?
    @State private var showLeaveConfirm = false
    @State private var showBlockConfirm = false

    private var canLeave: Bool {
        chat.type.isGroup || chat.type.isChannel
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                loadedView(vm: vm)
            } else {
                ProgressView("Loading…")
                    .frame(width: 320, height: 240)
            }
        }
        .task {
            let vm = ProfileViewModel(client: app.client)
            viewModel = vm
            switch chat.type {
            case .private(let userId):
                await vm.loadUser(id: userId, chatId: chat.id, isMuted: chat.isMuted)
            default:
                await vm.loadGroup(chatId: chat.id, type: chat.type, isMuted: chat.isMuted)
            }
        }
    }

    @ViewBuilder
    private func loadedView(vm: ProfileViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                AvatarView(title: chat.title, size: 80).accessibilityHidden(true)
                profileHeader(vm: vm)
                Divider()
                profileDetails(vm: vm)
                Divider()
                actionsSection(vm: vm)
                Spacer()
            }
            .padding(32)
        }
        .frame(width: 340, height: 520)
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .confirmationDialog(
            "Leave \"\(chat.title)\"?",
            isPresented: $showLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button("Leave", role: .destructive) {
                Task { try? await vm.leaveChat(); dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will no longer receive messages from this chat.")
        }
        .confirmationDialog(
            vm.isBlocked ? "Unblock \(vm.displayName)?" : "Block \(vm.displayName)?",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button(
                vm.isBlocked ? "Unblock" : "Block",
                role: vm.isBlocked ? .none : .destructive
            ) {
                Task { await vm.toggleBlock() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func profileHeader(vm: ProfileViewModel) -> some View {
        VStack(spacing: 6) {
            Text(vm.displayName.isEmpty ? chat.title : vm.displayName)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            if let u = vm.username {
                Text("@\(u)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Username: @\(u)")
            }
            if !vm.status.isEmpty {
                Text(vm.status)
                    .font(.caption)
                    .foregroundStyle(vm.status == "Online" ? .green : .secondary)
            }
        }
    }

    private func profileDetails(vm: ProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !vm.phone.isEmpty {
                profileRow(icon: "phone", label: "Phone", value: vm.phone)
            }
            if !vm.bio.isEmpty {
                profileRow(icon: "text.alignleft", label: "Bio", value: vm.bio)
            }
            if !vm.description.isEmpty {
                profileRow(icon: "info.circle", label: "Description", value: vm.description)
            }
            if let count = vm.memberCount {
                profileRow(icon: "person.2", label: "Members", value: "\(count)")
            }
            profileRow(icon: "bubble.left", label: "Type", value: chat.type.typeLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func actionsSection(vm: ProfileViewModel) -> some View {
        VStack(spacing: 8) {
            Button {
                Task { await vm.toggleMute() }
            } label: {
                Label(
                    vm.isMuted ? "Unmute" : "Mute",
                    systemImage: vm.isMuted ? "bell" : "bell.slash"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(vm.isMuted ? "Unmute chat" : "Mute chat")

            if case .private = chat.type {
                Button {
                    showBlockConfirm = true
                } label: {
                    Label(
                        vm.isBlocked ? "Unblock" : "Block",
                        systemImage: vm.isBlocked ? "hand.raised.slash" : "hand.raised"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(vm.isBlocked ? nil : .red)
                .accessibilityLabel(vm.isBlocked ? "Unblock contact" : "Block contact")
            }

            if canLeave {
                Button(role: .destructive) {
                    showLeaveConfirm = true
                } label: {
                    Label("Leave", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .accessibilityLabel("Leave \(chat.title)")
            }
        }
    }

    private func profileRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
