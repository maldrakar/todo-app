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

/// A derived id is a function of its two inputs and nothing else, the same on every call, so that two devices that
/// derive one write one row (ADR-0004, amendment of 2026-11-01).
@Test func aDerivedIDIsTheSameForTheSameBaseAndName() {
    let base = EntityID()
    #expect(EntityID.derived(from: base, "tomorrow") == EntityID.derived(from: base, "tomorrow"))
}

/// Either input changes the id: the name, the base, and the boundary between them, which the NUL keeps, so that a
/// base and a name cannot trade characters and spell the same input.
@Test func aDerivedIDDiffersByNameAndByBase() {
    let base = EntityID("a"), other = EntityID("b")
    #expect(EntityID.derived(from: base, "x") != EntityID.derived(from: base, "y"))
    #expect(EntityID.derived(from: base, "x") != EntityID.derived(from: other, "x"))
    #expect(EntityID.derived(from: EntityID("ab"), "c") != EntityID.derived(from: EntityID("a"), "bc"))
}

/// A derived id is read back by the parser every route reads an id with, so `view/<id>` opens it, and it is a UUID of
/// version 8 with the RFC 4122 variant, which no seed's `00000000-0000-4000-8000-00000000000N` can be: the thirteenth
/// hex digit is `8`, where the seeds' is `4`.
@Test func aDerivedIDReadsAsAUUIDAndCarriesVersionEight() throws {
    for name in ["", "tomorrow", "{\"kind\":\"when\"}", "ё"] {
        let id = EntityID.derived(from: BuiltInTaskViews.upcoming, name)
        #expect(try EntityID(uuidString: id.rawValue) == id)
        let digits = Array(id.rawValue)
        #expect(digits[14] == "8", "the version, the thirteenth hex digit")
        #expect(["8", "9", "a", "b"].contains(digits[19]), "the variant, the seventeenth hex digit")
    }
}

/// The derivation is kept stable for ever (ADR-0004, amendment of 2026-11-01): the digest, the NUL between the two
/// inputs and the UUID's layout are fixed by this vector, Upcoming's group one day ahead, the base Upcoming's id and
/// the name the JSON `groupView` writes for `.when(.on(1))`. It was computed once, in the first run, and checked
/// against FNV-1a 64 computed apart from the core; a change that moves it moves every group row's id on every device.
@Test func aDerivedIDIsTheOneThePlanPinned() throws {
    let name = #"{"day":{"kind":"on","offset":1},"kind":"when"}"#
    #expect(try Filter.when(.on(1)).json() == name)
    #expect(EntityID.derived(from: EntityID("00000000-0000-4000-8000-000000000003"), name) == EntityID("c9c1b9b3-294a-88a9-b517-7ef4071de355"))
}
