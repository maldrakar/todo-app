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
    package init(uuidString text: String) throws(EntityIDParseError) {
        guard let read = UUID(uuidString: text)?.uuidString.lowercased(), read == text.lowercased() else {
            throw EntityIDParseError(input: text)
        }
        self.init(read)
    }
}

extension EntityID {
    /// An id derived from another and a name, the same on every device and every platform: FNV-1a 64 over the
    /// UTF-8 of "<base>\u{0}<name>", once from the standard basis and once more from the first result, the two
    /// words written as a UUID with version 8 and the RFC 4122 variant. Two devices that derive the same id write
    /// one row, and the journal merges their writes (ADR-0003).
    ///
    /// `Hasher` would not do, since it is seeded anew in every process. The function is kept stable for ever, as a
    /// group row's id is this function of its list's id and its condition (ADR-0004, amendment of 2026-11-01), and
    /// `aDerivedIDIsTheOneThePlanPinned` holds it to one vector. UUID-shaped, because every route reads an id with
    /// `init(uuidString:)`; version 8 is the RFC's for an id laid out by its own rule, and it keeps a derived id
    /// apart from the seeds', whose version digit is 4.
    public static func derived(from base: EntityID, _ name: String) -> EntityID {
        let bytes = Array("\(base.rawValue)\u{0}\(name)".utf8)
        let high = fnv1a64(bytes, from: fnvOffsetBasis)
        let low = fnv1a64(bytes, from: high)
        let version = (high & ~0xF000) | 0x8000
        let variant = (low & 0x3FFF_FFFF_FFFF_FFFF) | 0x8000_0000_0000_0000
        let hex = hexDigits(version) + hexDigits(variant)
        let groups = [hex[0..<8], hex[8..<12], hex[12..<16], hex[16..<20], hex[20..<32]]
        return EntityID(groups.map { String(decoding: $0, as: UTF8.self) }.joined(separator: "-"))
    }

    private static let fnvOffsetBasis: UInt64 = 0xCBF2_9CE4_8422_2325
    private static let fnvPrime: UInt64 = 0x0000_0100_0000_01B3

    private static func fnv1a64(_ bytes: [UInt8], from basis: UInt64) -> UInt64 {
        var hash = basis
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* fnvPrime
        }
        return hash
    }

    /// The sixteen lowercase hex digits of a word, most significant first, as UTF-8.
    private static func hexDigits(_ word: UInt64) -> [UInt8] {
        let digits = Array("0123456789abcdef".utf8)
        return (0..<16).reversed().map { digits[Int(truncatingIfNeeded: (word >> (UInt64($0) * 4)) & 0xF)] }
    }
}
