// Sources/TodoCore/Model/View.swift

/// A view as read from the store: a filter over tasks, a place in the sidebar tree, and how its results are
/// sorted and grouped. `parent` is effective, by the rule the task tree follows — a link to a missing,
/// deleted or circular parent reads as no link and the view shows at the root.
///
/// A view with no filter has no results of its own and serves as a folder; a heading inside a project is the
/// same mechanism, a child view whose filter is "listed in this view". `needsNewerApp` carries the kind this
/// version of the app could not read out of the stored definition: a view written by a newer app is reported
/// by name instead of evaluated, because a filter with a condition dropped is a list missing exactly the rows
/// that condition selected.
public struct TodoView: Equatable, Sendable {
    public let id: ViewID
    public let title: String
    public let parent: ViewID?
    public let rank: String
    public let filter: Filter?
    public let sort: [SortKey]
    public let groupBy: GroupBy?
    public let needsNewerApp: String?
    public let createdAt: Int64
    public let updatedAt: Int64
}

/// What a caller knows about a view before it exists. Everything but the title has a default, and the id, the
/// rank and the timestamps are the store's to mint, the way `NewTask` leaves them.
public struct NewView: Sendable {
    public let title: String
    public let parent: ViewID?
    public let filter: Filter?
    public let sort: [SortKey]
    public let groupBy: GroupBy?

    public init(
        title: String,
        parent: ViewID? = nil,
        filter: Filter? = nil,
        sort: [SortKey] = [],
        groupBy: GroupBy? = nil
    ) {
        self.title = title
        self.parent = parent
        self.filter = filter
        self.sort = sort
        self.groupBy = groupBy
    }
}

/// One field of a view set to one value. The parent is not among them, for the reason written on
/// `TaskChange`: re-parenting also ranks the view among its new siblings, so it is `move(view:to:at:)`.
public enum ViewChange: Sendable, Equatable {
    case title(String)
    case filter(Filter?)
    case sort([SortKey])
    case groupBy(GroupBy?)
}

extension ViewChange {
    /// The state column this change writes, which is how a write keeps the last change for a field.
    var field: String {
        switch self {
        case .title: "title"
        case .filter: "filter"
        case .sort: "sort"
        case .groupBy: "group_by"
        }
    }
}

/// The five views every store starts with. The ids are fixed so that two devices seed the same rows and sync
/// merges them instead of ending up with two Inboxes; the seed carries clock zero, so any edit a person makes
/// to one of them outranks it and survives every later open. They are ordinary rows: nesting, editing and
/// deleting them works exactly as it does for a view a person created.
public enum BuiltInViews {
    public static let inbox = ViewID("00000000-0000-4000-8000-000000000001")
    public static let today = ViewID("00000000-0000-4000-8000-000000000002")
    public static let upcoming = ViewID("00000000-0000-4000-8000-000000000003")
    public static let logbook = ViewID("00000000-0000-4000-8000-000000000004")
    public static let trash = ViewID("00000000-0000-4000-8000-000000000005")

    /// Day conditions are offsets from the day the query is made, so "today" and "upcoming" mean the same
    /// thing on a device that has been asleep for a week as on one opened a minute ago.
    static let definitions: [(id: ViewID, title: String, rank: String, filter: Filter, sort: [SortKey], groupBy: GroupBy?)] = [
        (inbox, "Inbox", "1", .and([.status([.open]), .when(.empty), .parent(nil)]), [SortKey(.rank)], nil),
        (today, "Today", "2", .and([.status([.open]), .when(.onOrBefore(0))]), [SortKey(.when)], nil),
        (upcoming, "Upcoming", "3", .and([.status([.open]), .when(.onOrAfter(1))]), [SortKey(.when)], .whenDay),
        (logbook, "Logbook", "4", .status([.done, .canceled]), [SortKey(.completed, descending: true)], nil),
        (trash, "Trash", "5", .trashed(true), [SortKey(.updated, descending: true)], nil),
    ]
}

extension TodoView: TreeOrdered {}
