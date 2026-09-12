import Testing
@testable import TodoCore

@Test func generatedIDsAreLowercaseUUIDsAndUnique() {
    let a = EntityID.generate(), b = EntityID.generate()
    #expect(a != b)
    #expect(a.rawValue.count == 36)
    #expect(a.rawValue == a.rawValue.lowercased())
    #expect(a.description == a.rawValue)
}

@Test func idsCompareByRawValue() {
    #expect(EntityID("a") < EntityID("b"))
    #expect(EntityID("x") == EntityID("x"))
}
