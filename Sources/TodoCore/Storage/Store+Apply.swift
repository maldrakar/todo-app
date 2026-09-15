// Sources/TodoCore/Storage/Store+Apply.swift
import SQLiteKit

extension Store {
    /// The one write path: journals every operation, applies those that win their field clock, rebuilds the
    /// task tree when the shape of it moved, and notifies the observer once the transaction has committed.
    ///
    /// It never touches this device's clock. An operation from another device carries a stamp this device has
    /// to stay ahead of, so it arrives through `receive`, which observes the stamp before handing it here.
    @discardableResult
    public func apply(_ ops: [Operation]) throws(StoreError) -> ChangeSet {
        guard !ops.isEmpty else { return ChangeSet() }
        let changes = try sql { () throws(SQLiteError) in
            try db.transaction { () throws(SQLiteError) in try applyRows(ops) }
        }
        if !changes.isEmpty { onChange?(changes) }
        return changes
    }

    /// Everything `apply` does to the database, inside a transaction the caller has already opened. The replay
    /// of the journal builds its operations out of rows and comes through here, so there is one loop and not
    /// two: journaling an operation that is already in the journal is the `INSERT OR IGNORE` doing nothing.
    func applyRows(_ ops: [Operation]) throws(SQLiteError) -> ChangeSet {
        var changes = ChangeSet()
        var treeDirty = false
        for op in ops {
            let known = FieldMap.isKnown(op.entity, op.field)
            try journal(op, applied: known)
            guard known else { continue }
            try applyToState(op, changes: &changes, treeDirty: &treeDirty)
        }
        if treeDirty { try rebuildTreeRows() }
        return changes
    }

    /// The three task fields `task_tree` is derived from, and the reason a change to one of them costs a
    /// rebuild: `parent` is the link the tree is built out of, `deleted` takes a task out of the tree and moves
    /// its children to the root, and `trashed` is inherited down it (Task 6). Each of the three can move rows
    /// the operation never named, and no other field can move any.
    static let treeFields: Set<String> = ["parent", "trashed", "deleted"]

    /// Builds an operation stamped by this device.
    func op(_ kind: EntityKind, _ id: String, _ field: String, _ value: Value, _ stamp: HLC) -> Operation {
        Operation(entity: kind, entityID: id, field: field, value: value, clock: stamp, device: deviceID)
    }

    /// Appends to the journal. The unique index on (device, clock, entity, entity_id, field) drops duplicates.
    /// `applied` says that this version of the app knew the field, not that the operation reached the state: an
    /// operation that lost its field clock was considered and is never replayed.
    func journal(_ op: Operation, applied: Bool) throws(SQLiteError) {
        try db.run(
            "INSERT OR IGNORE INTO ops (entity, entity_id, field, value, clock, device, applied) VALUES (?, ?, ?, ?, ?, ?, ?)",
            [.text(op.entity.rawValue), .text(op.entityID), .text(op.field), op.value, .integer(op.clock.raw), .text(op.device), Value(applied)]
        )
    }

