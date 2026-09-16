// Sources/TodoCore/Storage/Store+Tags.swift
import SQLiteKit

extension Store {
    @discardableResult
    public func createTag(title: String, parent: TagID? = nil, at placement: Placement = .end) throws(StoreError) -> TagID {
        if let parent { try requireTag(parent) }
        let id = TagID()
        let rank = try siblingRank(in: .tag, parent: parent, placement: placement, excluding: nil)
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

    /// Sets the given fields. A field named twice keeps the last change for it, for the reason written on
    /// `update(task:_:)`.
    public func update(tag id: TagID, _ changes: [TagChange]) throws(StoreError) {
        guard !changes.isEmpty else { return }
        try requireTag(id)
        let stamp = clock.next()
        let ops = Store.lastPerField(changes, by: { $0.field }).map { change in
            switch change {
            case .title(let title): op(.tag, id.rawValue, "title", .text(title), stamp)
            }
        }
        try apply(ops)
    }

    /// Re-parents the tag and ranks it among its new siblings, the way `move(task:to:at:)` does for a task:
    /// two operations under one stamp, and a move into the tag's own subtree refused here rather than left to
    /// the reading rule, which would answer the cycle by putting every tag on it at the root.
    public func move(tag id: TagID, to parent: TagID?, at placement: Placement) throws(StoreError) {
        try requireTag(id)
        if let parent {
            guard parent != id else { throw .invalid("a tag cannot be its own parent") }
            try requireTag(parent)
            if try isUnder(parent, ancestor: id, in: .tag) { throw .invalid("a tag cannot be moved under its own descendant") }
        }
        let rank = try siblingRank(in: .tag, parent: parent, placement: placement, excluding: id)
        let stamp = clock.next()
        try apply([op(.tag, id.rawValue, "parent", Value(parent?.rawValue), stamp), op(.tag, id.rawValue, "rank", .text(rank), stamp)])
    }

    /// Ranks the tag among the siblings it already has, without saying anything about its parent.
    public func move(tag id: TagID, at placement: Placement) throws(StoreError) {
        try requireTag(id)
        let rank = try siblingRank(in: .tag, parent: try effectiveParent(of: id, in: .tag), placement: placement, excluding: id)
        try apply([op(.tag, id.rawValue, "rank", .text(rank), clock.next())])
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
