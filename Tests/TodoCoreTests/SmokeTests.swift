import Testing
@testable import TodoCore

@Test func vendoredSQLiteHasTheExpectedVersion() throws {
    #expect(try CoreSmoke.sqliteVersion() == "3.53.4")
}

@Test func trigramTokenizerFoldsCaseAndFindsCyrillicSubstrings() throws {
    #expect(try CoreSmoke.trigramMatches("отч") == 1)
    #expect(try CoreSmoke.trigramMatches("ОТЧ") == 1)
    #expect(try CoreSmoke.trigramMatches("xyz") == 0)
}

@Test func databaseRoundTripsThroughSerializeAndDeserialize() throws {
    #expect(try CoreSmoke.snapshotSum() == 6)
}

@Test func uuidIsRandomAndClockAdvances() {
    let a = CoreSmoke.freshUUID()
    #expect(a.count == 36)
    #expect(a != CoreSmoke.freshUUID())
    let t1 = CoreSmoke.nowMilliseconds()
    let t2 = CoreSmoke.nowMilliseconds()
    // Under WasmKit the clock is fake, so only monotonicity is asserted, never a wall-clock value.
    #expect(t2 >= t1)
}
