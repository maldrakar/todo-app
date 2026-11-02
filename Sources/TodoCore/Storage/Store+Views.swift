// Sources/TodoCore/Storage/Store+Views.swift
import SQLiteKit

/// The definition of a view as this version of the app could read it. Parsing does not throw: a stored
/// definition was written by a device that may be newer, older or wrong, and a view that cannot be read has
/// to name what it could not read rather than take the whole sidebar down with it. `needsNewerApp` is that
/// name, and it is what stops the view from being evaluated.
private struct ViewDefinition {
    let filter: Filter?
    let sort: [SortKey]
    let groupBy: GroupBy?
    let needsNewerApp: String?

    init(filter: Value, sort: Value, groupBy: Value) {
        // Which of the three the read has reached, so that whatever fails is reported by the column it was
        // in. An unsupported node names itself instead, since the kind is what a person can act on; a
        // decoder's diagnostics are not, and never reach the sidebar.
        var reading = "filter"
        do {
            var parsedFilter: Filter?
            if let json = try ViewDefinition.text(filter) { parsedFilter = try Filter(json: json) }
            reading = "sort"
            let keys = try SortKey.parse(json: try ViewDefinition.text(sort) ?? "[]")
            reading = "group_by"
            let parsedGroup = try ViewDefinition.group(try ViewDefinition.text(groupBy))
            self.init(filter: parsedFilter, sort: keys, groupBy: parsedGroup, needsNewerApp: nil)
        } catch {
            let name = switch error {
            case .unsupported(let kind): kind
            case .malformed: reading
            }
            self.init(filter: nil, sort: [], groupBy: nil, needsNewerApp: name)
        }
    }

    /// One of the three columns as text. A null is the column being empty — no filter is a folder, no
    /// grouping is a flat list — and anything else that is not text is a value no version of this app wrote.
    /// Reading that as an empty column would draw a list, and a wrong one, which is what the report avoids.
    /// The column it happened in is `reading` above, so the message here is the one nobody has to read.
    private static func text(_ value: Value) throws(FilterError) -> String? {
        if value.isNull { return nil }
        guard let text = value.string else { throw .malformed("not text") }
        return text
    }

    private static func group(_ raw: String?) throws(FilterError) -> GroupBy? {
        guard let raw else { return nil }
        guard let known = GroupBy(rawValue: raw) else { throw .unsupported(kind: raw) }
        return known
    }

    private init(filter: Filter?, sort: [SortKey], groupBy: GroupBy?, needsNewerApp: String?) {
        self.filter = filter
        self.sort = sort
        self.groupBy = groupBy
        self.needsNewerApp = needsNewerApp
    }
}

extension Store {
    // MARK: - Writes

    /// Writes every field of the new view under one stamp in one transaction. An area is made at the root with
    /// no filter, and a request for one anywhere else is refused here, where it is a message about the view
    /// the caller built, rather than written and then read back as a list (ADR-0004, amendment of 2026-10-25).
    /// A group's view is made from its list by `groupView(of:condition:titled:)` and not here, so that its id is
    /// always the one every device derives, and nothing is made under one, since a group holds no lists (ADR-0004,
    /// amendment of 2026-11-01).
    @discardableResult
    public func createView(_ new: NewTaskView, at placement: Placement = .end) throws(StoreError) -> ViewID {
        switch new.kind {
        case .area:
            guard new.parent == nil else { throw Store.nestedAreaRefusal }
            guard new.filter == nil else { throw .invalid("an area has no rule") }
        case .group:
            throw .invalid("a group's view is made from its list")
        case .list:
            break
        }
        if let parent = new.parent { try requireParent(parent) }
        let id = ViewID()
        try insert(new, id: id, at: placement)
        return id
    }

