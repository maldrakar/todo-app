// Sources/TodoCore/Storage/Store+Tasks.swift
import SQLiteKit

extension Store {
    /// Every column a `TodoTask` is read from, in the order `task(from:)` decodes them. `parent` and `trashed`
    /// come from the tree and not from `tasks`, which is what makes a merge's leftovers invisible to a read.
    static let taskColumns = "t.id, t.title, t.status, t.when_day, t.deadline_day, tt.parent, t.rank, tt.trashed, t.created_at, t.updated_at, t.completed_at"

    // MARK: - Writes

    /// Creates a task and returns its id. Every field the caller gave is one operation in the same
    /// transaction, so a task never exists half-written, and the `created_at` operation is what carries this
    /// device's stamp into the row.
    @discardableResult
    public func createTask(_ new: NewTask, at placement: Placement = .end) throws(StoreError) -> TaskID {
        if let parent = new.parent { try requireTask(parent) }
        for tag in new.tags { try requireTag(tag) }
        let id = TaskID()
        let rank = try siblingRank(in: .task, parent: new.parent, placement: placement, excluding: nil)
        let stamp = clock.next()
        let fields: [(String, Value)] = [
            ("title", .text(new.title)), ("notes", .text(new.notes)), ("status", .integer(TaskStatus.open.rawValue)),
            ("when_day", Value(new.when?.daysSinceEpoch)), ("deadline_day", Value(new.deadline?.daysSinceEpoch)),
            ("parent", Value(new.parent?.rawValue)), ("rank", .text(rank)), ("trashed", Value(false)), ("deleted", Value(false)),
            ("created_at", .integer(stamp.millis)),
        ]
        var ops = fields.map { op(.task, id.rawValue, $0.0, $0.1, stamp) }
        for tag in new.tags { ops.append(op(.taskTag, Operation.pairID(id, tag), "present", Value(true), stamp)) }
        try apply(ops)
        return id
    }

    /// Sets the given fields. The completion time follows the status rather than being written by the caller:
    /// a task that leaves `open` records when it left, and one that returns to it has no completion time at
    /// all. Both are one operation each, so the two fields cannot disagree after a merge. A status the task
    /// already holds is not a crossing and moves nothing — marking a done task done again, which a bulk edit
    /// or a checkbox that re-sends its state does all the time, must not reorder the Logbook.
    ///
    /// A field named twice keeps the last change for it. Every operation of one call carries one stamp, so
    /// two of them for one field would meet as equals in `apply`, the second would lose the comparison and
    /// its journal row would be dropped as a duplicate: the value would be gone from the state and from a
    /// future sync alike, without a sound.
    public func update(task id: TaskID, _ changes: [TaskChange]) throws(StoreError) {
        guard !changes.isEmpty else { return }
        // The status the task holds now, and the existence check in the same query: the completion time below
        // moves only when the task crosses in or out of `open`, which is not a question the caller's list can
        // answer on its own.
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT status FROM tasks WHERE id = ? AND deleted = 0", [.text(id.rawValue)]) }
        guard let row = rows.first else { throw .notFound(id) }
        let current = TaskStatus(rawValue: row[0].int64 ?? 0) ?? .open
        let stamp = clock.next()
        var ops: [Operation] = []
        for change in Store.lastPerField(changes, by: { $0.field }) {
            switch change {
            case .title(let title): ops.append(op(.task, id.rawValue, "title", .text(title), stamp))
            case .notes(let notes): ops.append(op(.task, id.rawValue, "notes", .text(notes), stamp))
            case .when(let day): ops.append(op(.task, id.rawValue, "when_day", Value(day?.daysSinceEpoch), stamp))
            case .deadline(let day): ops.append(op(.task, id.rawValue, "deadline_day", Value(day?.daysSinceEpoch), stamp))
            case .status(let status):
                ops.append(op(.task, id.rawValue, "status", .integer(status.rawValue), stamp))
                if (status == .open) != (current == .open) {
                    ops.append(op(.task, id.rawValue, "completed_at", status == .open ? .null : .integer(stamp.millis), stamp))
                }
            }
        }
        try apply(ops)
    }

