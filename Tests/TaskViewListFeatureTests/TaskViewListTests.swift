import Testing
import TestSupport
import TaskViewListFeature
import TodoCore
import SQLiteKit

/// The change set a write produced, taken the way the composition root takes it: from `Store.onChange`, the
/// core's only push towards the UI and the only source of a `ChangeSet` there is, since nothing outside the
/// core can build one.
private func changeSet(of store: Store, from write: () throws -> Void) throws -> ChangeSet {
    var captured: ChangeSet?
    store.onChange = { captured = $0 }
    defer { store.onChange = nil }
    try write()
    return try #require(captured)
}

@Test func initialModelListsTheBuiltInViewsInRankOrderWithInboxSelected() throws {
    let model = try TaskViewList(store: try makeStore()).model
    #expect(model.rows.map(\.title) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash"])
    #expect(model.rows.allSatisfy { $0.depth == 0 })
    #expect(model.rows.filter(\.isSelected).map(\.id) == [BuiltInTaskViews.inbox])
    #expect(model.problem == nil)
}

@Test func nestedViewsGetTheirDepthInTreeOrder() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    let reviews = try store.createView(NewTaskView(title: "Reviews", parent: folder))
    try store.createView(NewTaskView(title: "Notes", parent: folder))
    try store.createView(NewTaskView(title: "Deep", parent: reviews))
    let rows = try TaskViewList(store: store).model.rows.dropFirst(5)
    #expect(rows.map(\.title) == ["Work", "Reviews", "Deep", "Notes"], "past the five built-in views, depth first and siblings by rank")
    #expect(rows.map(\.depth) == [0, 1, 2, 1])
}

@Test func selectionMovesTheHighlightAndReportsTheChoice() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    try store.createView(NewTaskView(title: "Reviews", parent: folder))
    let list = try TaskViewList(store: store)
    let before = list.model
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == .selected(BuiltInTaskViews.today))
    #expect(list.model.rows.filter(\.isSelected).map(\.id) == [BuiltInTaskViews.today])
    // Choosing the row that is already chosen is still a choice: the root opens the view again, where an
    // answer withheld would leave a person tapping a highlighted row and watching nothing happen.
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == .selected(BuiltInTaskViews.today))
    // The highlight moved back leaves the model as it was, which is what says that a move carries every
    // other field of every row along: the title a row draws, and the depth a nested one is drawn at.
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.inbox))) == .selected(BuiltInTaskViews.inbox))
    #expect(list.model == before)
}

@Test func changedWithAViewRereadsTheTree() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store)
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == .selected(BuiltInTaskViews.today))
    let created = try changeSet(of: store) { try store.createView(NewTaskView(title: "Docs")) }
    #expect(list.send(.changed(created)) == nil)
    #expect(list.model.rows.map(\.title) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash", "Docs"])
    // A view that appeared elsewhere is no reason to lose the row the person is on, and no reason to say
    // that anything went wrong.
    #expect(list.model.rows.filter(\.isSelected).map(\.id) == [BuiltInTaskViews.today])
    #expect(list.model.problem == nil)
}

@Test func changedWithoutAViewLeavesTheModelAlone() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store)
    let before = list.model
    let taskOnly = try changeSet(of: store) { try store.createTask(NewTask(title: "Write it down")) }
    try store.createView(NewTaskView(title: "Docs"))
    #expect(list.send(.changed(taskOnly)) == nil)
    #expect(list.model == before, "the view created since is missing, which is how a read that never ran shows")
}

@Test func theSelectionIsDroppedWhenTheSelectedViewDisappears() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store)
    let deleted = try changeSet(of: store) { try store.delete(view: BuiltInTaskViews.inbox) }
    #expect(list.send(.changed(deleted)) == nil, "a view a peer deleted is not a choice anybody made")
    #expect(list.model.rows.map(\.title) == ["Today", "Upcoming", "Logbook", "Trash"])
    let selected = list.model.rows.filter(\.isSelected)
    #expect(selected.isEmpty)
}

/// A chain thousands of links deep arrives from sync as easily as a shallow one, and a stack — 64 KiB of it
/// on wasm32 — is not what should decide whether the list draws (`docs/style.md`, "No recursion over
/// data-shaped depth"). The chain is journaled straight into the store, because a thousand calls to
/// `createView` would rank a thousand siblings and measure the write instead of the read.
@Test func aThousandNestedFoldersReadWithoutRecursion() throws {
    let store = try makeStore()
    let stamp = HLC(millis: 1, counter: 0)
    var ops: [JournalOperation] = []
    var ids: [String] = []
    for depth in 0..<1_000 {
        let id = "view-\(depth)"
        let fields: [(String, Value)] = [
            ("title", .text("v\(depth)")), ("parent", depth == 0 ? .null : .text(ids[depth - 1])),
            ("rank", .text(Rank.initial)), ("deleted", Value(false)),
        ]
        ops += fields.map { JournalOperation(entity: .view, entityID: id, field: $0.0, value: $0.1, clock: stamp, device: store.deviceID) }
        ids.append(id)
    }
    try store.apply(ops)
    let chain = try TaskViewList(store: store).model.rows.filter { $0.id.rawValue.hasPrefix("view-") }
    #expect(chain.map(\.id.rawValue) == ids, "parents before children, however deep the chain")
    #expect(chain.map(\.depth) == Array(0..<1_000))
}
