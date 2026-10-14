import Foundation
import KeyboardShortcuts

/// User preferences. Becomes UserDefaults-backed in M6 (library folder chooser, toggles).
enum Preferences {
    /// The library folder. Default `~/Stash`.
    static var libraryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Stash", directoryHint: .isDirectory)
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
