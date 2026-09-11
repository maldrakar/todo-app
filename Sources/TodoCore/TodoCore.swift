import SQLiteKit
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Replaced by the real store in Task 4. Exercises what the spec lists as unverified on WASI.
public enum CoreSmoke {
    public static func sqliteVersion() throws(SQLiteError) -> String {
        let db = try Connection.openInMemory()
        return try db.rows("SELECT sqlite_version()").first?.first?.string ?? ""
    }

    /// Creates a trigram FTS5 table in memory and counts the rows matching a Cyrillic substring.
    public static func trigramMatches(_ needle: String) throws(SQLiteError) -> Int64 {
        let db = try Connection.openInMemory()
        try db.execute("CREATE VIRTUAL TABLE t USING fts5(title, tokenize='trigram remove_diacritics 1');")
        try db.execute("INSERT INTO t VALUES ('Квартальный отчёт'), ('Купить молоко');")
        let quoted = "\"" + needle.replacing("\"", with: "\"\"") + "\""
        return try db.rows("SELECT count(*) FROM t WHERE t MATCH ?", [.text(quoted)]).first?.first?.int64 ?? -1
    }

    /// Serializes a database to bytes and restores it into a second connection: the web persistence bridge.
    public static func snapshotSum() throws(SQLiteError) -> Int64 {
        let source = try Connection.openInMemory()
        try source.execute("CREATE TABLE a(x); INSERT INTO a VALUES (1),(2),(3);")
        let bytes = try source.serialize()

        let restored = try Connection.openInMemory()
        try restored.deserialize(bytes)
        return try restored.rows("SELECT sum(x) FROM a").first?.first?.int64 ?? -1
    }

    public static func freshUUID() -> String { UUID().uuidString }
    public static func nowMilliseconds() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}
