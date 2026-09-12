/// Hybrid logical clock value: wall-clock milliseconds and a counter, packed into one Int64 (48 + 16 bits).
public struct HLC: Hashable, Comparable, Sendable {
    public let millis: Int64
    public let counter: Int32

    public init(millis: Int64, counter: Int32) {
        precondition(counter >= 0 && counter < 65_536, "HLC counter overflow")
        self.millis = millis
        self.counter = counter
    }

    public init(raw: Int64) {
        self.init(millis: raw >> 16, counter: Int32(raw & 0xFFFF))
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
        } else {
            last = HLC(millis: last.millis, counter: last.counter + 1)
        }
        return last
    }

    /// Records a clock seen from another device. Observing is not an event of its own, so it only merges the
    /// high-water mark and leaves the increment to the next `next()`, which is then strictly above the remote
    /// stamp. When the wall clock is ahead of both, the merged millisecond is still stored, so that a wall
    /// clock that later goes backwards cannot drag a stamp below what this device has already seen.
    public func observe(_ remote: HLC) {
        let wall = now()
        let millis = max(wall, last.millis, remote.millis)
        let counter: Int32
        if millis == last.millis && millis == remote.millis {
            counter = max(last.counter, remote.counter)
        } else if millis == last.millis {
            counter = last.counter
        } else if millis == remote.millis {
            counter = remote.counter
        } else {
            counter = 0
        }
        last = HLC(millis: millis, counter: counter)
    }
}
