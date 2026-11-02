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
/// The icon reads as its text, whatever it is: a name this app does not know is read by the feature module
/// that builds the tile, which gives it the default glyph (ADR-0007, amendment of 2026-10-26). A value that
/// is not text is none of the three.
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

/// A list deleted with everything under it goes in one write: every view of its subtree is tombstoned by
/// operations under one stamp, which one `apply` commits as one transaction, so nothing under it surfaces at
/// the root the way a child of `delete(view:)` does, and the views after it in the tree stay as they were
/// (spec section 6). A view that is gone is not there to delete.
@Test func deletingATreeTombstonesEveryViewUnderItInOneTransaction() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work"))
    let reviews = try store.createView(NewTaskView(title: "Reviews", parent: work, filter: .status([.open])))
    let projects = try store.createView(NewTaskView(title: "Projects", parent: work))
    let alpha = try store.createView(NewTaskView(title: "Alpha", parent: projects, filter: .when(.empty)))
    let home = try store.createView(NewTaskView(title: "Home"))
    try store.createView(NewTaskView(title: "Garden", parent: home))
    let before = try store.views()

    var commits: [ChangeSet] = []
    store.onChange = { commits.append($0) }
    try store.delete(viewTree: work)
    store.onChange = nil

    let tree: Set<ViewID> = [work, reviews, projects, alpha]
    #expect(try store.views() == before.filter { !tree.contains($0.id) }, "the tree is gone, and nothing of it surfaced at the root")
    #expect(commits.map(\.views) == [tree], "one transaction, which addressed the tree")
    let tombstones = try store.sql { () throws(SQLiteError) in
        try store.db.rows("SELECT entity_id, clock FROM ops WHERE entity = 'view' AND field = 'deleted' AND value = 1")
    }
    #expect(Set(tombstones.map { ViewID($0[0].string ?? "") }) == tree)
    #expect(Set(tombstones.map { $0[1].int64 }).count == 1, "under one stamp")
    #expect(throws: StoreError.notFound(work)) { try store.delete(viewTree: work) }
}

/// A list selects its tasks by its rule and holds none of them, so deleting the tree takes the rules away and
/// leaves every task as it was, the one its manual list pinned among them; the pins go unread with the list
/// they belong to, as they do after `delete(view:)` (spec section 6).
@Test func deletingATreeLeavesTheTasks() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let pinned = try store.createTask(NewTask(title: "pinned", tags: [work]))
    try store.createTask(NewTask(title: "loose"))
    let folder = try store.createView(NewTaskView(title: "Folder"))
    let tagged = try store.createView(NewTaskView(title: "Work", parent: folder, filter: .hasTag(work)))
    try store.pin(task: pinned, in: tagged)
    let before = try store.allTasks()

    try store.delete(viewTree: folder)

    #expect(try store.allTasks() == before)
    #expect(throws: StoreError.notFound(tagged)) { try store.tasks(in: tagged, today: Day(year: 2026, month: 10, day: 26)) }
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

// MARK: - A group's view and a manual list

/// An operation the way one arrives from another device, stamped past every clock the test's store has used, so that it
/// wins its field as a peer's later edit does.
private func fromPeer(_ store: Store, _ id: ViewID, _ field: String, _ value: Value) throws {
    let stamp = HLC(millis: store.clock.next().millis + 1_000, counter: 0)
    try store.receive([JournalOperation(entity: .view, entityID: id.rawValue, field: field, value: value, clock: stamp, device: "peer")])
}

/// The tombstone a view's row stores, whatever the row reads as.
private func storedTombstone(_ store: Store, _ id: ViewID) throws -> Value? {
    try store.sql { () throws(SQLiteError) in
        try store.db.rows("SELECT deleted FROM views WHERE id = ?", [.text(id.rawValue)])
    }.first?.first
}

/// The fields of a view journaled under one stamp, the latest the view's operations carry, by name.
private func lastWrite(_ store: Store, _ id: ViewID) throws -> [String] {
    try store.sql { () throws(SQLiteError) in
        try store.db.rows(
            "SELECT field FROM ops WHERE entity_id = ? AND clock = (SELECT max(clock) FROM ops WHERE entity_id = ?) ORDER BY field",
            [.text(id.rawValue), .text(id.rawValue)]
        )
    }.map { $0[0].string ?? "" }
}

