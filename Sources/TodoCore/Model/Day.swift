/// A calendar day with no time zone, stored as days since 1970-01-01.
///
/// The conversions are Howard Hinnant's `days_from_civil` and `civil_from_days` for the proleptic Gregorian
/// calendar: plain integer arithmetic, no `Calendar` and no time zone, so the same day means the same thing
/// on every platform the core builds for.
public struct Day: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let daysSinceEpoch: Int32

    public init(daysSinceEpoch: Int32) { self.daysSinceEpoch = daysSinceEpoch }

    public init(year: Int, month: Int, day: Int) {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = month > 2 ? month - 3 : month + 9
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        daysSinceEpoch = Int32(era * 146097 + doe - 719468)
    }

    /// Parses strict `YYYY-MM-DD`.
    public init?(_ iso: String) {
        let parts = iso.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        let candidate = Day(year: y, month: m, day: d)
        guard candidate.year == y, candidate.month == m, candidate.day == d else { return nil }
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
