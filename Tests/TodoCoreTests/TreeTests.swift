import Testing
@testable import TodoCore
@testable import SQLiteKit

private func tree(_ store: Store) throws(StoreError) -> [String: (parent: String?, trashed: Bool)] {
    try store.sql { () throws(SQLiteError) in
        var result: [String: (parent: String?, trashed: Bool)] = [:]
        for row in try store.db.rows("SELECT id, parent, trashed FROM task_tree") {
            result[row[0].string ?? ""] = (row[1].string, row[2].bool)
        }
        return result
    }
}

/// Builds each task out of the three fields the tree is derived from, the way a merge delivers them.
private func setup(_ store: Store, _ rows: [(id: String, parent: String?, trashed: Bool, deleted: Bool)]) throws(StoreError) {
    var ops: [JournalOperation] = []
    for (i, r) in rows.enumerated() {
        let stamp = HLC(millis: 1_000 + Int64(i), counter: 0)
        ops.append(store.op(.task, r.id, "parent", Value(r.parent), stamp))
        ops.append(store.op(.task, r.id, "trashed", Value(r.trashed), stamp))
        ops.append(store.op(.task, r.id, "deleted", Value(r.deleted), stamp))
    }
    try store.apply(ops)
}

/// A row no task owns. It survives everything except a rebuild, which is what makes a rebuild observable.
private func markTree(_ store: Store) throws(StoreError) {
    try store.sql { () throws(SQLiteError) in
        try store.db.run("INSERT INTO task_tree (id, parent, trashed) VALUES ('ghost', NULL, 0)")
    }
}

private func treeWasRebuilt(_ store: Store) throws(StoreError) -> Bool {
    try tree(store)["ghost"] == nil
}

@Test func effectiveParentsIgnoreMissingDeletedAndCircularLinks() {
    let nodes = [
        TreeRules.Node(id: "a", parent: nil, deleted: false),
        TreeRules.Node(id: "b", parent: "a", deleted: false),
        TreeRules.Node(id: "c", parent: "missing", deleted: false),
        TreeRules.Node(id: "d", parent: "gone", deleted: false),
        TreeRules.Node(id: "gone", parent: nil, deleted: true),
        TreeRules.Node(id: "x", parent: "y", deleted: false),
        TreeRules.Node(id: "y", parent: "x", deleted: false),
        TreeRules.Node(id: "z", parent: "x", deleted: false),
    ]
    let parents = TreeRules.effectiveParents(nodes)
    #expect(parents["a"] == .some(nil))
    #expect(parents["b"] == "a")
    #expect(parents["c"] == .some(nil), "a link to a parent no operation ever created reads as root")
    #expect(parents["d"] == .some(nil), "a link to a deleted parent reads as root")
    #expect(parents["gone"] == nil, "deleted nodes are absent")
    #expect(parents["x"] == .some(nil) && parents["y"] == .some(nil), "both members of a cycle show at the root")
    #expect(parents["z"] == "x", "a chain hanging off a cycle keeps its parent")
}

@Test func aSelfParentAndALongerCycleAlsoShowAtTheRoot() {
    let nodes = [
        TreeRules.Node(id: "self", parent: "self", deleted: false),
        TreeRules.Node(id: "p", parent: "q", deleted: false),
        TreeRules.Node(id: "q", parent: "r", deleted: false),
        TreeRules.Node(id: "r", parent: "p", deleted: false),
        TreeRules.Node(id: "hangs", parent: "q", deleted: false),
        TreeRules.Node(id: "deeper", parent: "hangs", deleted: false),
    ]
    let parents = TreeRules.effectiveParents(nodes)
    #expect(parents["self"] == .some(nil), "a task that is its own parent is at the root, not in a loop")
    #expect(parents["p"] == .some(nil) && parents["q"] == .some(nil) && parents["r"] == .some(nil))
    #expect(parents["hangs"] == "q" && parents["deeper"] == "hangs", "a chain of any depth off a cycle keeps its shape")
}

@Test func trashIsInheritedFromAncestors() throws {
    let store = try makeStore()
    try setup(store, [("p", nil, true, false), ("c", "p", false, false), ("g", "c", false, false), ("other", nil, false, false)])
    let t = try tree(store)
    #expect(t["p"]?.trashed == true)
    #expect(t["c"]?.trashed == true && t["c"]?.parent == "p")
    #expect(t["g"]?.trashed == true && t["g"]?.parent == "c", "trash reaches past the first generation")
    #expect(t["other"]?.trashed == false)
}

@Test func deletedTasksLeaveTheTreeAndTheirChildrenMoveToTheRoot() throws {
    let store = try makeStore()
    try setup(store, [("p", nil, false, true), ("c", "p", false, false)])
    let t = try tree(store)
    #expect(t["p"] == nil)
    #expect(t.keys.contains("c") && t["c"]?.parent == nil)
}

@Test func trashIsNotInheritedThroughADeletedAncestor() throws {
    let store = try makeStore()
    try setup(store, [("p", nil, true, false), ("mid", "p", false, true), ("c", "mid", false, false)])
    let t = try tree(store)
    #expect(t["c"]?.parent == nil && t["c"]?.trashed == false, "a deleted task carries neither its link nor its trash")
}

@Test func aCycleAfterAMergePutsItsMembersAtTheRoot() throws {
    let store = try makeStore()
    try setup(store, [("a", "b", false, false), ("b", "a", true, false), ("c", "a", false, false)])
    let t = try tree(store)
    #expect(t["a"]?.parent == nil && t["b"]?.parent == nil)
    #expect(t["c"]?.parent == "a")
    #expect(t["a"]?.trashed == false && t["b"]?.trashed == true && t["c"]?.trashed == false)
}