/// Every commit a write makes, which is how a test tells one transaction from two.
private func commits(of store: Store, _ write: () throws -> Void) rethrows -> [ChangeSet] {
    var commits: [ChangeSet] = []
    store.onChange = { commits.append($0) }
    defer { store.onChange = nil }
    try write()
    return commits
}

/// A list with a rule and a look of its own, the kind of list a group is opened from.
private func thisWeek(_ store: Store) throws -> ViewID {
    try store.createView(NewTaskView(
        title: "This week", color: .indigo, icon: "calendar", filter: .and([.status([.open]), .when(.between(0, 6))]),
        sort: [SortKey(.when), SortKey(.title)], groupBy: .whenDay
    ))
}

/// A row of kind `group` reads as one where it has a parent the store holds and a rule: the third kind beside `list`
/// and `area` (ADR-0004, amendment of 2026-11-01), here as a peer's operations bring one, and it is one of its list's
/// children, which the page, the counts and the sidebar skip by its kind.
@Test func aStoredGroupWithAParentAndAFilterReadsAsAGroup() throws {
    let store = try makeStore()
    let list = try thisWeek(store)
    let group = ViewID("g")
    let stamp = store.clock.next()
    try store.apply([
        store.op(.view, group.rawValue, "title", .text("Tomorrow"), stamp),
        store.op(.view, group.rawValue, "kind", .text("group"), stamp),
        store.op(.view, group.rawValue, "parent", .text(list.rawValue), stamp),
        store.op(.view, group.rawValue, "filter", .text(try Filter.when(.on(1)).json()), stamp),
    ])
    let read = try #require(try store.view(group))
    #expect(read.kind == .group && read.parent == list && read.filter == .when(.on(1)))
    #expect(try store.children(ofView: list).map(\.id) == [group])
}

/// A group whose list is gone reads as gone with it, and never as a list at the root, which is where the reading rule
/// would lift any other child of a deleted parent: a list named "Tomorrow" at the root of the sidebar (owner's review of
/// the plan, 2026-11-02). The list's tombstone arrives as a peer's does, so no delete of this app's ran, and the row
/// itself is still stored live. A group under a group is no group either, whether that group reads or not, since a
/// group holds no lists; so a group under an orphan stays out of the tree too.
@Test func anOrphanGroupReadsAsDeleted() throws {
    let store = try makeStore()
    let list = try thisWeek(store)
    let group = try store.groupView(of: list, condition: .when(.on(1)), titled: "Tomorrow")
    let under = ViewID("under")
    let stamp = store.clock.next()
    try store.apply([
        store.op(.view, under.rawValue, "kind", .text("group"), stamp),
        store.op(.view, under.rawValue, "parent", .text(group.rawValue), stamp),
        store.op(.view, under.rawValue, "filter", .text(try Filter.when(.on(2)).json()), stamp),
    ])
    #expect(try store.view(under) == nil, "a group under a group is an orphan while its parent reads")
    #expect(try store.view(group)?.kind == .group)

    try fromPeer(store, list, "deleted", Value(true))

    #expect(try storedTombstone(store, group) == .integer(0), "no cascade ran: the row is stored live")
    #expect(try !store.views().contains { $0.id == group || $0.id == under })
    #expect(try store.view(group) == nil)
    #expect(try store.children(ofView: nil).map(\.id) == [
        BuiltInTaskViews.inbox, BuiltInTaskViews.today, BuiltInTaskViews.upcoming, BuiltInTaskViews.logbook, BuiltInTaskViews.trash,
    ])
}

/// A group's rule is its list's and its condition written out, so a row of kind `group` with no filter is no group of
/// anything, and reads as gone rather than as a folder under its list.
@Test func aGroupWithoutAFilterReadsAsDeleted() throws {
    let store = try makeStore()
    let list = try thisWeek(store)
    let group = ViewID("g")
    let stamp = store.clock.next()
    try store.apply([
        store.op(.view, group.rawValue, "title", .text("Tomorrow"), stamp),
        store.op(.view, group.rawValue, "kind", .text("group"), stamp),
        store.op(.view, group.rawValue, "parent", .text(list.rawValue), stamp),
    ])
    #expect(try store.view(group) == nil)
    #expect(try store.children(ofView: list).isEmpty)
}

