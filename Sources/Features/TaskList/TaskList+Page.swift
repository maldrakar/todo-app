// Sources/Features/TaskList/TaskList+Page.swift
import DesignSystem
import DesignSystemComponents
import TodoCore

/// The view's page read into the screen's blocks (spec sections 1, 2, 5 and 7): the list's own tasks first, one block
/// per group of its own section, then one block per list inside; a group's screen as the one block of its list's own
/// section it was opened from; the tag bar's chips and their filter; the folds and the layout; the header and the empty
/// state's words. The screen is the store's one answer drawn: which task is in which block is the page's, and nothing
/// here decides it again (ADR-0004, amendments of 2026-11-01 and 2026-11-02).
extension TaskList {
    /// What one read of the store gives the list, kept whole until the next read replaces it: the view's page; every
    /// tag, whose titles the chips, the meta lines and the headers of a grouping by tag name and whose order the meta
    /// lines keep; the title of each parent task a group by parent stands for, by the parent's id, the page's groups'
    /// and the group's own on a group's screen by parent, each read once, never per row, which the header of such a
    /// group shows (spec section 9; the controller's ruling on #175, 2026-11-04); the tasks completed today that the
    /// Done strip holds, kept on a group's screen to the group; and the rules of each folder among the lists inside, by
    /// its id.
    struct PageSnapshot {
        let page: TaskViewPage
        let tags: [Tag]
        let parentTitles: [TaskID: String]
        let done: [TodoTask]
        fileprivate let folderRules: [ViewID: FolderRules]
    }

    /// The rules a folder inside is read by: its first list's, whose edit is the folder's and nil where it has none
    /// (spec section 4), and every list's its section reads, which a task dragged out of its block leaves (the
    /// controller's ruling on #176, 2026-11-05).
    fileprivate struct FolderRules {
        let first: Filter?
        let all: [Filter]
    }

    /// A block as the page gives it, before the tag bar's filter, the folds and the look: what it is, its tasks, what
    /// its header says, nil for a block with none, the colour of the list it belongs to, whose check its rows take, the
    /// rule it is read by, a folder's its first list's, what that rule asks of a task added or dropped there, nil where
    /// the block takes neither, and the rules of the lists a task dragged out of it leaves: a list inside's one, a
    /// folder's every list's, and none for an own block, whose task leaves by its new day or by being claimed.
    struct PageBlock {
        let id: Model.BlockID
        let tasks: [TodoTask]
        let heading: Heading?
        let color: DesignSystem.Color.Components.Tile
        let rule: Filter?
        let edit: TaskEdit?
        let listRules: [Filter]

        /// The block with the tasks a filter leaves.
        func keeping(_ tasks: [TodoTask]) -> PageBlock {
            PageBlock(
                id: id, tasks: tasks, heading: heading, color: color, rule: rule, edit: edit, listRules: listRules
            )
        }
    }

    /// What a header says: its title, and the line under it or after it, nil for none.
    struct Heading {
        let title: String
        let subtitle: String?
    }

    /// What the empty state says: its title, and the line under it that says what to do.
    struct EmptyWords {
        let title: String
        let text: String
    }

    /// A chip of the tag bar: its tag and the tag's title.
    struct Chip {
        let id: TagID
        let title: String
    }

    /// Reads the page of the head's view by the device's day, every tag, the title of each parent a group of the page's
    /// own section, or the head's group, is of, a parent that does not read having none and titled as no parent is, the
    /// tasks completed since the day began that the strip holds, and each folder's first list. Throws what the reads
    /// throw, a view that is gone as `.notFound` with its id among it.
    static func read(_ store: Store, head: Route.Head, day: DeviceDay) throws(StoreError) -> PageSnapshot {
        let page = try store.page(of: head.view, today: day.day)
        var wanted: [TaskID] = []
        for section in page.sections where section.view == nil {
            for group in section.groups {
                if case .parent(let id?)? = group.key { wanted.append(id) }
            }
        }
        if case .parent(let id?)? = head.group { wanted.append(id) }
        var titles: [TaskID: String] = [:]
        for id in wanted where titles[id] == nil {
            if let task = try store.task(id) { titles[id] = task.title }
        }
        return PageSnapshot(
            page: page, tags: try store.tags(), parentTitles: titles,
            done: try doneTasks(in: store, of: page.view, head: head, day: day),
            folderRules: try folderRules(in: store, of: page)
        )
    }

