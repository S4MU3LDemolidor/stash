import AppKit

/// What the Settings window can't do with plain preferences: moving the library, rebuilding
/// the index, launch at login.
@MainActor
final class SettingsModel: ObservableObject {
    @Published private(set) var libraryPath = Preferences.libraryDisplayPath
    @Published private(set) var referenceCount = 0
    @Published private(set) var libraryStatus: String?
    @Published private(set) var launchAtLogin = LoginItem.isEnabled
    @Published private(set) var loginItemNeedsApproval = LoginItem.needsApproval

    private let library: () -> LibraryStore?
    private let switchLibrary: (URL) throws -> Void

    init(library: @escaping () -> LibraryStore?, switchLibrary: @escaping (URL) throws -> Void) {
        self.library = library
        self.switchLibrary = switchLibrary
        NotificationCenter.default.addObserver(forName: .libraryDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        libraryPath = Preferences.libraryDisplayPath
        referenceCount = (try? library()?.index.count()) ?? 0
        launchAtLogin = LoginItem.isEnabled
        loginItemNeedsApproval = LoginItem.needsApproval
    }

    // MARK: Library folder

    func revealLibrary() {
        NSWorkspace.shared.open(library()?.root ?? Preferences.libraryURL)
    }

    /// Choose… → pick a folder, then move the library there or switch to the library it has.
    func chooseLibraryFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Folder"
        panel.message = "Choose where to keep your Stash library. A folder in iCloud Drive keeps it in sync across your Macs."
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        let current = library()?.root ?? Preferences.libraryURL
        do {
            switch try LibraryMover.plan(from: current, to: destination) {
            case .none:
                return
            case .switchToExisting(let count):
                guard confirm(
                    "Use the library in “\(destination.lastPathComponent)”?",
                    detail: "It already has \(count) references. Your current library stays where it is.",
                    button: "Use This Library"
                ) else { return }
                try switchLibrary(destination)
                libraryStatus = "Switched to the library in \(destination.lastPathComponent)."
            case .move(let count):
                guard confirm(
                    "Move your library to “\(destination.lastPathComponent)”?",
                    detail: "\(count) references and their images and files will be moved there.",
                    button: "Move Library"
                ) else { return }
                try LibraryMover.move(from: current, to: destination)
                try switchLibrary(destination)
                libraryStatus = "Moved \(count) references."
            }
        } catch {
            NSAlert(error: error).runModal()
        }
        refresh()
    }

    func rebuildIndex() {
        guard let library = library() else { return }
        do {
            try library.index.removeAll()
            let result = try library.syncNow()
            libraryStatus = "Index rebuilt: \(result.indexed) references."
                + (result.skipped.isEmpty ? "" : " \(result.skipped.count) files couldn't be read.")
        } catch {
            NSAlert(error: error).runModal()
        }
        refresh()
    }

    // MARK: Launch at login

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
        } catch {
            NSAlert(error: error).runModal()
        }
        refresh()
    }

    func openLoginItemsSettings() {
        LoginItem.openSystemSettings()
    }

    private func confirm(_ message: String, detail: String, button: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
