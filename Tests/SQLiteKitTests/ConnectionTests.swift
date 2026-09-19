import Testing
@testable import SQLiteKit

/// `SQLITE_OK` as the wrapper sees it, without importing the C module into the tests.
let SQLITE_OK_CODE: Int32 = 0

@Test func executesDDLAndReadsRowsBack() throws {
    let db = try Connection.openInMemory()
    try db.execute("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT, score REAL, data BLOB)")
    try db.run("INSERT INTO t (name, score, data) VALUES (?, ?, ?)", [.text("a"), .real(1.5), .blob([1, 2, 3])])
    try db.run("INSERT INTO t (name, score, data) VALUES (?, ?, ?)", [.null, .null, .null])
    let rows = try db.rows("SELECT id, name, score, data FROM t ORDER BY id")
    #expect(rows == [
        [.integer(1), .text("a"), .real(1.5), .blob([1, 2, 3])],
        [.integer(2), .null, .null, .null],
    ])
    #expect(db.lastInsertRowID == 2)
    #expect(rows[0][2].double == 1.5)
    #expect(rows[1][2].double == nil, "a null column has no number to read")
}

@Test func reportsErrorsWithCodeAndMessage() throws {
    let db = try Connection.openInMemory()
    var caught: SQLiteError?
    do { try db.execute("SELECT * FROM missing") } catch { caught = error }
    #expect(caught?.code == 1)
    #expect(caught?.message.contains("no such table") == true)
}

@Test func transactionRollsBackOnError() throws {
    let db = try Connection.openInMemory()
    try db.execute("CREATE TABLE t (x INTEGER)")
    var caught: SQLiteError?
    do {
        try db.transaction { () throws(SQLiteError) in
            try db.run("INSERT INTO t VALUES (1)")
            try db.execute("INSERT INTO nowhere VALUES (1)")
        }
    } catch { caught = error }
    #expect(caught != nil)
    #expect(try db.rows("SELECT count(*) FROM t") == [[.integer(0)]])
    let n: Int64 = try db.transaction { () throws(SQLiteError) in
        try db.run("INSERT INTO t VALUES (2)")
        return db.lastInsertRowID
    }
    #expect(n == 1)
    #expect(try db.rows("SELECT x FROM t") == [[.integer(2)]])
}

@Test func statementsBindStepAndReset() throws {
    let db = try Connection.openInMemory()
    try db.execute("CREATE TABLE t (x INTEGER)")
    let insert = try db.prepare("INSERT INTO t VALUES (?)")
    for i in 1...3 {
        try insert.bind([.integer(Int64(i))])
        _ = try insert.step()
        try insert.reset()
    }
    let select = try db.prepare("SELECT x FROM t WHERE x > ? ORDER BY x")
    try select.bind([.integer(1)])
    var seen: [Int64] = []
    while try select.step() { seen.append(select.value(at: 0).int64 ?? -1) }
    #expect(seen == [2, 3])
    #expect(select.columnCount == 1)
}

@Test func statementsOutliveTheConnectionReference() throws {
    // The statement is the only thing left holding the connection; stepping it must still be defined.
    let statement = try Connection.openInMemory().prepare("SELECT 1")
    #expect(try statement.step())
    #expect(statement.value(at: 0) == .integer(1))
}

@Test func openAppliesThePragmasTheClientAsksFor() throws {
    let plain = try Connection.openInMemory()
    #expect(try plain.rows("PRAGMA foreign_keys") == [[.integer(0)]])
    let configured = try Connection.openInMemory(pragmas: ["foreign_keys = ON", "user_version = 3"])
    #expect(try configured.rows("PRAGMA foreign_keys") == [[.integer(1)]])
    #expect(try configured.userVersion() == 3)
}

@Test func aPragmaThatFailsSaysWhichOneItWas() throws {
    var caught: SQLiteError?
    do { _ = try Connection.openInMemory(pragmas: ["foreign_keys = ON", "journal_mode = "]) } catch { caught = error }
    #expect(caught?.message.contains("PRAGMA journal_mode = ") == true)
}

@Test func userVersionRoundTrips() throws {
    let db = try Connection.openInMemory()
    #expect(try db.userVersion() == 0)
    try db.setUserVersion(7)
    #expect(try db.userVersion() == 7)
}

@Test func serializeAndDeserializeCopyTheDatabase() throws {
    let a = try Connection.openInMemory()
    try a.execute("CREATE TABLE t (x INTEGER); INSERT INTO t VALUES (1), (2), (3);")
    let bytes = try a.serialize()
    #expect(bytes.count > 0)
    let b = try Connection.openInMemory()
    try b.deserialize(bytes)
    #expect(try b.rows("SELECT sum(x) FROM t") == [[.integer(6)]])
    try b.run("INSERT INTO t VALUES (4)")
    #expect(try b.rows("SELECT count(*) FROM t") == [[.integer(4)]])
}

@Test func openFailsForAnUnwritablePath() {
    var caught: SQLiteError?
    do { _ = try Connection.open(path: "/nonexistent-dir/x.sqlite") } catch { caught = error }
    #expect(caught != nil)
}

