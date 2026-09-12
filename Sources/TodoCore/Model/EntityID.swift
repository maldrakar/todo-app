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
