// Sources/TodoCore/Model/Entities.swift

public enum TaskStatus: Int64, Sendable, CaseIterable {
    case open = 0
    case done = 1
    case canceled = 2
}

/// Where a created or moved item lands among its siblings.
public enum Placement: Sendable, Equatable {
    case end
    case start
    case after(EntityID)
}

/// A task as read from the store. `parent` and `trashed` are effective values from the task tree; notes are
/// read separately, because they are the one field of a task that is unbounded and no list needs them.
public struct Task: Equatable, Sendable {
    public var id: TaskID
    public var title: String
    public var status: TaskStatus
    public var when: Day?
    public var deadline: Day?
    public var parent: TaskID?
    public var rank: String
    public var tags: Set<TagID>
    public var trashed: Bool
    public var createdAt: Int64
    public var updatedAt: Int64
    public var completedAt: Int64?
}

/// What a caller knows about a task before it exists. Everything but the title has a default, and the id, the
/// rank and the timestamps are the store's to mint.
public struct NewTask: Sendable {
    public var title: String
    public var notes: String = ""
    public var when: Day? = nil
    public var deadline: Day? = nil
    public var parent: TaskID? = nil
    public var tags: Set<TagID> = []

    public init(title: String) { self.title = title }
}

/// One field of a task set to one value. A write takes a list of these, so an edit that changes three fields
/// is one transaction, one clock and one change set rather than three of each.
public enum TaskChange: Sendable, Equatable {
    case title(String)
    case notes(String)
    case status(TaskStatus)
    case when(Day?)
    case deadline(Day?)
}

extension TaskChange {
    /// The state column this change writes, which is how a write keeps the last change for a field and drops
    /// the earlier ones. `status` carries `completed_at` with it and is keyed by the status alone.
    var field: String {
        switch self {
        case .title: "title"
        case .notes: "notes"
        case .status: "status"
        case .when: "when_day"
        case .deadline: "deadline_day"
        }
    }
}

/// A tag as read from the store. `parent` is effective, by the same rule the task tree follows: a link to a
/// missing, deleted or circular parent reads as no link and the tag shows at the root.
public struct Tag: Equatable, Sendable {
    public var id: TagID
    public var title: String
    public var parent: TagID?
    public var rank: String
    public var createdAt: Int64
    public var updatedAt: Int64
}

public enum TagChange: Sendable, Equatable {
    case title(String)
    case parent(TagID?)
}

extension TagChange {
    /// The state column this change writes; `parent` carries the new `rank` with it.
    var field: String {
        switch self {
        case .title: "title"
        case .parent: "parent"
        }
    }
}
