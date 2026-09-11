import CSQLite
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Replaced by the real store in Task 4. Exercises what the spec lists as unverified on WASI.
public enum CoreSmoke {
    public static func sqliteVersion() -> String { String(cString: sqlite3_libversion()) }

    /// Creates a trigram FTS5 table in memory and counts the rows matching a Cyrillic substring.
    public static func trigramMatches(_ needle: String) -> Int64 {
        var db: OpaquePointer?
        precondition(sqlite3_open(":memory:", &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        let ddl = "CREATE VIRTUAL TABLE t USING fts5(title, tokenize='trigram remove_diacritics 1');"
        precondition(sqlite3_exec(db, ddl, nil, nil, nil) == SQLITE_OK, String(cString: sqlite3_errmsg(db)))
        precondition(sqlite3_exec(db, "INSERT INTO t VALUES ('Квартальный отчёт'), ('Купить молоко');", nil, nil, nil) == SQLITE_OK)
        var stmt: OpaquePointer?
        precondition(sqlite3_prepare_v2(db, "SELECT count(*) FROM t WHERE t MATCH ?", -1, &stmt, nil) == SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        let quoted = "\"" + needle.replacing("\"", with: "\"\"") + "\""
        sqlite3_bind_text(stmt, 1, quoted, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        precondition(sqlite3_step(stmt) == SQLITE_ROW)
        return sqlite3_column_int64(stmt, 0)
    }

    /// Serializes a database to bytes and restores it into a second connection: the web persistence bridge.
    public static func snapshotSum() -> Int64 {
        var db: OpaquePointer?
        precondition(sqlite3_open(":memory:", &db) == SQLITE_OK)
        precondition(sqlite3_exec(db, "CREATE TABLE a(x); INSERT INTO a VALUES (1),(2),(3);", nil, nil, nil) == SQLITE_OK)
        var size: sqlite3_int64 = 0
        guard let bytes = sqlite3_serialize(db, "main", &size, 0) else { preconditionFailure("serialize") }
        let copy = [UInt8](UnsafeBufferPointer(start: bytes, count: Int(size)))
        sqlite3_free(bytes)
        sqlite3_close(db)

        var db2: OpaquePointer?
        precondition(sqlite3_open(":memory:", &db2) == SQLITE_OK)
        defer { sqlite3_close(db2) }
        let buffer = sqlite3_malloc64(sqlite3_uint64(copy.count))!
        copy.withUnsafeBytes { buffer.copyMemory(from: $0.baseAddress!, byteCount: copy.count) }
        let flags = UInt32(SQLITE_DESERIALIZE_FREEONCLOSE | SQLITE_DESERIALIZE_RESIZEABLE)
        let rc = sqlite3_deserialize(db2, "main", buffer.assumingMemoryBound(to: UInt8.self), sqlite3_int64(copy.count), sqlite3_int64(copy.count), flags)
        precondition(rc == SQLITE_OK, "deserialize rc=\(rc)")
        var stmt: OpaquePointer?
        precondition(sqlite3_prepare_v2(db2, "SELECT sum(x) FROM a", -1, &stmt, nil) == SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        precondition(sqlite3_step(stmt) == SQLITE_ROW)
        return sqlite3_column_int64(stmt, 0)
    }

    public static func freshUUID() -> String { UUID().uuidString }
    public static func nowMilliseconds() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}