    /// A view whose rule lists itself, the heading of ADR-0004, made with its title, parent and colour and the
    /// `list` icon in one transaction: the id is minted first, so the filter can name it. It is the list the list
    /// screen's "+ Add list" makes, last among its parent's lists, and a task is in it by being pinned there
    /// (ADR-0004, amendment of 2026-11-01).
    @discardableResult
    public func createManualList(_ title: String, in parent: ViewID, color: TaskViewColor?) throws(StoreError) -> ViewID {
        try requireParent(parent)
        let id = ViewID()
        let new = NewTaskView(title: title, parent: parent, color: color, icon: "list", filter: .listedIn(id))
        try insert(new, id: id, at: .end)
        return id
    }

    /// The view of one group of a list, kind `group`: the list's rule and `condition` written out as its filter,
    /// the list's colour, icon and sort copied, its parent the list, its id derived from the list's id and the
    /// condition. Made when missing; when present, only the fields that differ are written, and nothing when none
    /// does. One transaction or none.
    ///
    /// The condition is named by its JSON from the encoder every filter is written with, whose sorted keys make it
    /// one string on every device, so two devices that open one group derive one id, write one row and the journal
    /// merges them (ADR-0004, amendment of 2026-11-01; ADR-0003). The row with that id is the group's whatever it
    /// holds, deleted alone, moved by an app older than the kind that read it as a list, or made by a peer, and it is
    /// held to what a make would write by `comparedFields(of:)`; a tombstone is a field like any other, so a row
    /// deleted comes back and a row moved returns under its list. Only a list this app reads with a rule has groups:
    /// a view that is not there is not found, one a newer app wrote is reported as the page reports it, and a folder,
    /// an area and a group's view are refused.
    @discardableResult
    public func groupView(of list: ViewID, condition: Filter, titled title: String) throws(StoreError) -> ViewID {
        let view = try Store.readableView(list, among: try views())
        switch view.kind {
        case .group: throw .invalid("a group has no groups")
        case .area: throw Store.folderRefusal
        case .list: break
        }
        guard let rule = view.filter else { throw Store.folderRefusal }
        let id = ViewID.derived(from: list, try filterJSON(condition))
        let new = NewTaskView(
            title: title, parent: list, kind: .group, color: view.color, icon: view.icon,
            filter: .and([rule, condition]), sort: view.sort
        )
        let fields = try comparedFields(of: new)
        let stored = try sql { () throws(SQLiteError) in
            try db.rows("SELECT \(fields.map(\.0).joined(separator: ", ")) FROM views WHERE id = ?", [.text(id.rawValue)])
        }
        guard let row = stored.first else {
            try insert(new, id: id, at: .end)
            return id
        }
        let differing = zip(fields, row).compactMap { field, stored in field.1 == stored ? nil : field }
        guard !differing.isEmpty else { return id }
        let stamp = clock.next()
        try apply(differing.map { op(.view, id.rawValue, $0.0, $0.1, stamp) })
        return id
    }

    /// Sets the given fields. A field named twice keeps the last change for it, for the reason written on
    /// `update(task:_:)`.
    public func update(view id: ViewID, _ changes: [TaskViewChange]) throws(StoreError) {
        guard !changes.isEmpty else { return }
        try requireView(id)
        let stamp = clock.next()
        // A `map` over a throwing call would need `try` on the whole expression and would still hide which
        // change failed, so the loop builds the list and the two encoders report the filter they refused.
        var ops: [JournalOperation] = []
        for change in Store.lastPerField(changes, by: { $0.field }) {
            switch change {
            case .title(let title): ops.append(op(.view, id.rawValue, "title", .text(title), stamp))
            case .filter(let filter): ops.append(op(.view, id.rawValue, "filter", try filterValue(filter), stamp))
            case .sort(let sort): ops.append(op(.view, id.rawValue, "sort", try sortValue(sort), stamp))
            case .groupBy(let group): ops.append(op(.view, id.rawValue, "group_by", Value(group?.rawValue), stamp))
            }
        }
        try apply(ops)
    }

