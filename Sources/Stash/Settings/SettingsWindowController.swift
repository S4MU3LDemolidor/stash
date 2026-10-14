import AppKit
import SwiftUI

/// Hosts `SettingsView` in a regular titled window. Managed by hand because SwiftUI's
/// `Settings` scene can't be opened reliably from an AppKit menu in a menu-bar-only app.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Stash Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
