// swiftlint:disable file_length
import AppKit
import SwiftUI

// swiftlint:disable:next type_body_length
@MainActor
struct MessageBubbleView: View {
    let message: Message
    let viewModel: ChatViewModel
    let onReply: () -> Void
    let onEdit: () -> Void
    let onForward: () -> Void
    let onDelete: () -> Void

    @State private var photoPath: String?
    @State private var videoPath: String?
    @State private var stickerPath: String?
    @State private var isDownloadingVideo = false
    @State private var isExpanded = false

    private var isOutgoing: Bool { message.isOutgoing }

    var body: some View {
        if case .service(let text) = message.content {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.vertical, 2)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(text)
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                if isOutgoing { Spacer(minLength: 60) }

                VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                    if !isOutgoing, !message.senderName.isEmpty {
                        Text(message.senderName)
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                            .padding(.leading, 4)
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if let fwd = message.forwardOriginName {
                            forwardHeader(from: fwd)
                        }
                        if let quoteText = message.replyQuoteText {
                            replyQuote(text: quoteText)
                        }
                        contentView
                        if !message.reactions.isEmpty {
                            reactionsRow
                        }
                        timeRow
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleColor)
                    .clipShape(BubbleShape(isOutgoing: isOutgoing))
                    .contextMenu { contextMenuItems }
                }

