import Testing
import TestSupport
@testable import TodoCore
@testable import SQLiteKit

private let today = Day(year: 2026, month: 11, day: 4)

/// The statement a view's read of `rules` runs, with the sizes the store reads for it, out of the functions the store
/// assembles both with: a guard that explained a copy would pass while the read itself degraded.
private func readStatement(_ store: Store, _ rules: [Filter], sort: [SortKey] = []) throws -> (sql: String, params: [Value]) {
    Store.viewStatement(rules: rules, sort: sort, today: today, sizes: try store.readSizes(for: [rules], today: today))
}

/// The statement the same read ran before #155, which every rewritten read is held to: the rules as
/// `FilterCompiler.whereClause(anyOf:today:)` writes them in its `.plain` form, which is the text it wrote before #155, as
/// `FilterTests`' literal assertions hold it, in the query `taskQuery` assembles.
private func todaysStatement(_ rules: [Filter], sort: [SortKey] = []) -> (sql: String, params: [Value]) {
    let clause = FilterCompiler.whereClause(anyOf: rules, today: today)
    return (Store.taskQuery(where: clause.sql, orderBy: FilterCompiler.orderBy(sort), limit: nil), clause.params)
}

/// The ids a statement returns, in its order.
private func ids(_ store: Store, _ statement: (sql: String, params: [Value])) throws -> [String] {
    try store.sql { () throws(SQLiteError) in try store.db.rows(statement.sql, statement.params).map { $0[0].string ?? "" } }
}

/// The rows of a statement's query plan, outer loop first.
private func plan(_ store: Store, _ statement: (sql: String, params: [Value])) throws -> [String] {
    try store.sql { () throws(SQLiteError) in
        try store.db.rows("EXPLAIN QUERY PLAN " + statement.sql, statement.params).map { $0[3].string ?? "" }
    }
}

/// Whether a plan walks every row of a table that grows with the list.
private func scans(_ plan: [String]) -> Bool {
    plan.contains { $0 == "SCAN t" || $0.hasPrefix("SCAN t ") || $0 == "SCAN tt" || $0.hasPrefix("SCAN tt ") }
}

/// How a read is written: as it was before #155, byte for byte; driven by a condition of its rule's own; or as before
/// but for its tags, written as lists off every index after the other conditions.
private enum Written { case asBefore, driven, listed }

private func written(_ store: Store, _ rules: [Filter]) throws -> Written {
    let statement = try readStatement(store, rules)
    if statement == todaysStatement(rules) { return .asBefore }
    return statement.sql.contains("+t.id IN (SELECT") ? .listed : .driven
}

/// Every sort a view can ask for, each field in each direction, two keys and none: a rewritten read is held to the
/// order of today's in each.
private let sorts: [[SortKey]] = SortField.allCases.flatMap { [[SortKey($0)], [SortKey($0, descending: true)]] }
    + [[SortKey(.deadline), SortKey(.title, descending: true)], []]

/// That the read of `rules` is written as `expected` and returns what today's statement returns, in its order, under
/// every sort.
private func expectRead(_ store: Store, _ rules: [Filter], is expected: Written, _ comment: Comment, sourceLocation: SourceLocation = #_sourceLocation) throws {
    #expect(try written(store, rules) == expected, comment, sourceLocation: sourceLocation)
    for sort in sorts {
        let read = try ids(store, try readStatement(store, rules, sort: sort))
        #expect(read == (try ids(store, todaysStatement(rules, sort: sort))), "\(comment), sorted by \(sort)", sourceLocation: sourceLocation)
    }
}

private let builtIns = [BuiltInTaskViews.inbox, BuiltInTaskViews.today, BuiltInTaskViews.upcoming, BuiltInTaskViews.logbook, BuiltInTaskViews.trash]

