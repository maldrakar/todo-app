// Sources/TodoCore/Model/TaskView.swift

/// A view as read from the store: a filter over tasks, a place in the sidebar tree, and how its results are
/// sorted and grouped. `parent` is effective, by the rule the task tree follows — a link to a missing,
/// deleted or circular parent reads as no link and the view shows at the root.
///
/// A view with no filter has no results of its own and serves as a folder; a heading inside a project is the
/// same mechanism, a child view whose filter is "listed in this view". `needsNewerApp` carries the kind this
/// version of the app could not read out of the stored definition: a view written by a newer app is reported
/// by name instead of evaluated, because a filter with a condition dropped is a list missing exactly the rows
/// that condition selected.
///
/// `kind`, `color` and `icon` are read by the rules of the Lists screen spec, section 2. An `area` stored on a
/// view with an effective parent or a filter reads as a list, since an area stands only at the root and selects
/// nothing; a colour this app has no name for reads as none; an icon is the name of a glyph in the app's own
/// set as text, which the platform maps and draws its default glyph for when it does not know the name. A
/// view written before the three existed reads as a plain list with no tile.
public struct TaskView: Equatable, Sendable {
    public let id: ViewID
    public let title: String
    public let parent: ViewID?
    public let rank: String
    public let kind: TaskViewKind
    public let color: TaskViewColor?
    public let icon: String?
    public let filter: Filter?
    public let sort: [SortKey]
    public let groupBy: GroupBy?
    public let needsNewerApp: String?
    public let createdAt: Int64
    public let updatedAt: Int64
}

/// What a view is for: a list, which opens and shows tasks, or an area, a line across the root of the tree that
/// groups the lists under it and itself opens nothing and selects nothing (ADR-0004, amendment of 2026-10-25).
/// It is written when the view is made and never changes afterwards, so no `TaskViewChange` sets it.
public enum TaskViewKind: String, Equatable, Sendable {
    case list, area
}

/// The colour of a list's tile, by name: the eleven the canvas's tiles use. The names are the core's, and what a
/// name looks like is the design system's, which names the same eleven without depending on the core; that is
/// what `CaseIterable` is for: a test walks every case to hold the two lists together.
public enum TaskViewColor: String, Equatable, Sendable, CaseIterable {
    case blue, amber, rose, green, stone, indigo, teal, pink, orange, violet, sky
}

/// What a caller knows about a view before it exists. Everything but the title has a default, and the id, the
/// rank and the timestamps are the store's to mint, the way `NewTask` leaves them. A view is a list unless it
/// is asked to be an area, and an area is made at the root with no filter or not at all (`Store.createView`).
public struct NewTaskView: Sendable {
    public let title: String
    public let parent: ViewID?
    public let kind: TaskViewKind
    public let color: TaskViewColor?
    public let icon: String?
    public let filter: Filter?
    public let sort: [SortKey]
    public let groupBy: GroupBy?

    public init(
        title: String,
        parent: ViewID? = nil,
        kind: TaskViewKind = .list,
        color: TaskViewColor? = nil,
        icon: String? = nil,
        filter: Filter? = nil,
        sort: [SortKey] = [],
        groupBy: GroupBy? = nil
    ) {
        self.title = title
        self.parent = parent
        self.kind = kind
        self.color = color
        self.icon = icon
        self.filter = filter
        self.sort = sort
        self.groupBy = groupBy
    }
}

/// One field of a view set to one value. The parent is not among them, for the reason written on
/// `TaskChange`: re-parenting also ranks the view among its new siblings, so it is `move(view:to:at:)`.
public enum TaskViewChange: Sendable, Equatable {
    case title(String)
    case filter(Filter?)
    case sort([SortKey])
    case groupBy(GroupBy?)
}

extension TaskViewChange {
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
/// deleting them works exactly as it does for a view a person created. Each wears the tile the canvas draws it
/// with, written at the same clock zero, so a colour a person chooses later outranks it as a rename does.
public enum BuiltInTaskViews {
    public static let inbox = ViewID("00000000-0000-4000-8000-000000000001")
    public static let today = ViewID("00000000-0000-4000-8000-000000000002")
    public static let upcoming = ViewID("00000000-0000-4000-8000-000000000003")
    public static let logbook = ViewID("00000000-0000-4000-8000-000000000004")
    public static let trash = ViewID("00000000-0000-4000-8000-000000000005")

    /// Day conditions are offsets from the day the query is made, so "today" and "upcoming" mean the same
    /// thing on a device that has been asleep for a week as on one opened a minute ago. Each is the
    /// `NewTaskView` a person could have asked for, so that the seed writes it as `createView` would.
    static let definitions: [(id: ViewID, rank: String, view: NewTaskView)] = [
        (inbox, "1", NewTaskView(
            title: "Inbox", color: .blue, icon: "tray",
            filter: .and([.status([.open]), .when(.empty), .parent(nil)]), sort: [SortKey(.rank)]
        )),
        (today, "2", NewTaskView(
            title: "Today", color: .amber, icon: "sun",
            filter: .and([.status([.open]), .when(.onOrBefore(0))]), sort: [SortKey(.when)]
        )),
        (upcoming, "3", NewTaskView(
            title: "Upcoming", color: .rose, icon: "calendar",
            filter: .and([.status([.open]), .when(.onOrAfter(1))]), sort: [SortKey(.when)], groupBy: .whenDay
        )),
        (logbook, "4", NewTaskView(
            title: "Logbook", color: .green, icon: "logbook",
            filter: .status([.done, .canceled]), sort: [SortKey(.completed, descending: true)]
        )),
        (trash, "5", NewTaskView(
            title: "Trash", color: .stone, icon: "trash",
            filter: .trashed(true), sort: [SortKey(.updated, descending: true)]
        )),
    ]
}

extension TaskView: TreeOrdered {}
