import Foundation
import GRDB

/// Size and modification date of a Markdown file when it was indexed.
struct FileStamp: Equatable, Sendable {
    var modified: Double
    var size: Int64
}

/// SQLite cache of the library for instant search. The Markdown files are the truth: this
/// can be deleted at any time and `LibrarySync` rebuilds it.
final class SearchIndex: Sendable {
    /// Bump when the schema changes; an index with another version is thrown away and rebuilt.
    static let schemaVersion = 3

    /// FTS columns, in the order `bm25` weights refer to them.
    static let searchColumns = ["title", "note", "tags", "site", "urlText", "text", "fileText"]
    static let searchWeights = "10.0, 5.0, 8.0, 3.0, 1.0, 2.0, 1.0"

    /// Shared with the query extensions in `SearchIndex+Queries.swift`.
    let db: DatabaseQueue

    /// - Parameter path: the SQLite file, or nil for an in-memory index (tests).
    init(path: String?) throws {
        guard let path else {
            db = try DatabaseQueue()
            try Self.prepareSchema(db)
            return
        }
        do {
            db = try Self.open(path)
        } catch {
            // It's only a cache: if it can't be opened (corrupt, other version), start over.
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: path + suffix)
            }
            db = try Self.open(path)
        }
    }

    private static func open(_ path: String) throws -> DatabaseQueue {
        let queue = try DatabaseQueue(path: path)
        try prepareSchema(queue)
        return queue
    }

    private static func prepareSchema(_ queue: DatabaseQueue) throws {
        try queue.write { db in
            let version = try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
            if version == schemaVersion { return }
            guard version == 0 else { throw DatabaseError(message: "Index schema \(version) is outdated") }

            try db.create(table: "reference") { t in
                t.column("id", .text).primaryKey()
                t.column("path", .text).notNull().unique()
                t.column("modified", .double).notNull()
                t.column("size", .integer).notNull()
                t.column("type", .text).notNull()
                t.column("created", .double).notNull().indexed()
                t.column("url", .text)
                // The URL as searched: no scheme, `www.` or query, so "h" doesn't match every https link.
                t.column("urlText", .text)
                t.column("title", .text)
                t.column("site", .text)
                t.column("timestamp", .integer)
                t.column("file", .text)
                t.column("filename", .text)
                t.column("width", .integer)
                t.column("height", .integer)
                t.column("thumbnail", .text)
                t.column("tags", .text).notNull()
                t.column("note", .text).notNull()
                t.column("text", .text)
                // Text inside an attached file (PDF, plain text…), see FileTextExtractor.
                t.column("fileText", .text)
            }
            try db.create(table: "referenceTag") { t in
                t.column("referenceId", .text).notNull().references("reference", onDelete: .cascade)
                t.column("tag", .text).notNull().indexed()
                t.primaryKey(["referenceId", "tag"])
            }
            // Links whose title and thumbnail were already fetched (see Enricher).
            try db.create(table: "enrichment") { t in
                t.column("referenceId", .text).primaryKey()
                t.column("attempted", .double).notNull()
            }
            try db.create(table: "meta") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text)
            }
            try db.create(virtualTable: "referenceSearch", using: FTS5()) { t in
                t.synchronize(withTable: "reference")
                // remove_diacritics=2: "acao" finds "ação".
                t.tokenizer = .unicode61(diacritics: .remove)
                for column in searchColumns { t.column(column) }
            }
            try db.execute(sql: "PRAGMA user_version = \(schemaVersion)")
        }
    }

    // MARK: Writing

    struct Upsert {
        var reference: Reference
        var stamp: FileStamp
        /// Text inside the attached file. Nil keeps what's already indexed.
        var fileText: String? = nil
    }

    /// Applies one sync pass in a single transaction.
    func apply(upserts: [Upsert], removedPaths: [String]) throws {
        try db.write { db in
            for path in removedPaths {
                try db.execute(sql: "DELETE FROM reference WHERE path = ?", arguments: [path])
            }
            for upsert in upserts {
                try Self.upsert(upsert.reference, stamp: upsert.stamp, fileText: upsert.fileText, in: db)
            }
        }
    }

    func upsert(_ reference: Reference, stamp: FileStamp, fileText: String? = nil) throws {
        try db.write { db in try Self.upsert(reference, stamp: stamp, fileText: fileText, in: db) }
    }

    func setFileText(_ text: String?, id: String) throws {
        try db.write { db in
            try db.execute(sql: "UPDATE reference SET fileText = ? WHERE id = ?", arguments: [text, id])
        }
    }

    func remove(id: String) throws {
        try db.write { db in
            try db.execute(sql: "DELETE FROM reference WHERE id = ?", arguments: [id])
        }
    }

    func removeAll() throws {
        try db.write { db in try db.execute(sql: "DELETE FROM reference") }
    }

    private static func upsert(_ reference: Reference, stamp: FileStamp, fileText: String?, in db: Database) throws {
        guard let path = reference.markdownPath else { return }
        // Another reference that used to live at this path (the file was replaced).
        try db.execute(sql: "DELETE FROM reference WHERE path = ? AND id != ?", arguments: [path, reference.id])

        let columns = [
            "id", "path", "modified", "size", "type", "created", "url", "urlText", "title", "site", "timestamp",
            "file", "filename", "width", "height", "thumbnail", "tags", "note", "text", "fileText",
        ]
        let values: [(any DatabaseValueConvertible)?] = [
            reference.id, path, stamp.modified, stamp.size, reference.type.rawValue,
            reference.created.timeIntervalSince1970, reference.url?.absoluteString,
            reference.url.map { (Reference.site(for: $0) ?? "") + $0.path(percentEncoded: false) }, reference.title,
            reference.site, reference.timestamp, reference.file, reference.originalFilename,
            reference.width, reference.height, reference.thumbnail,
            reference.tags.joined(separator: " "), reference.note, reference.text, fileText,
        ]
        let updates = columns.dropFirst().map { column in
            // Extracting file text is slow, so most writes leave it as it is.
            column == "fileText"
                ? "fileText = COALESCE(excluded.fileText, reference.fileText)"
                : "\(column) = excluded.\(column)"
        }.joined(separator: ", ")
        try db.execute(
            sql: """
                INSERT INTO reference (\(columns.joined(separator: ", ")))
                VALUES (\(Array(repeating: "?", count: columns.count).joined(separator: ", ")))
                ON CONFLICT(id) DO UPDATE SET \(updates)
                """,
            arguments: StatementArguments(values)
        )

        try db.execute(sql: "DELETE FROM referenceTag WHERE referenceId = ?", arguments: [reference.id])
        for tag in reference.tags {
            try db.execute(
                sql: "INSERT OR IGNORE INTO referenceTag (referenceId, tag) VALUES (?, ?)",
                arguments: [reference.id, tag]
            )
        }
    }

    // MARK: Meta

    func metaValue(_ key: String) throws -> String? {
        try db.read { db in try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = ?", arguments: [key]) }
    }

    func setMetaValue(_ value: String?, for key: String) throws {
        try db.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", arguments: [key, value])
        }
    }
}
