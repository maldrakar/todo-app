import Testing
import TestSupport
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

/// The tasks of each section of a page, in order: a page's shape compared whole, so a section that is missing or
/// out of place fails the comparison rather than an index past the end.
private func sectionTasks(_ page: TaskViewPage) -> [[TaskID]] {
    page.sections.map { $0.groups.flatMap(\.tasks).map(\.id) }
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

@Test func pagesRenderTheRemainderThenChildViewsAsSections() throws {
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
    #expect(page.sections.map { $0.view?.id } == [nil, phase1])
    #expect(sectionTasks(page) == [[ship], [design, build]])

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

/// The case this thread of the review found: a task dragged to the top of its own group must not carry the
/// group with it. Groups take their order from the sort, and the manual list orders tasks inside a group —
/// pinning `b2` used to put it at the head of the flat list, which lifted the whole of its day above the
/// earlier one and brought `b1` along.
@Test func aPinOrdersInsideItsGroupAndLeavesTheGroupWhereTheSortPutIt() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "a1", when: today))
    _ = try store.createTask(NewTask(title: "a2", when: today))
    _ = try store.createTask(NewTask(title: "b1", when: today.advanced(by: 1)))
    let b2 = try store.createTask(NewTask(title: "b2", when: today.advanced(by: 1)))
    let view = try store.createView(NewTaskView(title: "Days", filter: .status([.open]), sort: [SortKey(.when)], groupBy: .whenDay))
    try store.pin(task: b2, in: view, at: .start)

    let groups = try store.page(of: view, today: today).sections[0].groups
    #expect(groups.map(\.key) == [.day(today), .day(today.advanced(by: 1))], "the pin does not reorder the days")
    #expect(groups[0].tasks.map(\.title) == ["a1", "a2"])
    #expect(groups[1].tasks.map(\.title) == ["b2", "b1"], "it reorders the day it is in")
}

/// One rule and not two: no grouping is one group, so the flat list of a view is the groups of its own
/// section laid end to end. A page and the picker behind it would otherwise show a person two different
/// orders for the same view, and the two are asserted against each other here as well as against the answer,
/// so they cannot drift apart while both stay self-consistent.
@Test func theFlatListOfAGroupedViewIsItsOwnGroupsInOrder() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "a1", when: today))
    _ = try store.createTask(NewTask(title: "b1", when: today.advanced(by: 1)))
    let b2 = try store.createTask(NewTask(title: "b2", when: today.advanced(by: 1)))
    let view = try store.createView(NewTaskView(title: "Days", filter: .status([.open]), sort: [SortKey(.when)], groupBy: .whenDay))
    try store.pin(task: b2, in: view, at: .start)

    #expect(try store.tasks(in: view, today: today).map(\.title) == ["a1", "b2", "b1"])
    let page = try store.page(of: view, today: today)
    #expect(try store.tasks(in: view, today: today) == page.sections[0].groups.flatMap(\.tasks))
}

/// The manual list is an order and not a flag: inside a group it decides the order of the tasks in it, so a
/// list that contradicts the sort wins. Pinning in the order `b`, `a` under a sort by title is the smallest
/// case that tells the two apart.
@Test func theManualListOrdersAgainstTheSortInsideAGroup() throws {
    let store = try makeStore()
    let a = try store.createTask(NewTask(title: "a", when: today))
    let b = try store.createTask(NewTask(title: "b", when: today))
    _ = try store.createTask(NewTask(title: "c", when: today))
    let view = try store.createView(NewTaskView(title: "Days", filter: .status([.open]), sort: [SortKey(.title)], groupBy: .whenDay))
    try store.pin(task: b, in: view, at: .end)
    try store.pin(task: a, in: view, at: .end)

    let groups = try store.page(of: view, today: today).sections[0].groups
    #expect(groups.count == 1)
    #expect(groups[0].tasks.map(\.title) == ["b", "a", "c"], "the manual order, then what the sort brings")
}

