import SwiftUI

struct NewChatView: View {
    @Environment(AppViewModel.self) private var app
    @Binding var selectedChatId: Int64?
    @Environment(\.dismiss) private var dismiss
    @State private var contacts: [User] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var filtered: [User] {
        if searchText.isEmpty { return contacts }
        return contacts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            ($0.username?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("New Message")
                .font(.headline)
                .padding(.vertical, 12)
                .accessibilityAddTraits(.isHeader)

            Divider()

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search contacts", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search contacts")
            }
            .padding(8)
            .background(.quinary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if isLoading {
                ProgressView("Loading contacts…")
                    .frame(maxHeight: .infinity)
            } else if filtered.isEmpty {
                ContentUnavailableView(
                    "No Contacts",
                    systemImage: "person.2",
                    description: Text("Add contacts in the official Telegram app")
                )
            } else {
                List(filtered) { user in
                    Button(action: { openChat(with: user) }, label: {
                        HStack(spacing: 10) {
                            AvatarView(title: user.displayName, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName).font(.body)
                                if let u = user.username {
                                    Text("@\(u)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    })
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start chat with \(user.displayName)")
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 320, height: 420)
        .task { await loadContacts() }
        .alert(
            "Error",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
            actions: { Button("OK") { errorMessage = nil } },
            message: { Text(errorMessage ?? "") }
        )
    }

    private func loadContacts() async {
        isLoading = true
        defer { isLoading = false }
        guard let ids = try? await app.client.getContacts() else { return }
        var users: [User] = []
        for id in ids.prefix(100) {
            if let json = try? await app.client.getUser(id: id),
               let user = User(json: json) {
                users.append(user)
            }
        }
        contacts = users.sorted { $0.displayName < $1.displayName }
    }

    private func openChat(with user: User) {
        Task {
            guard let chatJSON = try? await app.client.createPrivateChat(userId: user.id),
                  let chatId = chatJSON["id"] as? Int64 else { return }
            await MainActor.run {
                selectedChatId = chatId
                dismiss()
            }
        }
    }
}
