import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let onReply: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var isOutgoing: Bool { message.isOutgoing }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOutgoing { Spacer(minLength: 60) }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                // Sender name (groups only, incoming only)
                if !isOutgoing, !message.senderName.isEmpty {
                    Text(message.senderName)
                        .font(.caption.bold())
                        .foregroundStyle(.accentColor)
                        .padding(.leading, 4)
                        .accessibilityHidden(true)  // included in bubble label
                }

                // Bubble
                VStack(alignment: .leading, spacing: 4) {
                    contentView
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
        // --- VoiceOver ---
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message.fullAccessibilityLabel)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityCustomActions(buildActions())
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch message.content {
        case .text(let t):
            Text(t)
                .font(.body)
                .textSelection(.enabled)

        case .photo(let caption, let hasSpoiler):
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .aspectRatio(4/3, contentMode: .fit)
                        .frame(maxWidth: 240)
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    if hasSpoiler {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                        Text("Tap to reveal")
                            .font(.caption)
                    }
                }
                if !caption.isEmpty {
                    Text(caption).font(.body)
                }
            }

        case .video(let caption, let duration):
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 240, height: 160)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                    Text(formatDuration(duration))
                        .font(.caption.monospacedDigit())
                        .padding(4)
                        .background(.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .bottomLeading)
                        .padding(6)
                }
                if !caption.isEmpty { Text(caption).font(.body) }
            }

        case .voice(let duration):
            Label("\(formatDuration(duration))", systemImage: "waveform")
                .font(.body)

        case .audio(let title, let performer, let duration):
            HStack(spacing: 10) {
                Image(systemName: "music.note")
                    .font(.title2)
                VStack(alignment: .leading) {
                    if !title.isEmpty { Text(title).font(.headline).lineLimit(1) }
                    if !performer.isEmpty { Text(performer).font(.caption).foregroundStyle(.secondary) }
                    Text(formatDuration(duration)).font(.caption.monospacedDigit())
                }
            }

        case .document(let name, let caption):
            HStack(spacing: 10) {
                Image(systemName: "doc.fill")
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text(name).font(.headline).lineLimit(1)
                    if !caption.isEmpty { Text(caption).font(.caption) }
                }
            }

        case .sticker(let emoji):
            Text(emoji).font(.system(size: 48))

        case .location(let lat, let lon):
            Label(String(format: "%.4f, %.4f", lat, lon), systemImage: "mappin.circle.fill")

        case .contact(let first, let last, let phone):
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
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

    // MARK: - Time Row

    private var timeRow: some View {
        HStack(spacing: 4) {
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
            Button("Copy") { onCopy() }
        }
        if message.canBeForwarded {
            Button("Forward") {}  // TODO: forward UI
        }
        Divider()
        Button("Delete…", role: .destructive) { onDelete() }
    }

    // MARK: - VoiceOver Custom Actions

    private func buildActions() -> [AccessibilityCustomAction] {
        var actions: [AccessibilityCustomAction] = []

        if message.canBeRepliedTo {
            actions.append(AccessibilityCustomAction("Reply") { onReply(); return true })
        }
        if case .text = message.content {
            actions.append(AccessibilityCustomAction("Copy text") { onCopy(); return true })
        }
        if message.canBeDeleted {
            actions.append(AccessibilityCustomAction("Delete") { onDelete(); return true })
        }
        return actions
    }
}

// MARK: - Bubble Shape

private struct BubbleShape: Shape {
    let isOutgoing: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 16
        let tailSize: CGFloat = 6

        var path = Path()
        if isOutgoing {
            path.addRoundedRect(in: rect.inset(by: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: tailSize)),
                                cornerSize: CGSize(width: r, height: r))
        } else {
            path.addRoundedRect(in: rect.inset(by: EdgeInsets(top: 0, leading: tailSize, bottom: 0, trailing: 0)),
                                cornerSize: CGSize(width: r, height: r))
        }
        return path
    }
}

// MARK: - Helpers

private func formatDuration(_ seconds: Int) -> String {
    let m = seconds / 60, s = seconds % 60
    return "\(m):\(String(format: "%02d", s))"
}
