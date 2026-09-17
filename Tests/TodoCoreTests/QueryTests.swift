import Testing
@testable import TodoCore
@testable import SQLiteKit

private let today = Day(year: 2026, month: 9, day: 11)

/// Inbox: "loose", "later" (dated) is not in Inbox. Today: "due", "overdue". Upcoming: "later". Logbook: "done". Trash: "binned".
private func seeded(_ store: Store) throws -> [String: TaskID] {
    var ids: [String: TaskID] = [:]
    ids["loose"] = try store.createTask(NewTask(title: "loose"))
    ids["due"] = try store.createTask(NewTask(title: "due", when: today))
    ids["overdue"] = try store.createTask(NewTask(title: "overdue", when: today.advanced(by: -3)))
    ids["later"] = try store.createTask(NewTask(title: "later", when: today.advanced(by: 2)))
    ids["much later"] = try store.createTask(NewTask(title: "much later", when: today.advanced(by: 9)))
    let done = try store.createTask(NewTask(title: "done"))
    try store.update(task: done, [.status(.done)])
    ids["done"] = done
    let binned = try store.createTask(NewTask(title: "binned"))
    try store.trash(task: binned)
    ids["binned"] = binned
    return ids
}

@Test func builtInViewsSelectTheExpectedTasks() throws {
    let store = try makeStore()
    _ = try seeded(store)
    func titles(_ view: ViewID) throws -> [String] { try store.tasks(in: view, today: today).map(\.title) }
    #expect(try titles(BuiltInTaskViews.inbox) == ["loose"])
    #expect(try titles(BuiltInTaskViews.today) == ["overdue", "due"])
    #expect(try titles(BuiltInTaskViews.upcoming) == ["later", "much later"])
    #expect(try titles(BuiltInTaskViews.logbook) == ["done"])
    #expect(try titles(BuiltInTaskViews.trash) == ["binned"])
    #expect(try store.tasks(in: BuiltInTaskViews.today, today: today.advanced(by: 2)).map(\.title) == ["overdue", "due", "later"])
}

@Test func manualOrderComesFirstThenTheSort() throws {
    let store = try makeStore()
    let ids = try seeded(store)
    try store.pin(task: ids["due"]!, in: BuiltInTaskViews.today)
    #expect(try store.tasks(in: BuiltInTaskViews.today, today: today).map(\.title) == ["due", "overdue"])
    try store.unpin(task: ids["due"]!, from: BuiltInTaskViews.today)
    #expect(try store.tasks(in: BuiltInTaskViews.today, today: today).map(\.title) == ["overdue", "due"])
}

@Test func pagesRenderChildViewsAsSectionsThenTheRemainder() throws {
    let store = try makeStore()
    let project = try store.createTask(NewTask(title: "Project"))
    let design = try store.createTask(NewTask(title: "design", parent: project))
    let build = try store.createTask(NewTask(title: "build", parent: project))
    let ship = try store.createTask(NewTask(title: "ship", parent: project))
    let view = try store.createView(NewTaskView(title: "Project", filter: .parent(project)))
    let phase1 = try store.createView(NewTaskView(title: "Phase 1", parent: view))
    try store.update(view: phase1, [.filter(.listedIn(phase1))])
    try store.pin(task: design, in: phase1)
    try store.pin(task: build, in: phase1)

    let page = try store.page(of: view, today: today)
    #expect(page.view.id == view)
    #expect(page.sections.count == 2)
    #expect(page.sections[0].view?.id == phase1)
    #expect(page.sections[0].groups.flatMap(\.tasks).map(\.id) == [design, build])
    #expect(page.sections[1].view == nil)
    #expect(page.sections[1].groups.flatMap(\.tasks).map(\.id) == [ship])

    let folder = try store.createView(NewTaskView(title: "Folder"))
    try store.move(view: view, to: folder, at: .end)
    let folderPage = try store.page(of: folder, today: today)
    #expect(folderPage.sections.count == 1 && folderPage.sections[0].view?.id == view, "a folder shows only its children")
    #expect(folderPage.sections[0].groups.flatMap(\.tasks).map(\.id) == [design, build, ship], "one level of sections: the child's own headings flatten into it")
}

