import SwiftUI

struct ChatListView: View {
    let viewModel: ChatListViewModel
    @Binding var selectedChatId: Int64?
    @AccessibilityFocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                TextField("Search", text: Binding(
                    get: { viewModel.searchQuery },
                    set: { viewModel.searchQuery = $0 }
                ))
                .textFieldStyle(.plain)
                .accessibilityLabel("Search conversations")
                .accessibilityFocused($searchFocused)

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
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

            Divider()

            // Chat list
            if viewModel.filteredChats.isEmpty && !viewModel.isLoading {
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
            } else {
                List(viewModel.filteredChats, selection: $selectedChatId) { chat in
                    ChatRowView(chat: chat)
                        .tag(chat.id)
                }
                .listStyle(.sidebar)
                .accessibilityLabel("Conversations")
            }
        }
        .navigationTitle("Accessgram")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    searchFocused = true
                } label: {
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
}
