// Sources/TodoCore/Model/Tag.swift

/// A tag as read from the store. `parent` is effective, by the same rule the task tree follows: a link to a
/// missing, deleted or circular parent reads as no link and the tag shows at the root.
public struct Tag: Equatable, Sendable {
    public let id: TagID
    public let title: String
    public let parent: TagID?
    public let rank: String
    public let createdAt: Int64
    public let updatedAt: Int64
}

/// One field of a tag set to one value. The parent is not among them, for the reason written on `TaskChange`:
/// re-parenting also ranks the tag among its new siblings, so it is `move(tag:to:at:)`, with `move(tag:at:)`
/// for a reorder inside one list.
public enum TagChange: Sendable, Equatable {
    case title(String)
}

extension TagChange {
    /// The state column this change writes, which is how a write keeps the last change for a field.
    var field: String {
        switch self {
        case .title: "title"
        }
    }
}
