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
