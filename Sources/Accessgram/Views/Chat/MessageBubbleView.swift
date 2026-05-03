import AppKit
import AVFoundation
import SwiftUI

@MainActor
struct MessageBubbleView: View {
    let message: Message
    let viewModel: ChatViewModel
    let onReply: () -> Void
    let onEdit: () -> Void
    let onForward: () -> Void
    let onDelete: () -> Void

    @State private var photoPath: String?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingAudio = false
    @State private var audioProgress: Double = 0   // 0…1
    @State private var audioSpeed: Float = 1.0
    private let speedOptions: [Float] = [0.5, 1.0, 1.5, 2.0]

    private var speedLabel: String {
        switch audioSpeed {
        case 0.5: return "0.5×"
        case 1.5: return "1.5×"
        case 2.0: return "2×"
        default:  return "1×"
        }
    }

    private var isOutgoing: Bool { message.isOutgoing }

    var body: some View {
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
                    .background(reaction.isChosen ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
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
            Text(t).font(.body).textSelection(.enabled)

        case .photo(let caption, let hasSpoiler, let file):
            photoView(file: file, caption: caption, hasSpoiler: hasSpoiler)

        case .video(let caption, let duration, _):
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.2))
                        .frame(width: 240, height: 160)
                    Image(systemName: "play.circle.fill").font(.system(size: 44)).foregroundStyle(.white)
                    Text(tdFormatDuration(duration)).font(.caption.monospacedDigit())
                        .padding(4).background(.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 4)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(6)
                }
                if !caption.isEmpty { Text(caption).font(.body) }
            }

        case .voice(let duration, let file):
            voiceView(file: file, duration: duration)

        case .audio(let title, let performer, let duration, let file):
            audioView(title: title, performer: performer, duration: duration, file: file)

        case .document(let name, let caption, _, let file):
            documentView(name: name, caption: caption, file: file)

        case .sticker(let emoji):
            Text(emoji).font(.system(size: 48))

        case .location(let lat, let lon):
            Label(String(format: "%.4f, %.4f", lat, lon), systemImage: "mappin.circle.fill")

        case .contact(let first, let last, let phone):
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill").font(.title2)
                VStack(alignment: .leading) {
                    Text("\(first) \(last)").font(.headline)
                    Text(phone).font(.caption).foregroundStyle(.secondary)
                }
            }

        case .poll(let q):
            Label(q, systemImage: "chart.bar.xaxis")

        case .videoNote:
            Label("Video message", systemImage: "video.circle.fill")

        case .unknown(let t):
            Text("[\(t)]").font(.body).foregroundStyle(.secondary)
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

    // MARK: - Voice

    @ViewBuilder
    private func voiceView(file: TDFile?, duration: Int) -> some View {
        audioPlayerView(file: file, duration: duration, title: nil, performer: nil)
    }

    // MARK: - Audio

    @ViewBuilder
    private func audioView(title: String, performer: String, duration: Int, file: TDFile?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !title.isEmpty { Text(title).font(.headline).lineLimit(1) }
            if !performer.isEmpty { Text(performer).font(.caption).foregroundStyle(.secondary) }
            audioPlayerView(file: file, duration: duration, title: title, performer: performer)
        }
    }

    // MARK: - Shared audio player (voice + audio messages)

    @ViewBuilder
    private func audioPlayerView(file: TDFile?, duration: Int, title: String?, performer: String?) -> some View {
        let elapsed = Int(audioProgress * Double(max(duration, 1)))
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                // Play / Pause
                Button {
                    Task { await toggleAudio(file: file) }
                } label: {
                    Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlayingAudio ? "Pause" : "Play")

                // Scrub slider
                Slider(
                    value: Binding(
                        get: { audioProgress },
                        set: { v in
                            audioProgress = v
                            audioPlayer?.currentTime = v * (audioPlayer?.duration ?? 0)
                        }
                    ),
                    in: 0...1
                )
                .accessibilityLabel("Playback position")
                .accessibilityValue("\(formatSeconds(elapsed)) of \(formatSeconds(duration))")

                // Speed toggle
                Button { cycleSpeed() } label: {
                    Text(speedLabel)
                        .font(.caption.bold().monospacedDigit())
                        .frame(minWidth: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Playback speed \(speedLabel)")
                .accessibilityHint("Double-tap to change speed")
            }

            // Time labels
            HStack {
                Text(formatSeconds(elapsed))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatSeconds(duration))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 200)
        // Progress polling — only active while playing
        .task(id: isPlayingAudio) {
            guard isPlayingAudio else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(80))
                guard let player = audioPlayer else { break }
                if player.isPlaying {
                    audioProgress = player.duration > 0 ? player.currentTime / player.duration : 0
                } else {
                    isPlayingAudio = false
                    audioProgress = 0
                    break
                }
            }
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

    // MARK: - Audio Playback

    private func toggleAudio(file: TDFile?) async {
        if isPlayingAudio {
            audioPlayer?.stop()
            isPlayingAudio = false
            return
        }
        guard let file else { return }
        if let path = viewModel.localPath(for: file) {
            playAudio(at: path)
        } else {
            await viewModel.downloadFile(file)
            if let path = viewModel.localPath(for: file) {
                playAudio(at: path)
            }
        }
    }

    private func playAudio(at path: String) {
        let url = URL(fileURLWithPath: path)
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.enableRate = true
        audioPlayer?.rate = audioSpeed
        if audioProgress > 0, let player = audioPlayer {
            player.currentTime = audioProgress * player.duration
        }
        audioPlayer?.play()
        isPlayingAudio = true
    }

    private func cycleSpeed() {
        let idx = speedOptions.firstIndex(of: audioSpeed) ?? 1
        audioSpeed = speedOptions[(idx + 1) % speedOptions.count]
        audioPlayer?.rate = audioSpeed
    }

    private func formatSeconds(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Time Row

    private var timeRow: some View {
        HStack(spacing: 4) {
            if editDatePresent {
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

    private var editDatePresent: Bool { message.editDate != nil }

    // MARK: - Styling

    private var bubbleColor: Color {
        isOutgoing ? Color.accentColor : Color(nsColor: .windowBackgroundColor)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Reply") { onReply() }
        if case .text = message.content {
            Button("Copy") { viewModel.copyText(of: message) }
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
            let rect2 = CGRect(x: rect.minX, y: rect.minY, width: rect.width - tail, height: rect.height)
            path.addRoundedRect(in: rect2, cornerSize: cornerSize)
        } else {
            let rect2 = CGRect(x: rect.minX + tail, y: rect.minY, width: rect.width - tail, height: rect.height)
            path.addRoundedRect(in: rect2, cornerSize: cornerSize)
        }
        return path
    }
}

// MARK: - Duration (file-private copy)

private func formatDuration(_ seconds: Int) -> String {
    "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
}
