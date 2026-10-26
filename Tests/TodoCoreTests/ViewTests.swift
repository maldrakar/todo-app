import Testing
import TestSupport
@testable import TodoCore
@testable import SQLiteKit

@Test func builtInViewsAreSeededOnceAndUserEditsSurviveReopen() throws {
    let clock = TestClock()
    let store = try makeStore(clock: clock)
    #expect(try store.views().map(\.title) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash"])
    #expect(try store.view(BuiltInTaskViews.today)?.filter == .and([.status([.open]), .when(.onOrBefore(0))]))
    // The canvas's tiles in the seed's order, the Inbox's tray on blue first, on five plain lists.
    let tiled = try store.views()
    #expect(tiled.map(\.color) == [.blue, .amber, .rose, .green, .stone])
    #expect(tiled.map(\.icon) == ["tray", "sun", "calendar", "logbook", "trash"])
    #expect(tiled.allSatisfy { $0.kind == .list })
    try store.update(view: BuiltInTaskViews.today, [.title("Сегодня")])
    try store.delete(view: BuiltInTaskViews.trash)
    let reopened = try Store.openInMemory(snapshot: try store.snapshot(), device: store.deviceID, now: clock.now)
    #expect(try reopened.views().map(\.title) == ["Inbox", "Сегодня", "Upcoming", "Logbook"])
    let seeded = try reopened.sql { () throws(SQLiteError) in try reopened.db.rows("SELECT count(*) FROM ops WHERE device = 'seed'") }
    #expect(seeded == [[.integer(55)]], "eleven fields for five views, journaled once")
}

/// A store an earlier version seeded holds the built-ins' eight fields and none of the three, and the seed of
/// this version adds the three at the next open: the eight are already in the journal and are dropped, the
/// three are not and apply, since no clock holds their fields yet. So the tiles show at once (spec section 2).
@Test func aStoreSeededBeforeTheFieldsShowsTheTilesAtTheNextOpen() throws {
    let clock = TestClock()
    let store = try makeStore(clock: clock)
    try store.sql { () throws(SQLiteError) in
        try store.db.run("DELETE FROM ops WHERE field IN ('kind', 'color', 'icon')")
        try store.db.run("DELETE FROM field_clocks WHERE field IN ('kind', 'color', 'icon')")
        try store.db.run("UPDATE views SET kind = NULL, color = NULL, icon = NULL")
    }
    #expect(try store.view(BuiltInTaskViews.inbox)?.color == nil, "the store as the earlier version left it")
    let reopened = try Store.openInMemory(snapshot: try store.snapshot(), device: store.deviceID, now: clock.now)
    let inbox = try #require(try reopened.view(BuiltInTaskViews.inbox))
    #expect(inbox.color == .blue && inbox.icon == "tray")
}

/// A view is written with its kind, its colour and its icon by the operations that create it, under the one
/// stamp the rest of its fields share, and a colour or an icon it has none of is a null the journal carries
/// like any other field (spec section 2).
@Test func aViewCarriesItsKindColourAndIcon() throws {
    let store = try makeStore()
    let area = try store.createView(NewTaskView(title: "Work", kind: .area))
    let tiled = try store.createView(NewTaskView(title: "Reviews", parent: area, color: .teal, icon: "list"))
    let plain = try store.createView(NewTaskView(title: "Plain"))
    let work = try #require(try store.view(area))
    #expect(work.kind == .area && work.color == nil && work.icon == nil)
    let reviews = try #require(try store.view(tiled))
    #expect(reviews.kind == .list && reviews.color == .teal && reviews.icon == "list" && reviews.parent == area)
    let other = try #require(try store.view(plain))
    #expect(other.kind == .list && other.color == nil && other.icon == nil)
    let journaled = try store.sql { () throws(SQLiteError) in
        try store.db.rows("SELECT field, value FROM ops WHERE entity_id = ? AND field IN ('kind', 'color', 'icon') ORDER BY field", [.text(area.rawValue)])
    }
    #expect(journaled == [[.text("color"), .null], [.text("icon"), .null], [.text("kind"), .text("area")]])
    let stamps = try store.sql { () throws(SQLiteError) in
        try store.db.rows("SELECT count(*), count(DISTINCT clock) FROM ops WHERE entity_id = ?", [.text(area.rawValue)])
    }
    #expect(stamps == [[.integer(11), .integer(1)]], "eleven fields under one stamp, in one write")
}

