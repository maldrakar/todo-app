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
