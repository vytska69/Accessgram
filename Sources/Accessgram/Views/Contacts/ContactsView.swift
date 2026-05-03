import SwiftUI

struct ContactsView: View {
    @Environment(AppViewModel.self) private var app
    @Binding var selectedChatId: Int64?

    @State private var contacts: [ContactEntry] = []
    @State private var isLoading = false
    @State private var searchQuery = ""

    struct ContactEntry: Identifiable {
        let id: Int64
        let name: String
        let username: String
        let phone: String
    }

    private var filtered: [ContactEntry] {
        guard !searchQuery.isEmpty else { return contacts }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.username.localizedCaseInsensitiveContains(searchQuery) ||
            $0.phone.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            content
        }
        .navigationTitle("Contacts")
        .task { await load() }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
            TextField("Search contacts", text: $searchQuery)
                .textFieldStyle(.plain)
                .accessibilityLabel("Search contacts")
            if !searchQuery.isEmpty {
                Button { searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(8)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Loading contacts…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Loading contacts")
        } else if filtered.isEmpty {
            ContentUnavailableView(
                searchQuery.isEmpty ? "No Contacts" : "No Results",
                systemImage: "person.2",
                description: Text(
                    searchQuery.isEmpty
                        ? "Your contacts will appear here"
                        : "No contacts match \"\(searchQuery)\""
                )
            )
        } else {
            List(filtered) { contact in
                Button {
                    openChat(userId: contact.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name).font(.headline)
                        if !contact.username.isEmpty {
                            Text("@\(contact.username)").font(.caption).foregroundStyle(.secondary)
                        }
                        if !contact.phone.isEmpty {
                            Text("+\(contact.phone)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    [contact.name,
                     contact.username.isEmpty ? "" : "@\(contact.username)",
                     contact.phone.isEmpty ? "" : "+\(contact.phone)"]
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                )
                .accessibilityHint("Open conversation")
            }
            .listStyle(.plain)
            .accessibilityLabel("Contacts")
        }
    }

    // MARK: - Load

    private func load() async {
        guard contacts.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        guard let ids = try? await app.client.getContacts() else { return }
        var entries: [ContactEntry] = []
        await withTaskGroup(of: ContactEntry?.self) { group in
            for id in ids {
                group.addTask {
                    guard let user = try? await app.client.getUser(id: id) else { return nil }
                    let first = user["first_name"] as? String ?? ""
                    let last = user["last_name"] as? String ?? ""
                    let name = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
                    guard !name.isEmpty else { return nil }
                    let unames = (user["usernames"] as? [String: Any])?["active_usernames"] as? [String]
                    let username = unames?.first ?? ""
                    let phone = user["phone_number"] as? String ?? ""
                    return ContactEntry(id: id, name: name, username: username, phone: phone)
                }
            }
            for await entry in group {
                if let e = entry { entries.append(e) }
            }
        }
        contacts = entries.sorted { $0.name < $1.name }
    }

    private func openChat(userId: Int64) {
        Task {
            if let chat = try? await app.client.createPrivateChat(userId: userId) {
                if let id = chat["id"] as? Int64 {
                    selectedChatId = id
                    // Make sure it's in the chat list
                    await app.chatListViewModel.addOrUpdate(from: chat)
                }
            }
        }
    }
}
