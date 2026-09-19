import Testing
@testable import TodoCore
@testable import SQLiteKit

@Test func tagsNestOrderAndUpdate() throws {
    let store = try makeStore()
    let areas = try store.createTag(title: "Areas")
    let work = try store.createTag(title: "Work", parent: areas)
    let home = try store.createTag(title: "Home", parent: areas, at: .start)
    #expect(try store.tags().map(\.title) == ["Areas", "Home", "Work"])
    #expect(try store.tag(work)?.parent == areas)
    try store.update(tag: work, [.title("Office")])
    try store.move(tag: work, to: nil, at: .end)
    let office = try #require(try store.tag(work))
    #expect(office.title == "Office" && office.parent == nil)
    #expect(try store.tags().map(\.title) == ["Areas", "Home", "Office"], "Office moved to the root after Areas")
    try store.delete(tag: areas)
    #expect(try store.tags().map(\.title) == ["Home", "Office"], "Home keeps its earlier rank")
    #expect(try store.tag(home)?.parent == nil, "a deleted parent tag leaves its children at the root")
}

@Test func tagCyclesAfterAMergeShowAtTheRoot() throws {
    let store = try makeStore()
    let a = try store.createTag(title: "a")
    let b = try store.createTag(title: "b", parent: a)
    try store.apply([store.op(.tag, a.rawValue, "parent", .text(b.rawValue), HLC(millis: 9_999_999_999_999, counter: 0))])
    let tags = try store.tags()
    #expect(tags.allSatisfy { $0.parent == nil })
    #expect(tags.count == 2)
}

/// A placement ranks among the siblings a read shows, and `tags()` resolves a parent link the way the task
/// tree does: a tag whose stored parent was deleted is at the root, whatever the column still says.
@Test func aTagPlacementRanksAmongTheTagsAReadShows() throws {
    let store = try makeStore()
    let areas = try store.createTag(title: "Areas")
    try store.createTag(title: "Home", parent: areas)
    try store.createTag(title: "Work", parent: areas)
    try store.delete(tag: areas)
    try store.createTag(title: "New")
    #expect(try store.tags().map(\.title) == ["Home", "Work", "New"])
    try store.createTag(title: "First", at: .start)
    #expect(try store.tags().map(\.title) == ["First", "Home", "Work", "New"])
}

/// A chain thousands of links deep arrives from sync as easily as a shallow one, and a stack is not what
/// should decide whether the tag tree reads — the rule `TreeRules` and `inheritedTrash` already follow.
@Test func aDeepTagChainReadsWithoutRecursion() throws {
    let store = try makeStore()
    let stamp = store.clock.next()
    var ops: [JournalOperation] = []
    var ids: [String] = []
    for depth in 0..<1_000 {
        let id = "tag-\(depth)"
        ops.append(store.op(.tag, id, "title", .text("t\(depth)"), stamp))
        ops.append(store.op(.tag, id, "parent", depth == 0 ? .null : .text(ids[depth - 1]), stamp))
        ops.append(store.op(.tag, id, "rank", .text(Rank.initial), stamp))
        ops.append(store.op(.tag, id, "deleted", Value(false), stamp))
        ids.append(id)
    }
    try store.apply(ops)
    let tags = try store.tags()
    #expect(tags.map(\.id.rawValue) == ids, "parents before children, however deep the chain")
}

@Test func theLastChangeForATagFieldWins() throws {
    let store = try makeStore()
    let a = try store.createTag(title: "a")
    try store.update(tag: a, [.title("first"), .title("second")])
    #expect(try store.tag(a)?.title == "second")
}

/// Tags move the way tasks do: re-parenting is a move with a placement, a reorder inside one list writes the
/// rank alone, and a move into the tag's own subtree is refused rather than left to the reading rule, which
/// would answer it by putting every tag on the cycle at the root.
@Test func tagsMoveAndReorderTheWayTasksDo() throws {
    let store = try makeStore()
    let areas = try store.createTag(title: "Areas")
    let work = try store.createTag(title: "Work", parent: areas)
    let home = try store.createTag(title: "Home", parent: areas)
    let errands = try store.createTag(title: "Errands", parent: areas)
    #expect(try store.tags().map(\.title) == ["Areas", "Work", "Home", "Errands"])
    try store.move(tag: errands, at: .after(work))
    #expect(try store.tags().map(\.title) == ["Areas", "Work", "Errands", "Home"])
    #expect(try store.tag(errands)?.parent == areas, "a reorder says nothing about the parent")
    try store.move(tag: home, to: nil, at: .start)
    #expect(try store.tags().map(\.title) == ["Home", "Areas", "Work", "Errands"])
    var caught: StoreError?
    do { try store.move(tag: areas, to: areas, at: .end) } catch { caught = error }
    #expect(caught == .invalid("a tag cannot be its own parent"))
    do { try store.move(tag: areas, to: work, at: .end) } catch { caught = error }
    #expect(caught == .invalid("a tag cannot be moved under its own descendant"))
    #expect(try store.tags().map(\.title) == ["Home", "Areas", "Work", "Errands"], "the refused moves left the tree as it was")
}