@Test func groupingByDayAndByTag() throws {
    let store = try makeStore()
    let ids = try seeded(store)
    let upcoming = try store.page(of: BuiltInTaskViews.upcoming, today: today)
    #expect(upcoming.sections[0].groups.map(\.key) == [.day(today.advanced(by: 2)), .day(today.advanced(by: 9))])
    let work = try store.createTag(title: "work")
    try store.add(tag: work, to: ids["due"]!)
    let view = try store.createView(NewTaskView(title: "By tag", filter: .status([.open]), sort: [SortKey(.title)], groupBy: .tag))
    let page = try store.page(of: view, today: today)
    #expect(page.sections[0].groups.map(\.key) == [.tag(work), .tag(nil)])
    #expect(page.sections[0].groups[0].tasks.map(\.title) == ["due"])
    #expect(page.sections[0].groups[1].tasks.map(\.title) == ["later", "loose", "much later", "overdue"])
}

/// The guard the spec promises under "Cost": a built-in view that degrades into a full scan of a table with
/// one row per task fails here instead of surprising a person with a large list.
///
/// `SCAN` of `tasks` or of `task_tree` is what it refuses; a `SCAN` of `view_items` or of a small temporary
/// would not be the same thing, so the assertion names the two tables that grow with the list. The statement
/// is the one `tasks(in:today:)` runs, built by the same function, not a copy of it.
@Test func builtInViewsUseIndexes() throws {
    let store = try makeStore()
    _ = try seeded(store)
    for id in [BuiltInTaskViews.inbox, BuiltInTaskViews.today, BuiltInTaskViews.upcoming, BuiltInTaskViews.logbook, BuiltInTaskViews.trash] {
        let view = try #require(try store.view(id))
        let filter = try #require(view.filter)
        let statement = Store.viewStatement(filter: filter, sort: view.sort, of: view.id, today: today)
        let plan = try store.sql { () throws(SQLiteError) in
            try store.db.rows("EXPLAIN QUERY PLAN " + statement.sql, statement.params).map { $0[3].string ?? "" }
        }
        // Without this the guard would pass on an empty plan, which is what a statement that failed to
        // prepare, or a `rows` call that returned nothing, would leave behind.
        #expect(plan.contains { $0.contains(" t ") || $0.hasSuffix(" t") }, "\(view.title) has no plan row for the tasks table: \(plan)")
        let scans = plan.filter { $0.hasPrefix("SCAN t ") || $0 == "SCAN t" || $0.hasPrefix("SCAN tt ") || $0 == "SCAN tt" }
        #expect(scans.isEmpty, "\(view.title) scans a table that grows with the list: \(plan)")
        // A scan is not the only way to lose. The first row is the outer loop of the join, and driving it
        // from the wrong side reads as a `SEARCH` while visiting nearly every task: an index over inherited
        // trash, which almost no task has, is usable by the `tt.trashed = 0` every other view carries, and
        // the planner takes it — 8.9x on the Logbook when it did. Every built-in but Trash is driven by its
        // own condition, over `tasks`; Trash is the one view whose condition is the trash itself.
        let driver = try #require(plan.first)
        if view.id == BuiltInTaskViews.trash {
            #expect(driver.contains("task_tree_trashed"), "Trash is driven by \(driver)")
        } else {
            #expect(driver.hasPrefix("SEARCH t "), "\(view.title) is driven by \(driver)")
        }
    }
}

/// A child view a newer app wrote costs its own section and nothing else. Blanking the whole page over it
/// would hide every sibling the newer app never touched, and a folder holds lists that have nothing to do
/// with each other. The view the page *is* stays an error: there is no page to draw without it.
@Test func aChildViewFromANewerAppLosesItsSectionAndNotThePage() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Folder"))
    let kept = try store.createTask(NewTask(title: "kept"))
    try store.createView(NewTaskView(title: "Good", parent: folder, filter: .status([.open])))
    let bad = ViewID("v-bad")
    let stamp = HLC(millis: 5, counter: 0)
    try store.apply([
        store.op(.view, bad.rawValue, "title", .text("Soon"), stamp),
        store.op(.view, bad.rawValue, "parent", .text(folder.rawValue), stamp),
        store.op(.view, bad.rawValue, "rank", .text("z"), stamp),
        store.op(.view, bad.rawValue, "filter", .text("{\"kind\":\"reminder_soon\"}"), stamp),
    ])

    let page = try store.page(of: folder, today: today)
    #expect(page.sections.map { $0.view?.title } == ["Good", "Soon"])
    #expect(page.sections[0].groups.flatMap(\.tasks).map(\.id) == [kept], "the sibling still draws")
    #expect(page.sections[1].groups.isEmpty, "the unreadable one contributes no tasks")
    #expect(page.sections[1].view?.needsNewerApp == "reminder_soon", "and says what it needs")

    var caught: StoreError?
    do { _ = try store.page(of: bad, today: today) } catch { caught = error }
    #expect(caught == .viewNeedsNewerApp(bad, kind: "reminder_soon"), "opening that view itself is still an error")
}
