// Sources/TodoCore/Model/Task.swift

public enum TaskStatus: Int64, Sendable, CaseIterable {
    case open = 0
    case done = 1
    case canceled = 2
}

/// A task as read from the store, and a value that never changes after the read: `parent` and `trashed` are
/// effective values from the task tree, so a copy kept across a write would describe a tree that has moved.
/// Notes are read separately, because they are the one field of a task that is unbounded and no list needs
/// them.
public struct Task: Equatable, Sendable {
    public let id: TaskID
    public let title: String
    public let status: TaskStatus
    public let when: Day?
    public let deadline: Day?
    public let parent: TaskID?
    public let rank: String
    public let tags: Set<TagID>
    public let trashed: Bool
    public let createdAt: Int64
    public let updatedAt: Int64
    public let completedAt: Int64?
}

/// What a caller knows about a task before it exists. Everything but the title has a default, and the id, the
/// rank and the timestamps are the store's to mint.
public struct NewTask: Sendable {
    public let title: String
    public let notes: String
    public let when: Day?
    public let deadline: Day?
    public let parent: TaskID?
    public let tags: Set<TagID>

    public init(
        title: String,
        notes: String = "",
        when: Day? = nil,
        deadline: Day? = nil,
        parent: TaskID? = nil,
        tags: Set<TagID> = []
    ) {
        self.title = title
        self.notes = notes
        self.when = when
        self.deadline = deadline
        self.parent = parent
        self.tags = tags
    }
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
