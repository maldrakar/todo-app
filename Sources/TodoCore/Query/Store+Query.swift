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
        let view = try Store.readableView(viewID, among: try views())
        let rules = view.filter.map { [$0] } ?? []
        let sizes = try readSizes(for: [rules], today: today)
        return try groups(of: view, from: try tasks(selectedByAnyOf: rules, sort: view.sort, today: today, sizes: sizes)).flatMap(\.tasks)
    }

    /// A page: the view's own section first, then every child view as a section in rank order, which is the
    /// product's order of a list (ADR-0004, amendment of 2026-11-01). One level deep — a child's own children
    /// flatten into the child's section here and become sections of their own when that child is the page being
    /// opened.
    ///
    /// The own section is the view's results that no child claimed, and it is there whenever the view has a rule,
    /// empty or not, so that a list with nothing in it still has a block to add into; a folder has no rule, no
    /// tasks of its own and no own section (spec section 2). A child with a rule holds its rule's results; a folder
    /// inside holds the union of the reads of the lists under it to any depth, each read keeping its own exclusion
    /// of the Trash, each task once and in the folder's own sort, the rules gathered as its count gathers them, so
    /// that it holds here what its number in the sidebar counts. What a child holds leaves the own section; nothing
    /// is taken out between siblings.
    ///
    /// A child this app cannot read costs its own section and nothing more: it contributes no tasks and
    /// claims none, and `section.view?.needsNewerApp` names what stopped it, so the page still draws every
    /// sibling a newer app never touched. The view the page *is* stays an error, because there is no page
    /// to draw without it.
    public func page(of viewID: ViewID, today: Day) throws(StoreError) -> TaskViewPage {
        let allViews = try views()
        let view = try Store.readableView(viewID, among: allViews)
        let children = Store.childSections(of: viewID, among: allViews)
        let sizes = try readSizes(for: [view.filter.map { [$0] } ?? []] + children.map(\.rules), today: today)
        var sections: [TaskViewPage.Section] = []
        var claimed: Set<TaskID> = []
        for (child, rules) in children {
            let tasks = try tasks(selectedByAnyOf: rules, sort: child.sort, today: today, sizes: sizes)
            claimed.formUnion(tasks.map(\.id))
            sections.append(TaskViewPage.Section(view: child, groups: try groups(of: child, from: tasks)))
        }
        guard let rule = view.filter else { return TaskViewPage(view: view, sections: sections) }
        let own = try tasks(selectedByAnyOf: [rule], sort: view.sort, today: today, sizes: sizes).filter { !claimed.contains($0.id) }
        return TaskViewPage(view: view, sections: [TaskViewPage.Section(view: nil, groups: try groups(of: view, from: own))] + sections)
    }

    /// The view a read is of, a page, its done tasks or the flat list, found among the views the read read once. It
    /// has to be there, and one this app cannot read is reported and not evaluated, because a filter with a condition
    /// dropped is a list missing exactly the rows that condition selected.
    static func readableView(_ id: ViewID, among views: [TaskView]) throws(StoreError) -> TaskView {
        guard let view = views.first(where: { $0.id == id }) else { throw .notFound(id) }
        if let kind = view.needsNewerApp { throw .viewNeedsNewerApp(view.id, kind: kind) }
        return view
    }

    /// Every child of a view in rank order, as `children(ofView:)` lists them, from the views the read read once,
    /// with the rules its section of the page holds the tasks of: a list's own rule, or the rules of a folder's
    /// lists, gathered as its count gathers them (`gatheredRules(of:)`); none for a child this app cannot read and
    /// for a folder with nothing under it to select. The page reads them, and the done read lifts them.
    static func childSections(of viewID: ViewID, among views: [TaskView]) -> [(view: TaskView, rules: [Filter])] {
        var gathered: [ViewID: [Filter]] = [:]
        for (view, rules) in gatheredRules(of: views) { gathered[view.id] = rules }
        return views.filter { $0.parent == viewID }.map { ($0, gathered[$0.id] ?? []) }
    }

    /// The tasks any of `rules` selects, each once, in `sort`: every read of a view's tasks is read here. A list's
    /// is its one rule, and a folder's section on a page the union of its lists' reads; a folder read on its own
    /// has no rule and selects nothing. `sizes` are what the call read for the choice of its reads' drivers.
    private func tasks(selectedByAnyOf rules: [Filter], sort: [SortKey], today: Day, sizes: ReadCompiler.Sizes) throws(StoreError) -> [TodoTask] {
        guard !rules.isEmpty else { return [] }
        let statement = Store.viewStatement(rules: rules, sort: sort, today: today, sizes: sizes)
        return try loadTasks(sql: statement.sql, statement.params)
    }

    /// The statement and parameters a view's read runs: the rules, one for a list and its lists' for a folder's
    /// section, each read with its own exclusion of the Trash, written by `ReadCompiler` so that the rule's own index
    /// drives the read where it has one (#155), and the sort, and nothing of the manual list. Ordering by the list here
    /// would order the whole result by it, and a manual list belongs to a group — `group(_:by:manual:)` applies it
    /// where it belongs. A filter that asks about the list, `listedIn`, is a condition like any other and compiles
    /// into a subquery of its own.
    ///
    /// Assembled here rather than inside the read, so that `builtInViewsUseIndexes` explains the query plan
    /// of exactly this statement (spec, "Cost"). A guard that explained a copy would pass while the read
    /// itself degraded into a scan.
    static func viewStatement(rules: [Filter], sort: [SortKey], today: Day, sizes: ReadCompiler.Sizes) -> (sql: String, params: [Value]) {
        let clause = ReadCompiler(today: today, sizes: sizes).compile(rules)
        return (Store.taskQuery(where: clause.sql, orderBy: FilterCompiler.orderBy(sort), limit: nil), clause.params)
    }

    /// The sizes the reads of `sections` choose their drivers by (`ReadCompiler`), each section the rules of one read,
    /// read once for the call however many of its reads ask for one. Each is read from an index and no table row, by
    /// the statements `readSizeStatements` assembles. A read that fails fails the call, as any of its reads would;
    /// `count(*)` always answers one row, and a size whose answer had none is left out, which costs speed and never a
    /// task.
    func readSizes(for sections: [[Filter]], today: Day) throws(StoreError) -> ReadCompiler.Sizes {
        try sql { () throws(SQLiteError) in
            var sizes: [(size: ReadCompiler.Size, tasks: Int64)] = []
            for read in Store.readSizeStatements(for: sections, today: today) {
                if let tasks = try db.rows(read.sql, read.params).first?.first?.int64 { sizes.append((read.size, tasks)) }
            }
            return ReadCompiler.Sizes(sizes)
        }
    }

    /// The statement of every size `readSizes` reads for `sections`, in the order it reads them: each size any of the
    /// reads asks for (`ReadCompiler.sizes(wantedBy:)`), once. Every task is counted on the smallest index SQLite has
    /// of them, a status on the status index, a tag on its partial index, and a condition on its day's index or, for
    /// the root, on the tree's parent index.
    ///
    /// Assembled here, beside `viewStatement` and for its reason: `theSizeReadsReadIndexesAlone` explains exactly these
    /// statements, and a guard that explained a copy would pass while a size read degraded into a walk of the tasks.
    static func readSizeStatements(for sections: [[Filter]], today: Day) -> [(size: ReadCompiler.Size, sql: String, params: [Value])] {
        var sizes: [ReadCompiler.Size] = []
        for rules in sections {
            for size in ReadCompiler.sizes(wantedBy: rules) where !sizes.contains(size) { sizes.append(size) }
        }
        return sizes.map { size in
            switch size {
            case .tasks:
                return (size, "SELECT count(*) FROM tasks", [])
            case .status(let status):
                return (size, Store.statusSizeQuery, [.integer(status.rawValue)])
            case .tag(let tag):
                return (size, Store.tagSizeQuery, [.text(tag.rawValue)])
            case .condition(let condition):
                let fragment = FilterCompiler.compile(condition, today: today)
                let table = condition == .parent(nil) ? "task_tree tt" : "tasks t"
                return (size, "SELECT count(*) FROM \(table) WHERE \(fragment.sql)", fragment.params)
            }
        }
    }

    /// The tasks the status index holds of one status, the trashed and the deleted among them, counted on the index alone.
    private static let statusSizeQuery = "SELECT count(*) FROM tasks WHERE status = ?"

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
