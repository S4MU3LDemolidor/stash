#if DEBUG
import AppKit
import Carbon.HIToolbox

/// Debug builds only: lets scripts drive the panel the way a user would, without accessibility
/// permissions (the events never leave Stash). Used to check focus handling and the keyboard map.
///
/// - `dev.stash.debug.toggle`, object `"capture"` or `"library"`: like pressing the shortcut;
///   `"settings"` opens Settings.
/// - `dev.stash.debug.keys`, object e.g. `"text:hoo down cmd+k esc"`: key presses, in order.
///   `paste:<text>` pastes into Capture from a private pasteboard (the clipboard isn't touched);
///   `image:<path>` does the same with a PNG file (the path can't contain spaces).
@MainActor
enum DebugHooks {
    static func install(panel: PanelController, openSettings: @escaping () -> Void) {
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: Notification.Name("dev.stash.debug.toggle"), object: nil, queue: .main) { [weak panel] note in
            let target = note.object as? String
            MainActor.assumeIsolated {
                if target == "settings" { return openSettings() }
                panel?.toggle(target == "library" ? .library : .capture)
            }
        }
        center.addObserver(forName: Notification.Name("dev.stash.debug.keys"), object: nil, queue: .main) { [weak panel] note in
            let script = note.object as? String ?? ""
            MainActor.assumeIsolated {
                guard let panel else { return }
                let windowNumber = panel.windowNumber
                for token in script.split(separator: " ") {
                    if token.hasPrefix("paste:") {
                        let pasteboard = NSPasteboard(name: NSPasteboard.Name("dev.stash.debug.paste"))
                        pasteboard.clearContents()
                        pasteboard.setString(String(token.dropFirst("paste:".count)), forType: .string)
                        panel.capture.paste(from: pasteboard)
                        continue
                    }
                    if token.hasPrefix("image:") {
                        let path = String(token.dropFirst("image:".count))
                        guard let data = FileManager.default.contents(atPath: path) else { continue }
                        let pasteboard = NSPasteboard(name: NSPasteboard.Name("dev.stash.debug.paste"))
                        pasteboard.clearContents()
                        pasteboard.setData(data, forType: .png)
                        panel.capture.paste(from: pasteboard)
                        continue
                    }
                    for event in events(for: String(token), windowNumber: windowNumber) {
                        NSApp.postEvent(event, atStart: false)
                    }
                }
            }
        }
    }

    private static let namedKeys: [String: (code: Int, character: String)] = [
        "return": (kVK_Return, "\r"), "esc": (kVK_Escape, "\u{1B}"), "tab": (kVK_Tab, "\t"),
        "backspace": (kVK_Delete, "\u{7F}"), "space": (kVK_Space, " "),
        "left": (kVK_LeftArrow, String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!))),
        "right": (kVK_RightArrow, String(Character(UnicodeScalar(NSRightArrowFunctionKey)!))),
        "up": (kVK_UpArrow, String(Character(UnicodeScalar(NSUpArrowFunctionKey)!))),
        "down": (kVK_DownArrow, String(Character(UnicodeScalar(NSDownArrowFunctionKey)!))),
    ]

    private static let letterCodes: [Character: Int] = [
        "a": kVK_ANSI_A, "c": kVK_ANSI_C, "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G,
        "k": kVK_ANSI_K, "v": kVK_ANSI_V,
    ]

    /// `text:hello` types characters; `cmd+shift+f`, `down`, `return`… press one key.
    private static func events(for token: String, windowNumber: Int) -> [NSEvent] {
        if token.hasPrefix("text:") {
            return token.dropFirst(5).compactMap { character in
                keyEvent(String(character), code: 0, modifiers: [], windowNumber: windowNumber)
            }
        }
        var parts = token.lowercased().split(separator: "+").map(String.init)
        let key = parts.removeLast()
        var modifiers: NSEvent.ModifierFlags = []
        if parts.contains("cmd") { modifiers.insert(.command) }
        if parts.contains("shift") { modifiers.insert(.shift) }
        if parts.contains("opt") { modifiers.insert(.option) }

        if let named = namedKeys[key] {
            return [keyEvent(named.character, code: named.code, modifiers: modifiers, windowNumber: windowNumber)].compactMap { $0 }
        }
        guard key.count == 1, let character = key.first else { return [] }
        let code = letterCodes[character] ?? 0
        return [keyEvent(String(character), code: code, modifiers: modifiers, windowNumber: windowNumber)].compactMap { $0 }
    }

    private static func keyEvent(_ characters: String, code: Int, modifiers: NSEvent.ModifierFlags, windowNumber: Int) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: UInt16(code)
        )
    }
}
#endif
