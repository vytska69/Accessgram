import AppKit
import SwiftUI

// MARK: - Editor context (shared between format buttons and the NSTextView)

@Observable
@MainActor
final class RichTextEditorContext {
    weak var textView: RichNSTextView?
    func bold()   { textView?.toggleTrait(.boldFontMask) }
    func italic() { textView?.toggleTrait(.italicFontMask) }
    func code()   { textView?.toggleCode() }
}

// MARK: - Custom NSTextView

final class RichNSTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onHeightChange: ((CGFloat) -> Void)?

    private static let defaultSize = NSFont.systemFontSize

    override var intrinsicContentSize: NSSize {
        guard let container = textContainer, let manager = layoutManager else {
            return super.intrinsicContentSize
        }
        manager.ensureLayout(for: container)
        let used = manager.usedRect(for: container)
        return NSSize(width: NSView.noIntrinsicMetric,
                      height: ceil(used.height) + textContainerInset.height * 2)
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
        let h = min(max(intrinsicContentSize.height, 36), 130)
        DispatchQueue.main.async { self.onHeightChange?(h) }
    }

    // MARK: Keyboard shortcuts

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard mods == .command else { return super.performKeyEquivalent(with: event) }
        switch event.charactersIgnoringModifiers {
        case "b": toggleTrait(.boldFontMask);   return true
        case "i": toggleTrait(.italicFontMask); return true
        case "e": toggleCode();                 return true
        default:  return super.performKeyEquivalent(with: event)
        }
    }

    override func insertNewline(_ sender: Any?) {
        if NSEvent.modifierFlags.contains(.shift) {
            super.insertNewline(sender)
        } else {
            onSubmit?()
        }
    }

    // MARK: Formatting

    func toggleTrait(_ trait: NSFontTraitMask) {
        let range = selectedRange()
        guard range.length > 0, let storage = textStorage else { return }
        let fm = NSFontManager.shared
        var allHave = true
        storage.enumerateAttribute(.font, in: range, options: []) { val, _, _ in
            if let f = val as? NSFont, !fm.traits(of: f).contains(trait) { allHave = false }
        }
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range, options: []) { val, sub, _ in
            let f = (val as? NSFont) ?? .systemFont(ofSize: Self.defaultSize)
            let new = allHave ? fm.convert(f, toNotHaveTrait: trait)
                              : fm.convert(f, toHaveTrait: trait)
            storage.addAttribute(.font, value: new, range: sub)
        }
        storage.endEditing()
        didChangeText()
    }

    func toggleCode() {
        let range = selectedRange()
        guard range.length > 0, let storage = textStorage else { return }
        var allCode = true
        storage.enumerateAttribute(.font, in: range, options: []) { val, _, _ in
            if let f = val as? NSFont, !f.fontDescriptor.symbolicTraits.contains(.monoSpace) { allCode = false }
        }
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range, options: []) { val, sub, _ in
            let size = (val as? NSFont)?.pointSize ?? Self.defaultSize
            let new: NSFont = allCode
                ? .systemFont(ofSize: size)
                : .monospacedSystemFont(ofSize: size, weight: .regular)
            storage.addAttribute(.font, value: new, range: sub)
        }
        storage.endEditing()
        didChangeText()
    }

    // MARK: Entity extraction

    static func extractEntities(from storage: NSTextStorage) -> [[String: Any]] {
        guard storage.length > 0 else { return [] }
        var result: [[String: Any]] = []
        let fm = NSFontManager.shared
        storage.enumerateAttribute(.font, in: NSRange(location: 0, length: storage.length), options: []) { val, r, _ in
            guard let font = val as? NSFont else { return }
            if font.fontDescriptor.symbolicTraits.contains(.monoSpace) {
                result.append(["@type": "textEntityTypeCode", "offset": r.location, "length": r.length])
            } else {
                let traits = fm.traits(of: font)
                if traits.contains(.boldFontMask) {
                    result.append(["@type": "textEntityTypeBold", "offset": r.location, "length": r.length])
                }
                if traits.contains(.italicFontMask) {
                    result.append(["@type": "textEntityTypeItalic", "offset": r.location, "length": r.length])
                }
            }
        }
        return result
    }
}

// MARK: - NSViewRepresentable

struct RichTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var editorHeight: CGFloat
    var inputFocused: AccessibilityFocusState<Bool>.Binding
    let editorContext: RichTextEditorContext
    let onFormattedChange: (String, [[String: Any]]) -> Void
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> RichNSTextView {
        let tv = RichNSTextView()
        tv.delegate = context.coordinator
        tv.onSubmit = onSubmit
        tv.onHeightChange = { [weak context] h in context?.coordinator.parent.editorHeight = h }
        tv.isRichText = true
        tv.allowsUndo = true
        tv.font = .systemFont(ofSize: NSFont.systemFontSize)
        tv.textContainerInset = NSSize(width: 4, height: 8)
        tv.backgroundColor = .controlBackgroundColor
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.textContainer?.widthTracksTextView = true
        DispatchQueue.main.async { self.editorContext.textView = tv }
        return tv
    }

    func updateNSView(_ nsView: RichNSTextView, context: Context) {
        context.coordinator.parent = self
        editorContext.textView = nsView
        if text.isEmpty && !nsView.string.isEmpty {
            nsView.textStorage?.setAttributedString(NSAttributedString(string: ""))
            nsView.didChangeText()
        }
        if inputFocused.wrappedValue {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor

        init(_ parent: RichTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? RichNSTextView,
                  let storage = tv.textStorage else { return }
            let text = storage.string
            let entities = Self.extractEntities(from: storage)
            parent.text = text
            parent.onFormattedChange(text, entities)
        }
    }
}
