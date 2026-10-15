import AppKit
import SwiftUI

/// The panel's text input: a plain `NSTextField` with no background, border or focus ring.
///
/// AppKit rather than SwiftUI's `TextField` so the panel can (1) reliably take focus each
/// time it opens and (2) intercept Esc / ↵ / ⇥ / ↑ / ↓ before the field editor acts on them
/// (Esc would otherwise trigger text completion and ⇥ would move focus out of the field).
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    /// When this changes, the field becomes first responder.
    let focusToken: Int
    var font: NSFont = Typography.searchNS
    let onCommand: (PanelKeyCommand) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = font
        field.textColor = Palette.textPrimary.nsColor
        field.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        if field.stringValue != text {
            field.stringValue = text
            // Set from outside (e.g. tag autocomplete): keep typing at the end.
            field.currentEditor()?.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        }

        if field.placeholderAttributedString?.string != placeholder {
            field.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [
                    .font: font,
                    .foregroundColor: Palette.textTertiary.nsColor,
                ]
            )
            field.setAccessibilityLabel(placeholder)
        }

        if coordinator.focusToken != focusToken {
            coordinator.focusToken = focusToken
            // Defer until the panel is key and the field is in its window.
            DispatchQueue.main.async {
                guard field.window?.firstResponder != field.currentEditor() || field.currentEditor() == nil else { return }
                field.window?.makeFirstResponder(field)
                // Becoming first responder selects everything; put the caret at the end instead,
                // so typing continues the text rather than replacing it.
                let length = (field.stringValue as NSString).length
                field.currentEditor()?.selectedRange = NSRange(location: length, length: 0)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchField
        var focusToken: Int?

        init(parent: SearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard let command = PanelKeyCommand(selector: selector) else { return false }
            return parent.onCommand(command)
        }
    }
}

private extension PanelKeyCommand {
    init?(selector: Selector) {
        switch selector {
        case #selector(NSResponder.cancelOperation(_:)): self = .cancel
        case #selector(NSResponder.insertNewline(_:)): self = .submit
        case #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)): self = .submitAlternate
        case #selector(NSResponder.insertTab(_:)): self = .tab
        case #selector(NSResponder.moveUp(_:)): self = .moveUp
        case #selector(NSResponder.moveDown(_:)): self = .moveDown
        case #selector(NSResponder.moveLeft(_:)): self = .moveLeft
        case #selector(NSResponder.moveRight(_:)): self = .moveRight
        case #selector(NSResponder.deleteBackward(_:)): self = .deleteBackward
        default: return nil
        }
    }
}
