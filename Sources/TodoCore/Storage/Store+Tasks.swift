// Sources/TodoCore/Storage/Store+Tasks.swift
import SQLiteKit

extension Store {
    /// Every column a `Task` is read from, in the order `task(from:)` decodes them. `parent` and `trashed`
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
        let rank = try siblingRank(table: "tasks", parent: new.parent, placement: placement, excluding: nil)
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
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT status FROM tasks WHERE id = ? AND deleted = 0", [.text(id.rawValue)]) }
        guard let row = rows.first else { throw .notFound(id) }
        let current = TaskStatus(rawValue: row[0].int64 ?? 0) ?? .open
        guard !changes.isEmpty else { return }
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

    /// Moves the task to the trash. Its descendants follow through the tree without an operation of their own,
    /// so restoring it brings back exactly what it took down.
    public func trash(task id: TaskID) throws(StoreError) { try setFlag(.task, id, "trashed", true) }

    public func restore(task id: TaskID) throws(StoreError) { try setFlag(.task, id, "trashed", false) }

    /// Tombstones the task: the row stays for sync, nothing shows it again, and its children move to the root.
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
            if try isUnder(parent, ancestor: id) { throw .invalid("a task cannot be moved under its own descendant") }
        }
        let rank = try siblingRank(table: "tasks", parent: parent, placement: placement, excluding: id)
        let stamp = clock.next()
        try apply([op(.task, id.rawValue, "parent", Value(parent?.rawValue), stamp), op(.task, id.rawValue, "rank", .text(rank), stamp)])
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

    public func task(_ id: TaskID) throws(StoreError) -> Task? {
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
    public func children(of parent: TaskID?, includeTrashed: Bool = false) throws(StoreError) -> [Task] {
        try loadTasks(where: "tt.parent IS ? AND (? OR tt.trashed = 0)", [Value(parent?.rawValue), Value(includeTrashed)], orderBy: "t.rank, t.id")
    }

    /// Every task that is not deleted, oldest first. The CLI resolves id prefixes over this list.
    public func allTasks(includeTrashed: Bool = false) throws(StoreError) -> [Task] {
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
    func siblingRank(table: String, parent: EntityID?, placement: Placement, excluding: EntityID?) throws(StoreError) -> String {
        let siblings = try orderedSiblings(table: table, parent: parent, excluding: excluding)
        switch placement {
        case .end: return Rank.between(siblings.last?.1, nil)
        case .start: return Rank.between(nil, siblings.first?.1)
        case .after(let anchor):
            guard let index = siblings.firstIndex(where: { $0.0 == anchor.rawValue }) else { throw .notFound(anchor) }
            let upper = index + 1 < siblings.count ? siblings[index + 1].1 : nil
            return Rank.between(siblings[index].1, upper)
        }
    }

    /// The siblings a read would show under `parent`, in the order it would show them, which is the list a
    /// placement has to rank among. Tasks take their effective parent from `task_tree`; `tags` and `views`
    /// have no derived table of their own, so the same rule is applied here instead of trusting the column —
    /// a tag whose stored parent was deleted, or made circular by a merge, is at the root of every read, and
    /// a placement that ranked it against the raw column would rank among a list nobody sees.
    private func orderedSiblings(table: String, parent: EntityID?, excluding: EntityID?) throws(StoreError) -> [(id: String, rank: String)] {
        if table == "tasks" {
            return try sql { () throws(SQLiteError) in
                try db.rows(
                    "SELECT t.id, t.rank FROM tasks t JOIN task_tree tt ON tt.id = t.id WHERE tt.parent IS ? AND t.id != ? ORDER BY t.rank, t.id",
                    [Value(parent?.rawValue), .text(excluding?.rawValue ?? "")]
                ).map { ($0[0].string ?? "", $0[1].string ?? Rank.initial) }
            }
        }
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT id, parent, rank, deleted FROM \(table)") }
        let parents = TreeRules.effectiveParents(rows.map { TreeRules.Node(id: $0[0].string ?? "", parent: $0[1].string, deleted: $0[3].bool) })
        return rows.compactMap { row -> (id: String, rank: String)? in
            let id = row[0].string ?? ""
            guard !row[3].bool, id != excluding?.rawValue, (parents[id] ?? nil) == parent?.rawValue else { return nil }
            return (id, row[2].string ?? Rank.initial)
        }.sorted { ($0.rank, $0.id) < ($1.rank, $1.id) }
    }

    /// Whether `id` sits under `ancestor` in the effective tree. The walk is SQLite's and not the stack's, and
    /// `UNION` bounds it even if `task_tree` ever held a cycle, which `TreeRules` promises it does not.
    private func isUnder(_ id: TaskID, ancestor: TaskID) throws(StoreError) -> Bool {
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

    /// The last change for each field, in the order the fields first appear. What it is for is written where
    /// the write methods use it.
    static func lastPerField<Change>(_ changes: [Change], by field: (Change) -> String) -> [Change] {
        var latest: [String: Change] = [:]
        var order: [String] = []
        for change in changes where latest.updateValue(change, forKey: field(change)) == nil { order.append(field(change)) }
        return order.compactMap { latest[$0] }
    }

    /// Loads tasks with their tags. `clause` may use the aliases `t` (tasks) and `tt` (task_tree); `join` is
    /// appended after the tree join, which is where Tasks 8 to 10 hang a filter, a manual list or an FTS
    /// table off the same loader.
    func loadTasks(where clause: String, _ params: [Value], orderBy: String, join: String = "", limit: Int? = nil) throws(StoreError) -> [Task] {
        let limitClause = limit.map { " LIMIT \($0)" } ?? ""
        var tasks = try sql { () throws(SQLiteError) in
            try db.rows("SELECT \(Store.taskColumns) FROM tasks t JOIN task_tree tt ON tt.id = t.id \(join) WHERE t.deleted = 0 AND (\(clause)) ORDER BY \(orderBy)\(limitClause)", params).map(Store.task(from:))
        }
        try attachTags(&tasks)
        return tasks
    }

    static func task(from row: [Value]) -> Task {
        Task(
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
            tags: [],
            trashed: row[7].bool,
            createdAt: row[8].int64 ?? 0,
            updatedAt: row[9].int64 ?? 0,
            completedAt: row[10].int64
        )
    }

    /// One query for the tags of a whole page of tasks instead of one per task, chunked because SQLite has a
    /// limit on how many parameters a statement takes. A tag that has been deleted is left out here rather
    /// than in every caller: the pair row stays for sync, and nothing shows it again.
    private func attachTags(_ tasks: inout [Task]) throws(StoreError) {
        guard !tasks.isEmpty else { return }
        var index: [TaskID: Int] = [:]
        for (i, task) in tasks.enumerated() { index[task.id] = i }
        let ids = Array(index.keys)
        for chunk in stride(from: 0, to: ids.count, by: 500).map({ Array(ids[$0..<min($0 + 500, ids.count)]) }) {
            let placeholders = Array(repeating: "?", count: chunk.count).joined(separator: ", ")
            let rows = try sql { () throws(SQLiteError) in
                try db.rows("SELECT x.task_id, x.tag_id FROM task_tags x JOIN tags g ON g.id = x.tag_id AND g.deleted = 0 WHERE x.present = 1 AND x.task_id IN (\(placeholders))", chunk.map { .text($0.rawValue) })
            }
            for row in rows {
                if let i = index[TaskID(row[0].string ?? "")] { tasks[i].tags.insert(TagID(row[1].string ?? "")) }
            }
        }
    }
}
