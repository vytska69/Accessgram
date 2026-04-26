import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    let isSending: Bool
    var inputFocused: AccessibilityFocusState<Bool>.Binding
    let onSend: () -> Void

    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Attach button (placeholder for future file/photo sending)
            Button {
                // TODO: attachment picker
            } label: {
                Image(systemName: "paperclip")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add attachment")
            .accessibilityHint("Send a photo, file, or other media")

            // Text input
            TextField("Message", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .focused($fieldFocused)
                .onSubmit {
                    // Shift+Return = new line, Return = send
                    if !NSEvent.modifierFlags.contains(.shift) {
                        onSend()
                    }
                }
                .accessibilityLabel("Message input")
                .accessibilityHint("Type your message. Press Return to send, Shift-Return for a new line.")
                .accessibilityFocused(inputFocused)
                .onChange(of: inputFocused.wrappedValue) { _, focused in
                    if focused { fieldFocused = true }
                }

            // Send button
            Button(action: onSend) {
                ZStack {
                    if isSending {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundStyle(text.trimmingCharacters(in: .whitespaces).isEmpty
                                             ? Color.secondary : Color.accentColor)
                    }
                }
                .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityLabel(isSending ? "Sending" : "Send message")
            .accessibilityHint(text.isEmpty ? "Type a message first" : "Send '\(text)'")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
