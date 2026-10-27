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

/// The statements `taskCounts` runs, by view, out of the function that assembles them for it: a guard that
/// explained a copy would pass while the count itself degraded.
private func countStatements(of store: Store) throws -> [ViewID: (sql: String, params: [Value])] {
    var statements: [ViewID: (sql: String, params: [Value])] = [:]
    for count in try store.countStatements(today: today) { statements[count.view] = (count.sql, count.params) }
    return statements
}

/// The rows of a statement's query plan, outer loop first.
private func plan(_ store: Store, _ statement: (sql: String, params: [Value])) throws -> [String] {
    try store.sql { () throws(SQLiteError) in
        try store.db.rows("EXPLAIN QUERY PLAN " + statement.sql, statement.params).map { $0[3].string ?? "" }
    }
}

/// The guard `builtInViewsUseIndexes` keeps over a view's read, kept over its count: the count of a built-in
/// that degrades into a full scan of a table with one row per task fails here, and so does one driven from
/// the wrong side of the join. The statement explained is the one `taskCounts` runs, out of the function it
/// assembles it with.
@Test func theCountStatementUsesTheIndexes() throws {
    let store = try makeStore()
    let statements = try countStatements(of: store)
    for id in [BuiltInTaskViews.inbox, BuiltInTaskViews.today, BuiltInTaskViews.upcoming, BuiltInTaskViews.logbook, BuiltInTaskViews.trash] {
        let view = try #require(try store.view(id))
        let statement = try #require(statements[id])
        // No built-in's rule has a condition of its own that drives a count (#153): an empty day, the root, a day
        // range open at one end, a status and the trash each select too much of a store to be worth an index. So
        // each is the statement #144 wrote, byte for byte: the rule compiled bare under the count's own conditions,
        // with the count's own status condition on its index.
        let fragment = FilterCompiler.compile(try #require(view.filter), today: today)
        #expect(statement.sql == "SELECT count(*) FROM tasks t JOIN task_tree tt ON tt.id = t.id WHERE t.deleted = 0 AND t.status = 0 AND tt.trashed = 0 AND (\(fragment.sql))")
        #expect(statement.params == fragment.params)
        let plan = try plan(store, statement)
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

/// The guard of #153 beside the built-ins': a count is driven by its rule's own index where the rule has one, and
/// only then is the count's own `t.status = 0` kept off the status index, so that the planner has one index to
/// take and the choice never rests on a tie in SQLite's estimates, which are its defaults because the store never
/// runs `ANALYZE`. A project list is driven by the tree's parent index; a tag list and a manual list by the list of
/// the tasks the tag or the pins hold, which SQLite looks the tasks up from by id; a short day range by its day's
/// index; a folder of a project and a tag by both, one `OR` branch each. A tag that holds too many tasks to beat
/// the walk of the open ones, a range a month wide and a rule that asks for a status other than open are not
/// driven by their own index, and the status index drives them as it drove every count before.
@Test func aCountIsDrivenByItsRulesOwnIndex() throws {
    let store = try makeStore()
    let small = try store.createTag(title: "small")
    let big = try store.createTag(title: "big")
    let project = try store.createTask(NewTask(title: "project"))
    for i in 0..<10 {
        try store.createTask(NewTask(title: "task \(i)", parent: i == 0 ? project : nil, tags: i < 5 ? [big] : i == 5 ? [small] : []))
    }
    let projectList = try store.createView(NewTaskView(title: "Project", filter: .parent(project)))
    let tagged = try store.createView(NewTaskView(title: "Small", filter: .hasTag(small)))
    let manual = try store.createView(NewTaskView(title: "Manual"))
    try store.update(view: manual, [.filter(.listedIn(manual))])
    let day = try store.createView(NewTaskView(title: "Today's", filter: .when(.on(0))))
    let week = try store.createView(NewTaskView(title: "Week", filter: .deadline(.between(0, 7))))
    let folder = try store.createView(NewTaskView(title: "Folder"))
    let one = try store.createView(NewTaskView(title: "One", parent: folder, filter: .parent(project)))
    let two = try store.createView(NewTaskView(title: "Two", parent: folder, filter: .hasTag(small)))
    // A rule with two conditions an index serves is driven by the better one, and the other is kept off its index:
    // left on it, the parent's equality is estimated below the pins' list, and the planner would take it.
    let pinnedInProject = try store.createView(NewTaskView(title: "Pinned in the project", filter: .and([.parent(project), .listedIn(manual)])))
    let crowded = try store.createView(NewTaskView(title: "Big", filter: .hasTag(big)))
    let undatedBig = Filter.and([.hasTag(big), .when(.empty)])
    let crowdedUndated = try store.createView(NewTaskView(title: "Big and undated", filter: undatedBig))
    let dueBig = Filter.and([.hasTag(big), .not(.deadline(.empty))])
    let crowdedDue = try store.createView(NewTaskView(title: "Big with a deadline", filter: dueBig))
    let month = try store.createView(NewTaskView(title: "Month", filter: .when(.between(0, 31))))
    let finished = try store.createView(NewTaskView(title: "Finished", filter: .and([.status([.done]), .hasTag(small)])))

    let statements = try countStatements(of: store)
    var plans: [ViewID: [String]] = [:]
    var quiet: Set<ViewID> = []
    for (id, statement) in statements {
        plans[id] = try plan(store, statement)
        if statement.sql.contains("+t.status = 0") { quiet.insert(id) }
    }
    let projectPlan = plans[projectList] ?? [], tagPlan = plans[tagged] ?? [], manualPlan = plans[manual] ?? []
    let dayPlan = plans[day] ?? [], weekPlan = plans[week] ?? [], folderPlan = plans[folder] ?? []
    let pinnedInProjectPlan = plans[pinnedInProject] ?? []

    #expect(projectPlan.first == "SEARCH tt USING INDEX task_tree_parent (parent=?)", "\(projectPlan)")
    #expect(tagPlan.prefix(4) == [
        "SEARCH tt USING PRIMARY KEY (id=?)", "LIST SUBQUERY 1",
        "SEARCH g USING INDEX sqlite_autoindex_tags_1 (id=?)", "SEARCH x USING COVERING INDEX task_tags_tag (tag_id=?)",
    ], "\(tagPlan)")
    #expect(manualPlan.prefix(3) == ["SEARCH tt USING PRIMARY KEY (id=?)", "LIST SUBQUERY 1", "SEARCH v USING PRIMARY KEY (view_id=?)"], "\(manualPlan)")
    #expect(pinnedInProjectPlan.prefix(3) == ["SEARCH tt USING PRIMARY KEY (id=?)", "LIST SUBQUERY 1", "SEARCH v USING PRIMARY KEY (view_id=?)"], "\(pinnedInProjectPlan)")
    #expect(dayPlan.first == "SEARCH t USING INDEX tasks_when (when_day=?)", "\(dayPlan)")
    #expect(weekPlan.first == "SEARCH t USING INDEX tasks_deadline (deadline_day>? AND deadline_day<?)", "\(weekPlan)")
    #expect(folderPlan.first == "MULTI-INDEX OR", "\(folderPlan)")
    #expect(folderPlan.contains("SEARCH p USING COVERING INDEX task_tree_parent (parent=?)"), "\(folderPlan)")
    #expect(folderPlan.contains("SEARCH x USING COVERING INDEX task_tags_tag (tag_id=?)"), "\(folderPlan)")
    #expect(quiet == [projectList, tagged, manual, day, week, folder, one, two, pinnedInProject], "the count's own status condition stays off its index exactly where the rule drives")

    // Not driven: the walk of the open tasks over the status index, as #144 counted everything. The big tag is
    // written as the list of its tasks all the same, which SQLite builds once instead of probing once per task.
    for id in [crowded, crowdedUndated, crowdedDue, month, finished] {
        let plan = plans[id] ?? []
        #expect(plan.first == "SEARCH t USING INDEX tasks_status (status=?)", "\(plan)")
    }
    let crowdedPlan = plans[crowded] ?? []
    #expect(crowdedPlan.contains("SEARCH x USING COVERING INDEX task_tags_tag (tag_id=?)"), "\(crowdedPlan)")
    // Beside an empty day, or beside having a deadline, both of which SQLite tests first, the big tag stays the
    // correlated `EXISTS` of #144, which runs on the tasks left alone: the rule is written as #144 wrote it, byte for
    // byte.
    for (id, rule) in [(crowdedUndated, undatedBig), (crowdedDue, dueBig)] {
        let fragment = FilterCompiler.compile(rule, today: today)
        #expect(statements[id]?.sql == "SELECT count(*) FROM tasks t JOIN task_tree tt ON tt.id = t.id WHERE t.deleted = 0 AND t.status = 0 AND tt.trashed = 0 AND (\(fragment.sql))")
    }
    // The rule of `finished` asks for a status the count's own condition excludes: kept on the status index, the
    // count's condition is a constant SQLite compares with the rule's before the loop, so the count reads no row,
    // as the Logbook's does.
    #expect(statements[finished]?.sql.contains("t.deleted = 0 AND t.status = 0 AND") == true)
}

/// The sizes the choice of a tag's driver asks for cost no table row: the open tasks are counted on the status index
/// and a tag's tasks on the tag's partial index, by the statements `taskCounts` runs for them.
@Test func theSizesOfTheTagsAreReadFromTheIndexesAlone() throws {
    let store = try makeStore()
    #expect(try plan(store, (Store.openTaskCountQuery, [])) == ["SEARCH tasks USING COVERING INDEX tasks_status (status=?)"])
    #expect(try plan(store, (Store.tagSizeQuery, [.text("tag")])) == ["SEARCH task_tags USING COVERING INDEX task_tags_tag (tag_id=?)"])
}

/// A tag drives a count only while it holds fewer than two fifths as many tasks as the status index holds open
/// ones (#153). Its driver walks every task the tag holds, done ones too, and the walk of the open tasks it would
/// replace reads the tag's list once and each open task once, which is cheaper from about that size on.
@Test func aTagDrivesWhileItHoldsFewerThanTwoFifthsOfTheOpenTasks() throws {
    let store = try makeStore()
    let tag = try store.createTag(title: "tag")
    for i in 0..<10 { try store.createTask(NewTask(title: "open \(i)", tags: i < 2 ? [tag] : [])) }
    let done = try store.createTask(NewTask(title: "done", tags: [tag]))
    try store.update(task: done, [.status(.done)])
    let list = try store.createView(NewTaskView(title: "Tagged", filter: .hasTag(tag)))
    #expect(try countStatements(of: store)[list]?.sql.contains("+t.status = 0") == true, "three tasks against ten open ones drive")

    let another = try store.createTask(NewTask(title: "done too", tags: [tag]))
    try store.update(task: another, [.status(.done)])
    #expect(try countStatements(of: store)[list]?.sql.contains("+t.status = 0") == false, "four, the done ones among them, do not")
    #expect(try store.taskCounts(today: today)[list] == 2)
}

/// Beside a day #144 tests first, a tag drives a count only while it holds fewer than three hundredths of the open
/// tasks (#153): #144 then rejects most open tasks before it probes the tag, and its count costs little more than
/// the walk of the open tasks. A range open at one end, a wide range, a day that is not empty and a choice of such days
/// lower the share; an empty day does not, and the same tag on its own still drives.
@Test func aTagBesideADayDrivesWhileItHoldsFewerThanThreeHundredthsOfTheOpenTasks() throws {
    let store = try makeStore()
    let tag = try store.createTag(title: "tag")
    for i in 0..<100 { try store.createTask(NewTask(title: "open \(i)", deadline: i < 50 ? today : nil, tags: i < 2 ? [tag] : [])) }
    let rules: [Filter] = [
        .and([.hasTag(tag), .deadline(.onOrBefore(30))]), .and([.hasTag(tag), .when(.between(-100, 100))]),
        .and([.hasTag(tag), .not(.deadline(.empty))]), .and([.hasTag(tag), .or([.deadline(.onOrBefore(30)), .when(.onOrAfter(1))])]),
    ]
    let besideDays = try rules.map { try store.createView(NewTaskView(title: "Beside a day", filter: $0)) }
    let undated = try store.createView(NewTaskView(title: "Undated", filter: .and([.hasTag(tag), .when(.empty)])))
    let alone = try store.createView(NewTaskView(title: "Alone", filter: .hasTag(tag)))
    #expect(try drivenViews(store).isSuperset(of: besideDays + [undated, alone]), "two tasks against a hundred open ones drive")

    let third = try store.createTask(NewTask(title: "tagged too", deadline: today, tags: [tag]))
    try store.update(task: third, [.status(.done)])
    let driven = try drivenViews(store)
    #expect(driven.isDisjoint(with: besideDays), "three, the done one among them, do not beside a day")
    #expect(driven.isSuperset(of: [undated, alone]), "and still do beside an empty day or alone")
    #expect(try store.taskCounts(today: today) == (try countsByReads(store)))
}

/// A disjunction of tags drives a count only while the tasks of the tags that drive its branches add up to fewer than
/// half of the open ones (#153), since its driver walks them all; each tag below its own share is not enough. A
/// folder of tag lists is judged the same way, as the disjunction of its lists.
@Test func aDisjunctionOfTagsDrivesWhileTheirTasksAddUpToFewerThanHalfOfTheOpenTasks() throws {
    let store = try makeStore()
    let first = try store.createTag(title: "first")
    let second = try store.createTag(title: "second")
    for i in 0..<10 { try store.createTask(NewTask(title: "open \(i)", tags: i < 2 ? [first] : i < 4 ? [second] : [])) }
    let either = try store.createView(NewTaskView(title: "Either", filter: .or([.hasTag(first), .hasTag(second)])))
    let folder = try store.createView(NewTaskView(title: "Folder"))
    let lists = [
        try store.createView(NewTaskView(title: "First", parent: folder, filter: .hasTag(first))),
        try store.createView(NewTaskView(title: "Second", parent: folder, filter: .hasTag(second))),
    ]
    #expect(try drivenViews(store) == Set(lists + [either, folder]), "four tasks against ten open ones drive")

    let done = try store.createTask(NewTask(title: "done", tags: [second]))
    try store.update(task: done, [.status(.done)])
    #expect(try drivenViews(store) == Set(lists), "five do not, though each tag alone still drives")
    #expect(try store.taskCounts(today: today) == (try countsByReads(store)))
}

/// A disjunction whose every branch #144 can reject by a day before it probes a tag is judged as a tag beside a day
/// is, its tags' tasks added up against three hundredths of the open ones (#153): SQLite tests the day first in a
/// branch too, whichever is written first, and by a project as surely as by a day. One branch with a tag and no
/// such condition makes #144 probe it for every open task, and the disjunction keeps its own share.
@Test func aDisjunctionADayRejectsInEveryBranchDrivesOnlyAsATagBesideADay() throws {
    let store = try makeStore()
    let first = try store.createTag(title: "first")
    let second = try store.createTag(title: "second")
    let third = try store.createTag(title: "third")
    let project = try store.createTask(NewTask(title: "project"))
    for i in 0..<99 {
        let tags: Set<TagID> = i < 1 ? [first] : i < 2 ? [second] : i < 7 ? [third] : []
        try store.createTask(NewTask(title: "open \(i)", when: i % 2 == 0 ? today.advanced(by: 1) : nil, deadline: i % 3 == 0 ? today : nil, parent: i % 5 == 0 ? project : nil, tags: tags))
    }
    let dated = Filter.or([.and([.hasTag(first), .deadline(.onOrBefore(30))]), .and([.when(.onOrAfter(1)), .hasTag(second)])])
    let datedView = try store.createView(NewTaskView(title: "Dated", filter: dated))
    let partly = try store.createView(NewTaskView(title: "Partly", filter: .or([.and([.hasTag(first), .deadline(.onOrBefore(30))]), .hasTag(second)])))
    let projected = try store.createView(NewTaskView(title: "Project or dated", filter: .or([.and([.parent(project), .hasTag(first)]), .and([.hasTag(third), .when(.onOrAfter(1))])])))
    let probed = try store.createView(NewTaskView(title: "Tag or dated", filter: .or([.hasTag(first), .and([.hasTag(third), .when(.onOrAfter(1))])])))
    let driven = try drivenViews(store)
    #expect(driven.isSuperset(of: [datedView, partly, probed]), "two tasks against a hundred open ones drive")
    #expect(!driven.contains(projected), "five, beside a day, in a disjunction a project and a day reject, do not")

    for title in ["first again", "second again"] {
        try store.createTask(NewTask(title: title, tags: [title == "first again" ? first : second]))
    }
    let after = try drivenViews(store)
    #expect(!after.contains(datedView), "four do not where a day rejects every branch")
    #expect(after.contains(partly), "and still do where one branch has no day")
    #expect(try store.taskCounts(today: today) == (try countsByReads(store)))
}

// MARK: - The counts every rewritten shape gives

/// The open tasks out of the trash that a list's read selects, the read #153 does not touch.
private func openTasks(_ store: Store, of list: ViewID) throws -> Set<TaskID> {
    Set(try store.tasks(in: list, today: today).filter { $0.status == .open && !$0.trashed }.map(\.id))
}

/// What a view counts by the rule of spec section 4, from the reads of the lists it counts, which #153 does not
/// touch: the open tasks out of the trash in the union of those reads. A list with a rule counts its rule; a folder
/// counts the lists under it, through the folders under it; an area and a view this app cannot read count nothing.
private func countsByReads(_ store: Store) throws -> [ViewID: Int] {
    let views = try store.views()
    func counted(_ view: TaskView) -> [ViewID] {
        guard view.kind == .list, view.needsNewerApp == nil else { return [] }
        if view.filter != nil { return [view.id] }
        return views.filter { $0.parent == view.id }.flatMap(counted)
    }
    var counts: [ViewID: Int] = [:]
    for view in views {
        let lists = counted(view)
        guard !lists.isEmpty else { continue }
        var open: Set<TaskID> = []
        for list in lists { open.formUnion(try openTasks(store, of: list)) }
        counts[view.id] = open.count
    }
    return counts
}

/// The views whose count is driven by a condition of their rule's own, which keeps the count's status off its index.
private func drivenViews(_ store: Store) throws -> Set<ViewID> {
    Set(try store.countStatements(today: today).filter { $0.sql.contains("+t.status = 0") }.map(\.view))
}

/// The counts whose statement scans a table that grows with the list. A count with every condition but its driver
/// off its index scans every task when SQLite cannot use the driver's form, which costs more than the walk of the
/// open tasks it replaced, so none may.
private func scanningViews(_ store: Store) throws -> Set<ViewID> {
    var scanning: Set<ViewID> = []
    for count in try store.countStatements(today: today) {
        let plan = try plan(store, (count.sql, count.params))
        if plan.contains(where: { $0 == "SCAN t" || $0.hasPrefix("SCAN t ") || $0 == "SCAN tt" || $0.hasPrefix("SCAN tt ") }) { scanning.insert(count.view) }
    }
    return scanning
}

/// The open tasks out of the trash that one list's read selects and none of `others` selects. A folder test holds
/// each of its lists to some, since a list that adds nothing to its folder's count would let a regrouping that
/// drops it pass unseen.
private func ownTasks(_ store: Store, of list: ViewID, besides others: [ViewID]) throws -> Set<TaskID> {
    var own = try openTasks(store, of: list)
    for other in others { own.subtract(try openTasks(store, of: other)) }
    return own
}

/// A store in which every condition of the shapes below has tasks on both sides of it: 300 tasks a fixed generator
/// spreads over the three statuses, days and deadlines around today or none, two projects or the root, four small
/// tags, each on about a twelfth of the tasks, so that any two drive a disjunction and four do not, a tag on most
/// tasks, the trash, and a manual list. One task is deleted.
private func shapesStore() throws -> (store: Store, small: [TagID], big: TagID, projects: [TaskID], manual: ViewID) {
    let store = try makeStore()
    let small = [try store.createTag(title: "a"), try store.createTag(title: "b"), try store.createTag(title: "c"), try store.createTag(title: "d")]
    let big = try store.createTag(title: "big")
    let projects = [try store.createTask(NewTask(title: "p0")), try store.createTask(NewTask(title: "p1"))]
    let manual = try store.createView(NewTaskView(title: "Pinned"))
    try store.update(view: manual, [.filter(.listedIn(manual))])
    var state: UInt64 = 153
    func roll(_ n: UInt64) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % n)
    }
    for i in 0..<300 {
        var tags: Set<TagID> = []
        for tag in small where roll(100) < 8 { tags.insert(tag) }
        if roll(100) < 70 { tags.insert(big) }
        let when = roll(100) < 40 ? nil : today.advanced(by: roll(9) - 4)
        let deadline = roll(100) < 50 ? nil : today.advanced(by: roll(12) - 3)
        let parent = [nil, nil, nil, projects[0], projects[1]][roll(5)]
        let task = try store.createTask(NewTask(title: "task \(i)", when: when, deadline: deadline, parent: parent, tags: tags))
        switch roll(20) {
        case 0..<7: try store.update(task: task, [.status(.done)])
        case 7..<9: try store.update(task: task, [.status(.canceled)])
        default: break
        }
        if roll(20) == 0 { try store.trash(task: task) }
        if roll(10) == 0 { try store.pin(task: task, in: manual) }
        if i == 150 { try store.delete(task: task) }
    }
    return (store, small, big, projects, manual)
}