    /// Tombstones the view, and the views of its groups with it, under one stamp in one transaction: a group's view
    /// lives and dies with its list, since it cannot stand anywhere else, and a row left behind would reach an app
    /// older than the kind, which reads it as a list (owner's review of the list screen plan, 2026-11-02). Its other
    /// children move to the root and its manual list stops being read, both by the reading rule rather than by a
    /// write that walks them.
    public func delete(view id: ViewID) throws(StoreError) {
        try requireView(id)
        let groups = try views().filter { $0.parent == id && $0.kind == .group }
        let stamp = clock.next()
        try apply(([id] + groups.map(\.id)).map { op(.view, $0.rawValue, "deleted", Value(true), stamp) })
    }

    /// Tombstones the view and every view under it, where `delete(view:)` tombstones one and lets its children
    /// surface at the root (spec section 6). The subtree is the one `views()` reads, in its one pass: parents
    /// come before children there, so a view is under the deleted one exactly when its parent has been taken
    /// before it, and nothing walks down the tree by recursion. One operation per view under one stamp, in one
    /// `apply`, which is one transaction, so the tree goes whole or not at all. The tasks are untouched, since
    /// a rule selects them and a rule gone selects nothing, and the manual lists of the deleted views stop
    /// being read, as after `delete(view:)`. The views of the groups of every list in the tree are in the subtree
    /// `views()` reads, under their lists, and go with them.
    public func delete(viewTree id: ViewID) throws(StoreError) {
        try requireView(id)
        let stamp = clock.next()
        var taken: Set<ViewID> = []
        var ops: [JournalOperation] = []
        for view in try views() where view.id == id || view.parent.map({ taken.contains($0) }) == true {
            taken.insert(view.id)
            ops.append(op(.view, view.id.rawValue, "deleted", Value(true), stamp))
        }
        try apply(ops)
    }

    /// Re-parents the view and ranks it among its new siblings, the way `move(tag:to:at:)` does for a tag:
    /// two operations under one stamp, and a move into the view's own subtree refused here rather than left
    /// to the reading rule, which would answer the cycle by putting every view on it at the root. An area
    /// moves along the root and nowhere else, and is told by the kind its row stores, so a move of one under
    /// any view is refused as `createView` refuses a nested one. A group's view stays under its list and holds no
    /// lists, so a move of one is refused, and so is a move under one (ADR-0004, amendment of 2026-11-01).
    public func move(view id: ViewID, to parent: ViewID?, at placement: Placement) throws(StoreError) {
        let kind = try requireView(id)
        guard kind != .group else { throw .invalid("a group's view stays under its list") }
        if let parent {
            guard kind != .area else { throw Store.nestedAreaRefusal }
            guard parent != id else { throw .invalid("a view cannot be its own parent") }
            try requireParent(parent)
            if try isUnder(parent, ancestor: id, in: .view) { throw .invalid("a view cannot be moved under its own descendant") }
        }
        let rank = try siblingRank(in: .view, parent: parent, placement: placement, excluding: id)
        let stamp = clock.next()
        try apply([op(.view, id.rawValue, "parent", Value(parent?.rawValue), stamp), op(.view, id.rawValue, "rank", .text(rank), stamp)])
    }

    // MARK: - Manual lists

    /// Puts the task into the view's manual list, where it comes before everything the sort brings inside its
    /// own group — the whole list being one group when the view groups by nothing (`group(_:by:manual:)`). The two
    /// operations share one stamp: a device that saw only the rank would hold a position in a list the task
    /// is not in, which is the case `writePairRow` seeds `present = 0` for.
    public func pin(task: TaskID, in view: ViewID, at placement: Placement = .end) throws(StoreError) {
        try requireTask(task)
        try requireView(view)
        let rank = try Store.rank(among: try pinnedItems(of: view, excluding: task), placement: placement)
        let stamp = clock.next()
        let id = JournalOperation.pairID(view, task)
        try apply([op(.viewItem, id, "present", Value(true), stamp), op(.viewItem, id, "rank", .text(rank), stamp)])
    }

