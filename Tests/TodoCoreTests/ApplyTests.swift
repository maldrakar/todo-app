import Testing
@testable import TodoCore
@testable import SQLiteKit

/// An operation from another device, the way one arrives from sync.
private func foreign(_ device: String, _ field: String, _ value: Value, _ clock: HLC, task id: String = "t1") -> Operation {
    Operation(entity: .task, entityID: id, field: field, value: value, clock: clock, device: device)
}

private func titleAndCreated(_ store: Store, _ id: String) throws(StoreError) -> (String, Int64)? {
    try store.sql { () throws(SQLiteError) in
        try store.db.rows("SELECT title, created_at FROM tasks WHERE id = ?", [.text(id)]).first.map { ($0[0].string ?? "", $0[1].int64 ?? -1) }
    }
}

@Test func applyingCreateOperationsInsertsARowAndReportsTheChange() throws {
    let store = try makeStore()
    var reported: [ChangeSet] = []
    store.onChange = { reported.append($0) }
    let stamp = HLC(millis: 1_000, counter: 0)
    let ops = [
        store.op(.task, "t1", "title", .text("Buy milk"), stamp),
        store.op(.task, "t1", "created_at", .integer(1_000), stamp),
    ]
    let changes = try store.apply(ops)
    #expect(changes.tasks == [TaskID("t1")])
    #expect(reported == [changes])
    let row = try titleAndCreated(store, "t1")
    #expect(row?.0 == "Buy milk" && row?.1 == 1_000)
    let journal = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM ops WHERE device != 'seed'") }
    #expect(journal == [[.integer(2)]])
}

@Test func anOlderClockLosesButStaysInTheJournal() throws {
    let store = try makeStore()
    try store.apply([store.op(.task, "t1", "title", .text("newer"), HLC(millis: 2_000, counter: 0))])
    let changes = try store.apply([store.op(.task, "t1", "title", .text("older"), HLC(millis: 1_000, counter: 0))])
    #expect(changes.isEmpty)
    #expect(try titleAndCreated(store, "t1")?.0 == "newer")
    // `applied` records that this version of the app knew the field, not that the operation reached the state:
    // the loser was considered and is never replayed.
    let journal = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT value, applied FROM ops WHERE device != 'seed' ORDER BY clock") }
    #expect(journal == [[.text("older"), .integer(1)], [.text("newer"), .integer(1)]])
}

@Test func differentFieldsFromDifferentDevicesBothSurvive() throws {
    let store = try makeStore()
    let a = foreign("A", "title", .text("from A"), HLC(millis: 5_000, counter: 0))
    let b = foreign("B", "when_day", .integer(20_707), HLC(millis: 1_000, counter: 0))
    try store.apply([a, b])
    let row = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT title, when_day FROM tasks WHERE id = 't1'") }
    #expect(row == [[.text("from A"), .integer(20_707)]])
}

@Test func equalClocksAreBrokenByDeviceIDInAnyOrder() throws {
    let stamp = HLC(millis: 1_000, counter: 0)
    for order in [["A", "B"], ["B", "A"]] {
        let store = try makeStore()
        for device in order {
            try store.apply([foreign(device, "title", .text("from \(device)"), stamp)])
        }
        #expect(try titleAndCreated(store, "t1")?.0 == "from B")
    }
}

@Test func unknownFieldsAreJournaledUnappliedAndReplayedWhenKnown() throws {
    let store = try makeStore()
    let changes = try store.apply([store.op(.task, "t1", "reminder_minutes", .integer(540), HLC(millis: 1_000, counter: 0))])
    #expect(changes.isEmpty)
    let unapplied = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT field, applied FROM ops WHERE device != 'seed'") }
    #expect(unapplied == [[.text("reminder_minutes"), .integer(0)]])
    #expect(try titleAndCreated(store, "t1") == nil)

    // Simulate a migration that made a field known: rewrite the journal row to a known field and replay.
    try store.sql { () throws(SQLiteError) in try store.db.run("UPDATE ops SET field = 'title', value = 'replayed' WHERE device != 'seed'") }
    try store.replayUnapplied()
    #expect(try titleAndCreated(store, "t1")?.0 == "replayed")
    let applied = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT applied FROM ops WHERE device != 'seed'") }
    #expect(applied == [[.integer(1)]])
}

@Test func theSameOperationTwiceIsJournaledOnce() throws {
    let store = try makeStore()
    let op = store.op(.task, "t1", "title", .text("x"), HLC(millis: 1_000, counter: 0))
    try store.apply([op])
    var reported = 0
    store.onChange = { _ in reported += 1 }
    // The second delivery is not a change: sync leans on that to tell a new operation from one it has seen.
    #expect(try store.apply([op]).isEmpty)
    #expect(reported == 0)
    let count = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM ops WHERE device != 'seed'") }
    #expect(count == [[.integer(1)]])
}