/// `groupView` is the one way to make a group's view, so that its id is always the one every device derives: a create
/// that asks for the kind is refused, and writes nothing.
@Test func createViewRefusesAGroup() throws {
    let store = try makeStore()
    let list = try thisWeek(store)
    let before = try store.views()
    #expect(throws: StoreError.invalid("a group's view is made from its list")) {
        try store.createView(NewTaskView(title: "Tomorrow", parent: list, kind: .group, filter: .when(.on(1))))
    }
    #expect(try store.views() == before)
}

/// A group's view stays under its list and holds no lists (ADR-0004, amendment of 2026-11-01), as an area stays at the
/// root: a move of one is refused, to the root or under another list, and so is a view moved under one, made under one,
/// or a manual list made in one. None of the refusals writes anything.
@Test func aGroupIsNotMovedAndTakesNoChild() throws {
    let store = try makeStore()
    let list = try thisWeek(store)
    let other = try store.createView(NewTaskView(title: "Other", filter: .status([.open])))
    let group = try store.groupView(of: list, condition: .when(.on(1)), titled: "Tomorrow")
    let before = try store.views()
    let stays = StoreError.invalid("a group's view stays under its list")
    let holdsNoLists = StoreError.invalid("a group's view holds no lists")
    #expect(throws: stays) { try store.move(view: group, to: nil, at: .end) }
    #expect(throws: stays) { try store.move(view: group, to: other, at: .end) }
    #expect(throws: holdsNoLists) { try store.move(view: other, to: group, at: .end) }
    #expect(throws: holdsNoLists) { try store.createView(NewTaskView(title: "Inside", parent: group)) }
    #expect(throws: holdsNoLists) { try store.createManualList("Inside", in: group, color: nil) }
    #expect(try store.views() == before)
}

/// A list made on the list screen is a manual list, the heading of ADR-0004: a view whose rule lists itself, which one
/// call makes in one transaction, the id minted before the filter that names it, with the `list` icon and the colour it
/// is given, last among its parent's lists (ADR-0004, amendment of 2026-11-01). A task is in it by being pinned there.
@Test func aManualListIsMadeInOneTransactionWithItsOwnIDInItsRule() throws {
    let store = try makeStore()
    let parent = try thisWeek(store)
    let first = try store.createView(NewTaskView(title: "First", parent: parent, filter: .status([.open])))
    var made: ViewID?
    let written = try commits(of: store) { made = try store.createManualList("Errands", in: parent, color: .teal) }
    let id = try #require(made)
    #expect(written.map(\.views) == [[id]], "one transaction")
    let list = try #require(try store.view(id))
    #expect(list.filter == .listedIn(id) && list.kind == .list && list.icon == "list" && list.color == .teal)
    #expect(list.title == "Errands" && list.parent == parent && list.groupBy == nil && list.sort.isEmpty)
    #expect(try store.children(ofView: parent).map(\.id) == [first, id], "ranked last")
    let stamps = try store.sql { () throws(SQLiteError) in
        try store.db.rows("SELECT count(*), count(DISTINCT clock) FROM ops WHERE entity_id = ?", [.text(id.rawValue)])
    }
    #expect(stamps == [[.integer(11), .integer(1)]], "eleven fields under one stamp")
    let task = try store.createTask(NewTask(title: "Buy stamps"))
    try store.pin(task: task, in: id)
    #expect(try store.tasks(in: id, today: Day(year: 2026, month: 11, day: 2)).map(\.id) == [task])
    #expect(throws: StoreError.notFound(ViewID("gone"))) { try store.createManualList("Lost", in: ViewID("gone"), color: nil) }
}

