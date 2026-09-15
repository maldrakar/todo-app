// Sources/TodoCore/Storage/Store+Tree.swift
import SQLiteKit

extension Store {
    /// Recomputes `task_tree` for every non-deleted task, inside a transaction opened by the caller. The table
    /// is what every read joins for the shape of the tree and for trash, so that no query has to resolve a
    /// merge's leftovers itself: `parent` here is the effective one from `TreeRules`, and `trashed` is true
    /// when the task or any of its effective ancestors is in the trash.
    ///
    /// `trashed` is also the normalized form of the flag. A peer may write any integer into `tasks.trashed`,
    /// and the column takes it; the derived row holds 0 or 1, so a filter compiled against `task_tree` can
    /// compare it to 1 and mean it (Task 8).
    ///
    /// Cost is linear in the number of tasks, in four passes: read them, resolve the links, inherit the trash,
    /// write the rows. It is still a whole-table rebuild, which is why `apply` runs it only when `parent`,
    /// `trashed` or `deleted` changed, or when an operation brought a task into being.
    func rebuildTreeRows() throws(SQLiteError) {
        var nodes: [TreeRules.Node] = []
        var ownTrashed: [String: Bool] = [:]
        for row in try db.rows("SELECT id, parent, trashed, deleted FROM tasks") {
            let id = row[0].string ?? ""
            nodes.append(TreeRules.Node(id: id, parent: row[1].string, deleted: row[3].bool))
            ownTrashed[id] = row[2].bool
        }
        let parents = TreeRules.effectiveParents(nodes)
        let inherited = Store.inheritedTrash(parents, ownTrashed)

        try db.run("DELETE FROM task_tree")
        let insert = try db.prepare("INSERT INTO task_tree (id, parent, trashed) VALUES (?, ?, ?)")
        // In key order, so the rows append to the primary key's B-tree instead of splitting pages in the
        // middle of it, and so that the same state lays the table out the same way twice.
        for id in parents.keys.sorted() {
            try insert.bind([.text(id), Value(parents[id] ?? nil), Value(inherited[id] ?? false)])
            _ = try insert.step()
        }
    }

    /// Trash for every node of the forest `TreeRules` returned: its own, or any effective ancestor's. Each
    /// chain is walked upwards once, as far as the first node whose answer is already known, and then filled
    /// in downwards, so the whole pass is linear and holds no recursion — a chain thousands of links long
    /// arrives from sync as easily as a shallow one, and a stack is not what should decide whether it reads.
    ///
    /// `parents` has to be a forest, which is exactly what `effectiveParents` promises. `onChain` is what a
    /// caller who breaks that promise meets instead of an endless walk: the answer it then returns for the
    /// nodes of the cycle is arbitrary, but it returns, and the device stays usable.
    private static func inheritedTrash(_ parents: [String: String?], _ own: [String: Bool]) -> [String: Bool] {
        var inherited: [String: Bool] = [:]
        var chain: [String] = []
        var onChain: Set<String> = []
        for id in parents.keys where inherited[id] == nil {
            chain.removeAll(keepingCapacity: true)
            onChain.removeAll(keepingCapacity: true)
            var cursor: String? = id
            while let current = cursor, inherited[current] == nil, onChain.insert(current).inserted {
                chain.append(current)
                cursor = parents[current] ?? nil
            }
            var trashed = cursor.map { inherited[$0] ?? false } ?? false
            for node in chain.reversed() {
                trashed = trashed || (own[node] ?? false)
                inherited[node] = trashed
            }
        }
        return inherited
    }
}
