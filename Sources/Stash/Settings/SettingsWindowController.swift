import AppKit
import SwiftUI

/// Hosts `SettingsView` in a regular titled window. Managed by hand because SwiftUI's
/// `Settings` scene can't be opened reliably from an AppKit menu in a menu-bar-only app.
@MainActor
final class SettingsWindowController {
    private let model: SettingsModel
    private let onShowMenuBarIconChange: (Bool) -> Void
    private var window: NSWindow?

    init(model: SettingsModel, onShowMenuBarIconChange: @escaping (Bool) -> Void) {
        self.model = model
        self.onShowMenuBarIconChange = onShowMenuBarIconChange
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        model.refresh()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let controller = NSHostingController(
            rootView: SettingsView(model: model, onShowMenuBarIconChange: onShowMenuBarIconChange)
        )
        // The window takes the form's size, and follows it (e.g. when a status line appears).
        controller.sizingOptions = [.preferredContentSize]

        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable]
        window.title = "Stash Settings"
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
