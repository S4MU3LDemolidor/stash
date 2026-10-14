import AppKit
import KeyboardShortcuts

/// Owns the menu bar item and its menu (design.md §5, "Menu bar").
@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem

    /// `target` receives the menu actions (see `AppDelegate` commands).
    init(target: AppDelegate) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: "Stash")
            image?.isTemplate = true
            button.image = image
        }

        statusItem.menu = Self.makeMenu(target: target)
    }

    var isVisible: Bool {
        get { statusItem.isVisible }
        set { statusItem.isVisible = newValue }
    }

    private static func makeMenu(target: AppDelegate) -> NSMenu {
        let menu = NSMenu()

        let capture = NSMenuItem(title: "Capture", action: #selector(AppDelegate.capture(_:)), keyEquivalent: "")
        capture.target = target
        // Keeps the displayed shortcut in sync with the user's recorded one.
        capture.setShortcut(for: .capture)
        menu.addItem(capture)

        let library = NSMenuItem(title: "Open Library", action: #selector(AppDelegate.openLibrary(_:)), keyEquivalent: "")
        library.target = target
        library.setShortcut(for: .library)
        menu.addItem(library)

        menu.addItem(.separator())

        let folder = NSMenuItem(
            title: "Open Library Folder",
            action: #selector(AppDelegate.openLibraryFolder(_:)),
            keyEquivalent: ""
        )
        folder.target = target
        menu.addItem(folder)

        let settings = NSMenuItem(title: "Settings…", action: #selector(AppDelegate.openSettings(_:)), keyEquivalent: ",")
        settings.target = target
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit Stash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }
}