    /// The tasks the strip holds: the list's completed today, and on a group's screen those its grouping puts under the
    /// group, by the rule the page grouped them by (spec section 2; `GroupKey(of:by:)`). A list that draws finished
    /// tasks as its rows has no strip, so it reads none.
    private static func doneTasks(
        in store: Store, of view: TaskView, head: Route.Head, day: DeviceDay
    ) throws(StoreError) -> [TodoTask] {
        if view.filter.map(drawsFinished) == true { return [] }
        let done = try store.doneTasks(in: head.view, since: day.began, today: day.day)
        guard let group = head.group, let groupBy = view.groupBy else { return done }
        let key = groupKey(of: group, today: day.day)
        return done.filter { GroupKey(of: $0, by: groupBy) == key }
    }

    /// The rules of each folder among the page's lists inside, by the folder's id, each by loops over the views and no
    /// recursion. Its first list's: a folder inside it handing on to its own first, to any depth; a folder with no
    /// lists, or one whose first this app cannot read, has none (spec section 4). Every list's, as far as its section
    /// reads, as the store gathers them (`Store.gatheredRules(of:)`): a list with a rule its rule and not the lists
    /// inside it, a folder its lists', and a view this app cannot read nothing. A view this app cannot read reads as
    /// having no rule and is no folder. A page with no folder inside reads nothing more.
    private static func folderRules(
        in store: Store, of page: TaskViewPage
    ) throws(StoreError) -> [ViewID: FolderRules] {
        let folders = page.sections.compactMap(\.view).filter { $0.filter == nil && $0.needsNewerApp == nil }
        guard !folders.isEmpty else { return [:] }
        let views = try store.views()
        var rules: [ViewID: FolderRules] = [:]
        for folder in folders {
            var first = views.first { $0.parent == folder.id }
            while let view = first, view.filter == nil, view.needsNewerApp == nil {
                first = views.first { $0.parent == view.id }
            }
            var all: [Filter] = []
            var inside = [folder.id]
            while let parent = inside.popLast() {
                for view in views where view.parent == parent && view.needsNewerApp == nil {
                    if let rule = view.filter { all.append(rule) } else { inside.append(view.id) }
                }
            }
            rules[folder.id] = FolderRules(first: first?.needsNewerApp == nil ? first?.filter : nil, all: all)
        }
        return rules
    }

    /// Why a group names nothing of its list as the read found it, and nil when it names a group: a word that is not
    /// the list's grouping is `.invalid`, and a tag or a parent that is gone `.notFound` with its id (ADR-0009,
    /// amendment of 2026-11-02). The group with no key, and a status, name a group whenever the grouping is the list's,
    /// since the screen reads its list's page and needs no condition of its own; on a given day such a group may hold
    /// no task, which is its block empty.
    static func refusal(of group: Route.Group, in snapshot: PageSnapshot) -> StoreError? {
        let view = snapshot.page.view
        guard view.groupBy == group.groupBy else {
            return .invalid("“\(view.title)” is not grouped by \(group.word.rawValue)")
        }
        switch group {
        case .tag(let id?) where !snapshot.tags.contains(where: { $0.id == id }): return .notFound(id)
        case .parent(let id?) where snapshot.parentTitles[id] == nil: return .notFound(id)
        case .day, .deadline, .tag, .parent, .status: return nil
        }
    }

