/// One SQLite value: what a column holds and what a parameter binds.
public enum Value: Equatable, Sendable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob([UInt8])

    public init(_ s: String?) { self = s.map { .text($0) } ?? .null }
    public init(_ i: Int64?) { self = i.map { .integer($0) } ?? .null }
    public init(_ i: Int32?) { self = i.map { .integer(Int64($0)) } ?? .null }
    public init(_ b: Bool) { self = .integer(b ? 1 : 0) }

    /// Reading a column without a `switch`. One accessor per case would be symmetric but idle: no column of
    /// schema version 1 is `REAL` or `BLOB`, so `real` and `blob` are read by matching the case, and an
    /// accessor for them is written when the first caller needs one.
    public var isNull: Bool { if case .null = self { return true } else { return false } }
    public var int64: Int64? { if case .integer(let v) = self { return v } else { return nil } }
    public var string: String? { if case .text(let v) = self { return v } else { return nil } }
}
