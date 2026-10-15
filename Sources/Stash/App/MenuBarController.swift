import AppKit
import KeyboardShortcuts

/// Owns the menu bar item and its menu (design.md §5, "Menu bar").
/// Holding ⌥ while opening the menu also shows developer commands.
/// Things dropped on the icon go to the shelf.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate, NSWindowDelegate, NSDraggingDestination {
    private let statusItem: NSStatusItem
    private var debugItems: [NSMenuItem] = []

    /// Something was dropped on the menu bar icon. Returns whether it was taken.
    var onDrop: ((NSPasteboard) -> Bool)?

    /// `target` receives the menu actions (see `AppDelegate` commands).
    init(target: AppDelegate) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            // The Stash mark as a template image: macOS tints it for light and dark menu bars.
            button.image = StashMark.image(height: Metrics.menuBarIconHeight)
        }

        let menu = makeMenu(target: target)
        menu.delegate = self
        statusItem.menu = menu
        // The status item's window only exists once the item is in the menu bar.
        DispatchQueue.main.async { [weak self] in self?.acceptDrops() }
    }

    var isVisible: Bool {
        get { statusItem.isVisible }
        set { statusItem.isVisible = newValue }
    }

    /// Where the shelf should appear for a drop on the icon: just below it.
    var dropPoint: NSPoint? {
        guard let frame = statusItem.button?.window?.frame else { return nil }
        return NSPoint(x: frame.midX, y: frame.minY - Metrics.shelfCollapsedHeight / 2 - 8)
    }

    /// The status item's window (which has no delegate of its own) forwards drag messages to
    /// its delegate.
    private func acceptDrops() {
        guard let window = statusItem.button?.window else { return }
        window.registerForDraggedTypes(ShelfPasteboard.acceptedTypes)
        window.delegate = self
    }

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.availableType(from: ShelfPasteboard.acceptedTypes) != nil ? .copy : []
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDrop?(sender.draggingPasteboard) ?? false
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
