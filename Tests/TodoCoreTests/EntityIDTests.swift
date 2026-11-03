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

/// An id from outside, a link or one typed by hand, is what `UUID(uuidString:)` reads, in either case, and it is
/// kept lowercase, the form `EntityID()` mints and the command line prints.
@Test func anIDIsReadInEitherCaseAndKeptLowercase() throws {
    let id = EntityID()
    #expect(try EntityID(uuidString: id.rawValue) == id)
    #expect(try EntityID(uuidString: id.rawValue.uppercased()) == id)
}

/// Anything else is refused with the string as written. `UUID(uuidString:)` stops reading at a NUL and answers for
/// what came before it, so an id is read only whole.
@Test func aStringThatIsNotAWholeIDIsRefusedAsWritten() {
    let id = EntityID().rawValue
    for text in ["inbox", "42", "", " \(id)", "\(id)x", "\(id)\u{0}junk", "\(id)\u{0}"] {
        #expect(throws: EntityIDParseError(input: text)) { try EntityID(uuidString: text) }
    }
}
