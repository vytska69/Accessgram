import SwiftUI

// MARK: - ViewModel

@Observable
@MainActor
private final class PrivacyExceptionsViewModel {
    struct ExceptionUser: Identifiable {
        let id: Int64
        let name: String
    }

    let setting: PrivacySetting
    var allowList: [ExceptionUser] = []
    var restrictList: [ExceptionUser] = []
    var contacts: [ExceptionUser] = []
    var isLoading = false
    var isLoadingContacts = false
    var errorMessage: String?

    private var baseValue: PrivacyValue = .everybody
    private let client: TDLibClient

    init(setting: PrivacySetting, client: TDLibClient) {
        self.setting = setting
        self.client = client
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let (value, exceptions) = try await client.getPrivacyRules(setting: setting)
            baseValue = value
            allowList = await resolve(ids: exceptions.allowUserIds)
            restrictList = await resolve(ids: exceptions.restrictUserIds)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadContacts() async {
        guard contacts.isEmpty else { return }
        isLoadingContacts = true
        defer { isLoadingContacts = false }
        guard let ids = try? await client.getContacts() else { return }
        contacts = await resolve(ids: ids)
    }

    func add(user: ExceptionUser, toAllow: Bool) async {
        if toAllow {
            guard !allowList.contains(where: { $0.id == user.id }) else { return }
            restrictList.removeAll { $0.id == user.id }
            allowList.append(user)
        } else {
            guard !restrictList.contains(where: { $0.id == user.id }) else { return }
            allowList.removeAll { $0.id == user.id }
            restrictList.append(user)
        }
        await save()
    }

    func remove(user: ExceptionUser, fromAllow: Bool) async {
        if fromAllow {
            allowList.removeAll { $0.id == user.id }
        } else {
            restrictList.removeAll { $0.id == user.id }
        }
        await save()
    }

    private func save() async {
        let exceptions = PrivacyExceptions(
            allowUserIds: allowList.map(\.id),
            restrictUserIds: restrictList.map(\.id)
        )
        do {
            try await client.setPrivacyRules(setting: setting, value: baseValue, exceptions: exceptions)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolve(ids: [Int64]) async -> [ExceptionUser] {
        var result: [ExceptionUser] = []
        for id in ids {
            guard let json = try? await client.getUser(id: id) else { continue }
            let first = json["first_name"] as? String ?? ""
            let last  = json["last_name"]  as? String ?? ""
            let name  = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
            result.append(ExceptionUser(id: id, name: name.isEmpty ? "User \(id)" : name))
        }
        return result
    }
}

// MARK: - Main View

@MainActor
struct PrivacyExceptionsView: View {
    let setting: PrivacySetting
    let client: TDLibClient

    @State private var vm: PrivacyExceptionsViewModel
    @State private var addingToAllow: Bool?

    init(setting: PrivacySetting, client: TDLibClient) {
        self.setting = setting
        self.client = client
        _vm = State(initialValue: PrivacyExceptionsViewModel(setting: setting, client: client))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
        }
        .navigationTitle("Exceptions — \(setting.label)")
        .task { await vm.load() }
        .alert(
            "Error",
            isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            ),
            actions: { Button("OK") { vm.errorMessage = nil } },
            message: { Text(vm.errorMessage ?? "") }
        )
        .sheet(item: $addingToAllow) { toAllow in
            ContactPickerView(
                contacts: vm.contacts,
                isLoading: vm.isLoadingContacts,
                onSelect: { user in
                    Task { await vm.add(user: user, toAllow: toAllow) }
                }
            )
            .frame(minWidth: 320, minHeight: 400)
            .task { await vm.loadContacts() }
        }
    }

    private var list: some View {
        List {
            exceptionSection(
                title: "Always Allow",
                footer: "These users can always see this information, regardless of your general setting.",
                users: vm.allowList,
                isAllow: true
            )
            exceptionSection(
                title: "Always Restrict",
                footer: "These users can never see this information, regardless of your general setting.",
                users: vm.restrictList,
                isAllow: false
            )
        }
        .listStyle(.inset)
    }

    private func exceptionSection(
        title: String,
        footer: String,
        users: [PrivacyExceptionsViewModel.ExceptionUser],
        isAllow: Bool
    ) -> some View {
        Section(header: Text(title), footer: Text(footer)) {
            ForEach(users) { user in
                HStack {
                    Text(user.name)
                    Spacer()
                    Button(
                        role: .destructive,
                        action: { Task { await vm.remove(user: user, fromAllow: isAllow) } },
                        label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                    )
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(user.name) from \(isAllow ? "always allow" : "always restrict")")
                }
            }
            Button(action: { addingToAllow = isAllow }, label: {
                Label("Add User…", systemImage: "plus.circle")
            })
            .accessibilityLabel("Add user to \(isAllow ? "always allow" : "always restrict") list")
        }
    }
}

// MARK: - Contact Picker

extension Bool: Identifiable {
    public var id: Bool { self }
}

@MainActor
private struct ContactPickerView: View {
    let contacts: [PrivacyExceptionsViewModel.ExceptionUser]
    let isLoading: Bool
    let onSelect: (PrivacyExceptionsViewModel.ExceptionUser) -> Void

    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [PrivacyExceptionsViewModel.ExceptionUser] {
        query.isEmpty ? contacts : contacts.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Contact").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()
            Divider()
            if isLoading {
                ProgressView("Loading contacts…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if contacts.isEmpty {
                ContentUnavailableView("No Contacts", systemImage: "person.slash")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TextField("Search", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.top, 8)
                List(filtered) { user in
                    Button(action: { onSelect(user); dismiss() }, label: {
                        Text(user.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    })
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
