import Testing
import TestSupport
@testable import TodoCore
@testable import SQLiteKit

private let today = Day(year: 2026, month: 10, day: 26)

/// A view made the way another device's operations arrive, for the views this app could not have written: one
/// whose definition only a newer app reads.
private func applyView(_ store: Store, _ id: String, parent: ViewID?, filter: String) throws {
    let stamp = store.clock.next()
    try store.apply([
        store.op(.view, id, "title", .text(id), stamp),
        store.op(.view, id, "parent", Value(parent?.rawValue), stamp),
        store.op(.view, id, "rank", .text("z"), stamp),
        store.op(.view, id, "filter", .text(filter), stamp),
    ])
}

/// A list counts the tasks its rule selects that are open, by the count's own condition and not by the rule's:
/// the Inbox's rule asks for open tasks itself, and a list whose rule does not ask still counts only the open
/// ones (spec section 4). The whole answer is compared, so a view that counts nothing is seen to be present as
/// 0, and a count that went missing fails here as surely as a wrong one.
@Test func aListCountsTheOpenTasksItsRuleSelects() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "a"))
    try store.createTask(NewTask(title: "b"))
    let done = try store.createTask(NewTask(title: "done"))
    try store.update(task: done, [.status(.done)])
    let undated = try store.createView(NewTaskView(title: "Undated", filter: .when(.empty)))
    #expect(try store.tasks(in: undated, today: today).count == 3, "the rule itself selects the done task too")
    #expect(try store.taskCounts(today: today) == [
        BuiltInTaskViews.inbox: 2, BuiltInTaskViews.today: 0, BuiltInTaskViews.upcoming: 0,
        BuiltInTaskViews.logbook: 0, BuiltInTaskViews.trash: 0, undated: 2,
    ])
}

/// Nothing in the Logbook or the Trash is open, so by the one rule both count nothing, though both select
/// tasks. The Trash is the case the count's own `tt.trashed = 0` is for: its rule names the trash, which is
/// what stops a view's read adding the exclusion, and a count built on that read would count the binned task.
@Test func logbookAndTrashCountNothing() throws {
    let store = try makeStore()
    let done = try store.createTask(NewTask(title: "done"))
    try store.update(task: done, [.status(.done)])
    let canceled = try store.createTask(NewTask(title: "canceled"))
    try store.update(task: canceled, [.status(.canceled)])
    let binned = try store.createTask(NewTask(title: "binned"))
    try store.trash(task: binned)
    #expect(try store.tasks(in: BuiltInTaskViews.logbook, today: today).count == 2)
    #expect(try store.tasks(in: BuiltInTaskViews.trash, today: today).map(\.id) == [binned])

    let counts = try store.taskCounts(today: today)
    #expect(counts[BuiltInTaskViews.logbook] == 0)
    #expect(counts[BuiltInTaskViews.trash] == 0, "the binned task is open, and still not counted")
    #expect(counts[BuiltInTaskViews.inbox] == 0, "nor counted by the Inbox, whose rule it otherwise matches")
}

/// A folder counts each task once however many of its lists select it, since a person reads its number as how
/// many tasks are in it and not as the sum of the numbers under it (spec section 4).
@Test func aFolderCountsTheUnionOfItsChildrenOnce() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    try store.createTask(NewTask(title: "both", when: today, tags: [work]))
    try store.createTask(NewTask(title: "tagged", tags: [work]))
    try store.createTask(NewTask(title: "due", when: today))
    let folder = try store.createView(NewTaskView(title: "Folder"))
    let tagged = try store.createView(NewTaskView(title: "Work", parent: folder, filter: .hasTag(work)))
    let due = try store.createView(NewTaskView(title: "Due", parent: folder, filter: .when(.on(0))))

    let counts = try store.taskCounts(today: today)
    #expect(counts[tagged] == 2 && counts[due] == 2)
    #expect(counts[folder] == 3, "the task both lists select is counted once")
}

/// A folder inside a folder is folded into the one above it as a list is, so the outer folder counts what
/// its grandchildren select, each task once.
@Test func aFolderOfFoldersCountsItsGrandchildren() throws {
    let store = try makeStore()
    let a = try store.createTag(title: "a")
    let b = try store.createTag(title: "b")
    try store.createTask(NewTask(title: "a", tags: [a]))
    try store.createTask(NewTask(title: "b", tags: [b]))
    try store.createTask(NewTask(title: "ab", tags: [a, b]))
    try store.createTask(NewTask(title: "neither"))
    let outer = try store.createView(NewTaskView(title: "Outer"))
    let inner = try store.createView(NewTaskView(title: "Inner", parent: outer))
    let deep = try store.createView(NewTaskView(title: "Deep", parent: inner, filter: .hasTag(a)))
    let near = try store.createView(NewTaskView(title: "Near", parent: outer, filter: .hasTag(b)))

    let counts = try store.taskCounts(today: today)
    #expect(counts[deep] == 2 && counts[inner] == 2 && counts[near] == 2)
    #expect(counts[outer] == 3, "the grandchild's tasks and the child's, the one they share once")
}

