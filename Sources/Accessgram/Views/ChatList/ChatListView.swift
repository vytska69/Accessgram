import SwiftUI

@MainActor
struct ChatListView: View {
    let viewModel: ChatListViewModel
    @Binding var selectedChatId: Int64?
    let onCompose: () -> Void
    @AccessibilityFocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if !viewModel.folders.isEmpty { folderTabs }
            Divider()
            chatContent
        }
        .navigationTitle("Accessgram")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onCompose) {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New message")
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            ToolbarItem(placement: .secondaryAction) {
                Button { searchFocused = true } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search conversations")
                .keyboardShortcut("f", modifiers: .command)
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isLoading {
                ProgressView()
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding()
                    .accessibilityLabel("Loading conversations")
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
            TextField("Search", text: Binding(
                get: { viewModel.searchQuery },
                set: { viewModel.searchQuery = $0 }
            ))
            .textFieldStyle(.plain)
            .accessibilityLabel("Search conversations")
            .accessibilityFocused($searchFocused)
            if !viewModel.searchQuery.isEmpty {
                Button { viewModel.searchQuery = "" } label: {
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

    private var folderTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                folderChip(id: nil, title: "All")
                ForEach(viewModel.folders) { folder in
                    folderChip(id: folder.id, title: folder.title)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func folderChip(id: Int?, title: String) -> some View {
        let active = viewModel.activeFolderId == id
        return Button { viewModel.activeFolderId = id } label: {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(active ? Color.accentColor : Color.secondary.opacity(0.12))
                .foregroundStyle(active ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)\(active ? ", selected" : "")")
    }

    @ViewBuilder
    private var chatContent: some View {
        if viewModel.filteredChats.isEmpty && !viewModel.isLoading {
            emptyState
        } else {
            List(viewModel.filteredChats, selection: $selectedChatId) { chat in
                ChatRowView(chat: chat)
                    .tag(chat.id)
                    .contextMenu { chatContextMenu(for: chat) }
            }
            .listStyle(.sidebar)
            .accessibilityLabel("Conversations")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.searchQuery.isEmpty {
            ContentUnavailableView(
                "No Conversations",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Your chats will appear here")
            )
            .accessibilityLabel("No conversations yet")
        } else {
            ContentUnavailableView.search(text: viewModel.searchQuery)
                .accessibilityLabel("No results for \(viewModel.searchQuery)")
        }
    }

    @ViewBuilder
    private func chatContextMenu(for chat: Chat) -> some View {
        Button(chat.isPinned ? "Unpin" : "Pin") {
            Task { await viewModel.togglePinned(chat) }
        }
        Button(chat.isMuted ? "Unmute" : "Mute") {
            Task { await viewModel.toggleMuted(chat) }
        }
        Button(chat.isMarkedAsUnread ? "Mark as Read" : "Mark as Unread") {
            Task { await viewModel.toggleMarkedUnread(chat) }
        }
        Divider()
        Button("Archive", role: .destructive) {
            Task { await viewModel.archiveChat(chat) }
        }
    }
}
