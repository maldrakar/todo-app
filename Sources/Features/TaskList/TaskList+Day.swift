// Sources/Features/TaskList/TaskList+Day.swift
import TodoCore

/// The days the screen names, in English, from the core's `Day` and its weekday: the long date under Today's title, a
/// block's day and its date, a group's screen's day, and the due text of a deadline (spec section 8). The core names no
/// day (`Weekday`), and no other module formats one yet, so the names live here, as the canvas spells them (canvas,
/// section 0); a day in another year is named without its year, as the canvas names none.
///
/// A day a peer wrote can lie anywhere a `Day` holds, while measuring two days apart and naming a date work in an
/// `Int`, which is 32 bits on wasm32 and leaves it for a day near either end (`Day.-`, the civil date). So every day
/// this names or measures is first drawn into the days `earliest` to `latest`, some two million years either side of
/// now, and a distance from a link or a filter is clamped to land in them: a day past them is named and measured as the
/// nearest one in them, and nothing traps (`docs/style.md`, "A trap is a bug").
extension TaskList {
    /// "Saturday, October 24": the weekday's and the month's names in full, and the day.
    static func longDate(_ day: Day) -> String {
        let day = Self.drawnIn(day)
        return "\(weekdayNames[day.weekday.rawValue]), \(monthNames[day.month - 1]) \(day.day)"
    }

    /// "Sat, Oct 24": the weekday's and the month's short names, and the day.
    private static func shortDate(_ day: Day) -> String {
        let day = Self.drawnIn(day)
        return "\(shortWeekdayNames[day.weekday.rawValue]), \(monthDate(day))"
    }

    /// A day's title, a block's or a group's screen's: "Today", "Tomorrow", and the weekday's full name for every other
    /// day, past or future, at any distance, since the date under it says which (canvas, `dayTitle`).
    static func dayTitle(_ day: Day, today: Day) -> String {
        switch distance(to: day, from: today) {
        case 0: "Today"
        case 1: "Tomorrow"
        default: weekdayNames[Self.drawnIn(day).weekday.rawValue]
        }
    }

    /// The date under a day's title: "Sat, Oct 24" for today and tomorrow, whose titles name no weekday, and "Oct 27"
    /// for every other day, whose title is its weekday (canvas, `dayDate`).
    static func dayDate(_ day: Day, today: Day) -> String {
        switch distance(to: day, from: today) {
        case 0, 1: shortDate(day)
        default: monthDate(Self.drawnIn(day))
        }
    }

    /// What a card's When pill says of its day: "Today", "Tomorrow", "Oct 22" for a day past, and "Mon, Oct 26" for a later
    /// one (canvas, `whenLabel`; the controller's ruling R89).
    static func whenPillText(_ day: Day, today: Day) -> String {
        switch distance(to: day, from: today) {
        case 0: "Today"
        case 1: "Tomorrow"
        case ..<0: monthDate(Self.drawnIn(day))
        default: shortDate(day)
        }
    }

    /// What a card's Deadline pill says of its day: "Sat, Oct 24", always, never "Today" (canvas, `dayShort`; the
    /// controller's ruling R89).
    static func deadlinePillText(_ day: Day) -> String {
        shortDate(day)
    }

    /// What a deadline says on a row: "Overdue 1 day" or "Overdue N days" once it has passed, "Due today", the
    /// weekday's short name through six days ahead, "Due Sun", with no "Due tomorrow", and "Due Oct 31" from seven
    /// days on (canvas, `dueText`).
    static func dueText(_ deadline: Day, today: Day) -> String {
        let distance = distance(to: deadline, from: today)
        return switch distance {
        case ..<0: "Overdue \(-distance) \(-distance == 1 ? "day" : "days")"
        case 0: "Due today"
        case 1...6: "Due \(shortWeekdayNames[deadline.weekday.rawValue])"
        default: "Due \(monthDate(Self.drawnIn(deadline)))"
        }
    }

    /// The day as a key, `yyyy-mm-dd`, which a day's fold is kept under in the device's state.
    static func dayKey(_ day: Day) -> String {
        Self.drawnIn(day).description
    }

    /// Whether a deadline is due, today or before, which the row draws in red (canvas, `dueColor`).
    static func isDue(_ deadline: Day, today: Day) -> Bool {
        distance(to: deadline, from: today) <= 0
    }

    /// How many days `day` is after `today`, negative before it, each drawn into the days this names first, so that the
    /// subtraction stays inside a 32-bit `Int`: two days in them are at most some 1.46 billion days apart, four million
    /// years, under `Int32.max`.
    static func distance(to day: Day, from today: Day) -> Int {
        drawnIn(day) - drawnIn(today)
    }

    /// The day `distance` days after `today`, the distance from a link, a filter's offset or a group's key, clamped so
    /// that the day lands in the days this names, since `Day.advanced(by:)` traps outside `Int32` (global
    /// constraints).
    static func day(_ distance: Int64, from today: Day) -> Day {
        let today = drawnIn(today)
        let lowest = Int64(Self.distance(to: earliest, from: today))
        let highest = Int64(Self.distance(to: latest, from: today))
        return today.advanced(by: Int(min(max(distance, lowest), highest)))
    }

    /// The day as the nearest of the days this names.
    private static func drawnIn(_ day: Day) -> Day {
        min(max(day, earliest), latest)
    }

    /// The first and the last day this names and measures: the civil date of either works in a 32-bit `Int`, and the
    /// distance between them is under `Int32.max`.
    private static let earliest = Day(year: -2_000_000, month: 1, day: 1)
    private static let latest = Day(year: 2_000_000, month: 1, day: 1)

    /// "Oct 24": the month's short name and the day.
    private static func monthDate(_ day: Day) -> String {
        "\(shortMonthNames[day.month - 1]) \(day.day)"
    }

    /// The names of the days of the week, in `Weekday`'s order, from Monday.
    private static let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private static let shortWeekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    /// The names of the months, January first.
    private static let monthNames = [
        "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November",
        "December",
    ]
    private static let shortMonthNames = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]
}