/// A section is drawn by its own view: its grouping and its manual list, not the ones of the page around it.
/// A task pinned in the parent is claimed by the child and shows where the child puts it.
@Test func aSectionGroupsAndOrdersByItsOwnViewAndNotThePagesView() throws {
    let store = try makeStore()
    let project = try store.createTask(NewTask(title: "Project"))
    let early = try store.createTask(NewTask(title: "early", when: today, parent: project))
    let late = try store.createTask(NewTask(title: "late", when: today.advanced(by: 1), parent: project))
    let view = try store.createView(NewTaskView(title: "Project", filter: .parent(project), sort: [SortKey(.when)]))
    let phase = try store.createView(NewTaskView(title: "Phase 1", parent: view, sort: [SortKey(.when)], groupBy: .whenDay))
    try store.update(view: phase, [.filter(.listedIn(phase))])
    try store.pin(task: early, in: phase, at: .end)
    try store.pin(task: late, in: phase, at: .start)
    // The page's own view groups by nothing and pins the other way round, so a section that read the page's
    // view instead of its own would draw one group in the opposite order.
    try store.pin(task: early, in: view, at: .start)

    let section = try #require(try store.page(of: view, today: today).sections.first { $0.view?.id == phase })
    #expect(section.groups.map(\.key) == [.day(today), .day(today.advanced(by: 1))], "the child's grouping")
    #expect(section.groups.flatMap(\.tasks).map(\.title) == ["early", "late"], "the child's manual list")
}

/// A pin is a position in a list, not a claim on a view: a task the filter does not select stays out, and a
/// task in the list that has been trashed or deleted leaves it on the way out, so neither shifts the rest.
@Test func aPinnedTaskTheViewDoesNotSelectChangesNothing() throws {
    let store = try makeStore()
    let ids = try seeded(store)
    let view = try store.createView(NewTaskView(title: "Open", filter: .status([.open]), sort: [SortKey(.title)]))
    let before = try store.tasks(in: view, today: today).map(\.title)
    try store.pin(task: ids["done"]!, in: view, at: .start)
    try store.pin(task: ids["binned"]!, in: view, at: .start)
    #expect(try store.tasks(in: view, today: today).map(\.title) == before)

    try store.pin(task: ids["later"]!, in: view, at: .start)
    try store.trash(task: ids["later"]!)
    #expect(try store.tasks(in: view, today: today).map(\.title) == before.filter { $0 != "later" }, "a pinned task that leaves the view leaves its list")
}

/// The guard the spec promises under "Cost": a built-in view that degrades into a full scan of a table with
/// one row per task fails here instead of surprising a person with a large list.
///
/// `SCAN` of `tasks` or of `task_tree` is what it refuses; a `SCAN` of a small temporary would not be the
/// same thing, so the assertion names the two tables that grow with the list. Both statements a view read
/// runs are explained — its own, and the read of its manual list, which every grouped page runs once per
/// section — and both come from the function the store calls rather than from a copy of the SQL.
@Test func builtInViewsUseIndexes() throws {
    let store = try makeStore()
    _ = try seeded(store)
    for id in [BuiltInTaskViews.inbox, BuiltInTaskViews.today, BuiltInTaskViews.upcoming, BuiltInTaskViews.logbook, BuiltInTaskViews.trash] {
        let view = try #require(try store.view(id))
        let filter = try #require(view.filter)
        let statement = Store.viewStatement(rules: [filter], sort: view.sort, today: today)
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

        // The manual list is a read of its own, so it needs its own guard: it is driven by the view it
        // belongs to, and reading every pin of every view to answer for one of them is the failure here.
        let manual = try store.sql { () throws(SQLiteError) in
            try store.db.rows("EXPLAIN QUERY PLAN " + Store.manualListQuery, [.text(view.id.rawValue), .text("")]).map { $0[3].string ?? "" }
        }
        #expect(try #require(manual.first).hasPrefix("SEARCH v USING PRIMARY KEY (view_id=?)"), "the manual list of \(view.title) is read by \(manual)")
        #expect(!manual.contains { $0.hasPrefix("SCAN t ") || $0 == "SCAN t" }, "the manual list of \(view.title) walks the tasks table: \(manual)")
    }
}

