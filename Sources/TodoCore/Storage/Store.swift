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
///
/// One store per database, and one database per device: two stores over one file hold two hybrid clocks and
/// two change callbacks over one journal, so an edit can lose a tie the other store never saw, and two
/// stores over two copies of one file are two devices and are opened with two ids (ADR-0005).
public final class Store {
    /// The identity this store stamps its operations with. It belongs to the installation and not to the
    /// database: a database can be copied, and the copy is another device (ADR-0005).
    public let deviceID: String

    /// Called after a transaction that changed something commits, with everything it touched. It lives in the
    /// class because an extension cannot add a stored property, and it is the core's only push towards the UI.
    public var onChange: ((ChangeSet) -> Void)?

    let db: Connection
    let clock: HybridClock

    /// The ids this database has written under, this store's own among them. What a push sends is the rows
    /// of every one of them, which is `SyncEngine`'s reason to read it.
    let ownDevices: Set<String>

    /// The device id on the journal rows of the built-in views. They are written by every device and are the
    /// same rows everywhere, so they carry no device's identity and no device ever pushes them.
    static let seedDevice = "seed"

    /// How the core opens a database. `SQLiteKit` sets no pragmas of its own, so the policy lives here and
    /// travels with the store. On an in-memory database `journal_mode` is accepted and ignored, so one list
    /// serves the file and the web target alike.
    private static let pragmas = ["foreign_keys = OFF", "journal_mode = WAL", "synchronous = NORMAL"]

    public static func open(path: String, device: String, now: @escaping () -> Int64) throws(StoreError) -> Store {
        let db: Connection
        do { db = try Connection.open(path: path, pragmas: pragmas) } catch { throw .sqlite(error) }
        return try Store(db: db, device: device, now: now)
    }

    /// An identity for a device that has none yet, for a platform with nowhere better to take one from. Where
    /// it is kept afterwards is the platform's: it has to outlive the database and not travel with it, since
    /// a restored copy that keeps the identity of the machine it came from is invisible to that machine
    /// (#51), and one that mints a new identity at every open never finishes pushing what it wrote.
    public static func newDeviceID() -> String { EntityID().rawValue }

    /// The wall clock in milliseconds since the epoch, for a caller that has no better one: the store is
    /// opened with the clock its caller chose (`docs/style.md`, "A lower layer holds no policy of its
    /// client"), and this is what a platform passes when its own clock is the machine's.
    ///
    /// It is the wall clock on every target this ships on, wasm among them: a browser has no WASI, and the
    /// JS host standing in for one answers the realtime clock out of the browser's own — `Date.now()`, in
    /// `@bjorn3/browser_wasi_shim`, which JavaScriptKit and carton build on — so a web entry point passes
    /// this like any other platform does, and an entry point that wires that one import to a stub instead
    /// is how the reading goes wrong there. FoundationEssentials reports nothing about such a host, because
    /// it is told a time and repeats it, so what this answers is only ever as true as the host's import. The
    /// test runner on wasm32 is such a host and tells the truth: WasmKit 0.3.1, in the 6.4 toolchains,
    /// answers the clock from the calendar, where the 0.1.6 in 6.3.3 answered it from the machine's last
    /// boot, days rather than decades after the epoch (#53), and a test in `StoreOpenTests` asserts a real
    /// wall-clock value on every target. A device that stamped its edits from a clock that far behind would
    /// lose every last-write-wins comparison in silence, which is why the fact is written here and not only
    /// in a test.
    public static func systemNow() -> Int64 { millis(since: Date().timeIntervalSince1970) }

    /// Seconds since the epoch as whole milliseconds. Separate from the clock it reads so that the
    /// saturation is a value a test can hand in: a machine set far enough ahead, or a clock that answers
    /// with nothing at all, is data from outside like any other.
    static func millis(since seconds: Double) -> Int64 {
        let millis = seconds * 1000
        guard millis > 0 else { return 0 }
        return millis < Double(Int64.max) ? Int64(millis) : Int64.max
    }

    public static func openInMemory(snapshot: [UInt8]? = nil, device: String, now: @escaping () -> Int64) throws(StoreError) -> Store {
        let db: Connection
        do {
            db = try Connection.openInMemory(pragmas: pragmas)
            if let snapshot { try db.deserialize(snapshot) }
        } catch { throw .sqlite(error) }
        return try Store(db: db, device: device, now: now)
    }