/// Every shape of rule a count rewrites counts what its read selects that is open (#153): a manual list, a project,
/// a day, a short range and a small tag as the driver; a negation and an empty day beside a driver, which SQL's
/// unknown would drop if they were written without `COALESCE` or as an equality; the root and a status that
/// includes open beside one; a disjunction of four different drivers, with a tag no other rule names, one of two
/// tags, and one of a project and a manual list beside a deadline; a range inside a tag's rule, which the range
/// drives; the trash beside a tag; and the last two days of the calendar. And the shapes that are not driven count
/// as before: a big tag, a tag or two beside a deadline or beside having one, which #144 tests first, a disjunction
/// of four tags whose tasks add up past the share, a range a month wide and one over every day there is, a disjunction with
/// an undriven branch, a disjunction inside a branch of another, negated tags, and a status the count excludes. No
/// count scans the tasks.
@Test func aDrivenListCountsWhatItsReadSelects() throws {
    let (store, small, big, projects, manual) = try shapesStore()
    let (a, b, c, d) = (small[0], small[1], small[2], small[3])
    func list(_ title: String, _ filter: Filter) throws -> ViewID { try store.createView(NewTaskView(title: title, filter: filter)) }
    let driven: Set<ViewID> = [
        manual,
        try list("Project", .parent(projects[0])),
        try list("On the day", .when(.on(0))),
        try list("This week", .deadline(.between(0, 7))),
        try list("Small tag", .hasTag(a)),
        try list("Not today", .and([.hasTag(a), .not(.when(.on(0)))])),
        try list("No day", .and([.hasTag(b), .when(.empty)])),
        try list("At the root", .and([.hasTag(c), .parent(nil)])),
        try list("Open or done", .and([.status([.open, .done]), .hasTag(c)])),
        try list("Any of four", .or([.parent(projects[1]), .hasTag(d), .when(.on(1)), .listedIn(manual)])),
        try list("Two tags", .or([.hasTag(a), .hasTag(b)])),
        try list("Pinned or the project, due", .and([.or([.parent(projects[1]), .listedIn(manual)]), .deadline(.onOrBefore(3))])),
        try list("Range first", .and([.hasTag(a), .when(.between(-1, 2))])),
        try list("Binned", .and([.hasTag(a), .trashed(true)])),
        try list("The last two days", .deadline(.between(.max - 1, .max))),
    ]
    let undriven: [(String, Filter)] = [
        ("Big tag", .hasTag(big)),
        ("Month", .when(.between(-3, 40))),
        ("Every day there is", .when(.between(.min, .max))),
        ("Tag, due soon", .and([.hasTag(a), .deadline(.onOrBefore(3))])),
        ("Tag with a deadline", .and([.hasTag(a), .not(.deadline(.empty))])),
        ("Four tags", .or([.hasTag(a), .hasTag(b), .hasTag(c), .hasTag(d)])),
        ("Two tags, due soon", .and([.or([.hasTag(a), .hasTag(b)]), .deadline(.onOrBefore(3))])),
        ("Tag or due", .or([.hasTag(a), .deadline(.onOrBefore(0))])),
        ("Nested", .or([.and([.or([.hasTag(a), .hasTag(b)]), .when(.empty)]), .parent(projects[0])])),
        ("Untagged", .and([.not(.hasTag(a)), .not(.hasTag(b))])),
        ("Closed", .and([.status([.done]), .hasTag(a)])),
    ]
    for (title, rule) in undriven { _ = try list(title, rule) }

    #expect(try store.taskCounts(today: today) == (try countsByReads(store)))
    #expect(try drivenViews(store) == driven, "the shapes above are the ones driven, and no other")
    #expect(try scanningViews(store).isEmpty)
}