    /// Writes one field of one entity into the state, inside the transaction its caller opened. The field name
    /// is interpolated into the SQL, so the `FieldMap` whitelist is what keeps that safe, and it is checked
    /// here rather than trusted from the two callers.
    func applyToState(_ op: Operation, changes: inout ChangeSet, treeDirty: inout Bool) throws(SQLiteError) {
        guard FieldMap.isKnown(op.entity, op.field) else { return }
        // A NOT NULL column refuses a null instead of falling back to its default, and that failure would roll
        // back the whole transaction — every operation delivered alongside this one would lose its journal row
        // too, on this delivery and on every retry. One malformed operation from a peer is journaled and
        // skipped instead, and the field stays open for the next well-formed one.
        guard !op.value.isNull || FieldMap.acceptsNull(op.entity, op.field) else { return }
        // Last write wins, per field, with the device id breaking a tie: this comparison is that rule, and
        // everything below it runs only for an operation that is strictly newer than the field's current clock.
        let key: [Value] = [.text(op.entity.rawValue), .text(op.entityID), .text(op.field)]
        if let existing = try db.rows("SELECT clock, device FROM field_clocks WHERE entity = ? AND entity_id = ? AND field = ?", key).first {
            let current = (existing[0].int64 ?? 0, existing[1].string ?? "")
            if current >= (op.clock.raw, op.device) { return }
        }
        // The state write and the change it reports share one branch, and a pair entity splits its id once.
        // The field clock at the end of the function is reached only by an operation the state took, so an id
        // that does not split leaves nothing behind for a well-formed one to lose to.
        let table = FieldMap.table(op.entity)
        switch op.entity {
        case .task:
            let created = try writeEntityRow(table, op)
            changes.tasks.insert(TaskID(op.entityID))
            // A task this operation brought into being has to reach task_tree even when the field that created
            // it says nothing about the tree: every read joins the tree from Task 6 on, and a task missing from
            // it is invisible until the next open rebuilds it.
            if created || Store.treeFields.contains(op.field) { treeDirty = true }
        case .tag:
            try writeEntityRow(table, op)
            changes.tags.insert(TagID(op.entityID))
        case .view:
            try writeEntityRow(table, op)
            changes.views.insert(ViewID(op.entityID))
        case .taskTag:
            guard let (taskID, tagID) = Operation.splitPair(op.entityID) else { return }
            try db.run("INSERT OR IGNORE INTO \(table) (task_id, tag_id, present) VALUES (?, ?, 0)", [.text(taskID), .text(tagID)])
            try db.run("UPDATE \(table) SET \(op.field) = ? WHERE task_id = ? AND tag_id = ?", [op.value, .text(taskID), .text(tagID)])
            changes.tasks.insert(TaskID(taskID))
        case .viewItem:
            guard let (viewID, taskID) = Operation.splitPair(op.entityID) else { return }
            try db.run("INSERT OR IGNORE INTO \(table) (view_id, task_id, present) VALUES (?, ?, 0)", [.text(viewID), .text(taskID)])
            try db.run("UPDATE \(table) SET \(op.field) = ? WHERE view_id = ? AND task_id = ?", [op.value, .text(viewID), .text(taskID)])
            changes.views.insert(ViewID(viewID))
            changes.tasks.insert(TaskID(taskID))
        }
        try db.run(
            "INSERT INTO field_clocks (entity, entity_id, field, clock, device) VALUES (?, ?, ?, ?, ?) ON CONFLICT(entity, entity_id, field) DO UPDATE SET clock = excluded.clock, device = excluded.device",
            key + [.integer(op.clock.raw), .text(op.device)]
        )
    }

    /// One field of a task, tag or view, and whether the row had to be created for it. The update goes first
    /// because a field of a row that already exists is the common case, and then it is the only statement;
    /// `changes` counts the rows a statement matched, so zero of them means there is no such row yet and the
    /// insert that follows gives the update something to land on.
    ///
    /// A pair row keeps its two statements instead. The schema defaults `present` to 1, and the row a `rank`
    /// operation creates has to say 0 for it — ranking a task inside a manual list is not what puts it in the
    /// list, and out-of-order delivery is exactly when the two arrive apart — so the seed is explicit, and
    /// folding it into one upsert costs more in built SQL than the statement it saves.
    @discardableResult
    private func writeEntityRow(_ table: String, _ op: Operation) throws(SQLiteError) -> Bool {
        let millis = Value(op.clock.millis)
        let update = "UPDATE \(table) SET \(op.field) = ?, updated_at = max(updated_at, ?) WHERE id = ?"
        let parameters: [Value] = [op.value, millis, .text(op.entityID)]
        try db.run(update, parameters)
        guard db.changes == 0 else { return false }
        try db.run("INSERT INTO \(table) (id, created_at, updated_at) VALUES (?, ?, ?)", [.text(op.entityID), millis, millis])
        try db.run(update, parameters)
        return true
    }
}
