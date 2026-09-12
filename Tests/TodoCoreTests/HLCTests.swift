import Testing
@testable import TodoCore

@Test func rawEncodingPreservesOrder() {
    let a = HLC(millis: 1_000, counter: 5), b = HLC(millis: 1_000, counter: 6), c = HLC(millis: 1_001, counter: 0)
    #expect(a < b && b < c)
    #expect(HLC(raw: a.raw) == a)
    #expect(a.raw < b.raw && b.raw < c.raw)
}

@Test func nextIsMonotonicEvenWhenTheWallClockStalls() {
    var wall: Int64 = 1_000
    let clock = HybridClock(now: { wall })
    let a = clock.next()
    let b = clock.next()
    #expect(a == HLC(millis: 1_000, counter: 0))
    #expect(b == HLC(millis: 1_000, counter: 1))
    wall = 999
    #expect(clock.next() == HLC(millis: 1_000, counter: 2))
    wall = 2_000
    #expect(clock.next() == HLC(millis: 2_000, counter: 0))
}

@Test func observeJumpsForwardToARemoteClockFromTheFuture() {
    var wall: Int64 = 1_000
    let clock = HybridClock(now: { wall })
    _ = clock.next()
    clock.observe(HLC(millis: 6_000, counter: 3))
    #expect(clock.next() == HLC(millis: 6_000, counter: 4))
    wall = 6_000
    #expect(clock.next() == HLC(millis: 6_000, counter: 5))
    wall = 6_001
    #expect(clock.next() == HLC(millis: 6_001, counter: 0))
}

@Test func observeIgnoresARemoteClockFromThePast() {
    let clock = HybridClock(now: { 5_000 })
    _ = clock.next()
    clock.observe(HLC(millis: 100, counter: 9))
    #expect(clock.next() == HLC(millis: 5_000, counter: 1))
}

@Test func theCounterCeilingBorrowsTheNextMillisecond() {
    // A bulk import inside one millisecond must not abort the process; it may only cost a millisecond.
    let clock = HybridClock(now: { 1_000 })
    for _ in 0...Int(HLC.maxCounter) { _ = clock.next() }
    #expect(clock.next() == HLC(millis: 1_001, counter: 0))
}

@Test func rawDecodesEveryStoredValue() {
    // Journal rows are decoded without validation, so even a value this version would never write reads back
    // as what it sorts as instead of trapping.
    #expect(HLC(raw: -1).raw == -1)
    #expect(HLC(raw: 0) == HLC(millis: 0, counter: 0))
    #expect(HLC(raw: -1) < HLC(raw: 0))
}
