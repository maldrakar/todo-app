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

@Test func aStampAtTheTopOfTheRangeSaturatesInsteadOfTrapping() {
    // `HLC(raw: Int64.max)` is the largest stamp the encoding holds, and `observe` takes whatever the journal
    // or a peer hands it. Borrowing the next millisecond from there leaves the 48 bits, so the clock stops
    // instead: the top stamp is its last answer, and it repeats it rather than abort the process (#34).
    let clock = HybridClock(now: { 1_000 })
    clock.observe(HLC(raw: .max))
    let ceiling = HLC(millis: HLC.maxMillis - 1, counter: HLC.maxCounter)
    #expect(clock.next() == ceiling)
    #expect(clock.next() == ceiling)
}

@Test func theCounterCeilingSaturatesInTheLastMillisecondItCanRepresent() {
    // The same ceiling reached from below, by a local clock that fills the counter in the last millisecond
    // of the range: there is no next millisecond to borrow, so the stamp stands still.
    let clock = HybridClock(now: { HLC.maxMillis - 1 })
    for _ in 0...Int(HLC.maxCounter) { _ = clock.next() }
    #expect(clock.next() == HLC(millis: HLC.maxMillis - 1, counter: HLC.maxCounter))
}

@Test func aWallClockOutsideTheEncodingDoesNotTrap() {
    // `now()` is injected, and a device whose system clock sits outside the 48 bits — far in the future, or
    // before the epoch — must not abort either: the reading is pulled into the range before it is stamped.
    var wall = Int64.max
    let clock = HybridClock(now: { wall })
    #expect(clock.next() == HLC(millis: HLC.maxMillis - 1, counter: 0))
    wall = -1
    clock.observe(HLC(millis: 5, counter: 0))
    #expect(clock.next() == HLC(millis: HLC.maxMillis - 1, counter: 1))
}
