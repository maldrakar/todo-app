#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum FilterError: Error, Equatable, Sendable {
    /// The stored definition uses a condition, a status or a sort field this version of the app does not
    /// know. The name is what a view shows the person instead of a list that would be missing rows.
    case unsupported(kind: String)
    case malformed(String)
}

/// Offsets are days relative to "today" as passed with the query; bounds are inclusive. They are `Int64`
/// and not `Int` because they come out of a document another device wrote and `Int` is 32 bits on wasm32:
/// the same stored filter has to mean the same thing on both, rather than reading on one platform and
/// failing to decode on the other (plan, Global Constraints).
public enum DayCondition: Equatable, Sendable {
    case empty
    case on(Int64)
    case onOrBefore(Int64)
    case onOrAfter(Int64)
    case between(Int64, Int64)
}

/// A view's filter: a tree of conditions over tasks.
public indirect enum Filter: Equatable, Sendable {
    case status([TaskStatus])
    case when(DayCondition)
    case deadline(DayCondition)
    case hasTag(TagID)
    /// `nil` selects tasks at the root.
    case parent(TaskID?)
    /// Tasks in the manual list of a view; the way a heading holds its tasks.
    case listedIn(ViewID)
    case trashed(Bool)
    case and([Filter])
    case or([Filter])
    case not(Filter)
}

public enum SortField: String, Sendable, Codable, CaseIterable {
    case when, deadline, title, created, updated, completed, rank
}

public struct SortKey: Equatable, Sendable, Codable {
    public let field: SortField
    public let descending: Bool

    public init(_ field: SortField, descending: Bool = false) {
        self.field = field
        self.descending = descending
    }

    private enum CodingKeys: String, CodingKey { case field, descending }

    /// Decoded by hand so that a sort field this version does not know reads as an unsupported kind, the
    /// way an unknown condition does, instead of as a decoding failure that says nothing about the view.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let name = try c.decode(String.self, forKey: .field)
        guard let field = SortField(rawValue: name) else { throw FilterError.unsupported(kind: "sort \(name)") }
        self.init(field, descending: try c.decode(Bool.self, forKey: .descending))
    }
}

/// The first caller is the view row of Task 9; a filter neither groups nor reads a group.
public enum GroupBy: String, Sendable, Codable, CaseIterable {
    case whenDay = "when_day"
    case deadlineDay = "deadline_day"
    case tag, parent, status
}

// MARK: - JSON

/// How deep a document may nest before the core refuses it, on the way in and on the way out alike. Every
/// walk over a filter recurses \u2014 Foundation's scanner and decoder, the encoder, and `FilterCompiler` \u2014 and on
/// wasm32, where the stack is 64 KiB, they give out between 60 and 100 levels, the compiler first. Neither
/// trap can be caught, and a view is read on every open (#34), so the depth is counted here, without
/// recursion, before the decoder sees the bytes and before a filter is written to a row. A filter a person
/// builds is a handful of levels deep, and a group costs two: the object and its list.
///
/// A device's own state is JSON in a row as well, read through the same decoder at every open of the module
/// that keeps it, so `Store.deviceState(_:as:)` and `setDeviceState(_:_:)` hold its value to the same bound.
let maximumDepth = 32

/// The one encoder of the core's JSON: a filter and a sort here, and a device state's value in the store.
func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    // Sorted keys because this is the on-disk and on-the-wire format: two devices that save the same filter
    // have to produce the same bytes, or last-write-wins compares strings that differ only in key order. A
    // device state never leaves the device, and the same bytes for the same value cost it nothing.
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return encoder
}

/// `JSONEncoder` refuses two things: a value that encodes nothing at all, and a `Double` that is not a
/// number. Neither can happen here \u2014 every case below writes its `kind` first, and nothing in a filter is a
/// `Double` \u2014 but the failure is reported rather than trapped, because a proof that a trap cannot fire is
/// worth less than a caller that can say what went wrong (`docs/style.md`, "A trap is a bug").
private func jsonString<T: Encodable>(_ value: T) throws(FilterError) -> String {
    do {
        return String(decoding: try makeEncoder().encode(value), as: UTF8.self)
    } catch {
        throw .malformed(String(describing: error))
    }
}

private func decodeJSON<T: Decodable>(_ type: T.Type, from json: String) throws(FilterError) -> T {
    guard nestingDepth(of: json) <= maximumDepth else {
        throw .malformed("nested deeper than \(maximumDepth) levels")
    }
    do {
        return try JSONDecoder().decode(type, from: Data(json.utf8))
    } catch let error as FilterError {
        // What the decoders below throw for a kind they do not know; it names the kind and passes through.
        throw error
    } catch {
        throw .malformed(String(describing: error))
    }
}

/// The deepest nesting of objects and arrays in a document, counted in one pass. A brace inside a string is
/// text — a tag id or a title can hold one — so the scan has to know when it is inside one.
func nestingDepth(of json: String) -> Int {
    var depth = 0, deepest = 0
    var inString = false, escaped = false
    for byte in json.utf8 {
        if escaped { escaped = false; continue }
        if inString {
            if byte == UInt8(ascii: "\\") { escaped = true }
            if byte == UInt8(ascii: "\"") { inString = false }
            continue
        }
        switch byte {
        case UInt8(ascii: "\""): inString = true
        case UInt8(ascii: "{"), UInt8(ascii: "["):
            depth += 1
            deepest = max(deepest, depth)
        case UInt8(ascii: "}"), UInt8(ascii: "]"): depth -= 1
        default: break
        }
    }
    return deepest
}

