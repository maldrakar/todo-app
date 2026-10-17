import Testing
import FeatureModule

/// What a stand-in reader refuses: the string it was handed, as a reader of an id from outside carries it.
private struct NotANumber: Error {
    let input: String
}

/// A reader with nothing of an id in it, so that the rule is held without the core: it reads a number, and
/// refuses anything else.
private func number(_ text: String) throws(NotANumber) -> Int {
    guard let value = Int(text) else { throw NotANumber(input: text) }
    return value
}

/// The id after a route's word is the segment at the front of what is left of the path, read by the route's own
/// reader and taken off the path, which leaves the rest for the next reader.
@Test func anIDIsReadFromTheFrontOfThePath() throws {
    var path: ArraySlice = ["42", "task", "7"]
    #expect(try path.popID(readBy: number) == 42)
    #expect(path == ["task", "7"])
}

/// Nothing at all where an id must stand is an empty id, the empty segment a doubled or trailing slash leaves is
/// that segment, unknown, and what the reader refuses is refused as written.
@Test func whatIsNotAnIDIsRefusedWithTheSegmentAsWritten() {
    var nothing: ArraySlice<String> = []
    #expect(throws: RouteError.notAnID("")) { try nothing.popID(readBy: number) }
    var slash: ArraySlice = ["", "42"]
    #expect(throws: RouteError.unknownSegment("")) { try slash.popID(readBy: number) }
    var word: ArraySlice = ["inbox"]
    #expect(throws: RouteError.notAnID("inbox")) { try word.popID(readBy: number) }
}
