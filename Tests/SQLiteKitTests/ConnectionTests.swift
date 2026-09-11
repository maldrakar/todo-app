import Testing
@testable import SQLiteKit

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
