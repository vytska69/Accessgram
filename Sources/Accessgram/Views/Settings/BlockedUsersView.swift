import SwiftUI

// MARK: - View Model

@Observable
@MainActor
private final class BlockedUsersViewModel {
    var users: [BlockedUser] = []
    var isLoading = false
    var hasMore = false
    var errorMessage: String?

    private let client: TDLibClient
    private let pageSize = 20

    init(client: TDLibClient) {
        self.client = client
    }

    func load() async {
        guard users.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        await fetchPage(offset: 0)
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        await fetchPage(offset: users.count)
    }

    func unblock(_ user: BlockedUser) async {
        do {
            try await client.unblockUser(userId: user.id)
            users.removeAll { $0.id == user.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchPage(offset: Int) async {
        guard let senders = try? await client.getBlockedMessageSenders(offset: offset, limit: pageSize) else { return }
        var newUsers: [BlockedUser] = []
        for sender in senders {
            guard case .user(let uid) = sender,
                  let json = try? await client.getUser(id: uid) else { continue }
            let first = json["first_name"] as? String ?? ""
            let last = json["last_name"] as? String ?? ""
            let name = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
            let username = (json["usernames"] as? [String: Any])?["editable_username"] as? String
            newUsers.append(BlockedUser(id: uid, name: name.isEmpty ? "Unknown" : name, username: username))
        }
        if offset == 0 {
            users = newUsers
        } else {
            users.append(contentsOf: newUsers)
        }
        hasMore = senders.count == pageSize
    }
}

// MARK: - View

@MainActor
struct BlockedUsersView: View {
    let client: TDLibClient
    @State private var vm: BlockedUsersViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    content(vm: vm)
                } else {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Blocked Users")
            .task {
                let model = BlockedUsersViewModel(client: client)
                vm = model
                await model.load()
            }
        }
        .frame(width: 360, height: 480)
    }

    @ViewBuilder
    private func content(vm: BlockedUsersViewModel) -> some View {
        if vm.isLoading && vm.users.isEmpty {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Loading blocked users")
        } else if vm.users.isEmpty {
            ContentUnavailableView(
                "No Blocked Users",
                systemImage: "hand.raised",
                description: Text("Users you block will appear here")
            )
        } else {
            List {
                ForEach(vm.users) { user in
                    userRow(user, vm: vm)
                }
                if vm.hasMore {
                    Button(action: { Task { await vm.loadMore() } }, label: {
                        if vm.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Load more…")
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.secondary)
                        }
                    })
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
            .alert(
                "Error",
                isPresented: Binding(
                    get: { vm.errorMessage != nil },
                    set: { if !$0 { vm.errorMessage = nil } }
                ),
                actions: { Button("OK") { vm.errorMessage = nil } },
                message: { Text(vm.errorMessage ?? "") }
            )
        }
    }

    private func userRow(_ user: BlockedUser, vm: BlockedUsersViewModel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.body)
                if let handle = user.username {
                    Text("@\(handle)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: { Task { await vm.unblock(user) } }, label: {
                Text("Unblock")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            })
            .buttonStyle(.plain)
            .accessibilityLabel("Unblock \(user.name)")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.name)\(user.username.map { ", @\($0)" } ?? ""), Blocked")
    }
}
