import Testing
@testable import TodoCore
@testable import SQLiteKit

private let day = Day(year: 2026, month: 9, day: 12)

/// Two stores and the relay between them. B's wall clock runs five seconds behind A's, which is the case the
/// merge rule exists for: on the wall clock alone every edit B makes loses, and it wins only through the
/// stamps it has observed from A.
private func pair() throws -> (a: Store, b: Store, relay: InMemoryRelay) {
    let relay = InMemoryRelay()
    let a = try makeStore(clock: TestClock(start: 1_757_500_000_000))
    let b = try makeStore(clock: TestClock(start: 1_757_500_000_000 - 5_000))
    return (a, b, relay)
}

/// Everything either store holds reaches the other. Two rounds, because what one pushes during a round is
/// still behind the other's pull cursor until the round after it.
private func exchange(_ a: Store, _ b: Store, _ relay: InMemoryRelay) throws {
    for _ in 0..<2 {
        try SyncEngine.sync(a, via: relay)
        try SyncEngine.sync(b, via: relay)
    }
}

/// An operation the way one arrives from another device.
private func foreign(_ entity: EntityKind, _ id: String, _ field: String, _ value: Value, _ millis: Int64) -> JournalOperation {
    JournalOperation(entity: entity, entityID: id, field: field, value: value, clock: HLC(millis: millis, counter: 0), device: "B")
}

/// Starts counting every row `apply` offers to the journal, the ones the unique index drops included: a
/// `BEFORE INSERT` trigger fires before the conflict is resolved, which is what makes the work visible where
/// the state shows nothing at all.
private func countJournalOffers(_ store: Store) throws {
    try store.sql { () throws(SQLiteError) in
        try store.db.run("CREATE TABLE offers (n INTEGER)")
        try store.db.run("CREATE TRIGGER count_offers BEFORE INSERT ON ops BEGIN INSERT INTO offers (n) VALUES (1); END")
    }
}

private func offers(_ store: Store) throws -> Int64 {
    try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM offers").first?.first?.int64 ?? -1 }
}

@Test func twoStoresConvergeAfterConcurrentEditsAndLaterEditsWin() throws {
    let (a, b, relay) = try pair()
    #expect(a.deviceID != b.deviceID)
    let id = try a.createTask(NewTask(title: "draft"))
    try exchange(a, b, relay)
    #expect(try b.task(id)?.title == "draft")

    try b.update(task: id, [.title("from B")])      // behind on the wall clock, ahead of nothing it has seen
    try a.update(task: id, [.when(day)])            // a different field, which the merge keeps
    try a.update(task: id, [.title("from A")])      // later than B's title
    try exchange(a, b, relay)
    let ta = try #require(try a.task(id))
    let tb = try #require(try b.task(id))
    #expect(ta == tb)
    #expect(ta.title == "from A")
    #expect(ta.when == day)

    // B's clock jumped past A's while receiving, so B's next edit outranks everything it has seen.
    try b.update(task: id, [.title("B after sync")])
    try exchange(a, b, relay)
    #expect(try a.task(id)?.title == "B after sync")
    #expect(try a.tasks(in: BuiltInTaskViews.today, today: day).map(\.id) == [id])
}

@Test func structureTagsViewsAndPinsPropagate() throws {
    let (a, b, relay) = try pair()
    let project = try a.createTask(NewTask(title: "Project"))
    let kid = try a.createTask(NewTask(title: "child", parent: project))
    let tag = try a.createTag(title: "work")
    try a.add(tag: tag, to: kid)
    let view = try a.createView(NewTaskView(title: "H"))
    try a.update(view: view, [.filter(.listedIn(view))])
    try a.pin(task: kid, in: view)
    try exchange(a, b, relay)
    #expect(try b.children(of: project).map(\.id) == [kid])
    #expect(try b.task(kid)?.tags == [tag])
    #expect(try b.tags().map(\.title) == ["work"])
    #expect(try b.tasks(in: view, today: day).map(\.id) == [kid])

    try b.trash(task: project)
    try a.delete(task: kid)
    try exchange(a, b, relay)
    #expect(try a.task(project)?.trashed == true)
    #expect(try b.task(kid) == nil)
}

