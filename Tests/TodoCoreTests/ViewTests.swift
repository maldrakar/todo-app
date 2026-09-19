import Testing
@testable import TodoCore
@testable import SQLiteKit

@Test func builtInViewsAreSeededOnceAndUserEditsSurviveReopen() throws {
    let clock = TestClock()
    let store = try makeStore(clock: clock)
    #expect(try store.views().map(\.title) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash"])
    #expect(try store.view(BuiltInTaskViews.today)?.filter == .and([.status([.open]), .when(.onOrBefore(0))]))
    try store.update(view: BuiltInTaskViews.today, [.title("Сегодня")])
    try store.delete(view: BuiltInTaskViews.trash)
    let reopened = try Store.openInMemory(snapshot: try store.snapshot(), now: clock.now)
    #expect(try reopened.views().map(\.title) == ["Inbox", "Сегодня", "Upcoming", "Logbook"])
    let seeded = try reopened.sql { () throws(SQLiteError) in try reopened.db.rows("SELECT count(*) FROM ops WHERE device = 'seed'") }
    #expect(seeded == [[.integer(40)]], "eight fields for five views, journaled once")
}

@Test func viewsNestMoveAndReadBackTheirDefinition() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    let reviews = try store.createView(NewTaskView(
        title: "Reviews", parent: folder, filter: .hasTag(TagID("g1")), sort: [SortKey(.deadline)], groupBy: .deadlineDay
    ))
    let inside = try #require(try store.view(reviews))
    #expect(inside.parent == folder && inside.filter == .hasTag(TagID("g1")) && inside.sort == [SortKey(.deadline)] && inside.groupBy == .deadlineDay)
    #expect(try store.view(folder)?.filter == nil, "a view without a filter is a folder")
    #expect(try store.children(ofView: folder).map(\.id) == [reviews])
    try store.move(view: folder, to: nil, at: .start)
    #expect(try Array(store.views().map(\.title).prefix(2)) == ["Work", "Reviews"])
    try store.update(view: reviews, [.filter(nil), .sort([]), .groupBy(nil), .title("Folder now")])
    let changed = try #require(try store.view(reviews))
    #expect(changed.filter == nil && changed.sort.isEmpty && changed.groupBy == nil && changed.title == "Folder now")
    try store.delete(view: folder)
    #expect(try store.view(reviews)?.parent == nil)
}

/// Views move the way tasks and tags do, and a move into the view's own subtree is refused rather than left
/// to the reading rule, which would answer the cycle by putting every view on it at the root — a person who
/// drags a folder onto one of its own children would watch the sidebar scatter.
@Test func aViewCannotBeMovedUnderItselfOrItsOwnDescendant() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    let inner = try store.createView(NewTaskView(title: "Reviews", parent: folder))
    var caught: StoreError?
    do { try store.move(view: folder, to: folder, at: .end) } catch { caught = error }
    #expect(caught == .invalid("a view cannot be its own parent"))
    do { try store.move(view: folder, to: inner, at: .end) } catch { caught = error }
    #expect(caught == .invalid("a view cannot be moved under its own descendant"))
    #expect(try store.view(inner)?.parent == folder, "the refused moves left the tree as it was")
}

/// A chain thousands of links deep arrives from sync as easily as a shallow one, and a stack — 64 KiB of it
/// on wasm32 — is not what should decide whether the sidebar reads (`docs/style.md`, "No recursion over
/// data-shaped depth").
@Test func aDeepViewChainReadsWithoutRecursion() throws {
    let store = try makeStore()
    let stamp = store.clock.next()
    var ops: [JournalOperation] = []
    var ids: [String] = []
    for depth in 0..<1_000 {
        let id = "view-\(depth)"
        ops.append(store.op(.view, id, "title", .text("v\(depth)"), stamp))
        ops.append(store.op(.view, id, "parent", depth == 0 ? .null : .text(ids[depth - 1]), stamp))
        ops.append(store.op(.view, id, "rank", .text(Rank.initial), stamp))
        ops.append(store.op(.view, id, "deleted", Value(false), stamp))
        ids.append(id)
    }
    try store.apply(ops)
    let chained = try store.views().map(\.id.rawValue).filter { $0.hasPrefix("view-") }
    #expect(chained == ids, "parents before children, however deep the chain")
}

@Test func aViewFromANewerAppIsReportedNotEvaluated() throws {
    let store = try makeStore()
    let id = ViewID("v-new")
    try store.apply([
        store.op(.view, id.rawValue, "title", .text("Soon"), HLC(millis: 5, counter: 0)),
        store.op(.view, id.rawValue, "filter", .text("{\"kind\":\"reminder_soon\"}"), HLC(millis: 5, counter: 0)),
    ])
    #expect(try store.view(id)?.needsNewerApp == "reminder_soon")
    var caught: StoreError?
    do { _ = try store.tasks(in: id, today: Day(year: 2026, month: 9, day: 11)) } catch { caught = error }
    #expect(caught == .viewNeedsNewerApp(id, kind: "reminder_soon"))
}

@Test func manualListsPinAndOrderTasks() throws {
    let store = try makeStore()
    let a = try store.createTask(NewTask(title: "a"))
    let b = try store.createTask(NewTask(title: "b"))
    let c = try store.createTask(NewTask(title: "c"))
    let heading = try store.createView(NewTaskView(title: "H"))
    try store.pin(task: a, in: heading)
    try store.pin(task: c, in: heading)
    try store.pin(task: b, in: heading, at: .after(a))
    #expect(try store.manualList(of: heading) == [a, b, c])
    try store.unpin(task: b, from: heading)
    #expect(try store.manualList(of: heading) == [a, c])
    try store.pin(task: b, in: heading, at: .start)
    #expect(try store.manualList(of: heading) == [b, a, c])
}

/// The three columns a view is defined by hold whatever another device wrote, and a value that is not text
/// at all is one no version of this app wrote. Read as "no filter" it would turn the view into a folder that
/// shows nothing, and a sort or a grouping read as absent would draw the list in the wrong order — a wrong
/// list, which is what the spec refuses. Each is reported by the column it could not read.
///
/// A number never gets this far: the column has TEXT affinity and SQLite converts it on the way in, so it
/// comes back as text that fails to parse. A blob is stored as a blob, and is the case that needs the check.
@Test func aViewDefinitionThatIsNotTextIsReportedNotReadAsAnEmptyOne() throws {
    let store = try makeStore()
    for column in ["filter", "sort", "group_by"] {
        let id = ViewID("v-\(column)")
        try store.apply([
            store.op(.view, id.rawValue, "title", .text("Broken"), store.clock.next()),
            store.op(.view, id.rawValue, column, .blob([0xFF]), store.clock.next()),
        ])
        #expect(try store.view(id)?.needsNewerApp == column, "a \(column) that is not text")
    }
}
