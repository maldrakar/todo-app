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

@Test func parsesAndPrintsISO() throws {
    #expect(try Day("2026-09-11") == Day(year: 2026, month: 9, day: 11))
    #expect(Day(year: 2026, month: 9, day: 1).description == "2026-09-01")
}

@Test func refusesEverythingThatIsNotAStrictISODay() {
    // The sign cases matter because `Int("+1")` parses: a day has to come back as the string it was read from.
    for bad in ["2026-9-1", "nope", "2026-13-01", "2026-02-30", "+999-01-01", "2026-01-+1", "2026-01-01 ", ""] {
        #expect(throws: DayParseError(input: bad)) { try Day(bad) }
    }
    #expect(DayParseError(input: "nope").description == "not a date: nope, expected YYYY-MM-DD")
}

/// A reading of the wall clock is data from outside: a clock set before 1970 or one that saturated at the top
/// of its range is still a reading, and neither may trap (`docs/style.md`). The UTC day is what a client with
/// no time zone of its own takes for today, so the boundary is midnight UTC and no other.
@Test func theDayOfAReadingIsItsUTCDay() {
    // 2026-10-14T23:59:59.999Z, the last millisecond of the day, and the first one of the next.
    let lastOfTheDay: Int64 = 1_792_022_399_999
    #expect(Day(millisSinceEpoch: lastOfTheDay) == Day(year: 2026, month: 10, day: 14))
    #expect(Day(millisSinceEpoch: lastOfTheDay + 1) == Day(year: 2026, month: 10, day: 15))
    #expect(Day(millisSinceEpoch: lastOfTheDay + 1) - Day(millisSinceEpoch: lastOfTheDay) == 1)
    #expect(Day(millisSinceEpoch: 0) == Day(year: 1970, month: 1, day: 1))
    #expect(Day(millisSinceEpoch: -1) == Day(year: 1970, month: 1, day: 1), "a reading before the epoch is day zero")
    #expect(Day(millisSinceEpoch: .min) == Day(year: 1970, month: 1, day: 1))
    // `Int64.max` milliseconds is about 1.07e11 days, past what the `Int32` day count holds.
    #expect(Day(millisSinceEpoch: .max).daysSinceEpoch == .max, "a reading past the last day is the last day")
}
