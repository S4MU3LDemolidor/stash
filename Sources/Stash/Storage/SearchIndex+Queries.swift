import Foundation
import GRDB

/// Read queries: search, tags, single references, and links waiting for enrichment.
extension SearchIndex {

    /// Indexed files by path: what `LibrarySync` compares the folder against.
    func indexedFiles() throws -> [String: (id: String, stamp: FileStamp)] {
        try db.read { db in
            var result: [String: (id: String, stamp: FileStamp)] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT id, path, modified, size FROM reference") {
                result[row["path"]] = (row["id"], FileStamp(modified: row["modified"], size: row["size"]))
            }
            return result
        }
    }

    func reference(id: String) throws -> Reference? {
        try db.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM reference WHERE id = ?", arguments: [id])
                .flatMap(Self.reference(from:))
        }
    }

    func count() throws -> Int {
        try db.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM reference") ?? 0 }
    }

    /// All tags with how many references use them, most used first (for autocomplete).
    func tags() throws -> [(name: String, count: Int)] {
        try db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT tag, COUNT(*) AS uses FROM referenceTag GROUP BY tag ORDER BY uses DESC, tag
                """).map { ($0["tag"], $0["uses"]) }
        }
    }

    /// References matching `query`. With search terms: hits in the title first, then by
    /// relevance, then newest. Without: newest first.
    func search(_ query: SearchQuery, limit: Int = 1000) throws -> [Reference] {
        var sql = "SELECT reference.* FROM reference"
        var conditions: [String] = []
        var arguments: [(any DatabaseValueConvertible)?] = []

        let pattern = query.ftsPattern
        if let pattern {
            sql += " JOIN referenceSearch ON referenceSearch.rowid = reference.rowid"
            conditions.append("referenceSearch MATCH ?")
            arguments.append(pattern)
        }
        if !query.types.isEmpty {
            conditions.append("reference.type IN (\(query.types.map { _ in "?" }.joined(separator: ", ")))")
            arguments += query.types.map(\.rawValue)
        }
        for tag in query.tags {
            conditions.append(
                "EXISTS (SELECT 1 FROM referenceTag WHERE referenceTag.referenceId = reference.id AND referenceTag.tag = ?)"
            )
            arguments.append(tag)
        }
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        if let pattern {
            // bm25 alone favors short entries; in a launcher a hit in the title should win.
            sql += " ORDER BY reference.rowid IN (SELECT rowid FROM referenceSearch WHERE referenceSearch MATCH ?) DESC,"
            sql += " bm25(referenceSearch, \(Self.searchWeights)), reference.created DESC"
            arguments.append("{title} : (\(pattern))")
        } else {
            sql += " ORDER BY reference.created DESC"
        }
        sql += " LIMIT ?"
        arguments.append(limit)

        let statementArguments = StatementArguments(arguments)
        return try db.read { db in
            try Row.fetchAll(db, sql: sql, arguments: statementArguments).compactMap(Self.reference(from:))
        }
    }

    // MARK: Enrichment

    /// Links still missing a title or thumbnail that haven't been fetched since `cutoff`, newest first.
    /// References tagged `excludingTag` (sample data) are left alone.
    func linksNeedingEnrichment(notAttemptedSince cutoff: Date, excludingTag: String, limit: Int = 50) throws -> [Reference] {
        try db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT reference.* FROM reference
                LEFT JOIN enrichment ON enrichment.referenceId = reference.id
                WHERE reference.type = 'link'
                  AND (reference.title IS NULL OR reference.thumbnail IS NULL)
                  AND (enrichment.attempted IS NULL OR enrichment.attempted < ?)
                  AND (' ' || reference.tags || ' ') NOT LIKE ?
                ORDER BY reference.created DESC
                LIMIT ?
                """, arguments: [cutoff.timeIntervalSince1970, "% \(excludingTag) %", limit]
            ).compactMap(Self.reference(from:))
        }
    }

    func markEnriched(id: String, at date: Date = Date()) throws {
        try db.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO enrichment (referenceId, attempted) VALUES (?, ?)",
                arguments: [id, date.timeIntervalSince1970]
            )
        }
    }

    // MARK: Text inside images

    /// Images whose text hasn't been read yet, newest first. Read images without text have "".
    func imagesNeedingText(limit: Int = 20) throws -> [Reference] {
        try db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT * FROM reference
                WHERE type = 'image' AND file IS NOT NULL AND fileText IS NULL
                ORDER BY created DESC
                LIMIT ?
                """, arguments: [limit]
            ).compactMap(Self.reference(from:))
        }
    }

    /// The text read from a reference's image or file; nil when there's none (or not yet).
    func fileText(id: String) throws -> String? {
        let text = try db.read { db in
            try String.fetchOne(db, sql: "SELECT fileText FROM reference WHERE id = ?", arguments: [id])
        }
        return text?.isEmpty == false ? text : nil
    }

    static func reference(from row: Row) -> Reference? {
        guard let type = ReferenceType(rawValue: row["type"]) else { return nil }
        let tags: String = row["tags"]
        var reference = Reference(
            id: row["id"],
            type: type,
            created: Date(timeIntervalSince1970: row["created"]),
            url: (row["url"] as String?).flatMap { URL(string: $0) },
            title: row["title"],
            site: row["site"],
            timestamp: row["timestamp"],
            file: row["file"],
            originalFilename: row["filename"],
            width: row["width"],
            height: row["height"],
            thumbnail: row["thumbnail"],
            tags: tags.split(separator: " ").map(String.init),
            note: row["note"],
            text: row["text"]
        )
        reference.markdownPath = row["path"]
        return reference
    }
}