    /// The blocks of the page as it was read. A group's screen is one block, its list's own section's group of the
    /// group's key at today, its tasks those of that group or none, with no header, since the screen's header names it
    /// and its title would open nothing (the controller's ruling on #175, 2026-11-04). A list's screen is its own
    /// blocks, a list that groups by nothing having one with no header, there whenever the list has a rule, empty or
    /// not, and a grouped list one per group left with a task; then one block per list inside, headed by its title in
    /// its colour, its tasks the section's groups in their order, drawn when it is empty too (spec section 2).
    ///
    /// Which block a task is in is the store's one answer; which of them are rows is the screen's: its open tasks, and
    /// the finished ones only where the block's rule draws them, the rest being the strip's (spec section 3; the
    /// controller's ruling on #176, 2026-11-05).
    static func blocks(of snapshot: PageSnapshot, head: Route.Head, today: Day) -> [PageBlock] {
        let view = snapshot.page.view
        let color = tileColor(view.color)
        let own = snapshot.page.sections.first { $0.view == nil }
        func ownBlock(_ key: GroupKey?, _ tasks: [TodoTask], heading: Heading?) -> PageBlock {
            PageBlock(
                id: .own(key), tasks: rows(of: tasks, by: view.filter), heading: heading, color: color,
                rule: view.filter, edit: ownEdit(of: view, key: key, today: today), listRules: []
            )
        }
        if let group = head.group {
            let key = groupKey(of: group, today: today)
            return [ownBlock(key, own?.groups.first { $0.key == key }?.tasks ?? [], heading: nil)]
        }
        var blocks: [PageBlock] = []
        if let own {
            if view.groupBy == nil {
                blocks.append(ownBlock(nil, own.groups.flatMap(\.tasks), heading: nil))
            } else {
                for group in own.groups {
                    let block = ownBlock(
                        group.key, group.tasks, heading: group.key.map { heading(of: $0, in: snapshot, today: today) }
                    )
                    if !block.tasks.isEmpty { blocks.append(block) }
                }
            }
        }
        for section in snapshot.page.sections {
            guard let child = section.view else { continue }
            let folder = snapshot.folderRules[child.id]
            let rule = child.needsNewerApp == nil ? child.filter ?? folder?.first : nil
            blocks.append(PageBlock(
                id: .list(child.id), tasks: rows(of: section.groups.flatMap(\.tasks), by: child.filter),
                heading: Heading(title: child.title, subtitle: nil), color: tileColor(child.color), rule: rule,
                edit: rule.flatMap { TaskEdit.of($0, today: today, day: nil) },
                listRules: child.filter.map { [$0] } ?? folder?.all ?? []
            ))
        }
        return blocks
    }

    /// The rows of a block's tasks: every one where its rule draws finished tasks, and the open ones otherwise.
    private static func rows(of tasks: [TodoTask], by rule: Filter?) -> [TodoTask] {
        rule.map(drawsFinished) == true ? tasks : tasks.filter { $0.status == .open }
    }

    /// What one of the list's own blocks asks of a task: the rule's edit, with a day block's day as its When, or as
    /// its deadline for a list grouped by deadline (the controller's ruling on #176, 2026-11-05). A grouping by tag,
    /// parent or status has no one field to set, so its blocks ask nothing and take nothing
    /// (`Store.group(_:by:manual:)`; the controller's ruling on #176, 2026-11-05).
    private static func ownEdit(of view: TaskView, key: GroupKey?, today: Day) -> TaskEdit? {
        guard let rule = view.filter else { return nil }
        switch key {
        case nil:
            return TaskEdit.of(rule, today: today, day: nil)
        case .day(let day)? where view.groupBy == .deadlineDay:
            return TaskEdit.of(rule, today: today, day: nil)?.settingDeadline(day)
        case .day(let day)?:
            return TaskEdit.of(rule, today: today, day: TaskEdit.DayEdit(day))
        case .tag?, .parent?, .status?:
            return nil
        }
    }

    /// What the floating "+" adds by, and the view whose top its task lands at (the controller's ruling on #176,
    /// 2026-11-05): a group's screen's one block, a folder's first block, which is its first list; and a list with a
    /// rule its first own block, where that block takes one, and otherwise the rule's edit with no day, a grouped list
    /// with no tasks having no block and a block of a grouping by tag asking nothing. A group's screen with such a
    /// block has none, a list whose rule reads as no edit has none, which is how Logbook and Trash have none, and
    /// neither has a folder with no lists. The view is one the page read: the list's, or the list inside's.
    static func floatingTarget(
        in blocks: [PageBlock], of snapshot: PageSnapshot, head: Route.Head, today: Day
    ) -> (edit: TaskEdit, view: TaskView)? {
        let page = snapshot.page
        guard let rule = page.view.filter, head.group == nil else {
            guard let first = blocks.first, let edit = first.edit else { return nil }
            let view = switch first.id {
            case .own: page.view
            case .list(let id): page.sections.first { $0.view?.id == id }?.view
            }
            return view.map { (edit, $0) }
        }
        if let first = blocks.first, case .own = first.id, let edit = first.edit { return (edit, page.view) }
        return TaskEdit.of(rule, today: today, day: nil).map { ($0, page.view) }
    }