/// A view this app cannot read counts nothing and shows nothing, and the folder above it counts its other
/// lists as though it were not there (spec section 4). It is no folder either, though its rule reads as none:
/// the list under it keeps its own count and lends it to nothing above, and a folder whose only list is the
/// unreadable one has nothing to count.
@Test func aViewTheAppCannotReadCountsNothingAndContributesNothing() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    try store.createTask(NewTask(title: "loose"))
    try store.createTask(NewTask(title: "tagged", tags: [work]))
    let folder = try store.createView(NewTaskView(title: "Folder"))
    let good = try store.createView(NewTaskView(title: "Good", parent: folder, filter: .and([.when(.empty), .not(.hasTag(work))])))
    try applyView(store, "v-bad", parent: folder, filter: "{\"kind\":\"reminder_soon\"}")
    let bad = ViewID("v-bad")
    let under = try store.createView(NewTaskView(title: "Under", parent: bad, filter: .hasTag(work)))
    let lonely = try store.createView(NewTaskView(title: "Lonely"))
    try applyView(store, "v-alone", parent: lonely, filter: "{\"kind\":\"reminder_soon\"}")
    #expect(try store.view(bad)?.needsNewerApp == "reminder_soon")

    let counts = try store.taskCounts(today: today)
    #expect(counts[bad] == nil && counts[ViewID("v-alone")] == nil)
    #expect(counts[good] == 1 && counts[under] == 1)
    #expect(counts[folder] == 1, "the unreadable list and what is under it add nothing")
    #expect(counts[lonely] == nil)
}

/// An area selects nothing and draws no number, and the lists under its line count as they would anywhere
/// (ADR-0004, amendment of 2026-10-25): an area is not a folder of its lists.
@Test func anAreaHasNoCountAndItsListsHaveTheirs() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "loose"))
    let area = try store.createView(NewTaskView(title: "Work", kind: .area))
    let list = try store.createView(NewTaskView(title: "Open", parent: area, filter: .status([.open])))

    let counts = try store.taskCounts(today: today)
    #expect(counts[area] == nil)
    #expect(counts[list] == 1)
}

/// A folder with nothing to count has no number, which is not a count of zero: a folder holding only an empty
/// folder has none either, and a folder whose lists select no open task counts 0 like any list that does.
@Test func anEmptyFolderHasNoCount() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "loose"))
    let empty = try store.createView(NewTaskView(title: "Empty"))
    let holder = try store.createView(NewTaskView(title: "Holder"))
    let inner = try store.createView(NewTaskView(title: "Inner", parent: holder))
    let quiet = try store.createView(NewTaskView(title: "Quiet"))
    let finished = try store.createView(NewTaskView(title: "Finished", parent: quiet, filter: .status([.done])))

    let counts = try store.taskCounts(today: today)
    #expect(counts[empty] == nil && counts[holder] == nil && counts[inner] == nil)
    #expect(counts[finished] == 0 && counts[quiet] == 0, "a folder's zero is a count")
    #expect(counts[BuiltInTaskViews.inbox] == 1, "the store counts all the same")
}

/// A list with a rule counts what its rule selects, and the lists under it, which its page draws as sections
/// of their own, add nothing to its number: only a list with no rule counts the union of its children.
@Test func aListWithARuleCountsItsOwnRuleAndNotItsLists() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    try store.createTask(NewTask(title: "both", when: today, tags: [work]))
    try store.createTask(NewTask(title: "tagged", tags: [work]))
    try store.createTask(NewTask(title: "due", when: today))
    let due = try store.createView(NewTaskView(title: "Due", filter: .when(.on(0))))
    let tagged = try store.createView(NewTaskView(title: "Work", parent: due, filter: .hasTag(work)))

    let counts = try store.taskCounts(today: today)
    #expect(counts[tagged] == 2)
    #expect(counts[due] == 2, "the tagged task only its list selects is not the parent's")
}

/// The guard `builtInViewsUseIndexes` keeps over a view's read, kept over its count: the count of a built-in
/// that degrades into a full scan of a table with one row per task fails here, and so does one driven from
/// the wrong side of the join. The statement explained is the one `taskCounts` runs, out of the function it
/// assembles it with, over the condition it compiles.
@Test func theCountStatementUsesTheIndexes() throws {
    let store = try makeStore()
    for id in [BuiltInTaskViews.inbox, BuiltInTaskViews.today, BuiltInTaskViews.upcoming, BuiltInTaskViews.logbook, BuiltInTaskViews.trash] {
        let view = try #require(try store.view(id))
        let fragment = FilterCompiler.compile(try #require(view.filter), today: today)
        let plan = try store.sql { () throws(SQLiteError) in
            try store.db.rows("EXPLAIN QUERY PLAN " + Store.countStatement(where: fragment.sql), fragment.params).map { $0[3].string ?? "" }
        }
        #expect(plan.contains { $0.contains(" t ") || $0.hasSuffix(" t") }, "\(view.title) has no plan row for the tasks table: \(plan)")
        let scans = plan.filter { $0.hasPrefix("SCAN t ") || $0 == "SCAN t" || $0.hasPrefix("SCAN tt ") || $0 == "SCAN tt" }
        #expect(scans.isEmpty, "\(view.title) counts by scanning a table that grows with the list: \(plan)")
        // Every count but the Trash's is driven by the count's own `t.status = 0` over the status index, which
        // drives the four reads too: a count reads the open tasks and never the done ones, the part of a store
        // that grows without end. The Trash's is driven by its own condition, over the partial index its literal
        // `1` implies, as its read is. The rules of the Logbook and the Trash each ask for what the count's own
        // conditions exclude, a status that is not open and the trash, and SQLite compares the two constants
        // before the loop, so neither count reads a row (`EXPLAIN`, SQLite 3.53.4).
        let driver = try #require(plan.first)
        if view.id == BuiltInTaskViews.trash {
            #expect(driver.contains("task_tree_trashed"), "the Trash's count is driven by \(driver)")
        } else {
            #expect(driver == "SEARCH t USING INDEX tasks_status (status=?)", "\(view.title)'s count is driven by \(driver)")
        }
    }
}
