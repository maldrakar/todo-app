// Sources/TodoCore/Storage/Store+Apply.swift
import SQLiteKit

extension Store {
    /// The one write path: journals every operation, applies those that win their field clock,
    /// rebuilds the task tree when a structural field changed, and notifies the observer after commit.
    ///
    /// It never touches this device's clock. An operation from another device carries a stamp this device has
    /// to stay ahead of, so it arrives through `receive`, which observes the stamp before handing it here.
    @discardableResult
    public func apply(_ ops: [Operation]) throws(StoreError) -> ChangeSet {
        guard !ops.isEmpty else { return ChangeSet() }
        let changes = try sql { () throws(SQLiteError) in
            try db.transaction { () throws(SQLiteError) in
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
        }
        if !changes.isEmpty { onChange?(changes) }
        return changes
    }

    /// The fields of a task that the shape of the tree is derived from.
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

    /// Last write wins per field: the operation that loses its field clock, and the one the state cannot hold,
    /// leave both the row and the clock as they were. The field name is interpolated into the SQL below, so the
    /// `FieldMap` whitelist is what keeps that safe; it is checked here rather than trusted from the callers.
    func applyToState(_ op: Operation, changes: inout ChangeSet, treeDirty: inout Bool) throws(SQLiteError) {
        guard FieldMap.isKnown(op.entity, op.field) else { return }
        // A NOT NULL column refuses a null instead of falling back to its default, and that failure would roll
        // back the whole transaction — every operation delivered alongside this one would lose its journal row
        // too, on this delivery and on every retry. One malformed operation from a peer is journaled and
        // skipped instead, and the field stays open for the next well-formed one.
        guard !op.value.isNull || FieldMap.acceptsNull(op.entity, op.field) else { return }
        let key: [Value] = [.text(op.entity.rawValue), .text(op.entityID), .text(op.field)]
        if let existing = try db.rows("SELECT clock, device FROM field_clocks WHERE entity = ? AND entity_id = ? AND field = ?", key).first {
            let current = (existing[0].int64 ?? 0, existing[1].string ?? "")
            if current >= (op.clock.raw, op.device) { return }
        }
        // The state write and the change it reports share one branch, and a pair entity splits its id once.
        // The field clock at the end of the function is reached only by an operation the state took, so an id
        // that does not split leaves nothing behind for a well-formed one to lose to.
        let millis = Value(op.clock.millis)
        switch op.entity {
        case .task, .tag, .view:
            let table = FieldMap.table(op.entity)
            try db.run("INSERT OR IGNORE INTO \(table) (id, created_at, updated_at) VALUES (?, ?, ?)", [.text(op.entityID), millis, millis])
            let created = db.changes > 0
            try db.run("UPDATE \(table) SET \(op.field) = ?, updated_at = max(updated_at, ?) WHERE id = ?", [op.value, millis, .text(op.entityID)])
            switch op.entity {
            case .task:
                changes.tasks.insert(TaskID(op.entityID))
                // A task this operation brought into being has to reach `task_tree` even when the field that
                // created it says nothing about the tree: every read joins the tree, and a task missing from it
                // is invisible until the next open rebuilds it.
                if created || Store.treeFields.contains(op.field) { treeDirty = true }
            case .tag: changes.tags.insert(TagID(op.entityID))
            case .view: changes.views.insert(ViewID(op.entityID))
            case .taskTag, .viewItem: break  // the pair kinds are the arms below, not this one
            }
        case .taskTag:
            guard let (taskID, tagID) = Operation.splitPair(op.entityID) else { return }
            try db.run("INSERT OR IGNORE INTO task_tags (task_id, tag_id, present) VALUES (?, ?, 0)", [.text(taskID), .text(tagID)])
            try db.run("UPDATE task_tags SET \(op.field) = ? WHERE task_id = ? AND tag_id = ?", [op.value, .text(taskID), .text(tagID)])
            changes.tasks.insert(TaskID(taskID))
        case .viewItem:
            guard let (viewID, taskID) = Operation.splitPair(op.entityID) else { return }
            try db.run("INSERT OR IGNORE INTO view_items (view_id, task_id, present) VALUES (?, ?, 0)", [.text(viewID), .text(taskID)])
            try db.run("UPDATE view_items SET \(op.field) = ? WHERE view_id = ? AND task_id = ?", [op.value, .text(viewID), .text(taskID)])
            changes.views.insert(ViewID(viewID))
            changes.tasks.insert(TaskID(taskID))
        }
        try db.run(
            "INSERT INTO field_clocks (entity, entity_id, field, clock, device) VALUES (?, ?, ?, ?, ?) ON CONFLICT(entity, entity_id, field) DO UPDATE SET clock = excluded.clock, device = excluded.device",
            key + [.integer(op.clock.raw), .text(op.device)]
        )
    }
}
