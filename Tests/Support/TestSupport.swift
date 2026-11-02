import Testing
import TodoCore

/// A clock that starts at a fixed millisecond and advances by one on every call.
public final class TestClock {
    private var millis: Int64
    public init(start: Int64 = 1_757_500_000_000) { millis = start }
    public func now() -> Int64 { millis += 1; return millis }
    public func jump(by ms: Int64) { millis += ms }
}

/// The device's day `day` as a device on UTC hands it to a module: the day, and the instant it began, its count of
/// days since the epoch in the clock's milliseconds. A module's day is an event of the world, so a test hands a fixed
/// one and never reads the wall clock (ADR-0006, amendment of 2026-11-01).
public func deviceDay(_ day: Day) -> DeviceDay {
    DeviceDay(day: day, began: Int64(day - Day(year: 1970, month: 1, day: 1)) * 86_400_000)
}

/// The day the module tests make their modules on: the day `TestClock` starts on, so that a module's day and the
/// store's clock agree.
public let testDay = deviceDay(Day(year: 2025, month: 9, day: 10))

/// A store with an identity of its own, the way a platform opens one. Two calls are two devices, which is
/// what the sync tests exchange between; a test that reopens the same database passes the first store's id.
public func makeStore(device: String = Store.newDeviceID(), clock: TestClock = TestClock()) throws(StoreError) -> Store {
    try Store.openInMemory(device: device, now: clock.now)
}

/// The change set a write produced, taken the way the composition root takes it: from `Store.onChange`, the
/// core's only push towards the UI and the only source of a `ChangeSet` there is, since nothing outside the
/// core can build one.
public func changeSet(of store: Store, from write: () throws -> Void) throws -> ChangeSet {
    var captured: ChangeSet?
    store.onChange = { captured = $0 }
    defer { store.onChange = nil }
    try write()
    return try #require(captured)
}