extension Filter {
    /// Internal: the store writes the filter of a view, and nothing outside the core does. The CLI reads one
    /// from a command line through `init(json:)`, which is why the other half of the codec is public.
    ///
    /// It throws on the same bound that `init(json:)` refuses, so that a write cannot leave a view holding a
    /// filter this app wrote and can never open again. A caller reports it where the filter was built; a
    /// refusal at the write is a message, a refusal at the read is a view that is gone.
    func json() throws(FilterError) -> String {
        let json = try jsonString(self)
        guard nestingDepth(of: json) <= maximumDepth else {
            throw .malformed("nested deeper than \(maximumDepth) levels")
        }
        return json
    }

    public init(json: String) throws(FilterError) {
        self = try decodeJSON(Filter.self, from: json)
    }
}

extension SortKey {
    static func json(_ keys: [SortKey]) throws(FilterError) -> String { try jsonString(keys) }

    /// An unknown sort field reads as an unsupported kind that names it; anything else that is not a list of
    /// sort keys is malformed.
    static func parse(json: String) throws(FilterError) -> [SortKey] {
        try decodeJSON([SortKey].self, from: json)
    }
}

extension DayCondition: Codable {
    private enum CodingKeys: String, CodingKey { case kind, offset, from, to }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "empty": self = .empty
        case "on": self = .on(try c.decode(Int64.self, forKey: .offset))
        case "on_or_before": self = .onOrBefore(try c.decode(Int64.self, forKey: .offset))
        case "on_or_after": self = .onOrAfter(try c.decode(Int64.self, forKey: .offset))
        case "between": self = .between(try c.decode(Int64.self, forKey: .from), try c.decode(Int64.self, forKey: .to))
        default: throw FilterError.unsupported(kind: kind)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .empty:
            try c.encode("empty", forKey: .kind)
        case .on(let n):
            try c.encode("on", forKey: .kind)
            try c.encode(n, forKey: .offset)
        case .onOrBefore(let n):
            try c.encode("on_or_before", forKey: .kind)
            try c.encode(n, forKey: .offset)
        case .onOrAfter(let n):
            try c.encode("on_or_after", forKey: .kind)
            try c.encode(n, forKey: .offset)
        case .between(let a, let b):
            try c.encode("between", forKey: .kind)
            try c.encode(a, forKey: .from)
            try c.encode(b, forKey: .to)
        }
    }
}

/// The conformance is what `init(json:)` and `json()` are written on top of, and the depth bound lives in
/// those two: a filter read with `JSONDecoder` directly is read without it.
extension Filter: Codable {
    private enum CodingKeys: String, CodingKey { case kind, statuses, day, tag, task, view, value, filters, filter }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        // A status another device wrote is a condition this version cannot evaluate either: dropping the
        // number would leave a filter that still runs and a list missing exactly the rows it selected.
        case "status": self = .status(try c.decode([Int64].self, forKey: .statuses).map {
            guard let status = TaskStatus(rawValue: $0) else { throw FilterError.unsupported(kind: "status \($0)") }
            return status
        })
        case "when": self = .when(try c.decode(DayCondition.self, forKey: .day))
        case "deadline": self = .deadline(try c.decode(DayCondition.self, forKey: .day))
        case "has_tag": self = .hasTag(TagID(try c.decode(String.self, forKey: .tag)))
        // An explicit `null` is the root, an absent key is a newer app selecting parents in a way this one
        // cannot read: without the check the second reads as the first and draws the whole root list.
        case "parent":
            guard c.contains(.task) else { throw FilterError.unsupported(kind: "parent") }
            self = .parent(try c.decodeIfPresent(String.self, forKey: .task).map(TaskID.init(_:)))
        case "listed_in": self = .listedIn(ViewID(try c.decode(String.self, forKey: .view)))
        case "trashed": self = .trashed(try c.decode(Bool.self, forKey: .value))
        case "and": self = .and(try c.decode([Filter].self, forKey: .filters))
        case "or": self = .or(try c.decode([Filter].self, forKey: .filters))
        case "not": self = .not(try c.decode(Filter.self, forKey: .filter))
        default: throw FilterError.unsupported(kind: kind)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .status(let statuses):
            try c.encode("status", forKey: .kind)
            try c.encode(statuses.map(\.rawValue), forKey: .statuses)
        case .when(let day):
            try c.encode("when", forKey: .kind)
            try c.encode(day, forKey: .day)
        case .deadline(let day):
            try c.encode("deadline", forKey: .kind)
            try c.encode(day, forKey: .day)
        case .hasTag(let tag):
            try c.encode("has_tag", forKey: .kind)
            try c.encode(tag.rawValue, forKey: .tag)
        // `encode` of an optional writes the key with `null`, which is what tells the root apart from a
        // parent this version cannot read when the filter is decoded again.
        case .parent(let task):
            try c.encode("parent", forKey: .kind)
            try c.encode(task?.rawValue, forKey: .task)
        case .listedIn(let view):
            try c.encode("listed_in", forKey: .kind)
            try c.encode(view.rawValue, forKey: .view)
        case .trashed(let flag):
            try c.encode("trashed", forKey: .kind)
            try c.encode(flag, forKey: .value)
        case .and(let filters):
            try c.encode("and", forKey: .kind)
            try c.encode(filters, forKey: .filters)
        case .or(let filters):
            try c.encode("or", forKey: .kind)
            try c.encode(filters, forKey: .filters)
        case .not(let filter):
            try c.encode("not", forKey: .kind)
            try c.encode(filter, forKey: .filter)
        }
    }
}
