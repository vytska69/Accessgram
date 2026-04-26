import SwiftUI

struct ChatRowView: View {
    let chat: Chat

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AvatarView(title: chat.title, size: 44)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(chat.title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    if let last = chat.lastMessage {
                        Text(last.timeString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text(chat.lastMessagePreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(chat.isMuted ? Color.secondary : Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .accessibilityHidden(true)  // included in row label
                    }
                }
            }
        }
        .padding(.vertical, 4)
        // Single accessible element for the whole row
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chat.accessibilityLabel)
        .accessibilityHint("Open conversation")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let title: String
    let size: CGFloat

    private var initial: String {
        title.first.map { String($0).uppercased() } ?? "#"
    }

    private var color: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .red, .teal, .indigo]
        let idx = abs(title.hashValue) % colors.count
        return colors[idx]
    }

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(Circle())
    }
}
