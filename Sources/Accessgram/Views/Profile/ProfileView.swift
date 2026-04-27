import SwiftUI

@MainActor
struct ProfileView: View {
    let chat: Chat
    @Environment(AppViewModel.self) private var app
    @State private var viewModel: ProfileViewModel?

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
                await vm.loadUser(id: userId)
            default:
                await vm.loadGroup(chatId: chat.id, type: chat.type)
            }
        }
    }

    @ViewBuilder
    private func loadedView(vm: ProfileViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                AvatarView(title: chat.title, size: 80)
                    .accessibilityHidden(true)

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

                Divider()

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
                        profileRow(
                            icon: "person.2",
                            label: "Members",
                            value: "\(count)"
                        )
                    }
                    profileRow(icon: "bubble.left", label: "Type", value: chat.type.typeLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding(32)
        }
        .frame(width: 340, height: 460)
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
