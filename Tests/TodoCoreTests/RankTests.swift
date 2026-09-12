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