/// An area stands at the root and selects nothing (ADR-0004, amendment of 2026-10-25), and the store refuses
/// a write that would make one otherwise, as it refuses a move into a view's own subtree, rather than leave
/// the reading rule to show a person a list where they made an area. An area still moves along the root.
@Test func anAreaIsNeverNestedAndHasNoRule() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Folder"))
    let area = try store.createView(NewTaskView(title: "Work", kind: .area))
    let before = try store.views()
    #expect(throws: StoreError.invalid("an area cannot be nested")) {
        try store.createView(NewTaskView(title: "Nested", parent: folder, kind: .area))
    }
    #expect(throws: StoreError.invalid("an area has no rule")) {
        try store.createView(NewTaskView(title: "Ruled", kind: .area, filter: .status([.open])))
    }
    #expect(throws: StoreError.invalid("an area cannot be nested")) { try store.move(view: area, to: folder, at: .end) }
    #expect(try store.views() == before, "the refused writes left the tree as it was")
    try store.move(view: area, to: nil, at: .start)
    #expect(try store.views().first?.id == area)
}

/// An app older than the field moves an area as a plain view, so an area can arrive with a parent. It reads
/// as a list with no rule, a folder with its lists under it, since a line inside a list is nothing the screen
/// can draw. That is a reading rule and not a repair: it reads the effective parent, so the same row reads as
/// an area again once its link stops holding, as any view surfaces at the root then.
@Test func anAreaThatArrivesNestedReadsAsAList() throws {
    let store = try makeStore()
    let stamp = HLC(millis: 5, counter: 0)
    try store.apply([
        store.op(.view, "p", "title", .text("Parent"), stamp),
        store.op(.view, "a", "title", .text("Was an area"), stamp),
        store.op(.view, "a", "kind", .text("area"), stamp),
        store.op(.view, "a", "parent", .text("p"), stamp),
    ])
    let nested = try #require(try store.view(ViewID("a")))
    #expect(nested.kind == .list && nested.parent == ViewID("p"))
    try store.delete(view: ViewID("p"))
    #expect(try store.view(ViewID("a"))?.kind == .area)
}

/// An area selects nothing, and one that arrives with a rule anyway, from an app older than the field that
/// read it as a folder, shows what the rule selects: a list, and not a line that hides a rule.
@Test func anAreaWithARuleReadsAsAList() throws {
    let store = try makeStore()
    let stamp = HLC(millis: 5, counter: 0)
    try store.apply([
        store.op(.view, "a", "title", .text("Ruled"), stamp),
        store.op(.view, "a", "kind", .text("area"), stamp),
        store.op(.view, "a", "filter", .text(try Filter.status([.open]).json()), stamp),
    ])
    let ruled = try #require(try store.view(ViewID("a")))
    #expect(ruled.kind == .list && ruled.filter == .status([.open]))
}

/// The kind and the colour are names this app owns, and a name it does not know, from a newer app or a wrong
/// one, reads as absent: a plain list with no colour, and never a view that stops reading (`docs/style.md`).
/// The icon is a name the platform maps and draws a default glyph for, so any text reads as itself; a value
/// that is not text is none of the three.
@Test func anUnknownKindOrColourReadsAsAbsent() throws {
    let store = try makeStore()
    let stamp = HLC(millis: 5, counter: 0)
    try store.apply([
        store.op(.view, "v", "title", .text("From elsewhere"), stamp),
        store.op(.view, "v", "kind", .text("cabinet"), stamp),
        store.op(.view, "v", "color", .text("mauve"), stamp),
        store.op(.view, "v", "icon", .text("sparkles"), stamp),
        store.op(.view, "w", "title", .text("Not text"), stamp),
        store.op(.view, "w", "kind", .blob([0xFF]), stamp),
        store.op(.view, "w", "color", .blob([0xFF]), stamp),
        store.op(.view, "w", "icon", .blob([0xFF]), stamp),
    ])
    let named = try #require(try store.view(ViewID("v")))
    #expect(named.kind == .list && named.color == nil && named.icon == "sparkles")
    let blobs = try #require(try store.view(ViewID("w")))
    #expect(blobs.kind == .list && blobs.color == nil && blobs.icon == nil)
}

/// A view a device brings from before version 5 has none of the three fields, and reads as it did: a plain
/// list with no tile (spec section 2).
@Test func aViewMadeBeforeTheFieldsReadsAsAPlainList() throws {
    let db = try Connection.openInMemory()
    for step in Migrations.steps where step.version <= 4 {
        try db.execute(step.sql)
        try db.setUserVersion(step.version)
    }
    try db.run("INSERT INTO views (id, title) VALUES ('v', 'Made at version 4')")
    let store = try Store(db: db, device: Store.newDeviceID(), now: TestClock().now)
    let old = try #require(try store.view(ViewID("v")))
    #expect(old.title == "Made at version 4" && old.kind == .list && old.color == nil && old.icon == nil)
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