                if !isOutgoing { Spacer(minLength: 60) }
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(message.fullAccessibilityLabel)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityAction(named: "Reply") { onReply() }
            .accessibilityAction(named: "Edit") { if message.isOutgoing { onEdit() } }
            .accessibilityAction(named: "Forward") { if message.canBeForwarded { onForward() } }
            .accessibilityAction(named: "Delete") { if message.canBeDeleted { onDelete() } }
        }
    }

    // MARK: - Forward Header

    private func forwardHeader(from name: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrowshape.turn.up.right.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Forwarded from \(name)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
        }
    }

    // MARK: - Reply Quote

    private func replyQuote(text: String) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 2)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Reactions

    private var reactionsRow: some View {
        HStack(spacing: 4) {
            ForEach(message.reactions, id: \.emoji) { reaction in
                Button {
                    Task {
                        if reaction.isChosen {
                            await viewModel.removeReaction(emoji: reaction.emoji, from: message)
                        } else {
                            await viewModel.addReaction(emoji: reaction.emoji, to: message)
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(reaction.emoji).font(.caption)
                        Text("\(reaction.count)").font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(reaction.isChosen
                        ? Color.accentColor.opacity(0.2)
                        : Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(reaction.emoji) \(reaction.count)")
                .accessibilityHint(reaction.isChosen ? "Tap to remove reaction" : "Tap to add reaction")
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch message.content {
        case .text(let t):
            let isLong = t.count > 500 || t.components(separatedBy: "\n").count > 10
            VStack(alignment: .leading, spacing: 4) {
                Text(t)
                    .font(.body)
                    .textSelection(.enabled)
                    .lineLimit(isExpanded || !isLong ? nil : 10)
                if isLong {
                    Button(isExpanded ? "Show less" : "Show more") {
                        isExpanded.toggle()
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .buttonStyle(.plain)
                }
            }
        case .photo(let caption, let hasSpoiler, let file):
            photoView(file: file, caption: caption, hasSpoiler: hasSpoiler)
        case .video(let caption, let duration, let file):
            videoView(caption: caption, duration: duration, file: file)
        case .voice(let duration, let file):
            BubbleAudioPlayerView(file: file, duration: duration, viewModel: viewModel)
        case .audio(let title, let performer, let duration, let file):
            audioView(title: title, performer: performer, duration: duration, file: file)
        case .document(let name, let caption, _, let file):
            documentView(name: name, caption: caption, file: file)
        case .sticker(let emoji, let file):
            stickerView(emoji: emoji, file: file)
        case .location(let lat, let lon):
            Button {
                let q = "\(lat),\(lon)"
                if let url = URL(string: "maps://?ll=\(q)&q=Location") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Label(String(format: "%.5f, %.5f", lat, lon), systemImage: "mappin.circle.fill")
                    Text("Open in Maps")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: "Location %.5f, %.5f. Open in Maps.", lat, lon))
        case .contact(let first, let last, let phone):
            contactView(first: first, last: last, phone: phone)
        case .poll(let q):
            Label(q, systemImage: "chart.bar.xaxis")
        case .animation(let caption, let duration, let file):
            videoView(caption: caption, duration: duration, file: file)
        case .dice(let emoji, let value):
            VStack(spacing: 4) {
                Text(emoji).font(.system(size: 52))
                if value > 0 {
                    Text("\(value)")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                }
            }
        case .videoNote:
            Label("Video message", systemImage: "video.circle.fill")
        case .animatedEmoji(let emoji):
            Text(emoji).font(.system(size: 48))
        case .unknown:
            Text("Unsupported message").font(.body).foregroundStyle(.secondary).italic()
        }
    }

    // MARK: - Sticker

    @ViewBuilder
    private func stickerView(emoji: String, file: TDFile?) -> some View {
        let path = stickerPath ?? file?.localPath
        if let path, let img = NSImage(contentsOfFile: path) {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 112, height: 112)
        } else {
            Text(emoji)
                .font(.system(size: 64))
                .task {
                    guard let file, file.localPath == nil, stickerPath == nil else { return }
                    await viewModel.downloadFile(file)
                    stickerPath = viewModel.localPath(for: file)
                }
        }
    }

    // MARK: - Photo

    @ViewBuilder
    private func photoView(file: TDFile?, caption: String, hasSpoiler: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let path = photoPath ?? file?.localPath
            if let path, let img = NSImage(contentsOfFile: path) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.2))
                        .frame(maxWidth: 240).aspectRatio(4 / 3, contentMode: .fit)
                    Image(systemName: hasSpoiler ? "eye.slash" : "photo")
                        .font(.largeTitle).foregroundStyle(.secondary)
                    if file != nil {
                        ProgressView().scaleEffect(0.6).offset(y: 20)
                    }
                }
                .task {
                    guard let file else { return }
                    await viewModel.downloadFile(file)
                    photoPath = viewModel.localPath(for: file)
                }
            }
            if !caption.isEmpty { Text(caption).font(.body) }
        }
    }

    // MARK: - Video

    private func videoView(caption: String, duration: Int, file: TDFile?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 240, height: 160)
                videoControls(file: file, duration: duration)
                Text(tdFormatDuration(duration))
                    .font(.caption.monospacedDigit())
                    .padding(4)
                    .background(.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(6)
            }
            if !caption.isEmpty { Text(caption).font(.body) }
        }
    }

    @ViewBuilder
    private func videoControls(file: TDFile?, duration: Int) -> some View {
        if let path = videoPath ?? file?.localPath {
            Button {
                viewModel.openFile(at: path)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play video, \(tdFormatDuration(duration))")
        } else if isDownloadingVideo {
            ProgressView().tint(.white)
        } else if let file {
            Button {
                Task {
                    isDownloadingVideo = true
                    await viewModel.downloadFile(file)
                    videoPath = viewModel.localPath(for: file)
                    isDownloadingVideo = false
                }
            } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Download video, \(tdFormatDuration(duration))")
        } else {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Audio

    private func audioView(title: String, performer: String, duration: Int, file: TDFile?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !title.isEmpty { Text(title).font(.headline).lineLimit(1) }
            if !performer.isEmpty { Text(performer).font(.caption).foregroundStyle(.secondary) }
            BubbleAudioPlayerView(file: file, duration: duration, viewModel: viewModel)
        }
    }

    // MARK: - Document

    @ViewBuilder
    private func documentView(name: String, caption: String, file: TDFile?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.fill").font(.title2)
            VStack(alignment: .leading) {
                Text(name).font(.headline).lineLimit(1)
                if !caption.isEmpty { Text(caption).font(.caption) }
            }
            Spacer()
            if let file {
                if let path = viewModel.localPath(for: file) {
                    Button {
                        viewModel.openFile(at: path)
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open file")
                } else {
                    Button {
                        Task { await viewModel.downloadFile(file) }
                    } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Download file")
                }
            }
        }
    }

    // MARK: - Contact

    private func contactView(first: String, last: String, phone: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill").font(.title2)
            VStack(alignment: .leading) {
                Text("\(first) \(last)").font(.headline)
                Text(phone).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Time Row

    private var timeRow: some View {
        HStack(spacing: 4) {
            if message.editDate != nil {
                Text("edited").font(.caption2).foregroundStyle(isOutgoing ? .white.opacity(0.7) : .secondary)
            }
            Text(message.timeString)
                .font(.caption2)
                .foregroundStyle(isOutgoing ? .white.opacity(0.7) : .secondary)
            if isOutgoing {
                Image(systemName: message.isRead ? "checkmark.message.fill" : "checkmark.message")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Styling

    private var bubbleColor: Color {
        isOutgoing ? Color.accentColor : Color(nsColor: .windowBackgroundColor)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Reply") { onReply() }
        if case .text = message.content {
            Button("Copy Text") { viewModel.copyText(of: message) }
        }
        if case .supergroup(let gid, _) = viewModel.chat.type {
            Button("Copy Link") {
                let link = "https://t.me/c/\(gid)/\(message.id)"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(link, forType: .string)
            }
        }
        if message.isOutgoing {
            Button("Edit") { onEdit() }
        }
        if message.canBeForwarded {
            Button("Forward") { onForward() }
        }
        Divider()
        Button("Delete…", role: .destructive) { onDelete() }
    }
}

// MARK: - Bubble Shape

private struct BubbleShape: Shape {
    let isOutgoing: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 16
        let tail: CGFloat = 6
        var path = Path()
        let cornerSize = CGSize(width: r, height: r)
        if isOutgoing {
            let adjusted = CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width - tail,
                height: rect.height
            )
            path.addRoundedRect(in: adjusted, cornerSize: cornerSize)
        } else {
            let adjusted = CGRect(
                x: rect.minX + tail,
                y: rect.minY,
                width: rect.width - tail,
                height: rect.height
            )
            path.addRoundedRect(in: adjusted, cornerSize: cornerSize)
        }
        return path
    }
}
// swiftlint:enable file_length