@Test func pairEntitiesUpsertTheirRows() throws {
    let store = try makeStore()
    let pair = Operation.pairID(TaskID("t1"), TagID("g1"))
    try store.apply([store.op(.taskTag, pair, "present", .integer(1), HLC(millis: 1_000, counter: 0))])
    var rows = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT task_id, tag_id, present FROM task_tags") }
    #expect(rows == [[.text("t1"), .text("g1"), .integer(1)]])
    let changes = try store.apply([store.op(.taskTag, pair, "present", .integer(0), HLC(millis: 1_001, counter: 0))])
    #expect(changes.tasks == [TaskID("t1")])
    rows = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT present FROM task_tags") }
    #expect(rows == [[.integer(0)]])
}

@Test func observerIsNotCalledWhenNothingChanged() throws {
    let store = try makeStore()
    try store.apply([store.op(.task, "t1", "title", .text("x"), HLC(millis: 2_000, counter: 0))])
    var calls = 0
    store.onChange = { _ in calls += 1 }
    try store.apply([store.op(.task, "t1", "title", .text("y"), HLC(millis: 1_000, counter: 0))])
    try store.apply([])
    #expect(calls == 0)
}

@Test func aViewItemUpsertsItsRowAndReportsBothSides() throws {
    let store = try makeStore()
    let pair = Operation.pairID(ViewID("v1"), TaskID("t1"))
    let changes = try store.apply([
        store.op(.viewItem, pair, "present", .integer(1), HLC(millis: 1_000, counter: 0)),
        store.op(.viewItem, pair, "rank", .text("m"), HLC(millis: 1_000, counter: 1)),
    ])
    #expect(changes.views == [ViewID("v1")])
    #expect(changes.tasks == [TaskID("t1")])
    let rows = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT view_id, task_id, present, rank FROM view_items") }
    #expect(rows == [[.text("v1"), .text("t1"), .integer(1), .text("m")]])
}

@Test func aNullFromAnotherDeviceForANotNullColumnIsJournaledAndSkippedInsteadOfFailingTheBatch() throws {
    let store = try makeStore()
    try store.apply([store.op(.task, "t1", "title", .text("kept"), HLC(millis: 1_000, counter: 0))])
    // `title` is NOT NULL and `when_day` is not; both arrive in one batch, the way a peer's pull would deliver
    // them, and the good one must not be rolled back by the bad one.
    let changes = try store.apply([
        foreign("B", "title", .null, HLC(millis: 2_000, counter: 0)),
        foreign("B", "when_day", .null, HLC(millis: 2_001, counter: 0)),
    ])
    #expect(changes.tasks == [TaskID("t1")])
    let row = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT title, when_day FROM tasks WHERE id = 't1'") }
    #expect(row == [[.text("kept"), .null]])
    let journal = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM ops WHERE device != 'seed'") }
    #expect(journal == [[.integer(3)]])
    // The refused operation left no field clock, so the next well-formed one for that field still wins.
    try store.apply([store.op(.task, "t1", "title", .text("later"), HLC(millis: 1_500, counter: 0))])
    #expect(try titleAndCreated(store, "t1")?.0 == "later")
}

@Test func aPairIDThatDoesNotSplitIsJournaledAndTouchesNothing() throws {
    let store = try makeStore()
    let changes = try store.apply([store.op(.taskTag, "t1", "present", .integer(1), HLC(millis: 1_000, counter: 0))])
    #expect(changes.isEmpty)
    let rows = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM task_tags") }
    #expect(rows == [[.integer(0)]])
    let clocks = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM field_clocks WHERE device != 'seed'") }
    #expect(clocks == [[.integer(0)]])
    let journal = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM ops WHERE device != 'seed'") }
    #expect(journal == [[.integer(1)]])
}

@Test func aReplayedOperationStillLosesToANewerOneAndIsNotReplayedAgain() throws {
    let store = try makeStore()
    try store.apply([store.op(.task, "t1", "reminder_minutes", .integer(540), HLC(millis: 1_000, counter: 0))])
    try store.apply([store.op(.task, "t1", "title", .text("newer"), HLC(millis: 3_000, counter: 0))])
    try store.sql { () throws(SQLiteError) in try store.db.run("UPDATE ops SET field = 'title', value = 'older' WHERE field = 'reminder_minutes'") }
    try store.replayUnapplied()
    #expect(try titleAndCreated(store, "t1")?.0 == "newer")
    let unapplied = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM ops WHERE applied = 0") }
    #expect(unapplied == [[.integer(0)]])
}

@Test func rankingATaskInsideAManualListDoesNotPutItInTheList() throws {
    let store = try makeStore()
    // `present` defaults to 1 in the schema, and the two operations arrive apart when delivery is out of
    // order, so the row a lone `rank` creates must not read as a membership.
    let pair = Operation.pairID(ViewID("v1"), TaskID("t1"))
    try store.apply([store.op(.viewItem, pair, "rank", .text("m"), HLC(millis: 1_000, counter: 0))])
    var rows = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT present, rank FROM view_items") }
    #expect(rows == [[.integer(0), .text("m")]])
    try store.apply([store.op(.viewItem, pair, "present", .integer(1), HLC(millis: 1_001, counter: 0))])
    rows = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT present, rank FROM view_items") }
    #expect(rows == [[.integer(1), .text("m")]])
}