/// A folder counts the union of its lists once however its count is regrouped (#153): conditions every list shares
/// are taken out in front, a list that asks for no more than the conditions another one shares with it absorbs
/// that one, and lists driven by the same condition are grouped under it, all of which hold in SQL's logic of
/// three values; a folder of folders counts its lists through them; a folder with an undriven list, with a big
/// tag's, with four tags' whose tasks add up past the share, or with a disjunction inside a list's conjunction,
/// which its own disjunction would nest, counts as before.
/// Every list but the absorbed ones selects open tasks no other list of its folder selects, so that no regrouping
/// can lose one unseen, and no count scans the tasks.
@Test func aFolderCountsTheUnionOfItsListsHoweverItIsRegrouped() throws {
    let (store, small, big, projects, _) = try shapesStore()
    let (a, b, c, d) = (small[0], small[1], small[2], small[3])
    func folder(_ title: String, in parent: ViewID? = nil, _ rules: [Filter]) throws -> (folder: ViewID, lists: [ViewID]) {
        let folder = try store.createView(NewTaskView(title: title, parent: parent))
        var lists: [ViewID] = []
        for (i, rule) in rules.enumerated() { lists.append(try store.createView(NewTaskView(title: "\(title) \(i)", parent: folder, filter: rule))) }
        return (folder, lists)
    }
    let factored = try folder("Factored", [.and([.when(.empty), .hasTag(a)]), .and([.when(.empty), .hasTag(b)])])
    let absorbed = try folder("Absorbed", [.hasTag(a), .and([.hasTag(a), .when(.on(0))])])
    let grouped = try folder("Grouped", [
        .and([.hasTag(a), .parent(nil)]), .and([.hasTag(a), .not(.parent(nil))]),
        .and([.hasTag(b), .when(.empty)]), .hasTag(b),
    ])
    let shared = try folder("Shared project", [.and([.parent(projects[0]), .hasTag(a)]), .and([.parent(projects[0]), .when(.empty)])])
    let outer = try folder("Outer", [.when(.on(0))])
    let inner = try folder("Inner", in: outer.folder, [.parent(projects[0]), .hasTag(c)])
    let mixed = try folder("Mixed", [.hasTag(a), .deadline(.onOrBefore(0))])
    let crowded = try folder("Crowded", [.hasTag(big), .parent(projects[0])])
    let nested = try folder("Nested", [.or([.hasTag(a), .parent(projects[1])]), .and([.or([.hasTag(b), .hasTag(c)]), .deadline(.onOrBefore(3))])])
    let tagged = try folder("Four tags", [.hasTag(a), .hasTag(b), .hasTag(c), .hasTag(d)])

    #expect(try store.taskCounts(today: today) == (try countsByReads(store)))
    let driven = try drivenViews(store)
    for id in [factored, absorbed, grouped, shared, outer, inner].map(\.folder) { #expect(driven.contains(id)) }
    for id in [mixed, crowded, nested, tagged].map(\.folder) { #expect(!driven.contains(id)) }
    #expect(try scanningViews(store).isEmpty)

    let absorbedLists: Set<ViewID> = [absorbed.lists[1], grouped.lists[2]]
    for lists in [factored.lists, absorbed.lists, grouped.lists, shared.lists, outer.lists + inner.lists, mixed.lists, crowded.lists, nested.lists, tagged.lists] {
        for list in lists where !absorbedLists.contains(list) {
            #expect(!(try ownTasks(store, of: list, besides: lists.filter { $0 != list })).isEmpty, "a list that adds nothing to its folder")
        }
    }
}
