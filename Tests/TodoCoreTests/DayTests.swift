import Testing
@testable import TodoCore

@Test func epochIsDayZero() {
    let d = Day(year: 1970, month: 1, day: 1)
    #expect(d.daysSinceEpoch == 0)
    #expect(d.year == 1970 && d.month == 1 && d.day == 1)
}

@Test func roundTripsKnownDates() {
    let cases: [(Int, Int, Int, Int32)] = [
        (2000, 3, 1, 11017), (2024, 2, 29, 19782), (2026, 9, 11, 20707), (1969, 12, 31, -1), (2100, 2, 28, 47540),
    ]
    for (y, m, d, expected) in cases {
        let day = Day(year: y, month: m, day: d)
        #expect(day.daysSinceEpoch == expected, "\(y)-\(m)-\(d)")
        #expect(day.year == y && day.month == m && day.day == d, "\(expected)")
    }
}

@Test func arithmeticAndOrdering() {
    let a = Day(year: 2026, month: 12, day: 31)
    #expect(a.advanced(by: 1) == Day(year: 2027, month: 1, day: 1))
    #expect(Day(year: 2027, month: 1, day: 1) - a == 1)
    #expect(a < a.advanced(by: 1))
    #expect(Day(year: 2024, month: 2, day: 28).advanced(by: 1) == Day(year: 2024, month: 2, day: 29))
}

@Test func parsesAndPrintsISO() {
    #expect(Day("2026-09-11") == Day(year: 2026, month: 9, day: 11))
    #expect(Day(year: 2026, month: 9, day: 1).description == "2026-09-01")
    #expect(Day("2026-9-1") == nil)
    #expect(Day("nope") == nil)
    #expect(Day("2026-13-01") == nil)
}