    /// Moves the task to the trash, which a person can see into and take things back out of. Its descendants
    /// follow through the tree without an operation of their own, so `restore` brings back exactly what the
    /// trashing took down.
    public func trash(task id: TaskID) throws(StoreError) { try setFlag(.task, id, "trashed", true) }

    /// Takes the task out of the trash, and with it everything that went down with it.
    public func restore(task id: TaskID) throws(StoreError) { try setFlag(.task, id, "trashed", false) }

    /// Tombstones the task: emptying the trash, and the half of the pair that does not come back. `trashed`
    /// is a place a task sits in and can leave; `deleted` ends it. The row itself stays behind, because a
    /// peer that never heard of the deletion would sync the task back from its own copy, and a tombstone is
    /// how it learns instead. Nothing reads the task again, and its children move to the root rather than
    /// vanish underneath it.
    public func delete(task id: TaskID) throws(StoreError) { try setFlag(.task, id, "deleted", true) }

    /// Re-parents the task and ranks it among its new siblings. The two operations share one stamp: a device
    /// that sees only one of them would place the task in a list it is not in.
    public func move(task id: TaskID, to parent: TaskID?, at placement: Placement) throws(StoreError) {
        try requireTask(id)
        if let parent {
            guard parent != id else { throw .invalid("a task cannot be its own parent") }
            try requireTask(parent)
            // A move into the task's own subtree closes a cycle, and the reading rule of ADR-0003 answers a
            // cycle by putting every task on it at the root: a person who drags a project onto one of its own
            // items would watch the subtree scatter. That rule is for merges, where neither of two concurrent
            // links is the better one and neither device ever saw the cycle; here the whole tree is in hand.
            if try isUnder(parent, ancestor: id, in: .task) { throw .invalid("a task cannot be moved under its own descendant") }
        }
        let rank = try siblingRank(in: .task, parent: parent, placement: placement, excluding: id)
        let stamp = clock.next()
        try apply([op(.task, id.rawValue, "parent", Value(parent?.rawValue), stamp), op(.task, id.rawValue, "rank", .text(rank), stamp)])
    }

    /// Ranks the task among the siblings it already has, without saying anything about its parent.
    ///
    /// `move(task:to:at:)` can do this too, by being handed the parent the task is under — but then the write
    /// carries a `parent` operation at a new stamp, and this device asserts the link a peer may have moved in
    /// the meantime. A drag inside one list means nothing about the parent, so it writes the rank alone.
    public func move(task id: TaskID, at placement: Placement) throws(StoreError) {
        try requireTask(id)
        let rank = try siblingRank(in: .task, parent: try effectiveParent(of: id, in: .task), placement: placement, excluding: id)
        try apply([op(.task, id.rawValue, "rank", .text(rank), clock.next())])
    }

    public func add(tag: TagID, to task: TaskID) throws(StoreError) {
        try requireTask(task)
        try requireTag(tag)
        try apply([op(.taskTag, Operation.pairID(task, tag), "present", Value(true), clock.next())])
    }

    /// Detaching is a `present = 0` and not a deleted row, so that a peer that attached the same tag offline
    /// meets a field clock to lose to instead of an absence that reads as "never attached". The tag itself is
    /// not required to be there: a tag deleted on another device is exactly one a person may be detaching.
    public func remove(tag: TagID, from task: TaskID) throws(StoreError) {
        try requireTask(task)
        try apply([op(.taskTag, Operation.pairID(task, tag), "present", Value(false), clock.next())])
    }

    // MARK: - Reads

    public func task(_ id: TaskID) throws(StoreError) -> TodoTask? {
        try loadTasks(where: "t.id = ?", [.text(id.rawValue)], orderBy: "t.rank").first
    }

