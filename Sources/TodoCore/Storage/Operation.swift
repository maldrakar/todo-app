// Sources/TodoCore/Storage/Operation.swift
import SQLiteKit

/// `Sendable` is not decoration here: `FieldMap` below keys two static lets by this type, and a global keyed
/// by a non-Sendable type does not pass Swift 6's concurrency checking. `CaseIterable` is what lets the test
/// that holds `FieldMap` and `Schema` together walk every kind.
public enum EntityKind: String, Sendable, CaseIterable {
    case task, tag, view
    case taskTag = "task_tag"
    case viewItem = "view_item"
}

/// One field of one entity set to one value at one clock by one device. The unit of the journal and of sync,
/// and a record of something that already happened: nothing about it changes after it is built.
public struct Operation: Equatable {
    public let entity: EntityKind
    public let entityID: String
    public let field: String
    public let value: Value
    public let clock: HLC
    public let device: String

    public init(entity: EntityKind, entityID: String, field: String, value: Value, clock: HLC, device: String) {
        self.entity = entity
        self.entityID = entityID
        self.field = field
        self.value = value
        self.clock = clock
        self.device = device
    }

    /// Entity id of a pair entity, in the column order of its table: task then tag for `task_tag`, view then
    /// task for `view_item`. All three id types are the same type, so nothing but this order tells them apart.
    public static func pairID(_ first: EntityID, _ second: EntityID) -> String {
        "\(first.rawValue)/\(second.rawValue)"
    }

    static func splitPair(_ id: String) -> (String, String)? {
        let parts = id.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return (String(parts[0]), String(parts[1]))
    }
}

/// Journal field names are the state column names. A field outside this map is journaled but not applied,
/// which is how an older app keeps operations from a newer one until it migrates.
///
/// The two maps restate what the DDL in `Schema` says, and a copy that drifts is expensive in both directions,
/// so `FieldMapTests` walks `PRAGMA table_info` and requires the two to agree. They are readable for that test
/// and not for anyone else; the rest of the module asks `isKnown` and `acceptsNull`.
enum FieldMap {
    static let known: [EntityKind: Set<String>] = [
        .task: ["title", "notes", "status", "when_day", "deadline_day", "parent", "rank", "trashed", "deleted", "created_at", "completed_at"],
        .tag: ["title", "parent", "rank", "deleted", "created_at"],
        .view: ["title", "parent", "rank", "filter", "sort", "group_by", "deleted", "created_at"],
        .taskTag: ["present"],
        .viewItem: ["present", "rank"],
    ]

    /// The fields whose column accepts a null. Every other column in the map is NOT NULL, and the schema
    /// refuses a null for it rather than fall back to its default, which `applyToState` has to know before it
    /// writes rather than find out from a failed statement.
    static let nullable: [EntityKind: Set<String>] = [
        .task: ["when_day", "deadline_day", "parent", "completed_at"],
        .tag: ["parent"],
        .view: ["parent", "filter", "group_by"],
        .taskTag: [],
        .viewItem: [],
    ]

    static func table(_ kind: EntityKind) -> String {
        switch kind {
        case .task: return "tasks"
        case .tag: return "tags"
        case .view: return "views"
        case .taskTag: return "task_tags"
        case .viewItem: return "view_items"
        }
    }

    static func isKnown(_ kind: EntityKind, _ field: String) -> Bool {
        known[kind]?.contains(field) ?? false
    }

    static func acceptsNull(_ kind: EntityKind, _ field: String) -> Bool {
        nullable[kind]?.contains(field) ?? false
    }
}
