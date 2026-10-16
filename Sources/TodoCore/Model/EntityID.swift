#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Identifier of a task, tag or view: a lowercase UUID string. One type for all three keeps the journal generic.
public struct EntityID: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: String

    /// Without an argument this mints a fresh identifier; with one it wraps what storage or sync already holds.
    public init(_ rawValue: String = UUID().uuidString.lowercased()) { self.rawValue = rawValue }

    public var description: String { rawValue }

    public static func < (lhs: EntityID, rhs: EntityID) -> Bool { lhs.rawValue < rhs.rawValue }
}

public typealias TaskID = EntityID
public typealias TagID = EntityID
public typealias ViewID = EntityID

/// Why a string is not an id. It carries the string as written, because what reads an id from outside, a route
/// among them, names it back to the person who wrote it.
package struct EntityIDParseError: Error, Equatable, Sendable {
    let input: String

    init(input: String) { self.input = input }
}

extension EntityID {
    /// An id read from a string from outside, a link or one typed by hand: what `UUID(uuidString:)` reads, in
    /// either case, kept lowercase, the form `EntityID()` mints and the command line prints. Anything else is
    /// refused with the string as written (`docs/style.md`, "A failure says what failed").
    ///
    /// Read whole: `UUID(uuidString:)` stops reading at a NUL and answers for what came before it, so the id it
    /// read is held against the string, both lowercase, and a string with anything after the id is refused.
    ///
    /// `package`, as `String.trimmed()` is: every caller is in this package, the routes that read an id from a
    /// path, and a member widens only as far as a call site forces (`docs/style.md`, "Tightest visibility by
    /// default"). Beside `init(_:)`, which wraps what the store already holds, it makes `.map(EntityID.init)`
    /// ambiguous, so the core names that one `init(_:)` where it maps.
    package init(uuidString text: String) throws(EntityIDParseError) {
        guard let read = UUID(uuidString: text)?.uuidString.lowercased(), read == text.lowercased() else {
            throw EntityIDParseError(input: text)
        }
        self.init(read)
    }
}
