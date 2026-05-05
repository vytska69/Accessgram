import SwiftUI

@MainActor
struct MembersView: View {
    let viewModel: ProfileViewModel
    let chatTitle: String

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.members.isEmpty && viewModel.isLoadingMembers {
                    ProgressView("Loading members…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("Loading members")
                } else if viewModel.members.isEmpty {
                    ContentUnavailableView(
                        "No Members",
                        systemImage: "person.2",
                        description: Text("Member list is unavailable")
                    )
                } else {
                    List {
                        ForEach(viewModel.members) { member in
                            memberRow(member)
                        }
                        if viewModel.hasMoreMembers {
                            Button(action: { Task { await viewModel.loadMoreMembers() } }) {
                                if viewModel.isLoadingMembers {
                                    ProgressView().frame(maxWidth: .infinity)
                                } else {
                                    Text("Load more…")
                                        .frame(maxWidth: .infinity)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
            .navigationTitle("Members")
            .task { await viewModel.loadMembers() }
        }
        .frame(width: 340, height: 480)
    }

    private func memberRow(_ member: ChatMember) -> some View {
        HStack(spacing: 10) {
            AvatarView(title: member.name, size: 36).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name).font(.body)
                if !member.role.label.isEmpty {
                    Text(member.role.label)
                        .font(.caption)
                        .foregroundStyle(member.role == .owner ? Color.accentColor : .secondary)
                }
            }
            Spacer()
            if member.role != .member {
                Text(member.role.label)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(member.role == .owner
                        ? Color.accentColor.opacity(0.15)
                        : Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                    .foregroundStyle(member.role == .owner ? Color.accentColor : .secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(member.role.label.isEmpty ? member.name : "\(member.name), \(member.role.label)")
    }
}