    /// Takes the task out of the manual list. `present = 0` and not a deleted row, for the reason written on
    /// `remove(tag:from:)`: a peer that pinned the same task offline meets a field clock to lose to instead
    /// of an absence that reads as "never pinned". The task itself is not required to be there, the way the
    /// tag is not when a tag is detached; the view is, because it is what the caller is editing.
    public func unpin(task: TaskID, from view: ViewID) throws(StoreError) {
        try requireView(view)
        try apply([op(.viewItem, JournalOperation.pairID(view, task), "present", Value(false), clock.next())])
    }

    /// The pinned tasks of a view in their manual order.
    public func manualList(of view: ViewID) throws(StoreError) -> [TaskID] {
        try pinnedItems(of: view, excluding: nil).map { TaskID($0.id) }
    }

    // MARK: - Reads

    /// Every view, parents before children, siblings by rank. `parent` is effective: a link to a missing,
    /// deleted or circular parent reads as root, exactly as `task_tree` resolves the same hazard for tasks.
    ///
    /// This loads the whole table. Views number in the tens, and the tree order needs every row anyway, so
    /// the query that would ask for one branch would still have to read the rest to know where it hangs.
    ///
    /// The kind, the colour and the icon are read by the rules written on `TaskView`: whatever another device
    /// wrote into the three columns reads as something, and a name this app does not know reads as none.
    ///
    /// A group stands under a view that is stored, live and no group, with a rule, and reads as gone anywhere else,
    /// rather than lifted to the root by `effectiveParents` as any other child of a missing parent is, where it would
    /// stand as a list named "Tomorrow" (owner's review of the list screen plan, 2026-11-02). The views that can hold
    /// one are taken from the rows in one pass, and a stray group's node is marked deleted before the parents resolve,
    /// so a list a peer put under it surfaces at the root, as a list under any deleted view does, and a group under it
    /// reads as gone too, since no group holds one.
    public func views() throws(StoreError) -> [TaskView] {
        let rows = try sql { () throws(SQLiteError) in
            try db.rows("SELECT id, title, parent, rank, filter, sort, group_by, created_at, updated_at, deleted, kind, color, icon FROM views")
        }
        let canHoldGroups = Set(rows.compactMap { $0[9].bool || Store.storedViewKind($0[10]) == .group ? nil : $0[0].string })
        let nodes = rows.map { row in
            let isStrayGroup = Store.storedViewKind(row[10]) == .group
                && (row[4].isNull || row[2].string.map(canHoldGroups.contains) != true)
            return TreeRules.Node(id: row[0].string ?? "", parent: row[2].string, deleted: row[9].bool || isStrayGroup)
        }
        let parents = TreeRules.effectiveParents(nodes)
        let views = zip(rows, nodes).compactMap { row, node -> TaskView? in
            guard !node.deleted else { return nil }
            let id = row[0].string ?? ""
            let parent = (parents[id] ?? nil).map(ViewID.init(_:))
            let definition = ViewDefinition(filter: row[4], sort: row[5], groupBy: row[6])
            return TaskView(
                id: ViewID(id), title: row[1].string ?? "", parent: parent, rank: row[3].string ?? Rank.initial,
                kind: Store.viewKind(stored: row[10], parent: parent, filter: row[4]),
                color: row[11].string.flatMap(TaskViewColor.init(rawValue:)), icon: row[12].string,
                filter: definition.filter, sort: definition.sort, groupBy: definition.groupBy,
                needsNewerApp: definition.needsNewerApp, createdAt: row[7].int64 ?? 0, updatedAt: row[8].int64 ?? 0
            )
        }
        return TreeRules.inTreeOrder(views)
    }

    public func view(_ id: ViewID) throws(StoreError) -> TaskView? {
        try views().first { $0.id == id }
    }

    /// The child views of one view, in rank order; `nil` lists the sidebar's top level.
    public func children(ofView parent: ViewID?) throws(StoreError) -> [TaskView] {
        try views().filter { $0.parent == parent }
    }