@Test func bindingAgainMidScanRestartsTheStatement() throws {
    let db = try Connection.openInMemory()
    try db.execute("CREATE TABLE t (x INTEGER); INSERT INTO t VALUES (1), (2), (3);")
    let select = try db.prepare("SELECT x FROM t WHERE x >= ? ORDER BY x")
    try select.bind([.integer(1)])
    #expect(try select.step())
    // The statement is busy with a row pending; rebinding it must restart it, not reach into its memory.
    try select.bind([.integer(3)])
    var seen: [Int64] = []
    while try select.step() { seen.append(select.value(at: 0).int64 ?? -1) }
    #expect(seen == [3])
}

@Test func resetRecoversAStatementAfterAFailedStep() throws {
    let db = try Connection.openInMemory()
    try db.execute("CREATE TABLE t (x INTEGER PRIMARY KEY)")
    let insert = try db.prepare("INSERT INTO t VALUES (?)")
    try insert.bind([.integer(1)])
    _ = try insert.step()
    try insert.reset()
    try insert.bind([.integer(1)])
    var caught: SQLiteError?
    do { _ = try insert.step() } catch { caught = error }
    #expect(caught?.code == 19)
    // The step's error has already reached the caller; resetting is how the statement is reused.
    try insert.reset()
    try insert.bind([.integer(2)])
    _ = try insert.step()
    #expect(try db.rows("SELECT x FROM t ORDER BY x") == [[.integer(1)], [.integer(2)]])
}

@Test func runRefusesToSilentlyDropStatementsAfterTheFirst() throws {
    let db = try Connection.openInMemory()
    try db.execute("CREATE TABLE t (x INTEGER)")
    var caught: SQLiteError?
    do { try db.run("INSERT INTO t VALUES (1); INSERT INTO t VALUES (2);") } catch { caught = error }
    #expect(caught != nil)
    #expect(try db.rows("SELECT count(*) FROM t") == [[.integer(0)]])
    // A trailing semicolon or blank is not a second statement.
    try db.run("INSERT INTO t VALUES (1); ")
    #expect(try db.rows("SELECT count(*) FROM t") == [[.integer(1)]])
}

@Test func preparingNothingIsAnError() throws {
    let db = try Connection.openInMemory()
    var caught: SQLiteError?
    do { _ = try db.prepare("  -- just a comment\n") } catch { caught = error }
    #expect(caught != nil)
    #expect(caught?.code != SQLITE_OK_CODE)
    #expect(caught?.message.isEmpty == false)
}

@Test func textKeepsEveryByteIncludingAnEmbeddedNUL() throws {
    let db = try Connection.openInMemory()
    try db.execute("CREATE TABLE t (s TEXT)")
    try db.run("INSERT INTO t VALUES (?)", [.text("ab\u{0}cd")])
    #expect(try db.rows("SELECT octet_length(s) FROM t") == [[.integer(5)]])
    #expect(try db.rows("SELECT s FROM t") == [[.text("ab\u{0}cd")]])
}

@Test func changesCountsTheRowsTheLastStatementTouched() throws {
    let db = try Connection.openInMemory()
    try db.execute("CREATE TABLE t (x INTEGER); INSERT INTO t VALUES (1), (2), (3);")
    try db.run("UPDATE t SET x = x + 10 WHERE x > 1")
    #expect(db.changes == 2)
}

@Test func valuesWrapOptionalsAndReadThemBack() {
    #expect(Value(nil as String?) == .null)
    #expect(Value("a") == .text("a"))
    #expect(Value(nil as Int64?) == .null)
    #expect(Value(7 as Int64?) == .integer(7))
    #expect(Value(3 as Int32?) == .integer(3))
    #expect(Value(true) == .integer(1))
    #expect(Value(false) == .integer(0))
    #expect(Value.null.isNull)
    #expect(Value.integer(1).isNull == false)
    #expect(Value.text("a").int64 == nil)
    #expect(Value.integer(1).string == nil)
}

@Test func deserializeRejectsBytesThatAreNotADatabase() throws {
    let db = try Connection.openInMemory()
    var caught: SQLiteError?
    do { try db.deserialize([UInt8](repeating: 7, count: 4096)) } catch { caught = error }
    #expect(caught != nil)
}

@Test func theVendoredLibraryIsTheVersionTheRepositoryPins() throws {
    // `Sources/CSQLite/README.md` records the provenance; this is what makes a silent bump visible.
    let db = try Connection.openInMemory()
    #expect(try db.rows("SELECT sqlite_version()").first?.first?.string == "3.53.4")
}

@Test func trigramSearchFindsCyrillicSubstringsOnEveryPlatform() throws {
    // FTS5 with the trigram tokenizer is what the core searches titles with, and wasm32 is the platform the
    // spec listed as unverified, so this runs on every platform CI tests.
    let db = try Connection.openInMemory()
    try db.execute("CREATE VIRTUAL TABLE t USING fts5(title, tokenize='trigram remove_diacritics 1');")
    try db.execute("INSERT INTO t VALUES ('Квартальный отчёт'), ('Купить молоко');")
    func matches(_ needle: String) throws -> Int64 {
        try db.rows("SELECT count(*) FROM t WHERE t MATCH ?", [.text("\"\(needle)\"")]).first?.first?.int64 ?? -1
    }
    #expect(try matches("отч") == 1)
    #expect(try matches("ОТЧ") == 1)
    #expect(try matches("xyz") == 0)
}
