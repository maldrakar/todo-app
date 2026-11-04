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
    /// lines keep; and the titles of the parents the page's groups by parent are of, and the group's own on a group's
    /// screen by parent, each read once, never per row (spec section 9; the controller's ruling on #175, 2026-11-04).
    struct Read {
        let page: TaskViewPage
        let tags: [Tag]
        let parents: [TaskID: String]
    }

    /// A block as the page gives it, before the tag bar's filter, the folds and the look: what it is, its tasks, what
    /// its header says, nil for a block with none, and the colour of the list it belongs to, whose check its rows take.
    struct PageBlock {
        let id: Model.BlockID
        let tasks: [TodoTask]
        let heading: Heading?
        let color: DesignSystem.Color.Components.Tile
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

    /// Reads the page of the head's view by the device's day, every tag, and the title of each parent a group of the
    /// page's own section, or the head's group, is of; a parent that does not read has none, and is titled as no
    /// parent is. Throws what the reads throw, a view that is gone as `.notFound` with its id among it.
    static func read(_ store: Store, head: Route.Head, today: Day) throws(StoreError) -> Read {
        let page = try store.page(of: head.view, today: today)
        var wanted: [TaskID] = []
        for section in page.sections where section.view == nil {
            for group in section.groups {
                if case .parent(let id?)? = group.key { wanted.append(id) }
            }
        }
        if case .parent(let id?)? = head.group { wanted.append(id) }
        var parents: [TaskID: String] = [:]
        for id in wanted where parents[id] == nil {
            if let task = try store.task(id) { parents[id] = task.title }
        }
        return Read(page: page, tags: try store.tags(), parents: parents)
    }

    /// Why a group names nothing of its list as the read found it, and nil when it names a group: a word that is not
    /// the list's grouping is `.invalid`, and a tag or a parent that is gone `.notFound` with its id (ADR-0009,
    /// amendment of 2026-11-02). The group with no key, and a status, name a group whenever the grouping is the list's,
    /// since the screen reads its list's page and needs no condition of its own; on a given day such a group may hold
    /// no task, which is its block empty.
    static func refusal(of group: Route.Group, in read: Read) -> StoreError? {
        let view = read.page.view
        guard view.groupBy == group.groupBy else {
            return .invalid("“\(view.title)” is not grouped by \(group.word.rawValue)")
        }
        switch group {
        case .tag(let id?) where !read.tags.contains(where: { $0.id == id }): return .notFound(id)
        case .parent(let id?) where read.parents[id] == nil: return .notFound(id)
        case .day, .deadline, .tag, .parent, .status: return nil
        }
    }

    /// The screen's model, computed from what the module holds on every read (`State.model`): the blocks of the page,
    /// the chips of their open tasks and the rows the picked ones leave, the layout the list is shown as where Show as
    /// offers Columns and the list otherwise, a block's fold where it has a header to fold by, and the header, Show as,
    /// the empty state and the sentence.
    ///
    /// Columns are offered where the list groups or has more than one block, and never on a group's screen, which has
    /// one block and no grouping (spec section 5; the controller's ruling on #175, 2026-11-04). The empty state stands
    /// when no block has a row after the filter and the page has no lists inside (canvas, the empty state; the
    /// controller's ruling on #175, 2026-11-04).
    static func model(
        head: Route.Head, title: String, read: Read, today: Day, folded: Set<String>, layout: Model.Layout.Kind,
        picks: Set<TagID>, problem: String?
    ) -> Model {
        let view = read.page.view
        let blocks = blocks(of: read, head: head, today: today)
        let chips = chips(in: blocks, tags: read.tags)
        let picked = picks.intersection(chips.map(\.id))
        let shown = blocks.map { block in
            picked.isEmpty ? block : PageBlock(
                id: block.id, tasks: block.tasks.filter { !$0.tags.isDisjoint(with: picked) }, heading: block.heading,
                color: block.color
            )
        }
        let canBoard = head.group == nil && (view.groupBy != nil || blocks.count > 1)
        let metrics = Metrics.of(canBoard ? layout : .list)
        let color = tileColor(view.color)
        let icon = tileIcon(view.icon)
        let tags = TagNames(read.tags)
        let hasListsInside = blocks.contains { if case .list = $0.id { true } else { false } }
        let isEmpty = shown.allSatisfy(\.tasks.isEmpty) && !hasListsInside
        return Model(
            header: header(
                screenHeading(head: head, title: title, rule: view.filter, read: read, today: today), color: color,
                icon: icon, metrics.header
            ),
            tagBar: tagBar(chips, picked: picked, colors: color.check, metrics.tagBar),
            layout: TaskList.layout(shown, title: title, folded: folded, today: today, tags: tags, metrics.blocks),
            showAs: showAs(canBoard: canBoard),
            empty: isEmpty
                ? empty(emptyWords(head: head, view: view, tags: tags), color: color, icon: icon, metrics.empty) : nil,
            problem: problem
        )
    }

    /// The blocks of the page as it was read. A group's screen is one block, its list's own section's group of the
    /// group's key at today, its tasks those of that group or none, with no header, since the screen's header names it
    /// and its title would open nothing (the controller's ruling on #175, 2026-11-04). A list's screen is its own
    /// blocks, a list that groups by nothing having one with no header, there whenever the list has a rule, empty or
    /// not, and a grouped list one per group that holds a task; then one block per list inside, headed by its title in
    /// its colour, its tasks the section's groups in their order, drawn when it is empty too (spec section 2).
    static func blocks(of read: Read, head: Route.Head, today: Day) -> [PageBlock] {
        let view = read.page.view
        let color = tileColor(view.color)
        let own = read.page.sections.first { $0.view == nil }
        if let group = head.group {
            let key = groupKey(of: group, today: today)
            let tasks = own?.groups.first { $0.key == key }?.tasks ?? []
            return [PageBlock(id: .own(key), tasks: tasks, heading: nil, color: color)]
        }
        var blocks: [PageBlock] = []
        if let own {
            if view.groupBy == nil {
                blocks.append(PageBlock(id: .own(nil), tasks: own.groups.flatMap(\.tasks), heading: nil, color: color))
            } else {
                for group in own.groups {
                    blocks.append(PageBlock(
                        id: .own(group.key), tasks: group.tasks,
                        heading: group.key.map { heading(of: $0, in: read, today: today) }, color: color
                    ))
                }
            }
        }
        for section in read.page.sections {
            guard let child = section.view else { continue }
            blocks.append(PageBlock(
                id: .list(child.id), tasks: section.groups.flatMap(\.tasks),
                heading: Heading(title: child.title, subtitle: nil), color: tileColor(child.color)
            ))
        }
        return blocks
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
    private static func heading(of key: GroupKey, in read: Read, today: Day) -> Heading {
        switch key {
        case .day(let day?):
            Heading(title: dayTitle(day, today: today), subtitle: dayDate(day, today: today))
        case .day(nil):
            Heading(title: "No date", subtitle: nil)
        case .tag(let tag):
            Heading(title: tag.flatMap { tag in read.tags.first { $0.id == tag }?.title } ?? "No tag", subtitle: nil)
        case .parent(let parent):
            Heading(title: parent.flatMap { read.parents[$0] } ?? "No parent", subtitle: nil)
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
    private static func screenHeading(
        head: Route.Head, title: String, rule: Filter?, read: Read, today: Day
    ) -> Heading {
        guard let group = head.group else {
            return Heading(title: title, subtitle: day(of: rule, today: today).map(longDate))
        }
        let heading = heading(of: groupKey(of: group, today: today), in: read, today: today)
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
    private static func emptyWords(head: Route.Head, view: TaskView, tags: TagNames) -> EmptyWords {
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