    // MARK: - Shared helpers

    /// Inserts the built-in views with clock zero from the device `seed`. It runs at every open: the journal's
    /// unique index drops the rows it already holds, and the field clocks keep the state as it is, so the
    /// second open writes nothing. Any edit a person made outranks clock zero, and a built-in view a person
    /// deleted stays deleted.
    ///
    /// The device id is `Store.seedDevice` and not this device's, so that two devices produce byte-identical
    /// journal rows for the same five views and sync merges them instead of racing to create two Inboxes. It
    /// is outside `own_devices`, which is what keeps these rows out of every push.
    ///
    /// A store an earlier version seeded already holds the fields it knew, and the ones it did not, the kind,
    /// the colour and the icon, are new rows that apply at the first open by this version: no clock holds those
    /// fields yet, so the built-ins show their tiles at once.
    func seedBuiltInViews() throws(StoreError) {
        let zero = HLC(millis: 0, counter: 0)
        var ops: [JournalOperation] = []
        for definition in BuiltInTaskViews.definitions {
            let fields = try creationFields(of: definition.view, rank: definition.rank, createdAt: 0)
            ops += fields.map { JournalOperation(entity: .view, entityID: definition.id.rawValue, field: $0.0, value: $0.1, clock: zero, device: Store.seedDevice) }
        }
        try apply(ops)
    }

    /// Every field of a new view under one stamp in one transaction, ranked at `placement` among its parent's views,
    /// under the id its caller chose: a fresh one for `createView` and for `createManualList`, whose rule names it,
    /// and the derived one for `groupView`. The seed writes its fixed ids at clock zero instead.
    private func insert(_ new: NewTaskView, id: ViewID, at placement: Placement) throws(StoreError) {
        let rank = try siblingRank(in: .view, parent: new.parent, placement: placement, excluding: nil)
        let stamp = clock.next()
        let fields = try creationFields(of: new, rank: rank, createdAt: stamp.millis)
        try apply(fields.map { op(.view, id.rawValue, $0.0, $0.1, stamp) })
    }

    /// Every field a view is created with, for `insert` and the seed alike, so that a built-in is written exactly as
    /// a view a person makes. A colour or an icon the view has none of is a null like any other.
    private func creationFields(of new: NewTaskView, rank: String, createdAt: Int64) throws(StoreError) -> [(String, Value)] {
        try comparedFields(of: new) + [
            ("rank", .text(rank)), ("group_by", Value(new.groupBy?.rawValue)), ("created_at", .integer(createdAt)),
        ]
    }

    /// The fields of a make a group's view is held to when its group is opened again (`groupView`): all but the
    /// rank, the grouping and the time it was made, which only the make writes. Two devices that made one row each
    /// ranked it and made it when they did, which is no difference of the group, and nothing gives a group a grouping
    /// that opening it should take back.
    private func comparedFields(of new: NewTaskView) throws(StoreError) -> [(String, Value)] {
        [
            ("title", .text(new.title)), ("parent", Value(new.parent?.rawValue)), ("kind", .text(new.kind.rawValue)),
            ("color", Value(new.color?.rawValue)), ("icon", Value(new.icon)),
            ("filter", try filterValue(new.filter)), ("sort", try sortValue(new.sort)), ("deleted", Value(false)),
        ]
    }

    /// The refusal of an area anywhere but the root, which a create and a move both answer with.
    private static let nestedAreaRefusal = StoreError.invalid("an area cannot be nested")

    /// The refusal of a group's view of a view that selects nothing, a folder or an area, which has no groups.
    private static let folderRefusal = StoreError.invalid("a folder has no groups")