    /// The notes of a task, read on their own. Throws if the task is not there, which is what tells an empty
    /// note apart from a task that no longer exists.
    public func notes(of id: TaskID) throws(StoreError) -> String {
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT notes FROM tasks WHERE id = ? AND deleted = 0", [.text(id.rawValue)]) }
        guard let row = rows.first else { throw .notFound(id) }
        return row[0].string ?? ""
    }

    /// Direct children by effective parent, in rank order. `nil` lists the root.
    public func children(of parent: TaskID?, includeTrashed: Bool = false) throws(StoreError) -> [TodoTask] {
        try loadTasks(where: "tt.parent IS ? AND (? OR tt.trashed = 0)", [Value(parent?.rawValue), Value(includeTrashed)], orderBy: "t.rank, t.id")
    }

    /// Every task that is not deleted, oldest first. The CLI resolves id prefixes over this list.
    public func allTasks(includeTrashed: Bool = false) throws(StoreError) -> [TodoTask] {
        try loadTasks(where: "(? OR tt.trashed = 0)", [Value(includeTrashed)], orderBy: "t.created_at, t.id")
    }

    // MARK: - Shared helpers

    /// A write names the task it edits, and a caller that names one that is gone gets an error rather than an
    /// operation that creates a row out of nothing: `applyToState` inserts the row it does not find, which is
    /// what sync needs and what a typo must not reach.
    func requireTask(_ id: TaskID) throws(StoreError) {
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT 1 FROM tasks WHERE id = ? AND deleted = 0", [.text(id.rawValue)]) }
        if rows.isEmpty { throw .notFound(id) }
    }

    func setFlag(_ kind: EntityKind, _ id: EntityID, _ field: String, _ value: Bool) throws(StoreError) {
        if kind == .task { try requireTask(id) }
        try apply([op(kind, id.rawValue, field, Value(value), clock.next())])
    }

    /// A rank among the siblings of `parent` in `table`: `tasks` asks the effective parent from `task_tree`,
    /// `tags` and `views` the raw column, since neither has a derived table of its own.
    ///
    /// The siblings are read at the moment of the write, so two devices editing the same list offline can and
    /// do compute the same key. That is what `Rank.between` tolerates and what the `, id` in every order
    /// clause settles: equal ranks fall back to the id, and the list is stable everywhere.
    func siblingRank(in kind: EntityKind, parent: EntityID?, placement: Placement, excluding: EntityID?) throws(StoreError) -> String {
        try Store.rank(among: try orderedSiblings(in: kind, parent: parent, excluding: excluding), placement: placement)
    }

    /// The fractional key a placement asks for in an ordered list, whatever the list is: the siblings of a
    /// task, a tag or a view, or the manual list of a view (Task 9). The caller reads the list a read would
    /// show and leaves out the item being placed, so `.after` finds its anchor among exactly the rows a
    /// person sees, and a placement never ranks among a list nobody does.
    static func rank(among ordered: [(id: String, rank: String)], placement: Placement) throws(StoreError) -> String {
        switch placement {
        case .end: return Rank.between(ordered.last?.rank, nil)
        case .start: return Rank.between(nil, ordered.first?.rank)
        case .after(let anchor):
            guard let index = ordered.firstIndex(where: { $0.id == anchor.rawValue }) else { throw .notFound(anchor) }
            let upper = index + 1 < ordered.count ? ordered[index + 1].rank : nil
            return Rank.between(ordered[index].rank, upper)
        }
    }

