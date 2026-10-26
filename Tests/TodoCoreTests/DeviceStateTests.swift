import Testing
import TestSupport
@testable import TodoCore
@testable import SQLiteKit

/// A device's own UI state is a key and a text value kept in the store outside the journal (ADR-0010). Writing
/// a value again replaces it, and writing none takes the key away instead of keeping a row that says nothing.
@Test func deviceStateRoundTripsAndNilRemovesTheRow() throws {
    let store = try makeStore()
    #expect(try store.deviceState("sidebar.folded") == nil)
    try store.setDeviceState("sidebar.folded", "a,b")
    #expect(try store.deviceState("sidebar.folded") == "a,b")
    try store.setDeviceState("sidebar.folded", "c")
    #expect(try store.deviceState("sidebar.folded") == "c")
    try store.setDeviceState("sidebar.folded", nil)
    #expect(try store.deviceState("sidebar.folded") == nil)
    let rows = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM device_state") }
    #expect(rows == [[.integer(0)]], "no value is no row")
}

/// Nothing in the table leaves the device and nothing in it is the data, so a write neither journals an
/// operation, which a push would send, nor reports a change set, which every window would answer with a reread.
@Test func aDeviceStateWriteReportsNoChangeAndJournalsNothing() throws {
    let store = try makeStore()
    func journaled() throws -> [[Value]] {
        try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM ops") }
    }
    let before = try journaled()
    var reported: [ChangeSet] = []
    store.onChange = { reported.append($0) }
    try store.setDeviceState("sidebar.folded", "a")
    try store.setDeviceState("sidebar.folded", "b")
    try store.setDeviceState("sidebar.folded", nil)
    #expect(reported.isEmpty)
    #expect(try journaled() == before)
}

/// The table is the file's, so the bytes the web target persists carry it and a store opened from them reads
/// what the device kept.
@Test func deviceStateSurvivesASnapshot() throws {
    let clock = TestClock()
    let store = try makeStore(clock: clock)
    try store.setDeviceState("sidebar.folded", "a,b")
    let reopened = try Store.openInMemory(snapshot: try store.snapshot(), device: store.deviceID, now: clock.now)
    #expect(try reopened.deviceState("sidebar.folded") == "a,b")
}