@Test func aFieldOutsideTheTreeDoesNotRebuildIt() throws {
    let store = try makeStore()
    try setup(store, [("a", nil, false, false)])
    try markTree(store)
    try store.apply([store.op(.task, "a", "title", .text("renamed"), HLC(millis: 9_000, counter: 0))])
    #expect(try treeWasRebuilt(store) == false)
}

/// Every test above builds its tasks and their structure in one batch, where the rebuild is owed to the task
/// being new. These three move a task that already has a row, which is what trashing, moving and emptying the
/// trash do in the product, and they are what holds `Store.treeFields` to its three fields.
@Test func movingATaskThatAlreadyExistsRebuildsTheTree() throws {
    let store = try makeStore()
    try setup(store, [("a", nil, false, false), ("b", nil, false, false)])
    try markTree(store)
    try store.apply([store.op(.task, "b", "parent", .text("a"), HLC(millis: 9_001, counter: 0))])
    #expect(try treeWasRebuilt(store))
    #expect(try tree(store)["b"]?.parent == "a")
}

@Test func trashingATaskThatAlreadyExistsFlipsItsDescendants() throws {
    let store = try makeStore()
    try setup(store, [("p", nil, false, false), ("c", "p", false, false), ("g", "c", false, false)])
    #expect(try tree(store)["g"]?.trashed == false)
    try store.apply([store.op(.task, "p", "trashed", Value(true), HLC(millis: 9_002, counter: 0))])
    let t = try tree(store)
    #expect(t["p"]?.trashed == true)
    #expect(t["c"]?.trashed == true && t["g"]?.trashed == true, "the trash reaches a subtree no operation named")
}

@Test func deletingATaskThatAlreadyExistsLiftsItsChildrenToTheRoot() throws {
    let store = try makeStore()
    try setup(store, [("p", nil, false, false), ("c", "p", false, false)])
    #expect(try tree(store)["c"]?.parent == "p")
    try store.apply([store.op(.task, "p", "deleted", Value(true), HLC(millis: 9_003, counter: 0))])
    let t = try tree(store)
    #expect(t["p"] == nil)
    #expect(t.keys.contains("c") && t["c"]?.parent == nil)
}

@Test func aTaskCreatedByAFieldOutsideTheTreeStillReachesIt() throws {
    let store = try makeStore()
    try store.apply([store.op(.task, "c", "title", .text("born from a title"), HLC(millis: 9_100, counter: 0))])
    let t = try tree(store)
    // `t["c"]?.parent == nil` would hold for a task that never reached the table at all, and a task missing
    // from the tree is invisible to every read that joins it. So presence is asserted on its own first.
    #expect(t.keys.contains("c"))
    #expect(t["c"]?.parent == nil)
}

@Test func openingAStoreRebuildsATreeThatIsNotThere() throws {
    let store = try makeStore()
    try setup(store, [("p", nil, true, false), ("c", "p", false, false)])
    try store.sql { () throws(SQLiteError) in try store.db.run("DELETE FROM task_tree") }
    let again = try Store.openInMemory(snapshot: try store.snapshot(), now: TestClock().now)
    let t = try tree(again)
    #expect(t["c"]?.parent == "p" && t["c"]?.trashed == true)
}

// MARK: - TreeRules.inTreeOrder

/// The shape the sidebar order needs of an item. `tags()` and `views()` pass `Tag` and `TaskView`; these
/// tests pass this, so what is under test is the rule and not the two tables that happen to use it.
private struct Node: TreeOrdered, Equatable {
    let id: EntityID
    let parent: EntityID?
    let rank: String

    init(_ id: String, parent: String? = nil, rank: String = "i") {
        self.id = EntityID(id)
        self.parent = parent.map(EntityID.init)
        self.rank = rank
    }
}

@Test func treeOrderPutsParentsBeforeChildrenAndSortsSiblingsByRankThenID() {
    let nodes = [
        Node("b", rank: "m"), Node("a", rank: "c"),
        Node("a2", parent: "a", rank: "t"), Node("a1", parent: "a", rank: "d"),
        Node("a1x", parent: "a1"),
        // Two siblings whose ranks two offline devices computed alike: the id settles them.
        Node("zz", parent: "b", rank: "i"), Node("yy", parent: "b", rank: "i"),
    ]
    #expect(TreeRules.inTreeOrder(nodes).map(\.id.rawValue) == ["a", "a1", "a1x", "a2", "b", "yy", "zz"])
}

@Test func treeOrderReadsALinkToAnItemThatIsNotThereAsNoLink() {
    // The deleted and the never-seen parent both arrive as an id the list does not hold; the child belongs
    // at the root, where it is visible, and not under a parent nothing will ever draw.
    let nodes = [Node("kid", parent: "gone", rank: "m"), Node("root", rank: "c")]
    #expect(TreeRules.inTreeOrder(nodes).map(\.id.rawValue) == ["root", "kid"])
}

/// `effectiveParents` promises a forest, so its callers never send a cycle here. If one ever arrives — a
/// second caller, or that promise broken — the items on it still come out: a row missing from a sidebar is
/// a bug nobody can see, and this is the line that keeps it from being silent.
@Test func treeOrderLosesNothingToACycle() {
    let nodes = [Node("root"), Node("x", parent: "y"), Node("y", parent: "x")]
    let ordered = TreeRules.inTreeOrder(nodes)
    #expect(ordered.map(\.id.rawValue) == ["root", "x", "y"])
    #expect(Set(ordered.map(\.id)) == Set(nodes.map(\.id)), "every item comes out")
    #expect(ordered.count == nodes.count, "and exactly once")
}

@Test func treeOrderIsEmptyForNoItems() {
    #expect(TreeRules.inTreeOrder([Node]()).isEmpty)
}
