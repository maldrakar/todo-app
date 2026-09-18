// Sources/TodoCore/Model/TreeRules.swift

/// The one rule for parent links after a merge (spec, "Parent links"): a link to a missing or deleted parent,
/// or a link that closes a cycle, is ignored when reading, and the item shows at the root.
///
/// It is a rule and not a repair. Two devices can each move one of two items under the other without either
/// ever seeing an invalid state, and the merge that puts the two operations together has no reason to prefer
/// one link over the other. So the links stay in the state exactly as they were written, and every read
/// resolves them through here: whichever device later moves one of the two out of the cycle publishes an
/// ordinary edit, and the other link becomes valid again on its own. Tags (Task 7) and views (Task 9) have the
/// same column shape and the same hazard, and read the same way.
enum TreeRules {
    struct Node {
        let id: String
        let parent: String?
        let deleted: Bool
    }

    /// Effective parent for every non-deleted node. The result holds only non-deleted ids, a value of
    /// `.some(nil)` means "at the root", and an id that is absent has no place in the tree at all. Every value
    /// is also a key, and the links form a forest, so a walk up from any node reaches a root in a finite
    /// number of steps — `Store.inheritedTrash` is built on that promise. Ids are expected to be unique, as
    /// they are in every table this reads from, where the column is declared UNIQUE.
    ///
    /// Linear in the number of nodes, which is not the obvious reading of the rule: asking each node in turn
    /// whether the chain above it comes back costs a walk per node, and a chain 60,000 deep — which sync can
    /// deliver, and which nothing in the write path bounds — would turn every edit and every open into minutes
    /// of work. Each node has at most one parent, so the links form a functional graph whose cycles are
    /// disjoint, and one marked walk per unvisited node finds every node that lies on one. Each node is
    /// touched by exactly one walk, which is also where its answer is written.
    static func effectiveParents(_ nodes: [Node]) -> [String: String?] {
        var byID: [String: Node] = [:]
        for node in nodes { byID[node.id] = node }

        /// The link a node would keep if nothing were circular: none, once the parent is missing or deleted.
        func link(_ node: Node) -> String? {
            guard let parent = node.parent, let parentNode = byID[parent], !parentNode.deleted else { return nil }
            return parent
        }

        // A node lies on a cycle when the walk from it arrives back inside the walk itself. An id left behind
        // by an earlier walk ends this one instead: everything above it has been settled already, and a cycle
        // up there belongs to its own members and not to the chain hanging off it, which keeps its shape.
        enum Mark { case walking, settled }
        var marks: [String: Mark] = [:]
        var result: [String: String?] = [:]
        var onCycle: Set<String> = []
        var path: [String] = []
        for node in nodes where !node.deleted && marks[node.id] == nil {
            path.removeAll(keepingCapacity: true)
            var cursor: String? = node.id
            while let current = cursor, let currentNode = byID[current], !currentNode.deleted, marks[current] == nil {
                marks[current] = .walking
                path.append(current)
                let parent = link(currentNode)
                result[current] = parent
                cursor = parent
            }
            if let closed = cursor, marks[closed] == .walking, let start = path.firstIndex(of: closed) {
                onCycle.formUnion(path[start...])
            }
            for id in path { marks[id] = .settled }
        }
        // Only the members of a cycle have to give their link back, and usually there are none. Everyone else
        // was answered by the walk that visited them, so nothing here passes over all the nodes again.
        // `updateValue` and not `result[id] = nil`, which on a dictionary of optionals removes the key and
        // would take the node out of the tree altogether instead of moving it to the root.
        for id in onCycle { result.updateValue(nil, forKey: id) }
        return result
    }
}

/// What the sidebar order needs of an item: where it sits and how it sorts among its siblings. Tags and views
/// are two tables with one shape, and `inTreeOrder` is the one reading of it.
protocol TreeOrdered {
    var id: EntityID { get }
    var parent: EntityID? { get }
    var rank: String { get }
}

extension TreeRules {
    /// Parents before children, siblings by rank and then by id, out of items whose `parent` is already the
    /// effective one from `effectiveParents`.
    ///
    /// Without recursion: a chain thousands of links deep arrives from sync as easily as a shallow one, and a
    /// stack — 64 KiB of it on wasm32 — is not what should decide whether a tree reads. Children go onto the
    /// stack in reverse, so they come off it in rank order.
    ///
    /// Every item comes out, exactly once, whatever the links say. `effectiveParents` promises a forest, so
    /// the two callers never exercise the rest; the promise is theirs to keep and losing a row from a sidebar
    /// is not a way to find out that one of them stopped. A parent that is not in the list reads as no
    /// parent, the way a link to a missing one does everywhere else here, and anything still unreached — the
    /// members of a cycle — follows the tree rather than vanishing under it.
    static func inTreeOrder<Item: TreeOrdered>(_ items: [Item]) -> [Item] {
        let present = Set(items.map(\.id))
        var byParent: [EntityID?: [Item]] = [:]
        for item in items {
            byParent[item.parent.flatMap { present.contains($0) ? $0 : nil }, default: []].append(item)
        }
        func children(of parent: EntityID?) -> [Item] {
            (byParent[parent] ?? []).sorted { ($0.rank, $0.id.rawValue) < ($1.rank, $1.id.rawValue) }
        }
        var ordered: [Item] = []
        var emitted: Set<EntityID> = []
        var stack = Array(children(of: nil).reversed())
        while let item = stack.popLast() {
            guard emitted.insert(item.id).inserted else { continue }
            ordered.append(item)
            stack.append(contentsOf: children(of: item.id).reversed())
        }
        return ordered + items.filter { !emitted.contains($0.id) }.sorted { ($0.rank, $0.id.rawValue) < ($1.rank, $1.id.rawValue) }
    }
}