    /// The tags the open tasks of the blocks carry, each task once however many blocks draw it, the most used first,
    /// ties by title as a person reads it, whatever its case, then by its characters, so that the order is always the
    /// same (canvas, `localeCompare`), and a tag every one of those tasks carries left out, since it
    /// would filter nothing (spec section 7; the controller's ruling on #175, 2026-11-04). A tag the read does not
    /// hold, which the store's reading rule never leaves on a task, has no title to show and no chip.
    static func chips(in blocks: [PageBlock], tags: [Tag]) -> [Chip] {
        var counted: Set<TaskID> = []
        var counts: [TagID: Int] = [:]
        for block in blocks {
            for task in block.tasks where task.status == .open && counted.insert(task.id).inserted {
                for tag in task.tags { counts[tag, default: 0] += 1 }
            }
        }
        let carried = tags.enumerated().compactMap { index, tag in
            counts[tag.id].flatMap { $0 < counted.count ? (index: index, tag: tag, count: $0) : nil }
        }
        return carried.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            let (left, right) = (lhs.tag.title.lowercased(), rhs.tag.title.lowercased())
            if left != right { return left < right }
            if lhs.tag.title != rhs.tag.title { return lhs.tag.title < rhs.tag.title }
            return lhs.index < rhs.index
        }
        .map { Chip(id: $0.tag.id, title: $0.tag.title) }
    }

    /// The key a block's fold is kept under in the device's state: a day's group as `day/<yyyy-mm-dd>` or `day/none`,
    /// for a grouping by When or by deadline alike, since the page keys both by the day; a tag's, a parent's and a
    /// status's under their group's word and key; a list inside as `view/<id>`; and none for the own block of a list
    /// that groups by nothing, which has no header to fold by (the controller's ruling on #175, 2026-11-04).
    static func foldKey(of id: Model.BlockID) -> String? {
        let group: Route.Group.Word
        let key: String
        switch id {
        case .own(nil):
            return nil
        case .own(.day(let day)?):
            (group, key) = (.day, day.map(dayKey) ?? Route.Group.none)
        case .own(.tag(let tag)?):
            (group, key) = (.tag, tag?.rawValue ?? Route.Group.none)
        case .own(.parent(let parent)?):
            (group, key) = (.parent, parent?.rawValue ?? Route.Group.none)
        case .own(.status(let status)?):
            (group, key) = (.status, status.name)
        case .list(let view):
            return "view/\(view.rawValue)"
        }
        return "\(group.rawValue)/\(key)"
    }

    /// One of the list's own groups as its address, a day a distance from today, of the deadline's word for a list
    /// grouped by deadline, a distance outside `Int32` clamped; the rest as they are (spec section 2).
    static func address(of key: GroupKey, by groupBy: GroupBy?, today: Day) -> Route.Group {
        switch key {
        case .day(let day):
            let offset = day.map { Int32(clamping: distance(to: $0, from: today)) }
            return groupBy == .deadlineDay ? .deadline(offset) : .day(offset)
        case .tag(let tag): return .tag(tag)
        case .parent(let parent): return .parent(parent)
        case .status(let status): return .status(status)
        }
    }

    /// The key of the page's group a group's address names at today, a day the distance from today, clamped as every
    /// day offset is, so that a new day moves the screen onto the new day's group (spec section 2).
    private static func groupKey(of group: Route.Group, today: Day) -> GroupKey {
        switch group {
        case .day(let distance), .deadline(let distance): .day(distance.map { day(Int64($0), from: today) })
        case .tag(let tag): .tag(tag)
        case .parent(let parent): .parent(parent)
        case .status(let status): .status(status)
        }
    }

    /// What a group's header says, which its screen's title says too: a day's title with its date, "No date" for the
    /// group with no day, a tag's title or "No tag", a parent's title or "No parent", a status's name, with no line but
    /// a day's (the controller's ruling on #175, 2026-11-04). A tag or a parent the read does not hold is titled as the
    /// group with no key.
    private static func heading(of key: GroupKey, in snapshot: PageSnapshot, today: Day) -> Heading {
        switch key {
        case .day(let day?):
            Heading(title: dayTitle(day, today: today), subtitle: dayDate(day, today: today))
        case .day(nil):
            Heading(title: "No date", subtitle: nil)
        case .tag(let tag):
            Heading(title: tag.flatMap { tag in snapshot.tags.first { $0.id == tag }?.title } ?? "No tag", subtitle: nil)
        case .parent(let parent):
            Heading(title: parent.flatMap { snapshot.parentTitles[$0] } ?? "No parent", subtitle: nil)
        case .status(let status):
            Heading(title: statusTitles[status] ?? status.name, subtitle: nil)
        }
    }

    /// The titles of the statuses, a status group's header and screen's.
    private static let statusTitles: [TaskStatus: String] = [.open: "Open", .done: "Done", .canceled: "Canceled"]

    /// What the screen's header says. A list's: its title, and under it the date of the one day its rule's When
    /// condition gives where that condition is on a day or on or before one, Today's (engineer's call: the canvas gives
    /// Today its date and nothing names the built-in). A group's screen's: the group's name for its title, and under it
    /// the list's title with the group's date after it for a day, "This week · Oct 26" (spec section 2).
    static func screenHeading(
        head: Route.Head, title: String, rule: Filter?, snapshot: PageSnapshot, today: Day
    ) -> Heading {
        guard let group = head.group else {
            return Heading(title: title, subtitle: day(of: rule, today: today).map(longDate))
        }
        let heading = heading(of: groupKey(of: group, today: today), in: snapshot, today: today)
        return Heading(title: heading.title, subtitle: title + (heading.subtitle.map { " · " + $0 } ?? ""))
    }

    /// The one day a rule's When condition gives, where the rule is that condition or a conjunction holding it alone
    /// among its When conditions and the condition is on a day or on or before one; nil otherwise, a condition of
    /// several days or of none, or two of them, since neither names one day.
    private static func day(of rule: Filter?, today: Day) -> Day? {
        let conditions: [Filter] = switch rule {
        case .and(let conditions)?: conditions
        case let rule?: [rule]
        case nil: []
        }
        let whens = conditions.compactMap { condition -> DayCondition? in
            guard case .when(let when) = condition else { return nil }
            return when
        }
        guard whens.count == 1 else { return nil }
        switch whens[0] {
        case .on(let offset), .onOrBefore(let offset): return day(offset, from: today)
        case .empty, .onOrAfter, .between: return nil
        }
    }

    /// What the empty state says, by what the list is (canvas, section 1; the controller's ruling on #175, 2026-11-04):
    /// Trash and Logbook their own, a manual list that a task is added or dragged in, a folder with no lists that lists
    /// go inside, a list of one tag the tag, and every other list and every group's screen that what its rule matches
    /// shows up.
    static func emptyWords(head: Route.Head, view: TaskView, tags: TagNames) -> EmptyWords {
        let nothing = "Nothing here yet"
        let rule = "Tasks that match this list’s rule will show up here."
        if head.group != nil { return EmptyWords(title: nothing, text: rule) }
        switch (view.id, view.filter) {
        case (BuiltInTaskViews.trash, _):
            return EmptyWords(title: "Trash is empty", text: "Deleted tasks wait here until you empty it.")
        case (BuiltInTaskViews.logbook, _):
            return EmptyWords(title: "Nothing done yet", text: rule)
        case (_, .listedIn(let list)?) where list == view.id:
            return EmptyWords(title: nothing, text: "Add a task here, or drag one in.")
        case (_, nil):
            return EmptyWords(title: "A new list", text: "Put lists inside it, or give it a rule here.")
        case (_, .hasTag(let tag)?):
            let tagged = tags[tag].map { "Tasks tagged #\($0.title) will show up here." }
            return EmptyWords(title: nothing, text: tagged ?? rule)
        default:
            return EmptyWords(title: nothing, text: rule)
        }
    }

    /// The tags as a row's meta line and the empty state read them: each one's title and place in the tags' order, by
    /// id, built once per model.
    struct TagNames {
        private let byID: [TagID: (index: Int, title: String)]

        init(_ tags: [Tag]) {
            var byID: [TagID: (index: Int, title: String)] = [:]
            for (index, tag) in tags.enumerated() { byID[tag.id] = (index, tag.title) }
            self.byID = byID
        }

        fileprivate subscript(_ id: TagID) -> (index: Int, title: String)? { byID[id] }

        /// The titles of the tags a task carries, in the tags' order; one the read does not hold is left out.
        func titles(of tags: Set<TagID>) -> [String] {
            tags.compactMap { byID[$0] }.sorted { $0.index < $1.index }.map(\.title)
        }
    }
}

extension TaskList.Route.Group {
    /// The grouping whose group this is, which the list's must be for the group to name one (ADR-0009, amendment of
    /// 2026-11-02).
    fileprivate var groupBy: GroupBy {
        switch self {
        case .day: .whenDay
        case .deadline: .deadlineDay
        case .tag: .tag
        case .parent: .parent
        case .status: .status
        }
    }
}
