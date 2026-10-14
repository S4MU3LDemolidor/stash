import AppKit
import Carbon.HIToolbox

/// Keyboard map (design.md §8) and saving.
extension PanelController {
    /// Keys forwarded by the text field. Returns whether the key was handled.
    func handle(_ command: PanelKeyCommand) -> Bool {
        let showingSuggestions = state.mode == .capture && !capture.suggestions.isEmpty

        switch command {
        case .cancel:
            if showingSuggestions {
                capture.dismissSuggestions(for: state.note)
            } else {
                hide()
            }
            return true

        case .tab, .submit:
            if showingSuggestions, let completed = capture.completeSuggestion(in: state.note) {
                state.note = completed
            } else if command == .tab {
                switchMode(to: state.mode == .capture ? .library : .capture)
            } else if state.mode == .capture {
                saveCapture(keepOpen: false)
            }
            // Library's Open arrives in M4. Swallow ↵ either way so the field keeps focus.
            return true

        case .moveUp, .moveDown:
            guard showingSuggestions else { return false }
            capture.moveSuggestion(by: command == .moveUp ? -1 : 1)
            return true
        }
    }

    /// ⌘-shortcuts, before the text field or the Edit menu sees them.
    func handleKeyEquivalent(_ event: NSEvent) -> Bool {
        guard state.mode == .capture,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
        else { return false }

        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            // ⌘↵: save and keep the panel open for the next one.
            saveCapture(keepOpen: true)
            return true
        case kVK_Delete:
            // ⌘⌫: clear the captured item.
            capture.clear()
            return true
        default:
            // ⌘V replaces the capture with the clipboard instead of pasting into the note.
            if event.charactersIgnoringModifiers?.lowercased() == "v" {
                capture.paste()
                return true
            }
            return false
        }
    }

    /// ↵ closes the panel right away; the file is written in the background (after a browser
    /// read that's still in flight), then the HUD confirms.
    func saveCapture(keepOpen: Bool) {
        let note = state.note
        guard capture.canSave(note: note) else {
            NSSound.beep()
            return
        }
        if !keepOpen { hide() }

        Task {
            do {
                if try await capture.save(note: note) == nil {
                    HUDController.shared.show(.nothingToSave)
                    return
                }
                HUDController.shared.show(.saved)
                if keepOpen, isShown {
                    state.note = ""
                    capture.clear()
                }
            } catch {
                HUDController.shared.show(.failed(error.localizedDescription))
            }
        }
    }
}
