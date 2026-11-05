import Testing
@testable import TodoCore

@Test func initialKeyAndNeighbours() {
    #expect(Rank.initial == "i")
    #expect(Rank.between(nil, nil) == "i")
    #expect(Rank.between(nil, "i") == "9")
    #expect(Rank.between("i", nil) == "r")
    #expect(Rank.between("9", "i") == "d")
}

@Test func betweenAlwaysSortsStrictlyBetween() {
    var keys = ["i"]
    // Insert 200 keys at random positions and at both ends; the list must stay strictly sorted.
    var seed: UInt64 = 42
    for _ in 0..<200 {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        let position = Int(seed >> 33) % (keys.count + 1)
        let lower = position == 0 ? nil : keys[position - 1]
        let upper = position == keys.count ? nil : keys[position]
        let key = Rank.between(lower, upper)
        if let lower { #expect(lower < key, "\(lower) < \(key)") }
        if let upper { #expect(key < upper, "\(key) < \(upper)") }
        #expect(Rank.isValid(key))
        keys.insert(key, at: position)
    }
    #expect(keys == keys.sorted())
    #expect(Set(keys).count == keys.count)
}

@Test func adjacentKeysGetALongerKeyBetweenThem() {
    let k = Rank.between("a", "b")
    #expect("a" < k && k < "b")
    #expect(k.count == 2)
    let z = Rank.between("z", nil)
    #expect("z" < z)
}

@Test func validityRejectsEmptyTrailingZeroAndForeignCharacters() {
    #expect(Rank.isValid("a0z"))
    #expect(!Rank.isValid(""))
    #expect(!Rank.isValid("a0"))
    #expect(!Rank.isValid("A"))
    #expect(!Rank.isValid("a-b"))
}

@Test func toleratesNeighboursThatAMergeCanProduce() {
    // Equal ranks arise when two devices append to the same list offline; a key outside the alphabet arises
    // from a corrupt row or a newer version. Neither may abort the process.
    for (lower, upper) in [("k", "k"), ("m", "d"), ("k", ""), ("k", "A")] {
        let key = Rank.between(lower, upper)
        #expect(lower < key, "\(lower) < \(key)")
        #expect(Rank.isValid(key))
    }
    let afterBrokenLower = Rank.between("A", "i")
    #expect(afterBrokenLower < "i")
    #expect(Rank.isValid(afterBrokenLower))
}

/// Several keys for one gap are halved out of it: the next key after the last would grow a digit every five keys, so that
/// pinning the 13,680 rows above a drop wrote some 19 MB of ranks (#176's measure), where halving keeps them a few digits.
/// They stand in order between the neighbours, with the neighbours a merge can leave too.
@Test func severalKeysForOneGapAreHalvedOutOfIt() throws {
    func expectOrdered(_ keys: [String], after lower: String?, before upper: String?) {
        #expect(keys.allSatisfy(Rank.isValid))
        #expect(zip(keys, keys.dropFirst()).allSatisfy { $0 < $1 })
        if let lower, let first = keys.first { #expect(lower < first) }
        if let upper, let last = keys.last { #expect(last < upper) }
    }
    let many = Rank.between(nil, nil, count: 20_000)
    #expect(many.count == 20_000)
    expectOrdered(many, after: nil, before: nil)
    #expect(try #require(many.map(\.count).max()) <= 6)
    let gap = Rank.between("a", "b", count: 1_000)
    expectOrdered(gap, after: "a", before: "b")
    #expect(try #require(gap.map(\.count).max()) <= 5)
    #expect(Rank.between("a", "b", count: 1) == [Rank.between("a", "b")], "one key is the one `between` gives")
    #expect(Rank.between("a", "b", count: 0).isEmpty)
    let unordered = Rank.between("z", "a", count: 3)
    expectOrdered(unordered, after: "z", before: nil)
}
