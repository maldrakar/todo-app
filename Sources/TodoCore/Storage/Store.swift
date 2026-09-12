// Sources/TodoCore/Storage/Store.swift
import SQLiteKit
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum StoreError: Error, Equatable, Sendable {
    case sqlite(SQLiteError)
    case notFound(EntityID)
    case viewNeedsNewerApp(ViewID, kind: String)
    case invalidFilter(String)
    case invalid(String)
}

/// Which entities a committed transaction touched. UI layers re-query the views they show.
public struct ChangeSet: Equatable, Sendable {
    public var tasks: Set<TaskID> = []
    public var tags: Set<TagID> = []
    public var views: Set<ViewID> = []

    public init() {}

    public var isEmpty: Bool { tasks.isEmpty && tags.isEmpty && views.isEmpty }

    mutating func merge(_ other: ChangeSet) {
        tasks.formUnion(other.tasks)
        tags.formUnion(other.tags)
        views.formUnion(other.views)
    }
}

/// The core's data layer. Synchronous, single-connection, not thread-safe: the platform confines it.
public final class Store {
    public let deviceID: String
    /// Called after every committed transaction that changed something.
    public var onChange: ((ChangeSet) -> Void)?

    let db: Connection
    let now: () -> Int64
    let clock: HybridClock

    /// Milliseconds since 1970-01-01 from the system clock. Under WasmKit this is a fake time; the platform passes a real one.
    public static func systemNow() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    /// How the core opens a database. `SQLiteKit` sets no pragmas of its own, so the policy lives here and
    /// travels with the store. On an in-memory database `journal_mode` is accepted and ignored, so one list
    /// serves the file and the web target alike.
    static let pragmas = ["foreign_keys = OFF", "journal_mode = WAL", "synchronous = NORMAL"]

    public static func open(path: String, now: @escaping () -> Int64) throws(StoreError) -> Store {
        let db: Connection
        do { db = try Connection.open(path: path, pragmas: pragmas) } catch { throw .sqlite(error) }
        return try Store(db: db, now: now)
    }

    public static func openInMemory(snapshot: [UInt8]? = nil, now: @escaping () -> Int64) throws(StoreError) -> Store {
        let db: Connection
        do {
            db = try Connection.openInMemory(pragmas: pragmas)
            if let snapshot { try db.deserialize(snapshot) }
        } catch { throw .sqlite(error) }
        return try Store(db: db, now: now)
    }

    init(db: Connection, now: @escaping () -> Int64) throws(StoreError) {
        self.db = db
        self.now = now
        self.clock = HybridClock(now: now)
        do { _ = try Migrations.run(on: db) } catch { throw .sqlite(error) }
        let stored = try Store.readMeta(db, "device_id").string
        if let stored {
            deviceID = stored
        } else {
            deviceID = EntityID().rawValue
            try Store.writeMeta(db, "device_id", .text(deviceID))
        }
        // The journal holds every stamp this device has issued or seen from another one. Without replaying its
        // maximum, a restart would let a local edit land behind a remote one and lose the last-write-wins
        // comparison in silence (#32). This runs before anything below issues a stamp.
        if let seen = try sql({ () throws(SQLiteError) in try db.rows("SELECT max(clock) FROM ops").first?.first?.int64 }) {
            clock.observe(HLC(raw: seen))
        }
        try seedBuiltInViews()
        try replayUnapplied()
        try rebuildTree()
    }

    /// The whole database as bytes, for the web page to persist.
    public func snapshot() throws(StoreError) -> [UInt8] {
        try sql { () throws(SQLiteError) in try db.serialize() }
    }

    public func schemaVersion() throws(StoreError) -> Int32 {
        try sql { () throws(SQLiteError) in try db.userVersion() }
    }

    // MARK: - Internal plumbing shared by the extensions

    /// Runs SQLiteKit calls and converts their error type.
    func sql<T>(_ body: () throws(SQLiteError) -> T) throws(StoreError) -> T {
        do { return try body() } catch { throw .sqlite(error) }
    }

    func meta(_ key: String) throws(StoreError) -> Value {
        try Store.readMeta(db, key)
    }

    func setMeta(_ key: String, _ value: Value) throws(StoreError) {
        try Store.writeMeta(db, key, value)
    }

    private static func readMeta(_ db: Connection, _ key: String) throws(StoreError) -> Value {
        do { return try db.rows("SELECT value FROM meta WHERE key = ?", [.text(key)]).first?.first ?? .null } catch { throw .sqlite(error) }
    }

    private static func writeMeta(_ db: Connection, _ key: String, _ value: Value) throws(StoreError) {
        do { try db.run("INSERT INTO meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value", [.text(key), value]) } catch { throw .sqlite(error) }
    }

    /// Filled in by Task 9: inserts Inbox, Today, Upcoming, Logbook and Trash with fixed ids and a zero clock.
    func seedBuiltInViews() throws(StoreError) {}

    /// Re-applies journal rows whose field became known after a migration. The body arrives in Task 5.
    func replayUnapplied() throws(StoreError) {
        try sql { () throws(SQLiteError) in
            try db.transaction { () throws(SQLiteError) in try replayUnappliedRows() }
        }
    }

    /// Recomputes task_tree. The body arrives in Task 6.
    func rebuildTree() throws(StoreError) {
        try sql { () throws(SQLiteError) in try rebuildTreeRows() }
    }

    /// Runs inside a transaction opened by the caller. Task 5 fills it in.
    func replayUnappliedRows() throws(SQLiteError) {}

    /// Runs inside a transaction opened by the caller. Task 6 fills it in.
    func rebuildTreeRows() throws(SQLiteError) {}
}
