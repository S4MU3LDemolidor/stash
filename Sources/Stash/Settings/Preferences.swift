import AppKit
import KeyboardShortcuts

/// User preferences, stored in UserDefaults. Edited in the Settings window.
enum Preferences {
    enum Key {
        /// Path of the library folder (`~` allowed). Also settable for one run with
        /// `-libraryPath /some/folder` on the command line.
        static let libraryPath = "libraryPath"
        /// Seconds after copying something during which Capture offers it. 0 turns it off.
        static let clipboardWindow = "clipboardWindow"
        /// Whether to fetch titles, thumbnails and icons for saved links (the only network use).
        static let fetchMetadata = "fetchMetadata"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let didShowWelcome = "didShowWelcome"
        /// Shaking a drag opens the shelf. Default on.
        static let shelfShake = "shelfShake"
        /// Where the shelf was last (bottom-left, screen coordinates), as `NSStringFromPoint`.
        static let shelfOrigin = "shelfOrigin"
    }

    /// Default on. When off, Stash makes no network requests at all.
    static var fetchMetadata: Bool {
        UserDefaults.standard.object(forKey: Key.fetchMetadata) as? Bool ?? true
    }

    /// How recently something must have been copied for Capture to pick it up. Default 1 minute.
    static var clipboardWindow: TimeInterval {
        UserDefaults.standard.object(forKey: Key.clipboardWindow) as? TimeInterval ?? 60
    }

    static var showMenuBarIcon: Bool {
        UserDefaults.standard.object(forKey: Key.showMenuBarIcon) as? Bool ?? true
    }

    static var shelfShake: Bool {
        UserDefaults.standard.object(forKey: Key.shelfShake) as? Bool ?? true
    }

    static var shelfOrigin: NSPoint? {
        get { UserDefaults.standard.string(forKey: Key.shelfOrigin).map(NSPointFromString) }
        set { UserDefaults.standard.set(newValue.map(NSStringFromPoint), forKey: Key.shelfOrigin) }
    }

    /// The library folder: `libraryPath` if set, otherwise `~/Stash`.
    static var libraryURL: URL {
        if let path = UserDefaults.standard.string(forKey: Key.libraryPath), !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Stash", directoryHint: .isDirectory)
    }

    static func setLibraryURL(_ url: URL) {
        UserDefaults.standard.set((url.path as NSString).abbreviatingWithTildeInPath, forKey: Key.libraryPath)
    }

    /// The library folder for display, e.g. `~/Stash`.
    static var libraryDisplayPath: String {
        (libraryURL.path as NSString).abbreviatingWithTildeInPath
    }
}

extension KeyboardShortcuts.Name {
    static let capture = Self("capture", default: .init(.s, modifiers: [.option, .shift]))
    static let library = Self("library", default: .init(.l, modifiers: [.option, .shift]))
}

enum AppInfo {
    /// `0.1.0 (12)`.
    static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    /// Where the source code lives.
    static let repositoryURL = URL(string: "https://github.com/S4MU3LDemolidor/stash")!
}
