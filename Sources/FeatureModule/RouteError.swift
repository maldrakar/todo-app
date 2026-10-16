// Sources/FeatureModule/RouteError.swift

/// Why a string is not a route, naming the segment.
///
/// A route's text form is data from outside, a link, a restored window or the web's address bar, so a string that
/// does not read is refused with a typed error that names the offending segment, and nothing traps (spec section
/// 2, `docs/style.md`). Each route reads its own part of the path and throws this for it, which is why it sits
/// beside `RouteValue` and not with any one route.
public enum RouteError: Error, Equatable, Sendable {
    /// A segment of the path no route has a place for, as written: the empty one a doubled or trailing slash
    /// leaves, and whatever stands before the first slash of a string that does not begin with one.
    case unknownSegment(String)
    /// A word a route knows where it cannot stand: `task` before `view`, either of them a second time, and
    /// `quick-entry` a second time in the query.
    case segmentOutOfPlace(String)
    /// What stands where an id must, as written, which does not read whole as an id, and the empty string when
    /// nothing stands there.
    case notAnID(String)
    /// A query item no route has a place for, as written: one with a value, and the empty one, included.
    case unknownQuery(String)
}

extension ArraySlice where Element == String {
    /// The id after a route's word, taken from the front of what is left of the path, which leaves the rest for
    /// the next reader.
    ///
    /// One rule for every route that reads an id, so no route repeats it: nothing at all where the id must stand
    /// is an empty id; the empty segment a doubled or trailing slash leaves is that segment, unknown; and what
    /// `read`, the route's reader of its id, refuses is refused as written. Generic over the reader, because this
    /// target depends on nothing (ADR-0007, amendment of 2026-10-15) and an id is the core's.
    package mutating func popID<ID, Failure: Error>(readBy read: (String) throws(Failure) -> ID) throws(RouteError) -> ID {
        guard let segment = popFirst() else { throw .notAnID("") }
        guard !segment.isEmpty else { throw .unknownSegment("") }
        do {
            return try read(segment)
        } catch {
            throw .notAnID(segment)
        }
    }
}
