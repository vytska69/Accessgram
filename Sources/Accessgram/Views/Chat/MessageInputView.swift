import AppKit
import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    let isSending: Bool
    var inputFocused: AccessibilityFocusState<Bool>.Binding
    @Binding var scheduledDate: Date?
    let onAttach: (URL) -> Void
    let onSend: () -> Void

    @FocusState private var fieldFocused: Bool
    @State private var showSchedulePicker = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            attachButton
            textField
            scheduleButton
            sendButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var attachButton: some View {
        Button { openAttachPanel() } label: {
            Image(systemName: "paperclip")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add attachment")
        .accessibilityHint("Send a photo or file")
    }

    private var textField: some View {
        TextField("Message", text: $text, axis: .vertical)
            .lineLimit(1...6)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .focused($fieldFocused)
            .onSubmit {
                if !NSEvent.modifierFlags.contains(.shift) { onSend() }
            }
            .accessibilityLabel("Message input")
            .accessibilityHint("Type your message. Return to send, Shift-Return for a new line.")
            .accessibilityFocused(inputFocused)
            .onChange(of: inputFocused.wrappedValue) { _, focused in
                if focused { fieldFocused = true }
            }
    }

    private var scheduleButton: some View {
        Button {
            showSchedulePicker.toggle()
        } label: {
            Image(systemName: scheduledDate != nil ? "calendar.badge.clock" : "calendar")
                .font(.title3)
                .foregroundStyle(scheduledDate != nil ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(scheduledDate != nil ? "Change scheduled send time" : "Schedule message")
        .popover(isPresented: $showSchedulePicker, arrowEdge: .top) {
            SchedulePickerView(scheduledDate: $scheduledDate)
        }
    }

    private var sendButton: some View {
        Button(action: onSend) {
            ZStack {
                if isSending {
                    ProgressView().progressViewStyle(.circular).scaleEffect(0.7)
                } else {
                    Image(systemName: scheduledDate != nil ? "calendar.badge.plus" : "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(
                            text.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.secondary : Color.accentColor
                        )
                }
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        .keyboardShortcut(.return, modifiers: [])
        .accessibilityLabel(isSending ? "Sending" : scheduledDate != nil ? "Confirm scheduled send" : "Send message")
        .accessibilityHint(text.isEmpty ? "Type a message first" : "Send '\(text)'")
    }

    private func openAttachPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.item]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        onAttach(url)
    }
}

private struct SchedulePickerView: View {
    @Binding var scheduledDate: Date?
    @State private var pickerDate: Date
    @Environment(\.dismiss) private var dismiss

    init(scheduledDate: Binding<Date?>) {
        _scheduledDate = scheduledDate
        _pickerDate = State(initialValue: scheduledDate.wrappedValue ?? Date().addingTimeInterval(3_600))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule Message")
                .font(.headline)
            DatePicker(
                "Send at",
                selection: $pickerDate,
                in: Date().addingTimeInterval(60)...,
                displayedComponents: [.date, .hourAndMinute]
            )
            HStack {
                if scheduledDate != nil {
                    Button("Clear", role: .destructive) {
                        scheduledDate = nil
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Schedule") {
                    scheduledDate = pickerDate
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
