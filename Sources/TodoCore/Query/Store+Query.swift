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
    /// The tasks a view selects, in the order a page lays them out: the sort gives the groups their order,
    /// and the manual list orders the tasks inside a group. A view that groups by nothing is one group, which
    /// is why the pinned tasks of the Inbox or of Today still come first — one rule and not two, so the tasks
    /// of a view are in one order whether they are read flat or drawn as the groups of its own section.
    ///
    /// Child views are ignored, which is the one thing a page does that this does not: a page draws them as
    /// sections of their own and subtracts what they claimed. This is the list behind a picker.
    public func tasks(in viewID: ViewID, today: Day) throws(StoreError) -> [TodoTask] {
        guard let view = try view(viewID) else { throw .notFound(viewID) }
        return try groups(of: view, from: try tasks(matching: view, today: today)).flatMap(\.tasks)
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
            sections.append(TaskViewPage.Section(view: child, groups: try groups(of: child, from: tasks)))
        }
        // A folder with children has no remainder of its own. A view that selects nothing and has no children
        // still gets one section, so that a page always names the view a person opened.
        let own = try tasks(matching: view, today: today).filter { !claimed.contains($0.id) }
        if !own.isEmpty || sections.isEmpty {
            sections.append(TaskViewPage.Section(view: nil, groups: try groups(of: view, from: own)))
        }
        return TaskViewPage(view: view, sections: sections)
    }

    /// A view that this app cannot read is reported and not evaluated, because a filter with a condition
    /// dropped is a list missing exactly the rows that condition selected. A view with no filter is a folder
    /// and selects nothing of its own.
    private func tasks(matching view: TaskView, today: Day) throws(StoreError) -> [TodoTask] {
        if let kind = view.needsNewerApp { throw .viewNeedsNewerApp(view.id, kind: kind) }
        guard let filter = view.filter else { return [] }
        let statement = Store.viewStatement(filter: filter, sort: view.sort, today: today)
        return try loadTasks(sql: statement.sql, statement.params)
    }

    /// The statement and parameters a view's read runs: the filter and the sort, and nothing of the manual
    /// list. Ordering by the list here would order the whole result by it, and a manual list belongs to a
    /// group — `group(_:by:manual:)` applies it where it belongs. A filter that asks about the list,
    /// `listedIn`, is a condition like any other and compiles into a subquery of its own.
    ///
    /// Assembled here rather than inside the read, so that `builtInViewsUseIndexes` explains the query plan
    /// of exactly this statement (spec, "Cost"). A guard that explained a copy would pass while the read
    /// itself degraded into a scan.
    static func viewStatement(filter: Filter, sort: [SortKey], today: Day) -> (sql: String, params: [Value]) {
        let clause = FilterCompiler.whereClause(filter, today: today)
        return (Store.taskQuery(where: clause.sql, orderBy: FilterCompiler.orderBy(sort), limit: nil), clause.params)
    }

    /// The groups of one section, from the tasks the view's sort brought back. A section with no tasks has no
    /// groups, and that is answered here, where the read it saves is: `group(_:by:manual:)` below is given a
    /// list with something in it.
    ///
    /// The manual list is read here, as a second and much smaller statement over `view_items`, rather than
    /// joined into the task query: a join has to be ordered by, and that orders the whole result. A section
    /// with no tasks is not a section, so it costs no read at all.
    private func groups(of view: TaskView, from tasks: [TodoTask]) throws(StoreError) -> [TaskViewPage.Group] {
        guard !tasks.isEmpty else { return [] }
        return Store.group(tasks, by: view.groupBy, manual: try manualList(of: view.id))
    }

    /// A stable partition: a group appears where the sort put its first task, and the tasks inside it keep
    /// the order they arrived in, except that the ones in the manual list come first, in its order. Grouping
    /// by nothing is one group, so an ungrouped view puts its pinned tasks at the top by the same rule and
    /// not by one of its own.
    ///
    /// A manual list applied to the whole result instead would drag a group with it: a task pinned in the
    /// second of two days became the first task of the section, and a group takes the position of its first
    /// task, so a person who dragged one task watched a whole day move above another.
    ///
    /// A task with several tags is grouped under the smallest of them — the UI may regroup, the core only
    /// promises the same answer every time. It is also why dragging a task between groups, which sets the
    /// field the view groups by, is not offered for a tag: there is no one field to set.
    private static func group(_ tasks: [TodoTask], by groupBy: GroupBy?, manual: [TaskID]) -> [TaskViewPage.Group] {
        var position: [TaskID: Int] = [:]
        for (index, id) in manual.enumerated() { position[id] = index }
        guard let groupBy else { return [TaskViewPage.Group(key: nil, tasks: Store.manualFirst(tasks, by: position))] }
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
        return order.map { TaskViewPage.Group(key: $0, tasks: Store.manualFirst(buckets[$0] ?? [], by: position)) }
    }

    /// The tasks of one group with the pinned ones first. Two pinned tasks never share a position, so the
    /// sort is total and the unpinned ones keep the order the SQL gave them. A view with no manual list, and
    /// a group holding none of it, hand back the tasks they were given rather than copy a list of thousands
    /// into two arrays to conclude that nothing moved.
    private static func manualFirst(_ tasks: [TodoTask], by position: [TaskID: Int]) -> [TodoTask] {
        guard !position.isEmpty else { return tasks }
        var pinned: [(at: Int, task: TodoTask)] = []
        var rest: [TodoTask] = []
        for task in tasks {
            if let at = position[task.id] { pinned.append((at, task)) } else { rest.append(task) }
        }
        guard !pinned.isEmpty else { return tasks }
        return pinned.sorted { $0.at < $1.at }.map(\.task) + rest
    }
}