/// The view of one group of a list, Monday of "This week", is made in one call and one transaction: kind `group`, the
/// list's rule and the condition written out as its filter, the list's colour, icon and sort, no grouping, its parent
/// the list, and its id derived from the list's id and the condition's JSON (ADR-0004, amendment of 2026-11-01).
@Test func aGroupViewIsMadeFromItsListInOneTransaction() throws {
    let store = try makeStore()
    let list = try thisWeek(store)
    let inside = try store.createView(NewTaskView(title: "Inside", parent: list, filter: .status([.open])))
    let condition = Filter.when(.on(1))
    var made: ViewID?
    let written = try commits(of: store) { made = try store.groupView(of: list, condition: condition, titled: "Tomorrow") }
    let group = try #require(made)
    #expect(group == EntityID.derived(from: list, try condition.json()))
    #expect(written.map(\.views) == [[group]], "one transaction")
    let read = try #require(try store.view(group))
    #expect(read.kind == .group && read.parent == list && read.title == "Tomorrow")
    #expect(read.filter == .and([.and([.status([.open]), .when(.between(0, 6))]), condition]))
    #expect(read.color == .indigo && read.icon == "calendar" && read.sort == [SortKey(.when), SortKey(.title)] && read.groupBy == nil)
    #expect(try store.children(ofView: list).map(\.id) == [inside, group], "ranked last among the list's children")
    let stamps = try store.sql { () throws(SQLiteError) in
        try store.db.rows("SELECT count(*), count(DISTINCT clock) FROM ops WHERE entity_id = ?", [.text(group.rawValue)])
    }
    #expect(stamps == [[.integer(11), .integer(1)]], "eleven fields under one stamp")
}

/// Opening the same group again finds the row by the id it derives and writes nothing when nothing changed: no
/// transaction, no change set, and the journal as it was, since drawing a page must not grow the journal.
@Test func aGroupViewMadeAgainWritesNothing() throws {
    let store = try makeStore()
    let list = try thisWeek(store)
    let group = try store.groupView(of: list, condition: .when(.on(1)), titled: "Tomorrow")
    let journal = try store.journal(after: 0)
    var again: ViewID?
    let written = try commits(of: store) { again = try store.groupView(of: list, condition: .when(.on(1)), titled: "Tomorrow") }
    #expect(again == group)
    #expect(written.isEmpty)
    #expect(try store.journal(after: 0) == journal)
}

/// When the list's rule or look changed since its group was made, opening the group brings it up to date, and only the
/// fields that differ are written, under one stamp: the rule by `update(view:)`, the colour as a settings screen or a
/// peer writes it, the title as the module words it today; the rest stays as it is.
@Test func aGroupViewFollowsItsListsRuleAndLook() throws {
    let store = try makeStore()
    let list = try thisWeek(store)
    let group = try store.groupView(of: list, condition: .when(.on(1)), titled: "Tomorrow")
    try store.update(view: list, [.filter(.status([.open])), .sort([SortKey(.deadline)])])
    try store.apply([store.op(.view, list.rawValue, "color", .text("rose"), store.clock.next())])

    let written = try commits(of: store) { try store.groupView(of: list, condition: .when(.on(1)), titled: "Monday") }

    #expect(written.map(\.views) == [[group]], "one transaction")
    #expect(try lastWrite(store, group) == ["color", "filter", "sort", "title"])
    let read = try #require(try store.view(group))
    #expect(read.filter == .and([.status([.open]), .when(.on(1))]) && read.sort == [SortKey(.deadline)])
    #expect(read.color == .rose && read.icon == "calendar" && read.title == "Monday" && read.parent == list)
}

/// Only a list with a rule has groups to open: a folder and an area select nothing and are refused, a group's view
/// holds no grouping of its own, and a view that is not there, or is gone, is not found. A condition that the list's
/// rule takes past the depth a read takes is refused as every such filter is, though it is within the depth alone.
/// Nothing is written.
@Test func aGroupViewOfAFolderIsRefused() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Folder"))
    let area = try store.createView(NewTaskView(title: "Work", kind: .area))
    let list = try thisWeek(store)
    let group = try store.groupView(of: list, condition: .when(.on(1)), titled: "Tomorrow")
    let gone = try store.createView(NewTaskView(title: "Gone", filter: .status([.open])))
    try store.delete(view: gone)
    let journal = try store.journal(after: 0)
    let folderHasNone = StoreError.invalid("a folder has no groups")
    #expect(throws: folderHasNone) { try store.groupView(of: folder, condition: .when(.on(1)), titled: "Tomorrow") }
    #expect(throws: folderHasNone) { try store.groupView(of: area, condition: .when(.on(1)), titled: "Tomorrow") }
    #expect(throws: StoreError.invalid("a group has no groups")) { try store.groupView(of: group, condition: .when(.on(2)), titled: "In 2 days") }
    #expect(throws: StoreError.notFound(gone)) { try store.groupView(of: gone, condition: .when(.on(1)), titled: "Tomorrow") }
    #expect(throws: StoreError.notFound(ViewID("none"))) { try store.groupView(of: ViewID("none"), condition: .when(.on(1)), titled: "Tomorrow") }
    var deep = Filter.when(.empty)
    for _ in 0..<(maximumDepth - 2) { deep = .not(deep) }
    #expect(nestingDepth(of: try deep.json()) == maximumDepth)
    let tooDeep = StoreError.invalidFilter(String(describing: FilterError.malformed("nested deeper than \(maximumDepth) levels")))
    #expect(throws: tooDeep) { try store.groupView(of: list, condition: deep, titled: "Deep") }
    #expect(try store.journal(after: 0) == journal)
}

