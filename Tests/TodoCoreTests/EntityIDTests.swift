import Testing
@testable import TodoCore

@Test func freshIDsAreLowercaseUUIDsAndUnique() {
    let a = EntityID(), b = EntityID()
    #expect(a != b)
    #expect(a.rawValue.count == 36)
    #expect(a.rawValue == a.rawValue.lowercased())
    #expect(a.description == a.rawValue)
}

@Test func idsCompareByRawValue() {
    #expect(EntityID("a") < EntityID("b"))
    #expect(EntityID("x") == EntityID("x"))
}
