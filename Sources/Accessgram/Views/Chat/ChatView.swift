import SwiftUI

struct ChatView: View {
    let chat: Chat
    let client: TDLibClient
    @State private var viewModel: ChatViewModel
    @AccessibilityFocusState private var inputFocused: Bool

    init(chat: Chat, client: TDLibClient) {
        self.chat = chat
        self.client = client
        _viewModel = State(initialValue: ChatViewModel(chat: chat, client: client))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                onReply: { viewModel.startReply(to: message) },
                                onCopy: { viewModel.copyText(of: message) },
                                onDelete: { Task { await viewModel.deleteMessage(message, forAll: false) } }
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Reply preview
            if let reply = viewModel.replyToMessage {
                ReplyPreviewBar(message: reply) {
                    viewModel.cancelReply()
                }
            }

            Divider()

            // Input
            MessageInputView(
                text: Binding(
                    get: { viewModel.draftText },
                    set: { viewModel.draftText = $0 }
                ),
                isSending: viewModel.isSending,
                inputFocused: $inputFocused
            ) {
                Task { await viewModel.sendMessage() }
            }
        }
        .navigationTitle(chat.title)
        .navigationSubtitle(chat.type.typeLabel)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    inputFocused = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("Focus message input")
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .task {
            await client.addUpdateHandler { update in
                await MainActor.run { viewModel.handleUpdate(update) }
            }
            await viewModel.loadMessages()
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Reply Preview Bar

private struct ReplyPreviewBar: View {
    let message: Message
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.isOutgoing ? "You" : message.senderName)
                    .font(.caption.bold())
                    .foregroundStyle(.accentColor)

                Text(message.content.previewText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel reply")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.quinary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Replying to: \(message.content.previewText). Button: Cancel reply.")
    }
}