/// A group's row lives and dies with its list (owner's review of the plan, 2026-11-02): the tree delete the Lists screen
/// deletes a list by takes its groups with the lists under it, in its one transaction.
@Test func aListsTreeDeleteTakesItsGroups() throws {
    let store = try makeStore()
    let list = try thisWeek(store)
    let inside = try store.createView(NewTaskView(title: "Inside", parent: list, filter: .status([.open])))
    let group = try store.groupView(of: list, condition: .when(.on(1)), titled: "Tomorrow")
    let written = try commits(of: store) { try store.delete(viewTree: list) }
    #expect(written.map(\.views) == [[list, inside, group]])
    #expect(try storedTombstone(store, group) == .integer(1), "tombstoned, not only unread")
}

/// The one-view delete takes the list's groups too, in the same transaction, though the lists inside it surface at the
/// root as before: a group cannot stand anywhere but under its list, and a row left behind would sync to an older app,
/// which reads it as a list.
@Test func aListsDeleteTakesItsGroups() throws {
    let store = try makeStore()
    let list = try thisWeek(store)
    let inside = try store.createView(NewTaskView(title: "Inside", parent: list, filter: .status([.open])))
    let group = try store.groupView(of: list, condition: .when(.on(1)), titled: "Tomorrow")
    let written = try commits(of: store) { try store.delete(view: list) }
    #expect(written.map(\.views) == [[list, group]], "one change set naming both")
    #expect(try storedTombstone(store, group) == .integer(1))
    #expect(try store.view(inside)?.parent == nil, "a list inside surfaces at the root")
    let tombstones = try store.sql { () throws(SQLiteError) in
        try store.db.rows("SELECT count(DISTINCT clock) FROM ops WHERE entity = 'view' AND field = 'deleted' AND value = 1")
    }
    #expect(tombstones == [[.integer(1)]], "under one stamp")
}

/// A group's row deleted alone, by this app or by an older one that read it as a list, is not refused, since the same
/// tombstone can arrive from a peer whatever this app refuses; opening the group again takes the row with the derived id
/// back, writing only what differs, the tombstone.
@Test func aDeletedGroupRowComesBackWhenItsGroupIsOpened() throws {
    let store = try makeStore()
    let list = try thisWeek(store)
    let group = try store.groupView(of: list, condition: .when(.on(1)), titled: "Tomorrow")
    let made = try #require(try store.view(group))
    try store.delete(view: group)
    #expect(try store.view(group) == nil)

    let written = try commits(of: store) { try store.groupView(of: list, condition: .when(.on(1)), titled: "Tomorrow") }

    #expect(written.map(\.views) == [[group]])
    #expect(try lastWrite(store, group) == ["deleted"])
    let back = try #require(try store.view(group))
    #expect(back.kind == .group && back.parent == list && back.filter == made.filter && back.title == made.title)
}

/// An older app reads a group's row as a list and can move it, here under another list, where it still reads as a group
/// since its parent is a list. Opening the group from its own list writes the parent back, and nothing else.
@Test func aGroupRowMovedByAPeerReturnsUnderItsList() throws {
    let store = try makeStore()
    let list = try thisWeek(store)
    let other = try store.createView(NewTaskView(title: "Other", filter: .status([.open])))
    let group = try store.groupView(of: list, condition: .when(.on(1)), titled: "Tomorrow")
    try fromPeer(store, group, "parent", .text(other.rawValue))
    #expect(try store.view(group)?.parent == other)

    let written = try commits(of: store) { try store.groupView(of: list, condition: .when(.on(1)), titled: "Tomorrow") }

    #expect(written.map(\.views) == [[group]])
    #expect(try lastWrite(store, group) == ["parent"])
    #expect(try store.view(group)?.parent == list)
    #expect(try store.children(ofView: other).isEmpty)
}