/// No built-in's rule has a condition that drives a read better than SQLite already does, an empty day, the root, a
/// range open at one end, a status and the trash, and none names a tag, so each reads no size and is the statement it
/// was before #155, byte for byte, as its count is (`theCountStatementUsesTheIndexes`). Beside a list that does read
/// sizes, as on a page, it is still that statement with those sizes.
@Test func theBuiltInsReadsAreTheStatementsTheyWereByteForByte() throws {
    let store = try makeStore()
    let tag = try store.createTag(title: "work")
    try store.createTask(NewTask(title: "tagged", deadline: today.advanced(by: -2), tags: [tag]))
    let done = try store.createTask(NewTask(title: "done"))
    try store.update(task: done, [.status(.done)])
    let others: [[Filter]] = [
        [.hasTag(tag)], [.or([.hasTag(tag), .deadline(.onOrBefore(-1))])],
        [.and([.status([.open, .done, .canceled]), .when(.empty), .parent(nil), .not(.when(.empty)), .when(.onOrBefore(0)), .when(.onOrAfter(1)), .hasTag(tag)])],
    ]
    let theirs = try store.readSizes(for: others, today: today)
    for id in builtIns {
        let view = try #require(try store.view(id))
        let filter = try #require(view.filter)
        #expect(Store.readSizeStatements(for: [[filter]], today: today).isEmpty, "\(view.title) reads a size")
        let before = todaysStatement([filter], sort: view.sort)
        #expect(try readStatement(store, [filter], sort: view.sort) == before, "\(view.title)")
        #expect(Store.viewStatement(rules: [filter], sort: view.sort, today: today, sizes: theirs) == before, "\(view.title) beside the others")
    }
}