/// A child view a newer app wrote costs its own section and nothing else. Blanking the whole page over it
/// would hide every sibling the newer app never touched, and a folder holds lists that have nothing to do
/// with each other. The view the page *is* stays an error, and so does its done read: there is no page to draw
/// without it, and a strip read past the rule it cannot read would read the view as a folder.
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
    caught = nil
    do { _ = try store.doneTasks(in: bad, since: 0, today: today) } catch { caught = error }
    #expect(caught == .viewNeedsNewerApp(bad, kind: "reminder_soon"), "and so is its done read, which would read it as a folder")
    try store.update(task: kept, [.status(.done)])
    let strip = try store.doneTasks(in: folder, since: 0, today: today).map(\.id)
    #expect(strip == [kept], "while its parent's strip still reads the sibling it can read")
}

/// The product's order of a page (ADR-0004, amendment of 2026-11-01): the view's own tasks first, then one section
/// per list inside it in the sidebar's order. What a list inside claims is not among the own.
@Test func theOwnSectionComesFirstAndTheListsInsideFollow() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let home = try store.createTag(title: "home")
    let loose = try store.createTask(NewTask(title: "loose"))
    let office = try store.createTask(NewTask(title: "office", tags: [work]))
    let kitchen = try store.createTask(NewTask(title: "kitchen", tags: [home]))
    let all = try store.createView(NewTaskView(title: "All", filter: .status([.open])))
    let workList = try store.createView(NewTaskView(title: "Work", parent: all, filter: .hasTag(work)))
    let homeList = try store.createView(NewTaskView(title: "Home", parent: all, filter: .hasTag(home)))

    let page = try store.page(of: all, today: today)
    #expect(page.sections.map { $0.view?.id } == [nil, workList, homeList])
    #expect(sectionTasks(page) == [[loose], [office], [kitchen]])
}

/// A list with a rule has its own section whether its rule selects anything or not, so that the block a task is
/// added into is there to add into (spec section 2); with a list inside it, the empty own section still comes first.
@Test func aListWithARuleAndNothingInItHasAnEmptyOwnSection() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let office = try store.createTask(NewTask(title: "office", tags: [work]))
    let list = try store.createView(NewTaskView(title: "Due today", filter: .when(.on(0))))
    #expect(try store.page(of: list, today: today).sections == [TaskViewPage.Section(view: nil, groups: [])])

    let inside = try store.createView(NewTaskView(title: "Work", parent: list, filter: .hasTag(work)))
    let page = try store.page(of: list, today: today)
    #expect(page.sections.map { $0.view?.id } == [nil, inside])
    #expect(sectionTasks(page) == [[], [office]], "the own section is there and empty")
}

/// A folder has no rule and so no tasks of its own: its page is the sections of the lists inside it and nothing
/// else, and an empty folder's page has no section at all.
@Test func aFolderHasNoOwnSection() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "open"))
    let folder = try store.createView(NewTaskView(title: "Folder"))
    #expect(try store.page(of: folder, today: today).sections.isEmpty, "an empty folder draws nothing")

    let inside = try store.createView(NewTaskView(title: "Open", parent: folder, filter: .status([.open])))
    let page = try store.page(of: folder, today: today)
    #expect(page.sections.map { $0.view?.id } == [inside])
    #expect(sectionTasks(page) == [[open]])
}

