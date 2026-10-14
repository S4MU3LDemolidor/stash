import Foundation

/// Moving the library to another folder (Settings › Library › Choose…), e.g. into iCloud Drive.
enum LibraryMover {
    enum Plan: Equatable {
        /// Same folder: nothing to do.
        case none
        /// The folder already holds a Stash library (e.g. set up on another Mac): use it as is.
        case switchToExisting(referenceCount: Int)
        /// Move this library's files there.
        case move(referenceCount: Int)
    }

    enum MoveError: LocalizedError {
        case insideCurrentLibrary

        var errorDescription: String? {
            "Choose a folder outside the current library."
        }
    }

    static func plan(from current: URL, to destination: URL) throws -> Plan {
        let current = current.standardizedFileURL.resolvingSymlinksInPath()
        let destination = destination.standardizedFileURL.resolvingSymlinksInPath()
        if current.path == destination.path { return .none }
        if destination.path.hasPrefix(current.path + "/") { throw MoveError.insideCurrentLibrary }

        let existing = markdownCount(in: destination.appending(path: "items"))
        if existing > 0 { return .switchToExisting(referenceCount: existing) }
        return .move(referenceCount: markdownCount(in: current.appending(path: "items")))
    }

    /// Moves `items/` and `assets/` into `destination`, merging with what's there and never
    /// overwriting. The old folder is removed if nothing is left in it.
    static func move(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        for folder in ["items", "assets"] {
            let from = source.appending(path: folder, directoryHint: .isDirectory)
            let to = destination.appending(path: folder, directoryHint: .isDirectory)
            guard fileManager.fileExists(atPath: from.path) else { continue }
            if fileManager.fileExists(atPath: to.path) {
                try merge(from, into: to)
            } else {
                // Same volume (iCloud Drive included): a rename, instant. Otherwise a copy.
                try fileManager.moveItem(at: from, to: to)
            }
        }
        removeIfEmpty(source)
    }

    private static func merge(_ source: URL, into destination: URL) throws {
        let fileManager = FileManager.default
        for name in try fileManager.contentsOfDirectory(atPath: source.path) where name != ".DS_Store" {
            let from = source.appending(path: name)
            let to = destination.appending(path: name)
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: to.path, isDirectory: &isDirectory) {
                // Folders (assets/icons) merge; a file that's already there is left alone.
                if isDirectory.boolValue { try merge(from, into: to) }
            } else {
                try fileManager.moveItem(at: from, to: to)
            }
        }
        removeIfEmpty(source)
    }

    private static func removeIfEmpty(_ folder: URL) {
        let fileManager = FileManager.default
        let contents = (try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? []
        guard contents.allSatisfy({ $0 == ".DS_Store" }) else { return }
        try? fileManager.removeItem(at: folder)
    }

    private static func markdownCount(in folder: URL) -> Int {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { $0.hasSuffix(".md") || $0.hasSuffix(".md.icloud") }.count
    }
}
