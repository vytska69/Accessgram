import SwiftUI

struct PinnedMessageBanner: View {
    let message: Message
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pin.fill")
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Pinned Message")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                Text(message.content.previewText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss pinned message")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.quinary)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pinned: \(message.content.previewText). Tap to jump.")
        .accessibilityAction(named: "Jump to message") { onTap() }
        .accessibilityAction(named: "Dismiss") { onDismiss() }
    }
}
