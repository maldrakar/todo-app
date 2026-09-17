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

    @discardableResult
    public func createView(_ new: NewView, at placement: Placement = .end) throws(StoreError) -> ViewID {
        if let parent = new.parent { try requireView(parent) }
        let id = ViewID()
        let rank = try siblingRank(in: .view, parent: new.parent, placement: placement, excluding: nil)
        let stamp = clock.next()
        let fields: [(String, Value)] = [
            ("title", .text(new.title)), ("parent", Value(new.parent?.rawValue)), ("rank", .text(rank)),
            ("filter", try filterValue(new.filter)), ("sort", try sortValue(new.sort)),
            ("group_by", Value(new.groupBy?.rawValue)), ("deleted", Value(false)), ("created_at", .integer(stamp.millis)),
        ]
        try apply(fields.map { op(.view, id.rawValue, $0.0, $0.1, stamp) })
        return id
    }

    /// Sets the given fields. A field named twice keeps the last change for it, for the reason written on
    /// `update(task:_:)`.
    public func update(view id: ViewID, _ changes: [ViewChange]) throws(StoreError) {
        guard !changes.isEmpty else { return }
        try requireView(id)
        let stamp = clock.next()
        // A `map` over a throwing call would need `try` on the whole expression and would still hide which
        // change failed, so the loop builds the list and the two encoders report the filter they refused.
        var ops: [Operation] = []
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

    /// Tombstones the view. Its children move to the root and its manual list stops being read, both by the
    /// reading rule rather than by a write that walks them.
    public func delete(view id: ViewID) throws(StoreError) {
        try requireView(id)
        try setFlag(.view, id, "deleted", true)
    }

    /// Re-parents the view and ranks it among its new siblings, the way `move(tag:to:at:)` does for a tag:
    /// two operations under one stamp, and a move into the view's own subtree refused here rather than left
    /// to the reading rule, which would answer the cycle by putting every view on it at the root.
    public func move(view id: ViewID, to parent: ViewID?, at placement: Placement) throws(StoreError) {
        try requireView(id)
        if let parent {
            guard parent != id else { throw .invalid("a view cannot be its own parent") }
            try requireView(parent)
            if try isUnder(parent, ancestor: id, in: .view) { throw .invalid("a view cannot be moved under its own descendant") }
        }
        let rank = try siblingRank(in: .view, parent: parent, placement: placement, excluding: id)
        let stamp = clock.next()
        try apply([op(.view, id.rawValue, "parent", Value(parent?.rawValue), stamp), op(.view, id.rawValue, "rank", .text(rank), stamp)])
    }

    // MARK: - Manual lists

    /// Puts the task into the view's manual list, where it comes before everything the sort brings. The two
    /// operations share one stamp: a device that saw only the rank would hold a position in a list the task
    /// is not in, which is the case `writePairRow` seeds `present = 0` for.
    public func pin(task: TaskID, in view: ViewID, at placement: Placement = .end) throws(StoreError) {
        try requireTask(task)
        try requireView(view)
        let rank = try Store.rank(among: try pinnedItems(of: view, excluding: task), placement: placement)
        let stamp = clock.next()
        let id = Operation.pairID(view, task)
        try apply([op(.viewItem, id, "present", Value(true), stamp), op(.viewItem, id, "rank", .text(rank), stamp)])
    }

    /// Takes the task out of the manual list. `present = 0` and not a deleted row, for the reason written on
    /// `remove(tag:from:)`: a peer that pinned the same task offline meets a field clock to lose to instead
    /// of an absence that reads as "never pinned". The task itself is not required to be there, the way the
    /// tag is not when a tag is detached; the view is, because it is what the caller is editing.
    public func unpin(task: TaskID, from view: ViewID) throws(StoreError) {
        try requireView(view)
        try apply([op(.viewItem, Operation.pairID(view, task), "present", Value(false), clock.next())])
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
    public func views() throws(StoreError) -> [TodoView] {
        let rows = try sql { () throws(SQLiteError) in
            try db.rows("SELECT id, title, parent, rank, filter, sort, group_by, created_at, updated_at, deleted FROM views")
        }
        let nodes = rows.map { TreeRules.Node(id: $0[0].string ?? "", parent: $0[2].string, deleted: $0[9].bool) }
        let parents = TreeRules.effectiveParents(nodes)
        let views = rows.compactMap { row -> TodoView? in
            guard !row[9].bool else { return nil }
            let id = row[0].string ?? ""
            let definition = ViewDefinition(filter: row[4], sort: row[5], groupBy: row[6])
            return TodoView(
                id: ViewID(id), title: row[1].string ?? "", parent: (parents[id] ?? nil).map(ViewID.init),
                rank: row[3].string ?? Rank.initial, filter: definition.filter, sort: definition.sort,
                groupBy: definition.groupBy, needsNewerApp: definition.needsNewerApp,
                createdAt: row[7].int64 ?? 0, updatedAt: row[8].int64 ?? 0
            )
        }
        return TreeRules.inTreeOrder(views)
    }

    public func view(_ id: ViewID) throws(StoreError) -> TodoView? {
        try views().first { $0.id == id }
    }

    /// The child views of one view, in rank order; `nil` lists the sidebar's top level.
    public func children(ofView parent: ViewID?) throws(StoreError) -> [TodoView] {
        try views().filter { $0.parent == parent }
    }

    // MARK: - Shared helpers

    /// Inserts the built-in views with clock zero from the device `seed`. It runs at every open: the journal's
    /// unique index drops the rows it already holds, and the field clocks keep the state as it is, so the
    /// second open writes nothing. Any edit a person made outranks clock zero, and a built-in view a person
    /// deleted stays deleted.
    ///
    /// The device id is `seed` and not this device's, so that two devices produce byte-identical journal rows
    /// for the same five views and sync merges them instead of racing to create two Inboxes.
    func seedBuiltInViews() throws(StoreError) {
        let zero = HLC(millis: 0, counter: 0)
        var ops: [Operation] = []
        for definition in BuiltInViews.definitions {
            let fields: [(String, Value)] = [
                ("title", .text(definition.title)), ("parent", .null), ("rank", .text(definition.rank)),
                ("filter", try filterValue(definition.filter)), ("sort", try sortValue(definition.sort)),
                ("group_by", Value(definition.groupBy?.rawValue)), ("deleted", Value(false)), ("created_at", .integer(0)),
            ]
            ops += fields.map { Operation(entity: .view, entityID: definition.id.rawValue, field: $0.0, value: $0.1, clock: zero, device: "seed") }
        }
        try apply(ops)
    }

    /// A write names the view it edits, and a caller that names one that is gone gets an error rather than an
    /// operation that creates a row out of nothing, the way `requireTask` guards a task.
    private func requireView(_ id: ViewID) throws(StoreError) {
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT 1 FROM views WHERE id = ? AND deleted = 0", [.text(id.rawValue)]) }
        if rows.isEmpty { throw .notFound(id) }
    }

    /// The manual list of a view as a read shows it, with the ranks a placement needs. A deleted task is
    /// skipped here rather than in every caller: the pair row stays for sync, and nothing shows it again.
    private func pinnedItems(of view: ViewID, excluding: TaskID?) throws(StoreError) -> [(id: String, rank: String)] {
        try sql { () throws(SQLiteError) in
            try db.rows("""
                SELECT v.task_id, v.rank FROM view_items v JOIN tasks t ON t.id = v.task_id AND t.deleted = 0
                WHERE v.view_id = ? AND v.present = 1 AND v.task_id != ? ORDER BY v.rank, v.task_id
                """, [.text(view.rawValue), .text(excluding?.rawValue ?? "")]
            ).map { (id: $0[0].string ?? "", rank: $0[1].string ?? Rank.initial) }
        }
    }

    /// The one place a filter becomes a column value. A filter too deep to read back is refused here, where
    /// it is a message about the filter the caller just built rather than a view that no longer opens.
    private func filterValue(_ filter: Filter?) throws(StoreError) -> Value {
        guard let filter else { return .null }
        do { return .text(try filter.json()) } catch { throw .invalidFilter(String(describing: error)) }
    }

    private func sortValue(_ keys: [SortKey]) throws(StoreError) -> Value {
        do { return .text(try SortKey.json(keys)) } catch { throw .invalidFilter(String(describing: error)) }
    }
}
