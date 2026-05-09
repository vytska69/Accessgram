import AppKit
import SwiftUI

@MainActor
struct PhotoGalleryView: View {
    let viewModel: ChatViewModel
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    private var photoMessages: [Message] {
        viewModel.messages.filter { msg in
            guard case .photo = msg.content else { return false }
            return true
        }
    }

    init(messageId: Int64, viewModel: ChatViewModel) {
        self.viewModel = viewModel
        let photos = viewModel.messages.filter { msg in
            guard case .photo = msg.content else { return false }
            return true
        }
        _currentIndex = State(initialValue: photos.firstIndex(where: { $0.id == messageId }) ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            photoArea
            captionBar
        }
        .background(Color.black)
        .frame(minWidth: 560, minHeight: 460)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("Close gallery")

            Spacer()

            if let msg = photoMessages[safe: currentIndex] {
                VStack(spacing: 2) {
                    Text(msg.isOutgoing ? "You" : msg.senderName)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    Text(msg.timeString)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer()

            Text("\(currentIndex + 1) / \(photoMessages.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
    }

    // MARK: - Photo area

    private var photoArea: some View {
        HStack(spacing: 0) {
            navButton(direction: .previous)

            ZStack {
                Color.black
                if let msg = photoMessages[safe: currentIndex] {
                    GalleryPhotoCell(message: msg, viewModel: viewModel)
                        .id(msg.id)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            navButton(direction: .next)
        }
    }

    private enum Direction { case previous, next }

    private func navButton(direction: Direction) -> some View {
        let isPrev = direction == .previous
        let disabled = isPrev ? currentIndex == 0 : currentIndex == photoMessages.count - 1
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                currentIndex = isPrev
                    ? max(0, currentIndex - 1)
                    : min(photoMessages.count - 1, currentIndex + 1)
            }
        }) {
            Image(systemName: isPrev ? "chevron.left" : "chevron.right")
                .font(.title)
                .foregroundStyle(.white.opacity(disabled ? 0.15 : 0.75))
                .frame(width: 48)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .keyboardShortcut(isPrev ? .leftArrow : .rightArrow, modifiers: [])
        .accessibilityLabel(isPrev ? "Previous photo" : "Next photo")
    }

    // MARK: - Caption

    @ViewBuilder
    private var captionBar: some View {
        if let msg = photoMessages[safe: currentIndex],
           case .photo(let caption, _, _) = msg.content, !caption.isEmpty {
            Text(caption)
                .font(.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.black)
        }
    }
}

// MARK: - Single photo cell

@MainActor
private struct GalleryPhotoCell: View {
    let message: Message
    let viewModel: ChatViewModel
    @State private var imagePath: String?

    var body: some View {
        Group {
            if let imagePath, let img = NSImage(contentsOfFile: imagePath) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(photoAccessibilityLabel)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Loading photo")
            }
        }
        .task {
            guard case .photo(_, _, let file) = message.content, let file else { return }
            imagePath = viewModel.localPath(for: file)
            if imagePath == nil {
                await viewModel.downloadFile(file)
                imagePath = viewModel.localPath(for: file)
            }
        }
    }

    private var photoAccessibilityLabel: String {
        var parts: [String] = [message.isOutgoing ? "You" : message.senderName]
        if case .photo(let caption, _, _) = message.content, !caption.isEmpty {
            parts.append(caption)
        }
        parts.append(message.timeString)
        return parts.joined(separator: ", ")
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
