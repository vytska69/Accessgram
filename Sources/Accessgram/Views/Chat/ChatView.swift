import AppKit
import SwiftUI

@MainActor
struct ChatView: View {
    let chat: Chat
    let client: TDLibClient
    @State private var viewModel: ChatViewModel
    @State private var showProfile = false
    @State private var galleryMessageId: Int64?
    @AccessibilityFocusState private var inputFocused: Bool
    @State private var pendingScrollAnchor: Int64?
    @State private var scrollToBottomTrigger = 0
    @State private var isDraggedOver = false

    init(chat: Chat, client: TDLibClient) {
        self.chat = chat
        self.client = client
        _viewModel = State(initialValue: MainActor.assumeIsolated {
            ChatViewModel(chat: chat, client: client)
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            if let pinned = viewModel.pinnedMessage { pinnedBanner(pinned) }
            if viewModel.showSearch { searchBar }
            messageList
            bottomBar
        }
        .task(id: viewModel.draftText) {
            try? await Task.sleep(nanoseconds: 600_000_000)
            await viewModel.fetchLinkPreviewIfNeeded(for: viewModel.draftText)
        }
        .onDrop(of: [.fileURL], isTargeted: $isDraggedOver) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSURL.self) { nsurl, _ in
                guard let url = nsurl as? URL else { return }
                DispatchQueue.main.async { Task { await viewModel.sendAttachment(url: url) } }
            }
            return true
        }
        .overlay {
            if isDraggedOver {
                ZStack {
                    Color.primary.opacity(0.12)
                    VStack(spacing: 14) {
                        Image(systemName: "paperclip.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.accentColor)
                        Text("Drop to send")
                            .font(.title2.bold())
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .navigationTitle(chat.title)
        .navigationSubtitle(chat.type.typeLabel)
        .toolbar { toolbarItems }
        .sheet(isPresented: $showProfile) {
            ProfileView(chat: chat)
        }
        .sheet(isPresented: $viewModel.showForwardSheet) {
            ForwardView(viewModel: viewModel)
        }
        .sheet(isPresented: Binding(
            get: { galleryMessageId != nil },
            set: { if !$0 { galleryMessageId = nil } }
        )) {
            if let msgId = galleryMessageId {
                PhotoGalleryView(messageId: msgId, viewModel: viewModel)
            }
        }
        .task {
            await client.addUpdateHandler { update in
                await MainActor.run { viewModel.handleUpdate(update) }
            }
            await viewModel.loadMessages()
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Pinned Banner

    private func pinnedBanner(_ message: Message) -> some View {
        PinnedMessageBanner(message: message) {
            // scroll handled by id — no-op for now
        } onDismiss: {
            viewModel.pinnedMessage = nil
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
            TextField("Search in chat", text: Binding(
                get: { viewModel.searchQuery },
                set: { viewModel.searchQuery = $0 }
            ))
            .textFieldStyle(.plain)
            .onSubmit { Task { await viewModel.runSearch() } }
            .accessibilityLabel("Search messages")
            Button {
                viewModel.showSearch = false
                viewModel.searchQuery = ""
                viewModel.searchResults = []
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close search")
        }
        .padding(8)
        .background(.quinary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Message List

    private var messageList: some View {
        Group {
            if viewModel.messages.isEmpty && viewModel.isLoading {
                ProgressView("Loading messages…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Loading messages")
            } else {
                loadedMessageList
            }
        }
    }

    private var loadedMessageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    loadMoreButton
                    ForEach(displayMessages) { message in
                        MessageBubbleView(
                            message: message,
                            viewModel: viewModel,
                            onReply: { viewModel.startReply(to: message) },
                            onEdit: { viewModel.startEditing(message) },
                            onForward: { viewModel.startForward(message) },
                            onDelete: { Task { await viewModel.deleteMessage(message, forAll: false) } },
                            onOpenGallery: {
                                if case .photo = message.content { galleryMessageId = message.id }
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.last?.id) { _, newId in
                if let newId {
                    withAnimation { proxy.scrollTo(newId, anchor: .bottom) }
                }
            }
            .onChange(of: viewModel.messages.first?.id) { _, _ in
                if let anchor = pendingScrollAnchor {
                    proxy.scrollTo(anchor, anchor: .top)
                    pendingScrollAnchor = nil
                }
            }
            .onChange(of: scrollToBottomTrigger) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var displayMessages: [Message] {
        viewModel.showSearch && !viewModel.searchResults.isEmpty
            ? viewModel.searchResults
            : viewModel.messages
    }

    @ViewBuilder
    private var loadMoreButton: some View {
        if viewModel.hasMoreMessages && !viewModel.showSearch {
            Button {
                pendingScrollAnchor = viewModel.messages.first?.id
                Task { await viewModel.loadOlderMessages() }
            } label: {
                if viewModel.isLoadingMore {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Text("Load older messages").font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        if let msg = viewModel.editingMessage {
            editBar(for: msg)
        } else if let reply = viewModel.replyToMessage {
            ReplyPreviewBar(message: reply) { viewModel.cancelReply() }
        }
        if let preview = viewModel.linkPreview {
            LinkPreviewBar(preview: preview) { viewModel.dismissLinkPreview() }
        }
        if viewModel.scheduledDate != nil {
            scheduledBar
        }
        Divider()
        MessageInputView(
            text: Binding(get: { viewModel.draftText }, set: { viewModel.draftText = $0 }),
            isSending: viewModel.isSending,
            inputFocused: $inputFocused,
            scheduledDate: $viewModel.scheduledDate,
            onAttach: { url in Task { await viewModel.sendAttachment(url: url) } },
            onFormattedChange: { text, entities in
                viewModel.draftText = text
                viewModel.draftEntities = entities
            },
            onSend: {
                if viewModel.editingMessage != nil {
                    Task { await viewModel.submitEdit() }
                } else {
                    Task { await viewModel.sendMessage() }
                }
            }
        )
    }

    private var scheduledBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Scheduled").font(.caption.bold()).foregroundStyle(Color.accentColor)
                if let date = viewModel.scheduledDate {
                    Text(date, style: .dateTime).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: { viewModel.scheduledDate = nil }) {
                Image(systemName: "xmark").font(.caption.bold())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel scheduled send")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.quinary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Message scheduled for \(viewModel.scheduledDate.map { $0.formatted() } ?? ""). Button: Cancel.")
    }

    private func editBar(for message: Message) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "pencil").foregroundStyle(Color.accentColor).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Edit Message").font(.caption.bold()).foregroundStyle(Color.accentColor)
                Text(message.content.previewText).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button(action: viewModel.cancelEditing) {
                Image(systemName: "xmark").font(.caption.bold())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel editing")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.quinary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Editing: \(message.content.previewText). Button: Cancel.")
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { inputFocused = true } label: {
                Image(systemName: "square.and.pencil")
            }
            .accessibilityLabel("Focus message input")
            .keyboardShortcut("n", modifiers: .command)
        }
        ToolbarItem(placement: .primaryAction) {
            Button { scrollToBottomTrigger += 1 } label: {
                Image(systemName: "arrow.down.to.line")
            }
            .accessibilityLabel("Jump to latest message")
        }
        ToolbarItem(placement: .primaryAction) {
            Button { viewModel.showSearch.toggle() } label: {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel("Search in chat")
            .keyboardShortcut("f", modifiers: .command)
        }
        ToolbarItem(placement: .primaryAction) {
            Button { showProfile = true } label: {
                Image(systemName: "person.circle")
            }
            .accessibilityLabel("View profile")
        }
    }
}

// MARK: - Reply Preview Bar

private struct ReplyPreviewBar: View {
    let message: Message
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.accentColor).frame(width: 3).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(message.isOutgoing ? "You" : message.senderName)
                    .font(.caption.bold()).foregroundStyle(Color.accentColor)
                Text(message.content.previewText)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark").font(.caption.bold())
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
