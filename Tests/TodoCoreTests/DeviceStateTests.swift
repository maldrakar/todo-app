import Testing
import TestSupport
@testable import TodoCore
@testable import SQLiteKit

/// A module's own type for what it keeps, of the shape a state grows into beyond a list of ids.
private struct Columns: Codable, Equatable {
    let widths: [String: Int]
    let collapsed: [String]
}

/// A type that nests itself, two levels of the document per level of the value: an object and its list.
private struct Nest: Codable, Equatable {
    let inner: [Nest]

    /// A value whose document is `2 * levels + 2` deep.
    static func deep(_ levels: Int) -> Nest {
        var nest = Nest(inner: [])
        for _ in 0..<levels { nest = Nest(inner: [nest]) }
        return nest
    }

    /// The document of `deep(levels)`, written out by hand for a row the test puts in the table itself.
    static func json(_ levels: Int) -> String {
        String(repeating: "{\"inner\":[", count: levels) + "{\"inner\":[]}" + String(repeating: "]}", count: levels)
    }
}

/// A device's own UI state is a value of the module's own type, kept under a key in the store outside the
/// journal (ADR-0010, amendment of 2026-10-26). Writing a value again replaces it.
@Test func deviceStateRoundTripsAValueOfTheModulesType() throws {
    let store = try makeStore()
    #expect(try store.deviceState("sidebar.folded", as: [String].self) == nil)
    try store.setDeviceState("sidebar.folded", ["a", "b"])
    #expect(try store.deviceState("sidebar.folded", as: [String].self) == ["a", "b"])
    try store.setDeviceState("sidebar.folded", ["c"])
    #expect(try store.deviceState("sidebar.folded", as: [String].self) == ["c"])
    let columns = Columns(widths: ["sidebar": 280], collapsed: ["a"])
    try store.setDeviceState("window.columns", columns)
    #expect(try store.deviceState("window.columns", as: Columns.self) == columns)
    let rows = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM device_state") }
    #expect(rows == [[.integer(2)]], "one row per key, whatever was written to it before")
}

/// What is in the table was written by a version of the app that may be newer, older or wrong, or by a module
/// that has since changed its type. A value that does not decode as the type asked for reads as nothing kept,
/// and so does one that is not text or that nests deeper than the store reads, rather than a failure the
/// module has to survive at every open (`docs/style.md`, "A trap is a bug").
@Test func aValueThatDoesNotDecodeReadsAsNothingKept() throws {
    let store = try makeStore()
    try store.sql { () throws(SQLiteError) in
        try store.db.run("INSERT INTO device_state (key, value) VALUES ('not.json', 'a,b')")
        try store.db.run("INSERT INTO device_state (key, value) VALUES ('other.type', '{\"collapsed\":[\"a\"]}')")
        try store.db.run("INSERT INTO device_state (key, value) VALUES ('not.text', x'5b5d')")
        try store.db.run("INSERT INTO device_state (key, value) VALUES ('too.deep', ?)", [.text(Nest.json(20))])
        try store.db.run("INSERT INTO device_state (key, value) VALUES ('shallow', ?)", [.text(Nest.json(14))])
    }
    #expect(try store.deviceState("not.json", as: [String].self) == nil)
    #expect(try store.deviceState("other.type", as: [String].self) == nil)
    #expect(try store.deviceState("not.text", as: [String].self) == nil, "a blob that would read as [] if it were text")
    #expect(try store.deviceState("too.deep", as: Nest.self) == nil)
    #expect(try store.deviceState("shallow", as: Nest.self) == Nest.deep(14), "thirty levels, inside the limit")
}

/// A value the store could not read back is refused at the write, where it is a message about the value the
/// module just made rather than a state that reads as nothing kept at the next open: one the encoder refuses,
/// and one that nests deeper than the read above accepts.
@Test func aValueTheStoreCouldNotReadBackIsRefused() throws {
    let store = try makeStore()
    var caught: StoreError?
    do { try store.setDeviceState("not.a.number", Double.nan) } catch { caught = error }
    guard case .invalid(let sentence)? = caught else {
        Issue.record("a value the encoder refuses was not refused: \(String(describing: caught))")
        return
    }
    #expect(sentence.hasPrefix("the device state \"not.a.number\" could not be written as JSON: "))
    #expect(throws: StoreError.invalid("the device state \"too.deep\" nests deeper than 32 levels")) {
        try store.setDeviceState("too.deep", Nest.deep(20))
    }
    let rows = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM device_state") }
    #expect(rows == [[.integer(0)]])
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
    try store.setDeviceState("sidebar.folded", ["a"])
    try store.setDeviceState("sidebar.folded", ["b"])
    try store.setDeviceState("sidebar.folded", [String]())
    #expect(reported.isEmpty)
    #expect(try journaled() == before)
}

/// The table is the file's, so the bytes the web target persists carry it and a store opened from them reads
/// what the device kept.
@Test func deviceStateSurvivesASnapshot() throws {
    let clock = TestClock()
    let store = try makeStore(clock: clock)
    try store.setDeviceState("sidebar.folded", ["a", "b"])
    let reopened = try Store.openInMemory(snapshot: try store.snapshot(), device: store.deviceID, now: clock.now)
    #expect(try reopened.deviceState("sidebar.folded", as: [String].self) == ["a", "b"])
}