/// The guard of #155 beside the built-ins': a view's read is driven by its rule's own index where the rule has one, by
/// the plan of the statement the read runs. A project's read by the tree's parent index; a tag's and a manual list's by
/// the list of the tasks the tag or the pins hold, which SQLite looks the tasks up from by id; a folder of projects by
/// the parent index, its parents compared plainly, which SQLite reads as one search for all of them; an Urgent-shaped
/// rule, a tag or a deadline that has passed, by both indexes. A tag beside a range of deadlines that holds fewer tasks
/// than the tag stays on the range, and a closed status with a tag stays on the status index while nothing has that
/// status and goes to the tag once much does. A tag beside a choice of projects or of days, which SQLite tests before
/// the tag and which no index says the share of, stays on the parent's or the day's index. None of these reads walks
/// every task.
@Test func aReadIsDrivenByItsRulesOwnIndex() throws {
    let store = try makeStore()
    let small = try store.createTag(title: "small")
    let medium = try store.createTag(title: "medium")
    let big = try store.createTag(title: "big")
    let projects = [try store.createTask(NewTask(title: "p0")), try store.createTask(NewTask(title: "p1"))]
    let manual = try store.createView(NewTaskView(title: "Pinned"))
    try store.update(view: manual, [.filter(.listedIn(manual))])
    var all: [TaskID] = []
    for i in 0..<98 {
        let tags: Set<TagID> = i < 5 || i == 50 ? [small] : i < 25 ? [medium] : i < 85 ? [big] : []
        let deadline = (90..<93).contains(i) ? today.advanced(by: -30) : nil
        let when = (5..<8).contains(i) ? today : i == 8 ? today.advanced(by: 1) : nil
        let task = try store.createTask(NewTask(title: "task \(i)", when: when, deadline: deadline, parent: i < 3 ? projects[0] : i < 6 ? projects[1] : nil, tags: tags))
        if (93..<96).contains(i) { try store.pin(task: task, in: manual) }
        all.append(task)
    }
    let doneAndSmall: [Filter] = [.and([.status([.done]), .hasTag(small)])]
    func reads() throws -> [String: (rules: [Filter], plan: [String])] {
        var reads: [String: (rules: [Filter], plan: [String])] = [:]
        let rules: [(String, [Filter])] = [
            ("project", [.parent(projects[0])]), ("tag", [.hasTag(small)]), ("manual", [.listedIn(manual)]),
            ("projects", [.parent(projects[0]), .parent(projects[1])]), ("urgent", [.or([.hasTag(small), .deadline(.onOrBefore(-1))])]),
            ("beside a range", [.and([.hasTag(medium), .deadline(.onOrBefore(-20))])]), ("done", doneAndSmall),
            ("beside projects", [.and([.hasTag(medium), .or([.parent(projects[0]), .parent(projects[1])])])]),
            ("beside days", [.and([.hasTag(medium), .or([.when(.on(0)), .when(.on(1))])])]),
        ]
        for (name, rules) in rules {
            let statement = try readStatement(store, rules, sort: [SortKey(.title)])
            reads[name] = (rules, try plan(store, statement))
            #expect(try ids(store, statement) == (try ids(store, todaysStatement(rules, sort: [SortKey(.title)]))), "\(name)")
        }
        return reads
    }
    let before = try reads()
    #expect(before["project"]?.plan.first == "SEARCH tt USING INDEX task_tree_parent (parent=?)", "\(before["project"]?.plan ?? [])")
    #expect(before["tag"]?.plan.prefix(4) == [
        "SEARCH tt USING PRIMARY KEY (id=?)", "LIST SUBQUERY 1",
        "SEARCH g USING INDEX sqlite_autoindex_tags_1 (id=?)", "SEARCH x USING COVERING INDEX task_tags_tag (tag_id=?)",
    ], "\(before["tag"]?.plan ?? [])")
    #expect(before["manual"]?.plan.prefix(3) == ["SEARCH tt USING PRIMARY KEY (id=?)", "LIST SUBQUERY 1", "SEARCH v USING PRIMARY KEY (view_id=?)"], "\(before["manual"]?.plan ?? [])")
    #expect(before["projects"]?.plan.first == "SEARCH tt USING INDEX task_tree_parent (parent=?)", "\(before["projects"]?.plan ?? [])")
    let projectsRead = try readStatement(store, [.parent(projects[0]), .parent(projects[1])])
    #expect(projectsRead.sql.contains("((tt.parent = ?) OR (tt.parent = ?))") && !projectsRead.sql.contains("SELECT p.id"), "\(projectsRead.sql)")
    let urgent = before["urgent"]?.plan ?? []
    #expect(urgent.first == "MULTI-INDEX OR", "\(urgent)")
    #expect(urgent.contains("SEARCH x USING COVERING INDEX task_tags_tag (tag_id=?)") && urgent.contains("SEARCH t USING INDEX tasks_deadline (deadline_day<?)"), "\(urgent)")
    #expect(before["beside a range"]?.plan.first == "SEARCH t USING INDEX tasks_deadline (deadline_day<?)", "\(before["beside a range"]?.plan ?? [])")
    #expect(before["done"]?.plan.first == "SEARCH t USING INDEX tasks_status (status=?)", "\(before["done"]?.plan ?? [])")
    #expect(before["beside projects"]?.plan.first == "SEARCH tt USING INDEX task_tree_parent (parent=?)", "\(before["beside projects"]?.plan ?? [])")
    #expect(before["beside days"]?.plan.first == "SEARCH t USING INDEX tasks_when (when_day=?)", "\(before["beside days"]?.plan ?? [])")
    for (name, read) in before { #expect(!scans(read.plan), "\(name) walks every task: \(read.plan)") }

    for task in all[40..<90] { try store.update(task: task, [.status(.done)]) }
    let after = try reads()
    #expect(after["done"]?.plan.prefix(2) == ["SEARCH tt USING PRIMARY KEY (id=?)", "LIST SUBQUERY 1"], "\(after["done"]?.plan ?? [])")
    for (name, read) in after { #expect(!scans(read.plan), "\(name) walks every task: \(read.plan)") }
}

/// A store in which every condition of the shapes below has tasks on both sides of it, as `CountTests` builds one: 300
/// tasks a fixed generator spreads over the three statuses, days and deadlines around today or none, two projects or
/// the root, four small tags, each on about a twelfth of the tasks, a tag on most tasks, the trash, and a manual list.
/// One task is deleted.
private func shapesStore() throws -> (store: Store, small: [TagID], big: TagID, projects: [TaskID], manual: ViewID) {
    let store = try makeStore()
    let small = [try store.createTag(title: "a"), try store.createTag(title: "b"), try store.createTag(title: "c"), try store.createTag(title: "d")]
    let big = try store.createTag(title: "big")
    let projects = [try store.createTask(NewTask(title: "p0")), try store.createTask(NewTask(title: "p1"))]
    let manual = try store.createView(NewTaskView(title: "Pinned"))
    try store.update(view: manual, [.filter(.listedIn(manual))])
    var state: UInt64 = 155
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
        let task = try store.createTask(NewTask(title: "task \(roll(40))", when: when, deadline: deadline, parent: parent, tags: tags))
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

/// Every rewritten read returns the tasks today's statement returns, in its order, under every sort (#155), and each
/// shape is written the way the choice says: a manual list, a project, a day, a short range, a small tag, a tag beside
/// a negation, an empty day, the root, an open-ended range or a status that includes one closed, two tags, a tag or a
/// deadline that has passed, a choice of a tag and a day under a range, the trash beside a manual list, and the last
/// two days of the calendar drive. A big tag, a negated one, two negated, a tag beside a range or a closed status that holds
/// fewer tasks than it, a disjunction with a branch nothing drives and one inside another's branch keep today's
/// conditions with their tags as lists last; a big tag beside a status that holds few tasks, a range over every day
/// there is and a status no task has are today's statements.
@Test func aRewrittenReadReturnsWhatTodaysReturnsInItsOrder() throws {
    let (store, small, big, projects, manual) = try shapesStore()
    let (a, b, c, d) = (small[0], small[1], small[2], small[3])
    let shapes: [(String, Filter, Written)] = [
        ("manual list", .listedIn(manual), .driven),
        ("project", .parent(projects[0]), .driven),
        ("on the day", .when(.on(0)), .driven),
        ("this week", .deadline(.between(0, 7)), .driven),
        ("small tag", .hasTag(a), .driven),
        ("not today", .and([.hasTag(a), .not(.when(.on(0)))]), .driven),
        ("no day", .and([.hasTag(b), .when(.empty)]), .driven),
        ("at the root", .and([.hasTag(c), .parent(nil)]), .driven),
        ("open or done", .and([.status([.open, .done]), .hasTag(c)]), .driven),
        ("done", .and([.status([.done]), .hasTag(a)]), .driven),
        ("with a deadline", .and([.hasTag(a), .not(.deadline(.empty))]), .driven),
        ("since the first day", .and([.hasTag(a), .when(.onOrAfter(.min))]), .driven),
        ("two tags", .or([.hasTag(a), .hasTag(b)]), .driven),
        ("urgent", .or([.hasTag(a), .deadline(.onOrBefore(-1))]), .driven),
        ("tag or tomorrow, due soon", .and([.or([.hasTag(a), .when(.on(1))]), .deadline(.onOrBefore(3))]), .driven),
        ("tag beside projects", .and([.hasTag(a), .or([.parent(projects[0]), .parent(projects[1])])]), .driven),
        ("tag beside days", .and([.hasTag(a), .or([.when(.on(0)), .when(.on(1))])]), .driven),
        ("binned and pinned", .and([.trashed(true), .listedIn(manual)]), .driven),
        ("pinned and big", .and([.listedIn(manual), .hasTag(big)]), .driven),
        ("the last two days", .deadline(.between(.max - 1, .max)), .driven),
        ("big tag", .hasTag(big), .listed),
        ("not a", .not(.hasTag(a)), .listed),
        ("untagged", .and([.not(.hasTag(a)), .not(.hasTag(b))]), .listed),
        ("canceled", .and([.status([.canceled]), .hasTag(a)]), .listed),
        ("tag, long overdue", .and([.hasTag(a), .deadline(.onOrBefore(-2))]), .listed),
        ("five tags", .or([.hasTag(a), .hasTag(b), .hasTag(c), .hasTag(d), .hasTag(big)]), .listed),
        ("dated ever, or a", .or([.hasTag(a), .when(.onOrBefore(.max))]), .listed),
        ("nested", .or([.and([.or([.hasTag(a), .hasTag(b)]), .when(.empty)]), .parent(projects[0])]), .listed),
        ("big, canceled", .and([.status([.canceled]), .hasTag(big)]), .asBefore),
        ("big, long overdue", .and([.hasTag(big), .deadline(.onOrBefore(-2))]), .asBefore),
        ("every day there is", .when(.between(.min, .max)), .asBefore),
        ("no status", .and([.status([]), .hasTag(a)]), .asBefore),
        ("nothing", .or([]), .asBefore),
    ]
    for (title, rule, expected) in shapes { try expectRead(store, [rule], is: expected, "\(title)") }
}

/// A folder's section reads the union of its lists' reads, each with its own exclusion of the Trash, whatever the
/// regrouping does to it (#155): conditions every list shares taken out in front, the trash among them, a list that asks
/// for no more than those absorbing another, lists grouped under the condition that drives them, a list that names the
/// Trash beside one that does not, projects compared plainly, a disjunction with a range in a branch, and a list a big
/// tag holds, which leaves its folder undriven. Every list but the absorbed ones selects a task no other list of its
/// folder selects, so that a dropped branch cannot pass.
@Test func aFoldersRewrittenReadReturnsWhatTodaysReturnsInItsOrder() throws {
    let (store, small, big, projects, manual) = try shapesStore()
    let (a, b, c, d) = (small[0], small[1], small[2], small[3])
    let folders: [(String, [Filter], Written, absorbed: Set<Int>)] = [
        ("factored", [.and([.when(.empty), .hasTag(a)]), .and([.when(.empty), .hasTag(b)])], .driven, []),
        ("absorbed", [.hasTag(a), .and([.hasTag(a), .when(.on(0))])], .driven, [1]),
        ("grouped", [.and([.hasTag(a), .parent(nil)]), .and([.hasTag(a), .not(.parent(nil))]), .and([.hasTag(b), .when(.empty)]), .hasTag(b)], .driven, [2]),
        ("shared project", [.and([.parent(projects[0]), .hasTag(a)]), .and([.parent(projects[0]), .when(.empty)])], .driven, []),
        ("binned beside", [.hasTag(a), .and([.trashed(true), .listedIn(manual)])], .driven, []),
        ("projects", [.parent(projects[0]), .parent(projects[1])], .driven, []),
        ("mixed", [.hasTag(a), .deadline(.onOrBefore(0))], .driven, []),
        ("nested", [.or([.hasTag(a), .parent(projects[1])]), .and([.or([.hasTag(b), .hasTag(c)]), .deadline(.onOrBefore(3))])], .driven, []),
        ("four tags", [.hasTag(a), .hasTag(b), .hasTag(c), .hasTag(d)], .driven, []),
        ("crowded", [.hasTag(big), .parent(projects[0])], .listed, []),
    ]
    for (title, rules, expected, absorbed) in folders {
        try expectRead(store, rules, is: expected, "\(title)")
        let reads = try rules.map { Set(try ids(store, todaysStatement([$0]))) }
        for (i, read) in reads.enumerated() where !absorbed.contains(i) {
            let others = reads.enumerated().filter { $0.offset != i }.reduce(into: Set<String>()) { $0.formUnion($1.element) }
            #expect(!read.subtracting(others).isEmpty, "\(title): list \(i) adds nothing to its folder")
        }
    }
}

/// A rule at the bound on a stored filter's depth, fifteen groups, reads what today's statement reads, on both platforms:
/// every walk over it recurses as `FilterCompiler.compile` does, within the bound (`maximumDepth`), and so does the
/// form that writes its tags as lists last at every level.
@Test func aReadAtTheBoundOnAFiltersDepthReadsWhatTodaysReads() throws {
    let (store, small, _, _, _) = try shapesStore()
    var rule = Filter.hasTag(small[0])
    for level in 0..<15 { rule = level.isMultiple(of: 2) ? .or([.hasTag(small[1]), rule]) : .and([.not(.when(.on(0))), rule]) }
    let view = try store.createView(NewTaskView(title: "Deep", filter: rule))
    #expect(try written(store, [rule]) == .listed)
    #expect(try store.tasks(in: view, today: today).map(\.id.rawValue) == (try ids(store, todaysStatement([rule]))))
}

/// A page reads the sizes its reads choose by once, and each section, the own one and a folder's among them, holds what
/// it held before #155 (spec section 2).
@Test func aPagesSectionsHoldWhatTheyHeld() throws {
    let (store, small, big, projects, _) = try shapesStore()
    let page = try store.createView(NewTaskView(title: "Page", filter: .and([.hasTag(small[0]), .when(.empty)]), sort: [SortKey(.when)]))
    try store.createView(NewTaskView(title: "Big", parent: page, filter: .hasTag(big), sort: [SortKey(.title)]))
    let folder = try store.createView(NewTaskView(title: "Folder", parent: page, sort: [SortKey(.deadline, descending: true)]))
    try store.createView(NewTaskView(title: "Project", parent: folder, filter: .parent(projects[1])))
    try store.createView(NewTaskView(title: "Urgent", parent: folder, filter: .or([.hasTag(small[1]), .deadline(.onOrBefore(-1))])))

    let sections = try store.page(of: page, today: today).sections
    let views = try store.views()
    var claimed: Set<String> = []
    var expected: [[String]] = []
    for (child, rules) in Store.childSections(of: page, among: views) {
        let read = try ids(store, todaysStatement(rules, sort: child.sort))
        claimed.formUnion(read)
        expected.append(read)
    }
    let own = try ids(store, todaysStatement([.and([.hasTag(small[0]), .when(.empty)])], sort: [SortKey(.when)])).filter { !claimed.contains($0) }
    #expect(sections.map { $0.groups.flatMap(\.tasks).map(\.id.rawValue) } == [own] + expected)
    #expect(sections.count == 3)
}

/// A tag drives a read while it holds fewer tasks than three hundredths of the rows the read walks without it, W, and
/// two fifths of the rows it would test the tag on, S (#155): under a walk of every task, of the tasks of a status, of
/// a range of days, and beside a condition that keeps a share of the walk. One task more and it does not, and its tag
/// is a list written last instead. Either way the read returns what today's does.
@Test func aTagDrivesWhileItHoldsFewerThanItsShareOfTheWalk() throws {
    let (store, tag, tasks) = try thresholdStore()
    // Every task: W = S = 110, a share of 3.3 + 44 = 47.3.
    try expectSides(store, [.hasTag(tag("A"))], adding: tag("A"), to: tasks[47], "every task, 47 tasks")
    // The done tasks: W = S = 50, a share of 1.5 + 20 = 21.5.
    try expectSides(store, [.and([.status([.done]), .hasTag(tag("B"))])], adding: tag("B"), to: tasks[51], "the done tasks, 21 tasks")
    // A range of deadlines: W = S = 30, a share of 0.9 + 12 = 12.9.
    try expectSides(store, [.and([.hasTag(tag("C")), .deadline(.onOrBefore(-20))])], adding: tag("C"), to: tasks[82], "a range, 12 tasks")
    // Beside a day that is not empty: W = 110 and S = 50, the dated tasks, a share of 3.3 + 20 = 23.3.
    try expectSides(store, [.and([.hasTag(tag("D")), .not(.when(.empty))])], adding: tag("D"), to: tasks[63], "beside a day, 23 tasks")
}

/// The tags that drive a disjunction's branches drive it while the tasks they hold add up to fewer than three hundredths
/// of its walk and half the rows it tests them on (#155), each tag also driving its own branch: two tags of 29 tasks in
/// 110, and a tag beside a range of deadlines, which drives its branch under a walk of every task. One task more and it
/// does not. Under the open status the range has no walk of every task to beat and drives nothing.
@Test func aDisjunctionDrivesWhileItsDriversHoldFewerThanHalfOfItsWalk() throws {
    let (store, tag, tasks) = try thresholdStore()
    // W = S = 110 for each tag's branch, so the disjunction's are 110 too: a share of 3.3 + 55 = 58.3.
    try expectRead(store, [.hasTag(tag("E"))], is: .driven, "each tag alone drives")
    try expectSides(store, [.or([.hasTag(tag("E")), .hasTag(tag("F"))])], adding: tag("E"), to: tasks[29], "two tags, 58 tasks")
    // 28 tasks of H and the 30 deadlines: 58 against 58.3.
    try expectSides(store, [.or([.hasTag(tag("H")), .deadline(.onOrBefore(-20))])], adding: tag("H"), to: tasks[28], "a tag or a range, 58 tasks")
    try expectRead(store, [.and([.status([.open]), .or([.hasTag(tag("H")), .deadline(.onOrBefore(-20))])])], is: .listed, "under the open status")
}

/// A disjunction every branch of which narrows the read is weighed against the walk around it, as its branches are, and
/// not against its own narrowing, which only the conditions beside it are tested after (#155): a tag of 12 tasks among
/// the 30 deadlines, or the day, drives at 12 against 3.3 + 0.5 × 30 = 18.3, and its tag drives its branch at 12 against
/// 0.9 + 0.4 × 30 = 12.9.
@Test func aDisjunctionThatNarrowsIsWeighedAgainstTheWalkAroundIt() throws {
    let (store, tag, _) = try thresholdStore()
    let rule = Filter.or([.and([.hasTag(tag("C")), .deadline(.onOrBefore(-20))]), .when(.on(0))])
    try expectRead(store, [rule], is: .driven, "a tag beside a range, or the day")
    #expect(try plan(store, try readStatement(store, [rule])).first == "MULTI-INDEX OR")
}

/// An undriven read writes its tags as lists, last in their conjunction, while they hold fewer than four times the rows
/// they are tested on (#155), and is today's statement from there on. The list is written after the conditions SQLite
/// tests first, which it would otherwise build before them.
@Test func anUndrivenReadListsItsTagsWhileTheyHoldFewerThanFourTimesItsRows() throws {
    let (store, tag, tasks) = try thresholdStore()
    let rule = Filter.and([.status([.canceled]), .hasTag(tag("G"))])
    // W = S = 10, the canceled tasks: no driver from 4.3 tasks, no list from 40.
    try expectRead(store, [rule], is: .listed, "39 tasks")
    let listed = try readStatement(store, [rule])
    #expect(listed.sql.contains(" WHERE t.deleted = 0 AND (((((t.status IN (?) AND +t.id IN (SELECT x.task_id FROM task_tags x JOIN tags g ON g.id = x.tag_id AND g.deleted = 0 WHERE x.tag_id = ? AND x.present = 1))) AND tt.trashed = 0))) ORDER BY "), "\(listed.sql)")
    #expect(listed.params == [.integer(2), .text(tag("G").rawValue)])
    let reversed = Filter.and([.hasTag(tag("G")), .status([.canceled])])
    #expect(try readStatement(store, [reversed]).sql == listed.sql, "the list goes last whichever is written first")
    #expect(try plan(store, listed).first == "SEARCH t USING INDEX tasks_status (status=?)")
    try store.add(tag: tag("G"), to: tasks[70])
    try expectRead(store, [rule], is: .asBefore, "40 tasks")
}

/// 110 tasks for the shares: 50 done, 10 canceled, 50 open; 60 with no day; 30 with a deadline 25 days ago; each tag on
/// the tasks a test names, and the tag of each name.
private func thresholdStore() throws -> (store: Store, tag: (String) -> TagID, tasks: [TaskID]) {
    let store = try makeStore()
    let tagged: [String: Range<Int>] = ["A": 0..<47, "B": 30..<51, "C": 70..<82, "D": 40..<63, "E": 0..<29, "F": 81..<110, "G": 71..<110, "H": 0..<28]
    var tags: [String: TagID] = [:]
    for name in tagged.keys.sorted() { tags[name] = try store.createTag(title: name) }
    var tasks: [TaskID] = []
    for i in 0..<110 {
        let named = Set(tagged.filter { $0.value.contains(i) }.compactMap { tags[$0.key] })
        let task = try store.createTask(NewTask(title: "task \(i)", when: i < 60 ? nil : today, deadline: (60..<90).contains(i) ? today.advanced(by: -25) : nil, tags: named))
        if i < 50 { try store.update(task: task, [.status(.done)]) }
        if i >= 100 { try store.update(task: task, [.status(.canceled)]) }
        tasks.append(task)
    }
    return (store, { tags[$0] ?? TagID($0) }, tasks)
}

/// Both sides of a share: the read of `rules` driven, and with `tag` on one task more, listed.
private func expectSides(_ store: Store, _ rules: [Filter], adding tag: TagID, to task: TaskID, _ comment: Comment, sourceLocation: SourceLocation = #_sourceLocation) throws {
    try expectRead(store, rules, is: .driven, comment, sourceLocation: sourceLocation)
    try store.add(tag: tag, to: task)
    try expectRead(store, rules, is: .listed, "\(comment), and one more", sourceLocation: sourceLocation)
}

/// The sizes a read is weighed by cost no table row (#155): every task is counted on an index, a status on the status
/// index, a tag on its partial index, a day's condition on its day's index and the root on the tree's parent index, by
/// the statements `readSizes` runs. A read with no tag and no range in a disjunction reads none.
@Test func theSizeReadsReadIndexesAlone() throws {
    let store = try makeStore()
    let tag = TagID("t")
    let conditions: [Filter] = [
        .when(.empty), .deadline(.empty), .parent(nil), .when(.onOrBefore(7)), .deadline(.onOrAfter(-3)), .when(.between(-100, 100)), .deadline(.between(.min, .max)),
    ]
    let rule = Filter.and([.status([.open, .done, .canceled]), .hasTag(tag), .not(.when(.empty))] + conditions.dropFirst())
    let statements = Store.readSizeStatements(for: [[rule]], today: today)
    #expect(statements.map(\.size) == [.tasks, .status(.open), .status(.done), .status(.canceled), .tag(tag)] + conditions.map(ReadCompiler.Size.condition))
    for statement in statements {
        let plan = try plan(store, (statement.sql, statement.params))
        #expect(plan.count == 1 && plan[0].contains(" USING COVERING INDEX "), "\(statement.sql): \(plan)")
    }

    let project = TaskID("p")
    let none: [[Filter]] = [
        [.parent(project)], [.listedIn(ViewID("v"))], [.when(.on(0))], [.deadline(.between(0, 7))], [.parent(project), .parent(TaskID("q"))],
        [.or([.when(.on(0)), .parent(project)])], [.deadline(.onOrBefore(-1))], [.and([.status([.open]), .when(.onOrAfter(1)), .parent(nil)])],
        [.or([.parent(nil), .parent(project)])], [.and([.parent(nil), .when(.empty)]), .parent(project)],
    ]
    for rules in none { #expect(Store.readSizeStatements(for: [rules], today: today).isEmpty, "\(rules)") }
    #expect(Store.readSizeStatements(for: none + [[.hasTag(tag)], [.hasTag(tag)]], today: today).map(\.size) == [.tasks, .tag(tag)], "each size once")
}

