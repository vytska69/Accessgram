import AppKit
import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    let isSending: Bool
    var inputFocused: AccessibilityFocusState<Bool>.Binding
    @Binding var scheduledDate: Date?
    let onAttach: (URL) -> Void
    let onFormattedChange: (String, [[String: Any]]) -> Void
    let onSend: () -> Void

    @State private var editorContext = RichTextEditorContext()
    @State private var editorHeight: CGFloat = 36
    @State private var showSchedulePicker = false

    private var prefs: AppPreferences { AppPreferences.shared }

    var body: some View {
        VStack(spacing: 0) {
            if prefs.showFormatBar {
                formatBar
            }
            HStack(alignment: .bottom, spacing: 8) {
                attachButton
                richTextField
                scheduleButton
                sendButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Format bar

    private var formatBar: some View {
        HStack(spacing: 0) {
            formatButton(label: "B", font: .system(.caption).bold(), hint: "Bold (⌘B)") {
                editorContext.bold()
            }
            formatButton(label: "I", font: .system(.caption).italic(), hint: "Italic (⌘I)") {
                editorContext.italic()
            }
            formatButton(label: "</>", font: .system(.caption, design: .monospaced), hint: "Code (⌘E)") {
                editorContext.code()
            }
            Spacer()
            Text("Select text then apply format")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.trailing, 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func formatButton(label: String, font: Font, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(font)
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hint)
    }

    // MARK: - Rich text field

    private var richTextField: some View {
        RichTextEditor(
            text: $text,
            editorHeight: $editorHeight,
            inputFocused: inputFocused,
            editorContext: editorContext,
            onFormattedChange: onFormattedChange,
            onSubmit: onSend
        )
        .frame(height: min(max(editorHeight, 36), 130))
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel("Message input")
        .accessibilityHint(
            "Type your message. ⌘B bold, ⌘I italic, ⌘E code. Return to send, Shift-Return for a new line."
        )
    }

    // MARK: - Attach

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

    // MARK: - Schedule

    private var scheduleButton: some View {
        Button { showSchedulePicker.toggle() } label: {
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

    // MARK: - Send

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
    }

    // MARK: - Attach panel

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
            Text("Schedule Message").font(.headline)
            DatePicker(
                "Send at",
                selection: $pickerDate,
                in: Date().addingTimeInterval(60)...,
                displayedComponents: [.date, .hourAndMinute]
            )
            HStack {
                if scheduledDate != nil {
                    Button("Clear", role: .destructive) { scheduledDate = nil; dismiss() }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Schedule") { scheduledDate = pickerDate; dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