    init(db: Connection, device: String, now: @escaping () -> Int64) throws(StoreError) {
        // The identity arrives from outside like any other data, and the two values it may not take are worth
        // a refusal here rather than a fault much later: an empty id names no device, and `seed` is the core's
        // own, whose rows every device writes and none pushes, so a device stamping under it would push
        // nothing it wrote.
        guard !device.isEmpty else { throw .invalid("a device id cannot be empty") }
        guard device != Store.seedDevice else { throw .invalid("the device id \"\(Store.seedDevice)\" is the core's own") }
        self.db = db
        self.clock = HybridClock(now: now)
        self.deviceID = device
        do { _ = try Migrations.run(on: db) } catch { throw .sqlite(error) }
        try Store.writeOwnDevice(db, device)
        self.ownDevices = try Store.readOwnDevices(db)
        // The journal holds every stamp this device has issued or seen from another one. Without replaying its
        // maximum, a restart would let a local edit land behind a remote one and lose the last-write-wins
        // comparison in silence (#32). This runs before anything below issues a stamp.
        //
        // The scan used to bound itself away from the top of the encoding, because seeding from a row up there
        // pushed the clock to the one millisecond `next()` could not represent and trapped the process on the
        // very next stamp. `HybridClock` saturates inside its range instead (#34), so that rule lives in the
        // clock alone, where `Store.receive` meets it when a peer's stamp arrives, and the scan keeps only the
        // rule that is its own: `clock` is declared INTEGER, but SQLite takes a column's type as a preference,
        // and anything else stored there sorts above every number. Without `typeof` one such row would answer
        // `max`, fail to read back as a stamp, and turn the seed into no seed at all — #32 again, in silence.
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

    /// A lookup by a list of ids runs one statement per chunk: SQLite takes a bounded number of parameters in
    /// one statement, and the length of such a list is the caller's — a page of tasks, or a page of search
    /// hits. Both callers want the same chunk, so the size is a constant here rather than an argument. The
    /// vendored build allows 32,766 of them, and 500 sits far enough under any build's limit that the number
    /// is about keeping one statement small rather than about the ceiling.
    static func chunked(_ ids: [String]) -> [[String]] {
        let size = 500
        return stride(from: 0, to: ids.count, by: size).map { Array(ids[$0..<min($0 + size, ids.count)]) }
    }

    /// The `?, ?, ?` of an `IN` clause over one such chunk.
    static func placeholders(_ count: Int) -> String {
        Array(repeating: "?", count: count).joined(separator: ", ")
    }

    /// The `meta` pair the sync cursors read and write. It was a pair of `private static` twins behind these
    /// two lines while `init` read the device id before `deviceID` was assigned, which Swift forbids an
    /// instance call to do (review of PR #35); the id comes from the caller now, and the twins had one caller
    /// each left.
    func meta(_ key: String) throws(StoreError) -> Value {
        do { return try db.rows("SELECT value FROM meta WHERE key = ?", [.text(key)]).first?.first ?? .null } catch { throw .sqlite(error) }
    }

    func setMeta(_ key: String, _ value: Value) throws(StoreError) {
        do { try db.run("INSERT INTO meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value", [.text(key), value]) } catch { throw .sqlite(error) }
    }

    /// Adds this device to the ids the database has written under. Nothing to do on every open after the
    /// first one under this id, which is what `OR IGNORE` says.
    private static func writeOwnDevice(_ db: Connection, _ device: String) throws(StoreError) {
        do { try db.run("INSERT OR IGNORE INTO own_devices (id) VALUES (?)", [.text(device)]) } catch { throw .sqlite(error) }
    }

    /// The ids the database has written under. One on a database that has only ever been opened on one
    /// machine, and one more after a copy is opened under an identity of its own: what the predecessor wrote
    /// and never pushed is still in the journal under the old id, and the push has to keep sending it (#51).
    private static func readOwnDevices(_ db: Connection) throws(StoreError) -> Set<String> {
        do { return Set(try db.rows("SELECT id FROM own_devices").compactMap { $0.first?.string }) } catch { throw .sqlite(error) }
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
        var ops: [JournalOperation] = []
        var replayed: [Value] = []
        for row in try db.rows("SELECT \(JournalOperation.journalColumns) FROM ops WHERE applied = 0 ORDER BY clock, device, seq") {
            guard let op = JournalOperation(journalRow: row), FieldMap.isKnown(op.entity, op.field) else { continue }
            ops.append(op)
            replayed.append(row[0])
        }
        // The change set goes nowhere: the only caller is `Store.init`, where no observer can have been set
        // yet. A replay that ever runs mid-session has to hand it to `onChange` instead of dropping it. The
        // count of what the state refused goes nowhere for the same reason, and this is the second place one
        // can be refused — a peer's operation for a field the migration has just made known reaches the state
        // here for the first time. If the replay ever moves out of `init`, both numbers move with it.
        try applyRows(ops)
        for seq in replayed { try db.run("UPDATE ops SET applied = 1 WHERE seq = ?", [seq]) }
    }
}
