import AppKit
import KeyboardShortcuts

/// Owns the menu bar item and its menu (design.md §5, "Menu bar").
/// Holding ⌥ while opening the menu also shows developer commands.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private var debugItems: [NSMenuItem] = []

    /// `target` receives the menu actions (see `AppDelegate` commands).
    init(target: AppDelegate) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: "Stash")
            image?.isTemplate = true
            button.image = image
        }

        let menu = makeMenu(target: target)
        menu.delegate = self
        statusItem.menu = menu
    }

    var isVisible: Bool {
        get { statusItem.isVisible }
        set { statusItem.isVisible = newValue }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let showDebug = NSEvent.modifierFlags.contains(.option)
        for item in debugItems {
            item.isHidden = !showDebug
        }
    }

    private func makeMenu(target: AppDelegate) -> NSMenu {
        let menu = NSMenu()

        let capture = item("Capture", #selector(AppDelegate.capture(_:)), target: target)
        // Keeps the displayed shortcut in sync with the user's recorded one.
        capture.setShortcut(for: .capture)
        menu.addItem(capture)

        let library = item("Open Library", #selector(AppDelegate.openLibrary(_:)), target: target)
        library.setShortcut(for: .library)
        menu.addItem(library)

        menu.addItem(.separator())
        menu.addItem(item("Open Library Folder", #selector(AppDelegate.openLibraryFolder(_:)), target: target))
        menu.addItem(item("Settings…", #selector(AppDelegate.openSettings(_:)), key: ",", target: target))

        debugItems = [
            .separator(),
            item("Debug: Create Sample Reference", #selector(AppDelegate.createSampleReference(_:)), target: target),
            item("Debug: Generate 200 Sample References", #selector(AppDelegate.generateSampleLibrary(_:)), target: target),
            item("Debug: Remove Sample References", #selector(AppDelegate.removeSampleLibrary(_:)), target: target),
        ]
        debugItems.forEach(menu.addItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Stash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "", target: AnyObject) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        return item
    }
}
