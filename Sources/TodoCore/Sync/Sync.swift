// Sources/TodoCore/Sync/Sync.swift
import SQLiteKit

/// What a delivery of operations did to the store.
///
/// `refused` counts the operations the journal kept and the state could not take: a value a column cannot
/// hold, an id that is not a pair. Nothing is lost — the journal holds them and a later well-formed
/// operation for the same field still wins — but without the number nobody above the store ever hears that a
/// peer sent data this version had to drop. A field this version does not know is not refused: it waits in
/// the journal with `applied = 0` and reaches the state after the migration that adds the column.
///
/// The number is this delivery's and not a total: an operation the state refuses stays in the journal, and a
/// transport that delivers it again is answered with the same count again.
public struct SyncReport: Equatable, Sendable {
    public internal(set) var changes = ChangeSet()
    public internal(set) var refused = 0

    init() {}
}

public enum SyncError: Error, Equatable, Sendable {
    case store(StoreError)
    case transport(String)
}

/// Moves journal rows between devices. Two actions, as the spec says, and everything else is the store's.
public protocol SyncTransport: AnyObject {
    func push(_ ops: [JournalOperation]) throws(SyncError)
    func pull(after cursor: Int64) throws(SyncError) -> (ops: [JournalOperation], cursor: Int64)
}

/// A relay in memory: every device's pushes in arrival order, and the cursor into it is a position in that
/// order. The only transport in M1, and the one the convergence tests exchange through.
public final class InMemoryRelay: SyncTransport {
    public private(set) var log: [JournalOperation] = []

    public init() {}

    public func push(_ ops: [JournalOperation]) throws(SyncError) {
        log += ops
    }

    /// A cursor from a device that has been away, or from one that never pulled, is a number this relay's log
    /// may no longer cover in either direction, so it is pulled into the log rather than trusted as an index.
    public func pull(after cursor: Int64) throws(SyncError) -> (ops: [JournalOperation], cursor: Int64) {
        let start = Int(min(max(cursor, 0), Int64(log.count)))
        return (Array(log[start...]), Int64(log.count))
    }
}

extension Store {
    /// The `meta` rows that remember where sync stopped. Both are cursors and neither is the other's: the
    /// pushed one is a local sequence number, the pulled one belongs to the transport.
    private static let pushedSeqKey = "sync.pushed_seq"
    private static let pullCursorKey = "sync.pull_cursor"

    /// The journal after a local sequence number, oldest first, this device's operations and other devices'
    /// alike. An operation does not carry that number: it is this store's own counting and means nothing on
    /// another device, so walking the journal is `SyncEngine`'s business and what a caller reads here is the
    /// operations themselves.
    ///
    /// A page of no operations is the answer to a limit of zero or less, the rule the two searches already
    /// follow: SQLite reads a negative LIMIT as no limit at all, and a caller that asked for no room must not
    /// be handed the whole journal instead.
    public func journal(after seq: Int64, limit: Int = 1_000) throws(StoreError) -> [JournalOperation] {
        try journalPage(after: seq, limit: limit).ops
    }

    /// One page of the journal and the sequence number the scan reached, which is not the last operation's.
    ///
    /// A row naming an entity kind this version does not know is left out of `ops` and still moves `scanned`,
    /// and the difference is what the walk has to advance by: advancing by the last operation stops at the
    /// first page that decodes to nothing and never passes it, so a device that a newer app left such a page
    /// in would stop pushing its own later edits for the life of the file.
    func journalPage(after seq: Int64, limit: Int) throws(StoreError) -> (ops: [JournalOperation], scanned: Int64?) {
        guard limit > 0 else { return ([], nil) }
        return try sql { () throws(SQLiteError) in
            let rows = try db.rows("SELECT \(JournalOperation.journalColumns) FROM ops WHERE seq > ? ORDER BY seq LIMIT ?", [.integer(seq), .integer(Int64(limit))])
            return (rows.compactMap(JournalOperation.init(journalRow:)), rows.last?[0].int64)
        }
    }

