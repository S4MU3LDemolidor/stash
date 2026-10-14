import AppKit
import Carbon.HIToolbox

/// The keyboard map (design.md §8): what each key does in Capture and Library.
extension PanelController {
    /// Keys forwarded by the main text field. Returns whether the key was handled.
    func handle(_ command: PanelKeyCommand) -> Bool {
        switch state.mode {
        case .capture: handleCapture(command)
        case .library: handleLibrary(command)
        }
    }

    private func handleCapture(_ command: PanelKeyCommand) -> Bool {
        let autocomplete = capture.autocomplete
        switch command {
        case .cancel:
            if autocomplete.isShowing {
                autocomplete.dismiss(for: state.note)
            } else {
                hide()
            }
            return true
        case .tab, .submit:
            if autocomplete.isShowing, let completed = capture.completeSuggestion(in: state.note) {
                state.note = completed
            } else if command == .tab {
                switchMode(to: .library)
            } else {
                saveCapture(keepOpen: false)
            }
            return true
        case .moveUp, .moveDown:
            guard autocomplete.isShowing else { return false }
            autocomplete.move(by: command == .moveUp ? -1 : 1)
            return true
        case .moveLeft, .moveRight, .deleteBackward:
            return false
        }
    }

    private func handleLibrary(_ command: PanelKeyCommand) -> Bool {
        let library = libraryController

        // A delete waiting for confirmation: ↵ deletes, anything else cancels.
        if library.deleteCandidate != nil {
            switch command {
            case .submit:
                report { try library.confirmDelete() }
                return true
            case .cancel:
                library.deleteCandidate = nil
                return true
            default:
                library.deleteCandidate = nil
            }
        }

        if library.autocomplete.isShowing {
            switch command {
            case .tab, .submit:
                _ = library.editing != nil ? library.completeEditSuggestion() : library.completeTagSuggestion()
                return true
            case .moveUp, .moveDown:
                library.autocomplete.move(by: command == .moveUp ? -1 : 1)
                return true
            case .cancel:
                library.autocomplete.dismiss(for: library.editing != nil ? library.editText : library.searchText)
                return true
            default:
                break
            }
        }

        if library.editing != nil {
            switch command {
            case .submit: report { try library.commitEdit() }
            case .cancel: library.cancelEdit()
            case .tab: break
            default: return false
            }
            return true
        }

        switch command {
        case .cancel:
            // Clear the search first, then close.
            if !library.clearSearch() { hide() }
        case .tab:
            switchMode(to: .capture)
        case .submit:
            if let selected = library.selected {
                library.open(selected, atTimestamp: false)
            } else if library.results.isEmpty {
                report { try library.saveSearchAsNote() }
            }
        case .moveUp:
            library.moveSelection(.up)
        case .moveDown:
            library.moveSelection(.down)
        case .moveLeft, .moveRight:
            // In the list, ← → move the caret in the search field.
            guard library.layout == .grid else { return false }
            library.moveSelection(command == .moveLeft ? .left : .right)
        case .deleteBackward:
            return library.removeLastPill()
        }
        return true
    }

    /// Keys from the ⌘K menu's own search field. `Esc` closes only the menu.
    func handleMenu(_ command: PanelKeyCommand) -> Bool {
        let library = libraryController
        switch command {
        case .cancel: library.closeActionMenu()
        case .submit: library.runSelectedAction()
        case .moveUp: library.moveActionSelection(by: -1)
        case .moveDown: library.moveActionSelection(by: 1)
        case .tab: break
        case .moveLeft, .moveRight, .deleteBackward: return false
        }
        return true
    }

    /// ⌘-shortcuts, before the text field or the Edit menu sees them.
    func handleKeyEquivalent(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased()
        let isReturn = [kVK_Return, kVK_ANSI_KeypadEnter].contains(Int(event.keyCode))
        let isDelete = Int(event.keyCode) == kVK_Delete

        switch state.mode {
        case .capture:
            guard modifiers == .command else { return false }
            if isReturn {
                // ⌘↵: save and keep the panel open for the next one.
                saveCapture(keepOpen: true)
            } else if isDelete {
                capture.clear()
            } else if key == "v" {
                // ⌘V replaces the capture with the clipboard instead of pasting into the note.
                capture.paste()
            } else {
                return false
            }
            return true

        case .library:
            let library = libraryController
            // While editing, ⌘-keys belong to the text field (⌘A, ⌘V, ⌘Z…).
            guard library.editing == nil else { return false }
            let selected = library.selected

            if modifiers == [.command, .shift], key == "f", let selected {
                library.closeActionMenu()
                library.reveal(selected)
                return true
            }
            guard modifiers == .command else { return false }
            switch key {
            case "k":
                library.toggleActionMenu()
            case "g":
                library.closeActionMenu()
                library.toggleLayout()
            case "e" where selected != nil:
                library.closeActionMenu()
                library.beginEdit()
            case "c" where selected != nil && !hasSelectedText:
                library.copy(selected!)
            default:
                guard let selected, isReturn || isDelete else { return false }
                library.closeActionMenu()
                if isReturn {
                    library.open(selected, atTimestamp: true)
                } else {
                    library.requestDelete()
                }
            }
            return true
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

    private func report(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            HUDController.shared.show(.failed(error.localizedDescription))
        }
    }
}
