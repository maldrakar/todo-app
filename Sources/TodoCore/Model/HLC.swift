/// Hybrid logical clock value: wall-clock milliseconds and a counter, packed into one Int64 (48 + 16 bits).
public struct HLC: Hashable, Comparable, Sendable {
    /// The largest counter the 16 bits hold; `HybridClock` borrows the next millisecond rather than pass it,
    /// and in the last millisecond of the range, where there is none to borrow, stops at this counter.
    public static let maxCounter: Int32 = 65_535

    /// One past the largest millisecond the 48 bits hold.
    public static let maxMillis: Int64 = 1 << 47

    public let millis: Int64
    public let counter: Int32

    public init(millis: Int64, counter: Int32) {
        precondition(counter >= 0 && counter <= Self.maxCounter, "HLC counter overflow")
        precondition(millis >= 0 && millis < Self.maxMillis, "HLC milliseconds outside the 48 bits of the encoding")
        self.millis = millis
        self.counter = counter
    }

    /// Decodes what the journal stored, without the checks above: a row written by another version of the app,
    /// or a corrupt one, still has to read back as the value it sorts as instead of aborting the process.
    public init(raw: Int64) {
        millis = raw >> 16
        counter = Int32(raw & 0xFFFF)
    }

    public var raw: Int64 { (millis << 16) | Int64(counter) }

    public static func < (lhs: HLC, rhs: HLC) -> Bool { lhs.raw < rhs.raw }
}

/// Issues clocks that never go backwards on this device and stay ahead of every clock seen from other devices.
///
/// The clock saturates at the top of the encoding rather than leave it: once it reaches
/// `HLC(millis: HLC.maxMillis - 1, counter: HLC.maxCounter)`, every later `next()` answers that same stamp.
/// Stamps stop being unique there, so last-write-wins falls back to the device-id tie-break and a device stops
/// outranking its own earlier edit. It is still the cheaper answer: stamps reach this clock from the journal
/// and from other devices, `HLC(raw:)` decodes whatever bytes they hold, and a clock that trapped on one of
/// them would abort the process on the next local edit and keep aborting, because the stamp is stored (#34).
/// The range ends around the year 6430, so saturation is a rule for corrupt and hostile data, not a deadline.
/// The reading of the wall clock is pulled into the same range, so a system clock set outside it cannot trap
/// either.
public final class HybridClock {
    private let now: () -> Int64
    private var last = HLC(millis: 0, counter: 0)

    public init(now: @escaping () -> Int64) { self.now = now }

    /// The stamp for a local event: strictly greater than every stamp this clock has issued or observed, until
    /// the top of the range, where it repeats the largest stamp the encoding holds.
    public func next() -> HLC {
        let wall = wallMillis()
        if wall > last.millis {
            last = HLC(millis: wall, counter: 0)
        } else if last.counter == HLC.maxCounter {
            // The counter is all that separates stamps inside one millisecond, so when it fills up the clock
            // borrows the next millisecond. Staying ahead of itself is what the journal needs; agreeing with
            // the wall clock to the millisecond is not. In the last millisecond of the range there is nothing
            // left to borrow, and the clock stands still instead of stepping outside the encoding.
            if last.millis + 1 < HLC.maxMillis { last = HLC(millis: last.millis + 1, counter: 0) }
        } else {
            last = HLC(millis: last.millis, counter: last.counter + 1)
        }
        return last
    }

    /// Records a clock seen from another device. Observing is not an event of its own, so it only raises the
    /// high-water mark and leaves the increment to the next `next()`, which is then the first stamp strictly
    /// above both this device and the remote one. The wall clock joins the maximum so that a clock that later
    /// goes backwards cannot drag a stamp below what this device has already seen. Any stamp is accepted: what
    /// the encoding cannot represent is the business of `next()`, which never leaves the range.
    public func observe(_ remote: HLC) {
        last = max(last, remote, HLC(millis: wallMillis(), counter: 0))
    }

    /// The wall clock as a millisecond the encoding holds. `now()` is injected and reads a device's system
    /// clock, which may sit before the epoch or past the end of the range; neither may reach the initializer.
    /// A reading outside the range is pulled in rather than refused, because a machine with its clock set wrong
    /// is a condition to survive, not a programming error: the core has nowhere to report it and stopping the
    /// process over it would be the worse answer.
    private func wallMillis() -> Int64 { min(max(now(), 0), HLC.maxMillis - 1) }
}
