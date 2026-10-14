import Foundation
import KeyboardShortcuts

/// User preferences, stored in UserDefaults. The Settings window for them arrives in M6.
enum Preferences {
    enum Key {
        /// Path of the library folder (`~` allowed). Also settable for one run with
        /// `-libraryPath /some/folder` on the command line.
        static let libraryPath = "libraryPath"
    }

    /// The library folder: `libraryPath` if set, otherwise `~/Stash`.
    static var libraryURL: URL {
        if let path = UserDefaults.standard.string(forKey: Key.libraryPath), !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
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