    /// Takes operations from other devices through the same path a local edit takes, after this device's
    /// clock has observed their stamps: the next local edit then sorts after everything the peer sent, which
    /// is what makes an edit made in answer to what arrived win over it.
    ///
    /// Nothing is dropped here for carrying this device's own id, and the id is no longer read as a claim
    /// about what the journal holds. Operations that came back from a transport used to be, to save the
    /// journal statement and the field-clock read that an echo of a push costs — a transport hands back what
    /// it was given, and a server that echoes does the same — but the identity outlives the database it was
    /// opened on (ADR-0005), and the two come apart exactly where a device needs its journal most. A database
    /// lost while its identity was kept — a deleted file beside a kept `.device`, a page whose IndexedDB was
    /// cleared while `localStorage` was not — opens empty under the same id, and everything that device ever
    /// wrote comes back from the peer under it: dropping that is a device that never sees its own history
    /// again, and nothing anywhere says so. Against that, an operation the store already holds costs one
    /// `INSERT OR IGNORE` the unique index refuses and one field clock that refuses the value, and moves
    /// nothing. The same reasoning covers an id the database inherited from the machine a copy was taken
    /// from, which that machine goes on writing under (#51).
    @discardableResult
    public func receive(_ ops: [JournalOperation]) throws(StoreError) -> SyncReport {
        for op in ops { clock.observe(op.clock) }
        return try applyBatch(ops)
    }

    /// Where the last sync stopped. Zero from a store that has never synced, which is the cursor that pushes
    /// the whole journal and pulls the whole log.
    func syncCursors() throws(StoreError) -> (pushed: Int64, pulled: Int64) {
        (try meta(Store.pushedSeqKey).int64 ?? 0, try meta(Store.pullCursorKey).int64 ?? 0)
    }

    /// Written after the operations they account for are committed, so a crash between the two costs a second
    /// delivery of what the journal index and the field clocks drop anyway, never a lost operation.
    func setSyncCursors(pushed: Int64, pulled: Int64) throws(StoreError) {
        try setMeta(Store.pushedSeqKey, .integer(pushed))
        try setMeta(Store.pullCursorKey, .integer(pulled))
    }
}

public enum SyncEngine {
    /// How many journal rows one push reads at a time. It is the engine's policy and not the store's, which
    /// is why it is here and why `Store.journalPage` takes it as an argument.
    private static let pageSize = 1_000

    /// One round of sync: push the rows this device wrote that the transport has not seen, then pull what the
    /// other devices pushed and hand it to the store.
    ///
    /// The pushed cursor is a local sequence number and the pulled one belongs to the transport; both live in
    /// `meta`, so a restart resumes where the last round stopped.
    ///
    /// What the filter sends is the rows of every id this database has written under and not only the current
    /// one: a copy opens under an identity of its own (ADR-0005) and still holds what its predecessor never
    /// managed to push, and those edits reach nobody otherwise. What another device wrote stays where it
    /// arrived, its id being outside the set — with one exception, the id a copy inherited, under which the
    /// machine it was taken from goes on writing: those rows arrive here and are pushed a second time, which
    /// is #57 and costs a delivery the unique index drops where it lands.
    ///
    /// The pushed cursor is written as each page is taken rather than once at the end, because the pull that
    /// follows can fail after the transport already has the page: saving it costs a re-push the peers would
    /// drop anyway when the round is rolled back, while saving it late costs the whole journal again on every
    /// retry of a transport that is up for a push and down for a pull.
    @discardableResult
    public static func sync(_ store: Store, via transport: some SyncTransport) throws(SyncError) -> SyncReport {
        do {
            let cursors = try store.syncCursors()
            var pushed = cursors.pushed
            while true {
                let page = try store.journalPage(after: pushed, limit: pageSize)
                guard let scanned = page.scanned else { break }
                let own = page.ops.filter { store.ownDevices.contains($0.device) }
                if !own.isEmpty { try transport.push(own) }
                pushed = scanned
                try store.setSyncCursors(pushed: pushed, pulled: cursors.pulled)
            }
            let pulled = try transport.pull(after: cursors.pulled)
            let report = try store.receive(pulled.ops)
            try store.setSyncCursors(pushed: pushed, pulled: pulled.cursor)
            return report
        } catch let error as StoreError {
            throw .store(error)
        } catch let error as SyncError {
            throw error
        } catch {
            // Unreachable: the two clauses above name every type this body throws. A `do` block over calls
            // that throw two different typed errors has `any Error` as its own, and that is what the
            // exhaustiveness of the catch is judged against, so the clause is the language's and not a case.
            throw .transport(String(describing: error))
        }
    }
}