/// A folder inside a list holds what the lists under it select, to any depth, each task once however many of them
/// select it, as its count counts them (spec section 2), in the folder's own sort, which for a folder is the rank;
/// and what it holds is claimed and leaves the list's own section.
@Test func aFolderInsideReadsTheUnionOfItsListsOnce() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let home = try store.createTag(title: "home")
    let shared = try store.createTask(NewTask(title: "shared", tags: [work, home]))
    let office = try store.createTask(NewTask(title: "office", tags: [work]))
    let kitchen = try store.createTask(NewTask(title: "kitchen", tags: [home]))
    let loose = try store.createTask(NewTask(title: "loose"))
    let all = try store.createView(NewTaskView(title: "All", filter: .status([.open])))
    let folder = try store.createView(NewTaskView(title: "Folder", parent: all))
    try store.createView(NewTaskView(title: "Work", parent: folder, filter: .hasTag(work)))
    let deeper = try store.createView(NewTaskView(title: "Deeper", parent: folder))
    try store.createView(NewTaskView(title: "Home", parent: deeper, filter: .hasTag(home)))

    let page = try store.page(of: all, today: today)
    #expect(page.sections.map { $0.view?.id } == [nil, folder])
    #expect(sectionTasks(page) == [[loose], [shared, office, kitchen]], "the shared task once, in rank order, and not among the own")
}

/// A folder with nothing under it to select, an empty folder inside it included, is still a section of its parent's
/// page, empty, as an empty list inside is, so that it has a block on the screen.
@Test func aFolderInsideWithNothingToCountIsAnEmptySection() throws {
    let store = try makeStore()
    let loose = try store.createTask(NewTask(title: "loose"))
    let all = try store.createView(NewTaskView(title: "All", filter: .status([.open])))
    let folder = try store.createView(NewTaskView(title: "Folder", parent: all))
    try store.createView(NewTaskView(title: "Empty", parent: folder))

    let page = try store.page(of: all, today: today)
    #expect(page.sections.map { $0.view?.id } == [nil, folder])
    #expect(page.sections.map(\.groups.isEmpty) == [false, true])
    #expect(sectionTasks(page) == [[loose], []])
}

/// A folder inside holds the union of its lists' own reads, and each read keeps its own Trash: a list whose rule
/// names the Trash reads it, and a list whose rule does not still leaves its trashed tasks out, so a trashed task
/// only the second list's rule selects is in neither read and not in the union. The built-in Trash cannot show it,
/// since its rule takes every trashed task and the union holds the other list's trashed ones as the Trash's; a list
/// that names the Trash and asks for more, here the binned tasks tagged home, does.
@Test func aFolderInsideTakesTheTrashOnlyFromTheListThatNamesIt() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let home = try store.createTag(title: "home")
    let office = try store.createTask(NewTask(title: "office", tags: [work]))
    let binnedOffice = try store.createTask(NewTask(title: "binned office", tags: [work]))
    try store.trash(task: binnedOffice)
    let binnedKitchen = try store.createTask(NewTask(title: "binned kitchen", tags: [home]))
    try store.trash(task: binnedKitchen)
    let top = try store.createView(NewTaskView(title: "Top"))
    let folder = try store.createView(NewTaskView(title: "Folder", parent: top))
    try store.createView(NewTaskView(title: "Work", parent: folder, filter: .hasTag(work)))
    try store.createView(NewTaskView(title: "Binned at home", parent: folder, filter: .and([.trashed(true), .hasTag(home)])))

    let page = try store.page(of: top, today: today)
    #expect(page.sections.map { $0.view?.id } == [folder])
    #expect(sectionTasks(page) == [[office, binnedKitchen]], "the binned office task is in neither list's read")
}

/// A child of a kind other than `list` is no section of its parent's page and claims none of its tasks: a group's view
/// is a screen of its own over the list and not a block on it (ADR-0004, amendment of 2026-11-01), though it is still
/// one of the list's children, and the done read, which reads the page's sections, skips it alike.
@Test func aChildOfAKindOtherThanListIsNotASection() throws {
    let store = try makeStore()
    let loose = try store.createTask(NewTask(title: "loose"))
    let all = try store.createView(NewTaskView(title: "All", filter: .status([.open])))
    let group = try store.groupView(of: all, condition: .when(.empty), titled: "No date")

    let page = try store.page(of: all, today: today)
    #expect(page.sections.map { $0.view?.id } == [nil])
    #expect(sectionTasks(page) == [[loose]], "the group claimed nothing")
    #expect(try store.children(ofView: all).map(\.id) == [group])
}