@Test func receiveChangesNothingForAnOperationTheStoreAlreadyHolds() throws {
    let (a, _, _) = try pair()
    let id = try a.createTask(NewTask(title: "mine"))
    let own = try a.journal(after: 0).filter { $0.device == a.deviceID }
    var calls = 0
    a.onChange = { _ in calls += 1 }
    // Our own operation coming back and a peer's duplicate are the same thing to the state: the unique index
    // drops the row and the field clock drops the value, so either way the store ends where it was. Both are
    // offered, and that is the price of not reading a device id as a claim about what the journal holds —
    // the store that lost its database is the one that needs its own rows offered back to it.
    try countJournalOffers(a)
    #expect(try a.receive(own).changes.isEmpty)
    #expect(try offers(a) == Int64(own.count), "what this device wrote is offered to the journal, and the index refuses it")
    #expect(calls == 0)

    let mine = try #require(own.first { $0.field == "title" })
    let theirs = foreign(.task, mine.entityID, "title", .text("theirs"), mine.clock.millis + 10)
    #expect(try a.receive([theirs]).changes.tasks == [id])
    #expect(try a.receive([theirs]).changes.isEmpty, "a duplicate is dropped by the journal index and the field clock")
    #expect(try offers(a) == Int64(own.count) + 2, "a peer's operation is offered to the journal every time it arrives")
    #expect(try a.task(id)?.title == "theirs")
}

@Test func journalExportIsOrderedAndCursorsPersist() throws {
    let (a, _, relay) = try pair()
    _ = try a.createTask(NewTask(title: "one"))
    let ops = try a.journal(after: 0)
    #expect(ops.contains { $0.device == "seed" }, "seed rows are in the journal and are never pushed")
    // `after` is exclusive and a page is the operations that follow it, which is what the push walks by. The
    // sequence number is not on an operation, so the test reads it where it lives.
    let seqs = try a.sql { () throws(SQLiteError) in try a.db.rows("SELECT seq FROM ops ORDER BY seq").compactMap { $0[0].int64 } }
    #expect(try a.journal(after: seqs[0], limit: 2) == Array(ops[1...2]))
    try SyncEngine.sync(a, via: relay)
    #expect(relay.log.allSatisfy { $0.device == a.deviceID })
    let cursors = try a.syncCursors()
    #expect(cursors.pushed == seqs.last)
    #expect(cursors.pulled == Int64(relay.log.count))
    try SyncEngine.sync(a, via: relay)
    #expect(relay.log.count == 10, "ten fields of one task, pushed once")
}

@Test func cursorsSurviveAReopenAndNothingIsPushedTwice() throws {
    let (a, _, relay) = try pair()
    _ = try a.createTask(NewTask(title: "one"))
    try SyncEngine.sync(a, via: relay)
    let before = try a.syncCursors()
    let again = try Store.openInMemory(snapshot: try a.snapshot(), device: a.deviceID, now: TestClock().now)
    #expect(try again.syncCursors() == before)
    try SyncEngine.sync(again, via: relay)
    #expect(relay.log.count == 10, "the store that reopened pushes nothing it had pushed before")
}

@Test func receiveCountsTheOperationsTheStateCouldNotTake() throws {
    let (a, _, _) = try pair()
    let id = try a.createTask(NewTask(title: "kept"))
    // A null for a NOT NULL column and a pair id that does not split, delivered with a well-formed operation
    // the way one pull delivers a peer's batch: the good one must survive both.
    let report = try a.receive([
        foreign(.task, id.rawValue, "title", .null, 1_757_500_100_000),
        foreign(.taskTag, "no-slash", "present", .integer(1), 1_757_500_100_000),
        foreign(.task, id.rawValue, "notes", .text("theirs"), 1_757_500_100_000),
    ])
    #expect(report.refused == 2)
    #expect(report.changes.tasks == [id])
    #expect(try a.task(id)?.title == "kept")
    #expect(try a.notes(of: id) == "theirs")
}

