// Sources/TodoCore/Storage/Store.swift
import SQLiteKit

public enum StoreError: Error, Equatable, Sendable {
    case sqlite(SQLiteError)
    case notFound(EntityID)
    case viewNeedsNewerApp(ViewID, kind: String)
    case invalidFilter(String)
    case invalid(String)
}

/// Which entities a committed transaction touched. UI layers re-query the views they show.
///
/// It names the entities the operations addressed, not every row that moved. Trashing or re-parenting a task
/// rewrites the effective parent and inherited trash of everything below it in `task_tree`, and those
/// descendants are not in `tasks`: a consumer that redraws a single task from this set alone leaves a stale
/// child on screen, while redrawing the view the task belongs to is what the set is sized for.
public struct ChangeSet: Equatable, Sendable {
    public internal(set) var tasks: Set<TaskID> = []
    public internal(set) var tags: Set<TagID> = []
    public internal(set) var views: Set<ViewID> = []

    init() {}

    public var isEmpty: Bool { tasks.isEmpty && tags.isEmpty && views.isEmpty }
}

/// The core's data layer. Synchronous, single-connection, not thread-safe: the platform confines it.
public final class Store {
    public let deviceID: String

    /// Called after a transaction that changed something commits, with everything it touched. It lives in the
    /// class because an extension cannot add a stored property, and it is the core's only push towards the UI.
    public var onChange: ((ChangeSet) -> Void)?

    let db: Connection
    let clock: HybridClock

    /// The `meta` row that holds this device's identity in the journal.
    private static let deviceIDKey = "device_id"

    /// How the core opens a database. `SQLiteKit` sets no pragmas of its own, so the policy lives here and
    /// travels with the store. On an in-memory database `journal_mode` is accepted and ignored, so one list
    /// serves the file and the web target alike.
    private static let pragmas = ["foreign_keys = OFF", "journal_mode = WAL", "synchronous = NORMAL"]

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
        self.clock = HybridClock(now: now)
        do { _ = try Migrations.run(on: db) } catch { throw .sqlite(error) }
        if let stored = try Store.readMeta(db, Store.deviceIDKey).string {
            deviceID = stored
        } else {
            // The identity is this device's only claim in the journal, so nothing keeps it until the row is in
            // the database: a write that fails takes the whole open with it rather than leave a store whose id
            // no reopen would agree with.
            let minted = EntityID().rawValue
            try Store.writeMeta(db, Store.deviceIDKey, .text(minted))
            deviceID = minted
        }
        // The journal holds every stamp this device has issued or seen from another one. Without replaying its
        // maximum, a restart would let a local edit land behind a remote one and lose the last-write-wins
        // comparison in silence (#32). This runs before anything below issues a stamp.
        //
        // The scan used to bound itself away from the top of the encoding, because seeding from a row up there
        // pushed the clock to the one millisecond `next()` could not represent and trapped the process on the
        // very next stamp. `HybridClock` saturates inside its range instead (#34), so that rule lives in the
        // clock alone, where `Store.receive` will meet it in Task 11, and the scan keeps only the rule that is
        // its own: `clock` is declared INTEGER, but SQLite takes a column's type as a preference, and anything
        // else stored there sorts above every number. Without `typeof` a single such row would answer `max`,
        // fail to read back as a stamp, and turn the seed into no seed at all — #32 again, without a sound.
        if let seen = try sql({ () throws(SQLiteError) in
            try db.rows("SELECT max(clock) FROM ops WHERE typeof(clock) = 'integer'").first?.first?.int64
        }) {
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

    /// Re-applies journal rows whose field became known after a migration.
    func replayUnapplied() throws(StoreError) {
        try sql { () throws(SQLiteError) in
            try db.transaction { () throws(SQLiteError) in try replayUnappliedRows() }
        }
    }

    /// Recomputes task_tree from the state, which is what an open costs and what a migration needs: the rows
    /// `apply` keeps in step are only as good as the rules that were compiled in when it wrote them.
    func rebuildTree() throws(StoreError) {
        try sql { () throws(SQLiteError) in
            try db.transaction { () throws(SQLiteError) in try rebuildTreeRows() }
        }
    }

    /// Runs inside a transaction opened by the caller: hands the journal rows whose field is known now to the
    /// same path a fresh operation takes, and marks them applied. Calling `apply` itself is not an option — it
    /// opens a transaction of its own, and SQLite has no nested one — so what it shares is `applyRows`.
    func replayUnappliedRows() throws(SQLiteError) {
        var ops: [Operation] = []
        var replayed: [Value] = []
        for row in try db.rows("SELECT seq, entity, entity_id, field, value, clock, device FROM ops WHERE applied = 0 ORDER BY clock, device, seq") {
            guard let kind = EntityKind(rawValue: row[1].string ?? ""), let field = row[3].string, FieldMap.isKnown(kind, field) else { continue }
            ops.append(Operation(entity: kind, entityID: row[2].string ?? "", field: field, value: row[4], clock: HLC(raw: row[5].int64 ?? 0), device: row[6].string ?? ""))
            replayed.append(row[0])
        }
        // The change set goes nowhere: the only caller is `Store.init`, where no observer can have been set
        // yet. A replay that ever runs mid-session has to hand it to `onChange` instead of dropping it.
        try applyRows(ops)
        for seq in replayed { try db.run("UPDATE ops SET applied = 1 WHERE seq = ?", [seq]) }
    }
}
