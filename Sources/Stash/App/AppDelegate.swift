import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private lazy var settingsWindowController = SettingsWindowController()

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Info.plist sets LSUIElement for the bundled app; this also covers `swift run`.
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = MainMenu.make(target: self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(target: self)
    }

    /// Opening the app again (e.g. from Finder) shows Settings, so it stays reachable
    /// even if the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings(nil)
        return false
    }
}

// MARK: - Commands (targets of menu items)

extension AppDelegate {
    @objc func capture(_ sender: Any?) {
        // Opens the panel in Capture mode (M1).
    }

    @objc func openLibrary(_ sender: Any?) {
        // Opens the panel in Library mode (M1/M4).
    }

    @objc func openLibraryFolder(_ sender: Any?) {
        let url = Preferences.libraryURL
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            NSAlert(error: error).runModal()
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc func openSettings(_ sender: Any?) {
        settingsWindowController.show()
    }
}
