import SwiftUI

struct ChatRowView: View {
    let chat: Chat

    private var prefs: AppPreferences { AppPreferences.shared }

    private var avatarSize: CGFloat { prefs.compactChatList ? 36 : 44 }
    private var verticalPad: CGFloat { prefs.compactChatList ? 2 : 4 }

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(title: chat.title, size: avatarSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if chat.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    Text(chat.title)
                        .font(prefs.compactChatList ? .subheadline : .headline)
                        .lineLimit(1)
                    Spacer()
                    if let last = chat.lastMessage {
                        Text(last.timeString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !prefs.compactChatList {
                    HStack {
                        Text(chat.lastMessagePreview)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        badgeArea
                    }
                } else {
                    badgeArea.frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, verticalPad)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chat.accessibilityLabel)
        .accessibilityHint("Open conversation")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var badgeArea: some View {
        if chat.isMuted {
            Image(systemName: "bell.slash.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        if chat.unreadCount > 0 {
            Text("\(chat.unreadCount)")
                .font(.caption.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(chat.isMuted ? Color.secondary : Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .accessibilityHidden(true)
        } else if chat.isMarkedAsUnread {
            Circle()
                .fill(chat.isMuted ? Color.secondary : Color.accentColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
        }
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
        let colors: [Color] = [.blue, .green, .indigo, .orange, .purple, .red, .teal]
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
