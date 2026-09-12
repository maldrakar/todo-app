/// Why a string is not a calendar day. It carries the input because everything that parses a day — the command
/// line, a filter document, a URL — reports the failure back to a person.
public struct DayParseError: Error, Equatable, Sendable, CustomStringConvertible {
    public let input: String

    public init(input: String) { self.input = input }

    public var description: String { "not a date: \(input), expected YYYY-MM-DD" }
}

/// A calendar day with no time zone, stored as days since 1970-01-01.
///
/// The conversions are Howard Hinnant's `days_from_civil` and `civil_from_days` for the proleptic Gregorian
/// calendar: plain integer arithmetic, no `Calendar` and no time zone, so the same day means the same thing
/// on every platform the core builds for.
public struct Day: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// Internal on purpose: outside the core a day is a year, a month and a day or an ISO string, and this
    /// integer is only how the store binds it to a SQLite column.
    let daysSinceEpoch: Int32

    init(daysSinceEpoch: Int32) { self.daysSinceEpoch = daysSinceEpoch }

    public init(year: Int, month: Int, day: Int) {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = month > 2 ? month - 3 : month + 9
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        daysSinceEpoch = Int32(era * 146097 + doe - 719468)
    }

    /// Parses strict `YYYY-MM-DD`. A string that is not a day is an error rather than a `nil`, so a bad date
    /// from an argument, a file or a sync payload says which string it was instead of vanishing.
    public init(_ iso: String) throws(DayParseError) {
        let parts = iso.split(separator: "-", omittingEmptySubsequences: false)
        // The widths are checked before the arithmetic, because a year of arbitrary length would overflow the
        // day count rather than fail to parse.
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else {
            throw DayParseError(input: iso)
        }
        let candidate = Day(year: y, month: m, day: d)
        // One round trip replaces every field check: `description` prints exactly `YYYY-MM-DD`, so a sign, a
        // month of 13 and a 30th of February all fail to come back as the string that was parsed.
        guard candidate.description == iso else { throw DayParseError(input: iso) }
        self = candidate
    }

    private var civil: (year: Int, month: Int, day: Int) {
        let z = Int(daysSinceEpoch) + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (m <= 2 ? y + 1 : y, m, d)
    }

    public var year: Int { civil.year }
    public var month: Int { civil.month }
    public var day: Int { civil.day }

    public func advanced(by days: Int) -> Day { Day(daysSinceEpoch: daysSinceEpoch + Int32(days)) }

    public static func - (lhs: Day, rhs: Day) -> Int { Int(lhs.daysSinceEpoch) - Int(rhs.daysSinceEpoch) }

    public static func < (lhs: Day, rhs: Day) -> Bool { lhs.daysSinceEpoch < rhs.daysSinceEpoch }

    public var description: String {
        let c = civil
        func pad(_ n: Int, _ width: Int) -> String {
            let s = String(n)
            return String(repeating: "0", count: max(0, width - s.count)) + s
        }
        return "\(pad(c.year, 4))-\(pad(c.month, 2))-\(pad(c.day, 2))"
    }
}
