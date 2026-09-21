import TodoCore

/// A clock that starts at a fixed millisecond and advances by one on every call.
public final class TestClock {
    private var millis: Int64
    public init(start: Int64 = 1_757_500_000_000) { millis = start }
    public func now() -> Int64 { millis += 1; return millis }
    public func jump(by ms: Int64) { millis += ms }
}

/// A store with an identity of its own, the way a platform opens one. Two calls are two devices, which is
/// what the sync tests exchange between; a test that reopens the same database passes the first store's id.
public func makeStore(device: String = Store.newDeviceID(), clock: TestClock = TestClock()) throws(StoreError) -> Store {
    try Store.openInMemory(device: device, now: clock.now)
}