    /// The kind a view reads as. An area stands only at the root and selects nothing, so the column's `area`
    /// reads as one only where the view is that, with no effective parent and an empty filter column, and as a
    /// list anywhere else: a folder, or a list with a rule, which is what an app older than the field made of
    /// it when it nested it or gave it a rule (spec section 2). That is a reading rule and not a repair, as
    /// `TreeRules` reads a broken parent link as no link. A group reaches here only where `views()` kept it, under
    /// a view that holds it and with a rule, and reads as one; it is never read as a list, which is what the rule
    /// that reads it as gone is for.
    private static func viewKind(stored: Value, parent: ViewID?, filter: Value) -> TaskViewKind {
        switch storedViewKind(stored) {
        case .area: parent == nil && filter.isNull ? .area : .list
        case .group: .group
        case .list: .list
        }
    }

    /// The kind the column names, before the reading rules above: anything but `area` and `group` is a list, an
    /// unknown name, a null from a view written before the column and a value that is not text among them.
    private static func storedViewKind(_ value: Value) -> TaskViewKind {
        value.string.flatMap(TaskViewKind.init(rawValue:)) ?? .list
    }

    /// A write names the view it edits, and a caller that names one that is gone gets an error rather than an
    /// operation that creates a row out of nothing, the way `requireTask` guards a task. It answers the kind
    /// the row stores, read in the same statement, which is what `move` tells an area and a group by, and a
    /// parent a group (`requireParent`); the other callers only need the row to be there.
    @discardableResult
    private func requireView(_ id: ViewID) throws(StoreError) -> TaskViewKind {
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT kind FROM views WHERE id = ? AND deleted = 0", [.text(id.rawValue)]) }
        guard let row = rows.first else { throw .notFound(id) }
        return Store.storedViewKind(row[0])
    }

    /// The view a view is made or moved under: there, and no group's view, which holds no lists, as an area holds
    /// no tasks (ADR-0004, amendment of 2026-11-01).
    private func requireParent(_ id: ViewID) throws(StoreError) {
        guard try requireView(id) != .group else { throw .invalid("a group's view holds no lists") }
    }

    /// The second statement every grouped read runs, and the one a placement ranks among. It is a constant
    /// rather than a literal inside the read below for the reason `viewStatement` is assembled where it is:
    /// `builtInViewsUseIndexes` explains this exact string, and a guard that explained a copy would pass
    /// while the copy drifted away from the query a person waits on.
    static let manualListQuery = """
        SELECT v.task_id, v.rank FROM view_items v JOIN tasks t ON t.id = v.task_id AND t.deleted = 0
        WHERE v.view_id = ? AND v.present = 1 AND v.task_id != ? ORDER BY v.rank, v.task_id
        """

    /// The manual list of a view as a read shows it, with the ranks a placement needs. A deleted task is
    /// skipped here rather than in every caller: the pair row stays for sync, and nothing shows it again.
    private func pinnedItems(of view: ViewID, excluding: TaskID?) throws(StoreError) -> [(id: String, rank: String)] {
        try sql { () throws(SQLiteError) in
            try db.rows(Store.manualListQuery, [.text(view.rawValue), .text(excluding?.rawValue ?? "")])
                .map { (id: $0[0].string ?? "", rank: $0[1].string ?? Rank.initial) }
        }
    }

    /// The one place a filter becomes a column value. A filter too deep to read back is refused here, where
    /// it is a message about the filter the caller just built rather than a view that no longer opens.
    private func filterValue(_ filter: Filter?) throws(StoreError) -> Value {
        guard let filter else { return .null }
        return .text(try filterJSON(filter))
    }

    /// A filter as the column holds it, which is also how `groupView` names a condition: the sorted-keys JSON
    /// every device writes alike, refused past the depth a read takes, as every filter written is.
    private func filterJSON(_ filter: Filter) throws(StoreError) -> String {
        do { return try filter.json() } catch { throw .invalidFilter(String(describing: error)) }
    }

    private func sortValue(_ keys: [SortKey]) throws(StoreError) -> Value {
        do { return .text(try SortKey.json(keys)) } catch { throw .invalidFilter(String(describing: error)) }
    }
}