@Test func receiveDoesNotCountAFieldThisVersionDoesNotKnow() throws {
    let (a, _, _) = try pair()
    let id = try a.createTask(NewTask(title: "kept"))
    let report = try a.receive([foreign(.task, id.rawValue, "priority", .integer(1), 1_757_500_100_000)])
    #expect(report.refused == 0, "the field waits in the journal for the migration that adds it, and is not lost")
    #expect(report.changes.isEmpty)
    let unapplied = try a.sql { () throws(SQLiteError) in try a.db.rows("SELECT count(*) FROM ops WHERE applied = 0") }
    #expect(unapplied == [[.integer(1)]])
}

@Test func aJournalPageOfZeroRowsOrFewerAsksForNoRoom() throws {
    let (a, _, _) = try pair()
    _ = try a.createTask(NewTask(title: "one"))
    #expect(try a.journal(after: 0, limit: 0).isEmpty)
    #expect(try a.journal(after: 0, limit: -1).isEmpty, "SQLite reads a negative LIMIT as no limit at all")
}

@Test func aPageOfRowsThisVersionCannotDecodeDoesNotStopThePush() throws {
    let (a, _, relay) = try pair()
    try SyncEngine.sync(a, via: relay)
    let pushedBefore = relay.log.count
    // A newer app wrote a whole page of its own entity kind into the same file. This version steps over
    // those rows, and the push has to step over them too: a cursor that stops at a dead window stops sync
    // for good, in silence, and every later edit of this device stays on it.
    try a.sql { () throws(SQLiteError) in
        try a.db.transaction { () throws(SQLiteError) in
            for i in 0..<1_000 {
                try a.db.run(
                    "INSERT INTO ops (entity, entity_id, field, value, clock, device, applied) VALUES ('reminder', ?, 'title', 'x', ?, 'B', 1)",
                    [.text("r\(i)"), .integer(Int64(i))]
                )
            }
        }
    }
    _ = try a.createTask(NewTask(title: "after the dead window"))
    try SyncEngine.sync(a, via: relay)
    #expect(relay.log.count == pushedBefore + 10)
}

/// A transport that takes a push and then fails the pull of the same round, the way a server up for one and
/// down for the other does.
private final class PullFailsOnce: SyncTransport {
    let relay = InMemoryRelay()
    private var failed = false

    func push(_ ops: [JournalOperation]) throws(SyncError) {
        try relay.push(ops)
    }

    func pull(after cursor: Int64) throws(SyncError) -> (ops: [JournalOperation], cursor: Int64) {
        if failed { return try relay.pull(after: cursor) }
        failed = true
        throw .transport("the relay is down")
    }
}

@Test func aRoundThatFailsAfterThePushDoesNotPushItAgain() throws {
    let a = try makeStore()
    _ = try a.createTask(NewTask(title: "one"))
    let transport = PullFailsOnce()
    #expect(throws: SyncError.transport("the relay is down")) { try SyncEngine.sync(a, via: transport) }
    #expect(transport.relay.log.count == 10, "the push itself went through")
    try SyncEngine.sync(a, via: transport)
    #expect(transport.relay.log.count == 10, "a page the transport already took is not offered a second time")
}

@Test func aCursorTheRelayCannotIndexIsPulledIntoItsLog() throws {
    let relay = InMemoryRelay()
    let op = JournalOperation(entity: .task, entityID: "t1", field: "title", value: .text("x"), clock: HLC(millis: 1, counter: 0), device: "B")
    try relay.push([op, op, op])
    #expect(try relay.pull(after: 99).ops.isEmpty, "a cursor past the end of the log asks for what is not there")
    #expect(try relay.pull(after: 99).cursor == 3)
    #expect(try relay.pull(after: -5).ops.count == 3, "a cursor below the log reads it whole")
}

@Test func theEngineCarriesTheRefusalCountOutOfTheStore() throws {
    let a = try makeStore()
    let id = try a.createTask(NewTask(title: "kept"))
    let relay = InMemoryRelay()
    try SyncEngine.sync(a, via: relay)
    try relay.push([foreign(.task, id.rawValue, "title", .null, 1_757_500_100_000)])
    #expect(try SyncEngine.sync(a, via: relay).refused == 1)
}

