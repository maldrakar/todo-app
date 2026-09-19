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
        try applyBatch(ops).changes
    }

    /// Everything `apply` does, and the number it drops: the operations the state could not take. `receive`
    /// is the caller with somewhere to put that number, and it hands over a peer's operations alone, so a
    /// count that reaches a consumer is a peer's doing. `apply` drops it, because a refusal of our own is a
    /// bug in the write API rather than something to survive — for the null over a NOT NULL column, which is
    /// the one our own typed values could produce, the assertion below is where that bug stops being silent.
    func applyBatch(_ ops: [Operation]) throws(StoreError) -> SyncReport {
        guard !ops.isEmpty else { return SyncReport() }
        let report = try sql { () throws(SQLiteError) in
            try db.transaction { () throws(SQLiteError) in try applyRows(ops) }
        }
        if !report.changes.isEmpty { onChange?(report.changes) }
        return report
    }

    /// Everything `apply` does to the database, inside a transaction the caller has already opened. The replay
    /// of the journal builds its operations out of rows and comes through here, so there is one loop and not
    /// two: journaling an operation that is already in the journal is the `INSERT OR IGNORE` doing nothing.
    @discardableResult
    func applyRows(_ ops: [Operation]) throws(SQLiteError) -> SyncReport {
        var report = SyncReport()
        var treeDirty = false
        for op in ops {
            let known = FieldMap.isKnown(op.entity, op.field)
            try journal(op, applied: known)
            guard known else { continue }
            try applyToState(op, into: &report, treeDirty: &treeDirty)
        }
        if treeDirty { try rebuildTreeRows() }
        return report
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
    func applyToState(_ op: Operation, into report: inout SyncReport, treeDirty: inout Bool) throws(SQLiteError) {
        guard FieldMap.isKnown(op.entity, op.field) else { return }
        // An operation names the entity it edits, and an empty id names none. Nothing this device writes can
        // produce one — every id comes from `EntityID()` or from a row that already exists — but a peer's can,
        // and it would insert a row that reads as a task in the Inbox which nobody created and no read can
        // address. A pair id that does not split, below, is the same fault one level down, and the two are
        // refused and counted the same way.
        guard !op.entityID.isEmpty else {
            report.refused += 1
            return
        }
        // A NOT NULL column refuses a null instead of falling back to its default, and that failure would roll
        // back the whole transaction — every operation delivered alongside this one would lose its journal row
        // too, on this delivery and on every retry. So the operation is journaled and skipped instead, and the
        // field stays open for the next well-formed one, which is what an operation from another device has
        // earned. From our own code the same value is a bug rather than something to survive: the write API
        // builds operations out of typed values, and it takes a `Value(someOptional)` over a NOT NULL column to
        // produce this. The assertion is where that bug stops being silent, in every test run and every debug
        // build. It does not reach the built-in view seed of Task 9, whose operations carry a device id of
        // their own; what covers those is the test that holds `FieldMap` and the schema together.
        if op.value.isNull, !FieldMap.acceptsNull(op.entity, op.field) {
            assert(op.device != deviceID, "a null for \(op.entity.rawValue).\(op.field), which the schema keeps NOT NULL")
            report.refused += 1
            return
        }
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
            report.changes.tasks.insert(TaskID(op.entityID))
            // A task this operation brought into being has to reach task_tree even when the field that created
            // it says nothing about the tree: every read joins the tree from Task 6 on, and a task missing from
            // it is invisible until the next open rebuilds it.
            if created || Store.treeFields.contains(op.field) { treeDirty = true }
        case .tag:
            try writeEntityRow(table, op)
            report.changes.tags.insert(TagID(op.entityID))
        case .view:
            try writeEntityRow(table, op)
            report.changes.views.insert(ViewID(op.entityID))
        case .taskTag:
            guard let (taskID, tagID) = Operation.splitPair(op.entityID) else {
                report.refused += 1
                return
            }
            try writePairRow(table, ("task_id", "tag_id"), (taskID, tagID), op)
            report.changes.tasks.insert(TaskID(taskID))
        case .viewItem:
            guard let (viewID, taskID) = Operation.splitPair(op.entityID) else {
                report.refused += 1
                return
            }
            try writePairRow(table, ("view_id", "task_id"), (viewID, taskID), op)
            report.changes.views.insert(ViewID(viewID))
            report.changes.tasks.insert(TaskID(taskID))
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

    /// The same shape for a pair row, which is addressed by two ids instead of one. The insert seeds `present`
    /// explicitly because the schema defaults it to 1, and the row that a `rank` operation creates must not
    /// read as a membership — ranking a task inside a manual list is not what puts it in the list, and
    /// out-of-order delivery is exactly when the two operations arrive apart.
    private func writePairRow(_ table: String, _ keys: (String, String), _ ids: (String, String), _ op: Operation) throws(SQLiteError) {
        let update = "UPDATE \(table) SET \(op.field) = ? WHERE \(keys.0) = ? AND \(keys.1) = ?"
        let parameters: [Value] = [op.value, .text(ids.0), .text(ids.1)]
        try db.run(update, parameters)
        guard db.changes == 0 else { return }
        try db.run("INSERT INTO \(table) (\(keys.0), \(keys.1), present) VALUES (?, ?, 0)", [.text(ids.0), .text(ids.1)])
        try db.run(update, parameters)
    }
}
