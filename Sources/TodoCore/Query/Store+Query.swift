// Sources/TodoCore/Query/Store+Query.swift
import SQLiteKit

/// What a group of a page is keyed by. The core groups only by the fields it has: a calendar day, a tag, a
/// parent, a status. Grouping by the day something was completed belongs to the UI, which knows the time
/// zone that turns a timestamp into a day; the core never does (spec, "Built-in views").
public enum GroupKey: Hashable, Sendable {
    case day(Day?)
    case tag(TagID?)
    case parent(TaskID?)
    case status(TaskStatus)
}

/// What one opened view shows: the view itself, then its sections.
///
/// `Section` and `Group` are nested because neither means anything outside a page, and because both names
/// are taken where this type is consumed: `Section` is SwiftUI's, and a top-level `TaskGroup` would shadow
/// `_Concurrency.TaskGroup` the way `Task` once shadowed `_Concurrency.Task` (#42). Qualified by the page
/// they belong to, they cannot collide with anything.
public struct TaskViewPage: Equatable, Sendable {
    /// One section of a page: a child view's tasks, or, when `view` is nil, the page's own remainder.
    public struct Section: Equatable, Sendable {
        public let view: TaskView?
        public let groups: [Group]
    }

    /// The tasks of one section that share a group key, or all of them when the view groups by nothing.
    public struct Group: Equatable, Sendable {
        public let key: GroupKey?
        public let tasks: [TodoTask]
    }

    public let view: TaskView
    public let sections: [Section]
}

extension Store {
    /// The tasks a view selects: the pinned ones first in their manual order, then the view's own sort.
    /// Child views are ignored, so this is the flat list behind a page and behind a picker.
    public func tasks(in viewID: ViewID, today: Day) throws(StoreError) -> [TodoTask] {
        guard let view = try view(viewID) else { throw .notFound(viewID) }
        return try tasks(matching: view, today: today)
    }

    /// A page: every child view as a section in rank order, then the view's own results that no child
    /// claimed. One level deep — a child's own children flatten into the child's section here and become
    /// sections of their own when that child is the page being opened.
    ///
    /// A child this app cannot read costs its own section and nothing more: it contributes no tasks and
    /// claims none, and `section.view?.needsNewerApp` names what stopped it, so the page still draws every
    /// sibling a newer app never touched. The view the page *is* stays an error, because there is no page
    /// to draw without it.
    public func page(of viewID: ViewID, today: Day) throws(StoreError) -> TaskViewPage {
        guard let view = try view(viewID) else { throw .notFound(viewID) }
        if let kind = view.needsNewerApp { throw .viewNeedsNewerApp(view.id, kind: kind) }
        var sections: [TaskViewPage.Section] = []
        var claimed: Set<TaskID> = []
        for child in try children(ofView: viewID) {
            let tasks = child.needsNewerApp == nil ? try tasks(matching: child, today: today) : []
            claimed.formUnion(tasks.map(\.id))
            sections.append(TaskViewPage.Section(view: child, groups: group(tasks, by: child.groupBy)))
        }
        // A folder with children has no remainder of its own. A view that selects nothing and has no children
        // still gets one section, so that a page always names the view a person opened.
        let own = try tasks(matching: view, today: today).filter { !claimed.contains($0.id) }
        if !own.isEmpty || sections.isEmpty {
            sections.append(TaskViewPage.Section(view: nil, groups: group(own, by: view.groupBy)))
        }
        return TaskViewPage(view: view, sections: sections)
    }

    /// A view that this app cannot read is reported and not evaluated, because a filter with a condition
    /// dropped is a list missing exactly the rows that condition selected. A view with no filter is a folder
    /// and selects nothing of its own.
    private func tasks(matching view: TaskView, today: Day) throws(StoreError) -> [TodoTask] {
        if let kind = view.needsNewerApp { throw .viewNeedsNewerApp(view.id, kind: kind) }
        guard let filter = view.filter else { return [] }
        let statement = Store.viewStatement(filter: filter, sort: view.sort, of: view.id, today: today)
        return try loadTasks(sql: statement.sql, statement.params)
    }

    /// The statement and parameters a view's read runs. The manual list joins in as a `LEFT JOIN`, and its
    /// parameter leads, because the join comes before the WHERE in the statement `taskQuery` assembles;
    /// `vi.rank IS NULL` then puts the pinned tasks first, whatever the view's own sort is.
    ///
    /// Assembled here rather than inside the read, so that `builtInViewsUseIndexes` explains the query plan
    /// of exactly this statement (spec, "Cost"). A guard that explained a copy would pass while the read
    /// itself degraded into a scan.
    static func viewStatement(filter: Filter, sort: [SortKey], of view: ViewID, today: Day) -> (sql: String, params: [Value]) {
        let clause = FilterCompiler.whereClause(filter, today: today)
        let join = "LEFT JOIN view_items vi ON vi.view_id = ? AND vi.task_id = t.id AND vi.present = 1"
        let order = "(vi.rank IS NULL), vi.rank, " + FilterCompiler.orderBy(sort)
        return (Store.taskQuery(where: clause.sql, orderBy: order, join: join, limit: nil), [.text(view.rawValue)] + clause.params)
    }

    /// A stable partition: a group appears where its first task does, and the tasks inside it keep the order
    /// they arrived in. A task with several tags is grouped under the smallest of them — the UI may regroup,
    /// the core only promises the same answer every time.
    private func group(_ tasks: [TodoTask], by groupBy: GroupBy?) -> [TaskViewPage.Group] {
        guard !tasks.isEmpty else { return [] }
        guard let groupBy else { return [TaskViewPage.Group(key: nil, tasks: tasks)] }
        var order: [GroupKey] = []
        var buckets: [GroupKey: [TodoTask]] = [:]
        for task in tasks {
            let key: GroupKey = switch groupBy {
            case .whenDay: .day(task.when)
            case .deadlineDay: .day(task.deadline)
            case .parent: .parent(task.parent)
            case .status: .status(task.status)
            case .tag: .tag(task.tags.min())
            }
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(task)
        }
        return order.map { TaskViewPage.Group(key: $0, tasks: buckets[$0] ?? []) }
    }
}
