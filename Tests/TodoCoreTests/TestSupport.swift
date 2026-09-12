import TodoCore

/// A clock that starts at a fixed millisecond and advances by one on every call.
final class TestClock {
    private(set) var millis: Int64
    init(start: Int64 = 1_757_500_000_000) { millis = start }
    func now() -> Int64 { millis += 1; return millis }
    func jump(by ms: Int64) { millis += ms }
}

func makeStore(clock: TestClock = TestClock()) throws(StoreError) -> Store {
    try Store.openInMemory(now: clock.now)
}