    /// The siblings a read would show under `parent`, in the order it would show them, which is the list a
    /// placement has to rank among. Tasks take their effective parent from `task_tree`; tags and views have
    /// no derived table of their own, so the same rule is applied here instead of trusting the column —
    /// a tag whose stored parent was deleted, or made circular by a merge, is at the root of every read, and
    /// a placement that ranked it against the raw column would rank among a list nobody sees.
    private func orderedSiblings(in kind: EntityKind, parent: EntityID?, excluding: EntityID?) throws(StoreError) -> [(id: String, rank: String)] {
        if kind == .task {
            return try sql { () throws(SQLiteError) in
                try db.rows(
                    "SELECT t.id, t.rank FROM tasks t JOIN task_tree tt ON tt.id = t.id WHERE tt.parent IS ? AND t.id != ? ORDER BY t.rank, t.id",
                    [Value(parent?.rawValue), .text(excluding?.rawValue ?? "")]
                ).map { ($0[0].string ?? "", $0[1].string ?? Rank.initial) }
            }
        }
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT id, parent, rank, deleted FROM \(FieldMap.table(kind))") }
        let parents = TreeRules.effectiveParents(rows.map { TreeRules.Node(id: $0[0].string ?? "", parent: $0[1].string, deleted: $0[3].bool) })
        return rows.compactMap { row -> (id: String, rank: String)? in
            let id = row[0].string ?? ""
            guard !row[3].bool, id != excluding?.rawValue, (parents[id] ?? nil) == parent?.rawValue else { return nil }
            return (id, row[2].string ?? Rank.initial)
        }.sorted { ($0.rank, $0.id) < ($1.rank, $1.id) }
    }

    /// The item's parent as a read sees it, which is the list a reorder ranks among.
    func effectiveParent(of id: EntityID, in kind: EntityKind) throws(StoreError) -> EntityID? {
        if kind == .task {
            let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT parent FROM task_tree WHERE id = ?", [.text(id.rawValue)]) }
            return rows.first?[0].string.map(EntityID.init)
        }
        return (try effectiveParents(in: kind)[id.rawValue] ?? nil).map(EntityID.init)
    }

    /// Whether `id` sits under `ancestor` as a read sees the tree, which is what a move has to refuse.
    ///
    /// For tasks the walk is SQLite's and not the stack's, and `UNION` bounds it even if `task_tree` ever held
    /// a cycle, which `TreeRules` promises it does not. For the kinds without a derived tree the same promise
    /// is what ends the loop: every chain of effective parents reaches a root in a finite number of steps.
    func isUnder(_ id: EntityID, ancestor: EntityID, in kind: EntityKind) throws(StoreError) -> Bool {
        if kind == .task {
            let rows = try sql { () throws(SQLiteError) in
                try db.rows("""
                    WITH RECURSIVE ancestors(id) AS (
                        SELECT ?
                        UNION
                        SELECT tt.parent FROM task_tree tt JOIN ancestors a ON tt.id = a.id WHERE tt.parent IS NOT NULL
                    )
                    SELECT 1 FROM ancestors WHERE id = ? LIMIT 1
                    """, [.text(id.rawValue), .text(ancestor.rawValue)])
            }
            return !rows.isEmpty
        }
        let parents = try effectiveParents(in: kind)
        var cursor: String? = id.rawValue
        while let current = cursor {
            if current == ancestor.rawValue { return true }
            cursor = parents[current] ?? nil
        }
        return false
    }

    /// Effective parent links of a table that has no derived tree of its own, by the rule every read follows.
    private func effectiveParents(in kind: EntityKind) throws(StoreError) -> [String: String?] {
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT id, parent, deleted FROM \(FieldMap.table(kind))") }
        return TreeRules.effectiveParents(rows.map { TreeRules.Node(id: $0[0].string ?? "", parent: $0[1].string, deleted: $0[2].bool) })
    }

    /// The last change for each field, in the order the fields first appear. What it is for is written where
    /// the write methods use it.
    static func lastPerField<Change>(_ changes: [Change], by field: (Change) -> String) -> [Change] {
        var latest: [String: Change] = [:]
        var order: [String] = []
        for change in changes where latest.updateValue(change, forKey: field(change)) == nil { order.append(field(change)) }
        return order.compactMap { latest[$0] }
    }

