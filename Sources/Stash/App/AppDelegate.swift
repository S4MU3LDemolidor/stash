import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private let panelController = PanelController()
    /// Nil only if the library folder or its index couldn't be opened.
    private(set) var library: LibraryStore?
    private lazy var settingsWindowController = SettingsWindowController()

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Info.plist sets LSUIElement for the bundled app; this also covers `swift run`.
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = MainMenu.make(target: self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(target: self)
        loadLibrary()

        KeyboardShortcuts.onKeyDown(for: .capture) { [weak self] in
            self?.panelController.toggle(.capture)
        }
        KeyboardShortcuts.onKeyDown(for: .library) { [weak self] in
            self?.panelController.toggle(.library)
        }

        // Developer aid: `open build/Stash.app --args -StashShowPanel library` opens the panel at launch.
        switch UserDefaults.standard.string(forKey: "StashShowPanel") {
        case "capture": panelController.toggle(.capture)
        case "library": panelController.toggle(.library)
        default: break
        }

        #if DEBUG
        DebugHooks.install(panel: panelController)
        #endif
    }


    /// Opening the app again (e.g. from Finder) shows Settings, so it stays reachable
    /// even if the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings(nil)
        return false
    }

    /// Opens the library folder and its index, then keeps the index in sync with the folder.
    private func loadLibrary() {
        do {
            let library = try LibraryStore.openDefault()
            library.startWatching()
            library.scheduleSync()
            self.library = library
            panelController.library = library
        } catch {
            presentError(error)
        }
    }

    func presentError(_ error: Error) {
        NSApp.activate()
        NSAlert(error: error).runModal()
    }
}

// MARK: - Commands (targets of menu items)

extension AppDelegate {
    @objc func capture(_ sender: Any?) {
        panelController.toggle(.capture)
    }

    @objc func openLibrary(_ sender: Any?) {
        panelController.toggle(.library)
    }

    @objc func openLibraryFolder(_ sender: Any?) {
        let url = library?.root ?? Preferences.libraryURL
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            presentError(error)
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc func openSettings(_ sender: Any?) {
        settingsWindowController.show()
    }
}
