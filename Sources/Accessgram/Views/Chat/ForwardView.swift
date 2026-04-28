import SwiftUI

struct ForwardView: View {
    @Environment(AppViewModel.self) private var app
    let viewModel: ChatViewModel
    @State private var searchText = ""
    @State private var chats: [Chat] = []

    var filtered: [Chat] {
        if searchText.isEmpty { return chats }
        return chats.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Forward to…")
                .font(.headline)
                .padding(.vertical, 12)
                .accessibilityAddTraits(.isHeader)

            Divider()

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search chats", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search chats to forward to")
            }
            .padding(8)
            .background(.quinary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filtered, id: \.id) { chat in
                    Button {
                        Task { await viewModel.forwardTo(chat: chat) }
                    } label: {
                        HStack(spacing: 10) {
                            AvatarView(title: chat.title, size: 36)
                            Text(chat.title).font(.body)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Forward to \(chat.title)")
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 320, height: 420)
        .onAppear {
            chats = app.chatListViewModel.chats
        }
    }
}