    /// Loads tasks with their tags. `clause` may use the aliases `t` (tasks) and `tt` (task_tree), which is
    /// all a filter has needed: a view's manual list is a read of its own and the searches of Task 10 select
    /// through a subquery, so the loader joins the tree and nothing else. `limit` is Task 10's.
    func loadTasks(where clause: String, _ params: [Value], orderBy: String, limit: Int? = nil) throws(StoreError) -> [TodoTask] {
        try loadTasks(sql: Store.taskQuery(where: clause, orderBy: orderBy, limit: limit), params)
    }

    /// The statement the loader above runs, assembled and not executed. A view's read builds it through
    /// here and hands the same string to `EXPLAIN QUERY PLAN` in the suite: a plan explained from a second
    /// copy of the SQL would keep passing while the copy drifted away from the query a person waits on.
    static func taskQuery(where clause: String, orderBy: String, limit: Int?) -> String {
        let limitClause = limit.map { " LIMIT \($0)" } ?? ""
        return "SELECT \(Store.taskColumns) FROM tasks t JOIN task_tree tt ON tt.id = t.id WHERE t.deleted = 0 AND (\(clause)) ORDER BY \(orderBy)\(limitClause)"
    }

    /// Runs an assembled task query and attaches the tags.
    func loadTasks(sql: String, _ params: [Value]) throws(StoreError) -> [TodoTask] {
        let rows = try self.sql { () throws(SQLiteError) in try db.rows(sql, params) }
        let tags = try tagsByTask(rows.map { $0[0].string ?? "" })
        return rows.map { Store.task(from: $0, tags: tags[$0[0].string ?? ""] ?? []) }
    }

    static func task(from row: [Value], tags: Set<TagID>) -> TodoTask {
        TodoTask(
            id: TaskID(row[0].string ?? ""),
            title: row[1].string ?? "",
            status: TaskStatus(rawValue: row[2].int64 ?? 0) ?? .open,
            // A day column is a plain INTEGER and holds whatever a peer or a newer version of the app wrote
            // into it, while `Day` is 32 bits wide. A conversion that trapped would abort the process on every
            // read of every list the task appears in, for as long as the value is stored (#34), so a day the
            // type cannot hold reads as no day, the way an unusable parent link reads as no link.
            when: row[3].int64.flatMap { Int32(exactly: $0) }.map(Day.init(daysSinceEpoch:)),
            deadline: row[4].int64.flatMap { Int32(exactly: $0) }.map(Day.init(daysSinceEpoch:)),
            parent: row[5].string.map(TaskID.init),
            rank: row[6].string ?? Rank.initial,
            tags: tags,
            trashed: row[7].bool,
            createdAt: row[8].int64 ?? 0,
            updatedAt: row[9].int64 ?? 0,
            completedAt: row[10].int64
        )
    }

    /// One query for the tags of a whole page of tasks instead of one per task, chunked because SQLite has a
    /// limit on how many parameters a statement takes. A tag that has been deleted is left out here rather
    /// than in every caller: the pair row stays for sync, and nothing shows it again.
    private func tagsByTask(_ ids: [String]) throws(StoreError) -> [String: Set<TagID>] {
        guard !ids.isEmpty else { return [:] }
        var tags: [String: Set<TagID>] = [:]
        for chunk in Store.chunked(ids) {
            let rows = try sql { () throws(SQLiteError) in
                try db.rows("SELECT x.task_id, x.tag_id FROM task_tags x JOIN tags g ON g.id = x.tag_id AND g.deleted = 0 WHERE x.present = 1 AND x.task_id IN (\(Store.placeholders(chunk.count)))", chunk.map { .text($0) })
            }
            for row in rows { tags[row[0].string ?? "", default: []].insert(TagID(row[1].string ?? "")) }
        }
        return tags
    }
}
