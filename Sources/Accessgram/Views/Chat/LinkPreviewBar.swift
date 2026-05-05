import SwiftUI

struct LinkPreviewBar: View {
    let preview: WebPagePreview
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                if !preview.displayTitle.isEmpty {
                    Text(preview.displayTitle)
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                }
                if !preview.description.isEmpty {
                    Text(preview.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(preview.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.caption.bold())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss link preview")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.quinary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Link preview: \(preview.displayTitle.isEmpty ? preview.url : preview.displayTitle). Button: Dismiss."
        )
    }
}