@Test func aJournalRowWithFewerColumnsThanTheJournalHasIsNotAnOperation() throws {
    #expect(JournalOperation(journalRow: []) == nil)
    #expect(JournalOperation(journalRow: [.integer(1), .text("task")]) == nil)
}

@Test func anOperationThatNamesNoEntityIsRefused() throws {
    let a = try makeStore()
    let report = try a.receive([foreign(.task, "", "title", .text("ghost"), 1_757_500_100_000)])
    #expect(report.refused == 1)
    #expect(report.changes.isEmpty)
    #expect(try a.allTasks().isEmpty, "a row whose id no read can name is not a task anyone created")
}

@Test func twoStoresFromOneSnapshotAreTwoDevices() throws {
    let relay = InMemoryRelay()
    let origin = try makeStore()
    let id = try origin.createTask(NewTask(title: "shared"))
    let snapshot = try origin.snapshot()
    // One database on two machines, which is what a restored backup and the web target's snapshot both make.
    // Each opens under an identity of its own, because the bytes cannot tell a copy from the original (#51).
    let a = try Store.openInMemory(snapshot: snapshot, device: Store.newDeviceID(), now: TestClock().now)
    let b = try Store.openInMemory(snapshot: snapshot, device: Store.newDeviceID(), now: TestClock(start: 1_757_500_100_000).now)

    try a.update(task: id, [.title("from A")])
    try b.update(task: id, [.notes("from B")])
    try exchange(a, b, relay)
    #expect(try a.notes(of: id) == "from B")
    #expect(try b.task(id)?.title == "from A")
}

@Test func aStoreThatChangedItsIDStillPushesWhatItWroteBefore() throws {
    let relay = InMemoryRelay()
    let origin = try makeStore()
    _ = try origin.createTask(NewTask(title: "written before the copy"))
    // Copied before what it holds ever reached a transport: those operations are in the journal under the
    // old id, and a push that sent only the current one would leave them on this machine forever.
    let restored = try Store.openInMemory(snapshot: try origin.snapshot(), device: Store.newDeviceID(), now: TestClock().now)
    try SyncEngine.sync(restored, via: relay)
    #expect(relay.log.count == 10, "ten fields of one task, written under the id this database used to have")
    #expect(relay.log.allSatisfy { $0.device == origin.deviceID })
}

@Test func anEditFromTheDeviceWeWereCopiedFromIsNotTakenForOurOwn() throws {
    let origin = try makeStore()
    let id = try origin.createTask(NewTask(title: "shared"))
    let restored = try Store.openInMemory(snapshot: try origin.snapshot(), device: Store.newDeviceID(), now: TestClock(start: 1_757_500_100_000).now)
    #expect(restored.ownDevices == [origin.deviceID, restored.deviceID])
    // The machine the copy came from goes on writing under the id the copy inherited. What arrives under an
    // inherited id is another device's work, and dropping it as our own is #51 one turn later.
    try origin.update(task: id, [.title("from the original")])
    let ops = try origin.journal(after: 0).filter { $0.device == origin.deviceID }
    #expect(try restored.receive(ops).changes.tasks == [id])
    #expect(try restored.task(id)?.title == "from the original")
}

@Test func aDeviceThatLostItsDatabaseTakesItsOwnOperationsBack() throws {
    let relay = InMemoryRelay()
    let device = Store.newDeviceID()
    let origin = try makeStore(device: device)
    let id = try origin.createTask(NewTask(title: "Pay rent"))
    try SyncEngine.sync(origin, via: relay)
    // The identity outlives the database now (ADR-0005), so it can outlive the data too: a deleted file
    // beside a kept `.device`, or a web page whose IndexedDB was cleared while `localStorage` was not. What
    // this device wrote is on the peer and comes back under this device's own id, and dropping it as ours
    // would lose every row it ever wrote, with nothing to show for it.
    let replacement = try makeStore(device: device, clock: TestClock(start: 1_757_500_100_000))
    try SyncEngine.sync(replacement, via: relay)
    #expect(try replacement.task(id)?.title == "Pay rent")
}
