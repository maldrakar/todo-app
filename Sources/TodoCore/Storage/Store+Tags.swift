// Sources/TodoCore/Storage/Store+Tags.swift
import SQLiteKit

extension Store {
    @discardableResult
    public func createTag(title: String, parent: TagID? = nil, at placement: Placement = .end) throws(StoreError) -> TagID {
        if let parent { try requireTag(parent) }
        let id = TagID()
        let rank = try siblingRank(table: "tags", parent: parent, placement: placement, excluding: nil)
        let stamp = clock.next()
        try apply([
            op(.tag, id.rawValue, "title", .text(title), stamp),
            op(.tag, id.rawValue, "parent", Value(parent?.rawValue), stamp),
            op(.tag, id.rawValue, "rank", .text(rank), stamp),
            op(.tag, id.rawValue, "deleted", Value(false), stamp),
            op(.tag, id.rawValue, "created_at", .integer(stamp.millis), stamp),
        ])
        return id
    }

    /// Re-parenting is part of an edit here and not a `move` of its own: a tag tree is a handful of names in a
    /// sidebar, and the one placement it needs is the end of its new parent's list.
    public func update(tag id: TagID, _ changes: [TagChange]) throws(StoreError) {
        try requireTag(id)
        guard !changes.isEmpty else { return }
        let stamp = clock.next()
        var ops: [Operation] = []
        for change in Store.lastPerField(changes, by: { $0.field }) {
            switch change {
            case .title(let title): ops.append(op(.tag, id.rawValue, "title", .text(title), stamp))
            case .parent(let parent):
                if let parent {
                    guard parent != id else { throw .invalid("a tag cannot be its own parent") }
                    try requireTag(parent)
                }
                let rank = try siblingRank(table: "tags", parent: parent, placement: .end, excluding: id)
                ops.append(op(.tag, id.rawValue, "parent", Value(parent?.rawValue), stamp))
                ops.append(op(.tag, id.rawValue, "rank", .text(rank), stamp))
            }
        }
        try apply(ops)
    }

    /// Tombstones the tag. Its children move to the root and the tasks that carry it stop showing it, both by
    /// the reading rule and not by a write that touches every one of them.
    public func delete(tag id: TagID) throws(StoreError) {
        try requireTag(id)
        try setFlag(.tag, id, "deleted", true)
    }

    /// Every tag, parents before children, siblings by rank. `parent` is effective: a link to a missing,
    /// deleted or circular parent reads as root, exactly as `task_tree` resolves the same hazard for tasks.
    ///
    /// This loads the whole table. Tags number in the tens, and the tree order needs every row anyway, so the
    /// query that would ask for one branch would still have to read the rest to know where the branch hangs.
    public func tags() throws(StoreError) -> [Tag] {
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT id, title, parent, rank, created_at, updated_at, deleted FROM tags") }
        let nodes = rows.map { TreeRules.Node(id: $0[0].string ?? "", parent: $0[2].string, deleted: $0[6].bool) }
        let parents = TreeRules.effectiveParents(nodes)
        var byParent: [String?: [Tag]] = [:]
        for row in rows where !row[6].bool {
            let id = row[0].string ?? ""
            let tag = Tag(id: TagID(id), title: row[1].string ?? "", parent: (parents[id] ?? nil).map(TagID.init), rank: row[3].string ?? Rank.initial, createdAt: row[4].int64 ?? 0, updatedAt: row[5].int64 ?? 0)
            byParent[parents[id] ?? nil, default: []].append(tag)
        }
        // Parents before children without recursion: a chain thousands of links deep arrives from sync as
        // easily as a shallow one, and a stack — 64 KiB of it on wasm32 — is not what should decide whether
        // the tag tree reads. It is the rule `TreeRules` and `Store.inheritedTrash` already follow. Children
        // go onto the stack in reverse, so they come off it in rank order.
        func children(of parent: String?) -> [Tag] {
            (byParent[parent] ?? []).sorted { ($0.rank, $0.id.rawValue) < ($1.rank, $1.id.rawValue) }
        }
        var ordered: [Tag] = []
        var stack = Array(children(of: nil).reversed())
        while let tag = stack.popLast() {
            ordered.append(tag)
            stack.append(contentsOf: children(of: tag.id.rawValue).reversed())
        }
        return ordered
    }

    public func tag(_ id: TagID) throws(StoreError) -> Tag? {
        try tags().first { $0.id == id }
    }

    func requireTag(_ id: TagID) throws(StoreError) {
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT 1 FROM tags WHERE id = ? AND deleted = 0", [.text(id.rawValue)]) }
        if rows.isEmpty { throw .notFound(id) }
    }
}
