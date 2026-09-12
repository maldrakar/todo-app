/// Hybrid logical clock value: wall-clock milliseconds and a counter, packed into one Int64 (48 + 16 bits).
public struct HLC: Hashable, Comparable, Sendable {
    /// The largest counter the 16 bits hold; `HybridClock` borrows the next millisecond rather than pass it.
    public static let maxCounter: Int32 = 65_535

    public let millis: Int64
    public let counter: Int32

    public init(millis: Int64, counter: Int32) {
        precondition(counter >= 0 && counter <= Self.maxCounter, "HLC counter overflow")
        precondition(millis >= 0 && millis < 1 << 47, "HLC milliseconds outside the 48 bits of the encoding")
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
public final class HybridClock {
    private let now: () -> Int64
    private var last = HLC(millis: 0, counter: 0)

    public init(now: @escaping () -> Int64) { self.now = now }

    /// The stamp for a local event: strictly greater than every stamp this clock has issued or observed.
    public func next() -> HLC {
        let wall = now()
        if wall > last.millis {
            last = HLC(millis: wall, counter: 0)
        } else if last.counter == HLC.maxCounter {
            // The counter is all that separates stamps inside one millisecond, so when it fills up the clock
            // borrows the next millisecond. Staying ahead of itself is what the journal needs; agreeing with
            // the wall clock to the millisecond is not.
            last = HLC(millis: last.millis + 1, counter: 0)
        } else {
            last = HLC(millis: last.millis, counter: last.counter + 1)
        }
        return last
    }

    /// Records a clock seen from another device. Observing is not an event of its own, so it only raises the
    /// high-water mark and leaves the increment to the next `next()`, which is then the first stamp strictly
    /// above both this device and the remote one. The wall clock joins the maximum so that a clock that later
    /// goes backwards cannot drag a stamp below what this device has already seen.
    public func observe(_ remote: HLC) {
        last = max(last, remote, HLC(millis: now(), counter: 0))
    }
}
