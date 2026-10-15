import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private let panelController = PanelController()
    /// Nil only if the library folder or its index couldn't be opened.
    private(set) var library: LibraryStore?
    private let shelfStore = ShelfStore()
    private lazy var shelf = ShelfController(store: shelfStore)
    private let dragMonitor = DragMonitor()

    private lazy var settingsWindowController = SettingsWindowController(
        model: SettingsModel(
            library: { [weak self] in self?.library },
            switchLibrary: { [weak self] url in try self?.switchLibrary(to: url) }
        ),
        onShowMenuBarIconChange: { [weak self] show in self?.menuBarController?.isVisible = show },
        onShelfShakeChange: { [weak self] on in self?.setShelfShake(on) }
    )

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Info.plist sets LSUIElement for the bundled app; this also covers `swift run`.
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = MainMenu.make(target: self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(target: self)
        menuBarController?.isVisible = Preferences.showMenuBarIcon
        loadLibrary()
        setUpShelf()

        KeyboardShortcuts.onKeyDown(for: .capture) { [weak self] in
            self?.panelController.toggle(.capture)
        }
        KeyboardShortcuts.onKeyDown(for: .library) { [weak self] in
            self?.panelController.toggle(.library)
        }

        showWelcomeOnce()

        // Developer aid: `open build/Stash.app --args -StashShowPanel library` opens the panel at launch.
        switch UserDefaults.standard.string(forKey: "StashShowPanel") {
        case "capture": panelController.toggle(.capture)
        case "library": panelController.toggle(.library)
        default: break
        }

        #if DEBUG
        DebugHooks.install(panel: panelController, shelf: shelf) { [weak self] in self?.openSettings(nil) }
        #endif
    }

    /// Opening the app again (e.g. from Finder) shows Settings, so it stays reachable
    /// even if the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings(nil)
        return false
    }

    // MARK: Library

    /// Opens the library folder and its index, then keeps the index in sync with the folder.
    private func loadLibrary() {
        do {
            use(try LibraryStore.openDefault())
        } catch {
            presentError(error)
        }
    }

    /// Settings › Library › Choose…: from now on the library lives at `url`.
    func switchLibrary(to url: URL) throws {
        library?.stopWatching()
        let store = if let index = library?.index {
            try LibraryStore(root: url, index: index)
        } else {
            try LibraryStore.openDefault(root: url)
        }
        Preferences.setLibraryURL(url)
        use(store)
    }

    private func use(_ store: LibraryStore) {
        store.startWatching()
        store.scheduleSync()
        library = store
        panelController.library = store
    }

    // MARK: Shelf

    private func setUpShelf() {
        dragMonitor.onShake = { [weak self] point in self?.shelf.show(at: point) }
        dragMonitor.onDragEnded = { [weak self] in self?.shelf.dragEnded() }
        setShelfShake(Preferences.shelfShake)
        menuBarController?.onDrop = { [weak self] pasteboard in
            guard let self, self.shelf.accept(pasteboard) else { return false }
            if let point = self.menuBarController?.dropPoint { self.shelf.show(at: point) }
            return true
        }
        shelf.restore()
    }

    private func setShelfShake(_ on: Bool) {
        if on { dragMonitor.start() } else { dragMonitor.stop() }
    }

    // MARK: First launch

    /// Once: where Stash lives and how to capture.
    private func showWelcomeOnce() {
        guard !UserDefaults.standard.bool(forKey: Preferences.Key.didShowWelcome) else { return }
        UserDefaults.standard.set(true, forKey: Preferences.Key.didShowWelcome)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            HUDController.shared.show(.welcome(keys: KeyboardShortcuts.Name.capture.keycaps), hold: Motion.welcomeHold)
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
