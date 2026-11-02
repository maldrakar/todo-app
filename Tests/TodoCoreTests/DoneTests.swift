import Testing
import TestSupport
@testable import TodoCore
@testable import SQLiteKit

private let today = Day(year: 2026, month: 11, day: 2)

/// Finishes a task and answers the instant the store stamped its completion with, which is what `since` is compared
/// against.
@discardableResult
private func finish(_ store: Store, _ id: TaskID, as status: TaskStatus = .done) throws -> Int64 {
    try store.update(task: id, [.status(status)])
    return try #require(try store.task(id)?.completedAt)
}

/// The strip under a list holds what the list's rules completed since the day began (spec section 3): a task done
/// before the instant is the Logbook's and not the strip's, an open one is still a row, and a cancelled one is no
/// longer open, so it is in the strip as a done one is. The bound is inclusive and the newest comes first.
@Test func doneReadsTheTasksTheRulesCompletedSinceAnInstant() throws {
    let clock = TestClock()
    let store = try makeStore(clock: clock)
    let yesterday = try store.createTask(NewTask(title: "yesterday"))
    let morning = try store.createTask(NewTask(title: "morning"))
    let canceled = try store.createTask(NewTask(title: "canceled"))
    let evening = try store.createTask(NewTask(title: "evening"))
    try store.createTask(NewTask(title: "open"))
    try finish(store, yesterday)
    clock.jump(by: 86_400_000)
    let since = try finish(store, morning)
    try finish(store, canceled, as: .canceled)
    try finish(store, evening)

    #expect(try store.done(in: BuiltInTaskViews.inbox, since: since, today: today).map(\.id) == [evening, canceled, morning])
}

/// Every rule a person has asks for open tasks, and the strip is about the ones that stopped being open, so the
/// status conditions come out of the rules before they are read: Today's rule finds the task done today though
/// its read leaves it out, and still not one dated tomorrow. A status inside a negation is lifted to true as well,
/// which makes the negation false: a rule that asks for what is not cancelled has an empty strip, which is accepted.
@Test func doneLiftsEveryStatusConditionOfTheRules() throws {
    let store = try makeStore()
    let due = try store.createTask(NewTask(title: "due", when: today))
    try finish(store, due)
    let tomorrow = try store.createTask(NewTask(title: "tomorrow", when: today.advanced(by: 1)))
    try finish(store, tomorrow)
    #expect(try store.tasks(in: BuiltInTaskViews.today, today: today).isEmpty, "Today's own read asks for open tasks")

    #expect(try store.done(in: BuiltInTaskViews.today, since: 0, today: today).map(\.id) == [due])
    let notCanceled = try store.createView(NewTaskView(title: "Not cancelled", filter: .and([.when(.on(0)), .not(.status([.canceled]))])))
    #expect(try store.done(in: notCanceled, since: 0, today: today).isEmpty, "a negated status lifts to false")
}

/// A list's strip holds what its own rule and the lists inside it completed, a folder inside contributing its lists,
/// as the page's sections hold them; and a folder's own strip is its lists', since it has no rule.
@Test func doneReadsTheListsInsideAndTheirFolders() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let home = try store.createTag(title: "home")
    let due = try store.createTask(NewTask(title: "due", when: today))
    let office = try store.createTask(NewTask(title: "office", tags: [work]))
    let kitchen = try store.createTask(NewTask(title: "kitchen", tags: [home]))
    let stray = try store.createTask(NewTask(title: "stray"))
    for task in [due, office, kitchen, stray] { try finish(store, task) }
    let list = try store.createView(NewTaskView(title: "Due", filter: .and([.status([.open]), .when(.on(0))])))
    try store.createView(NewTaskView(title: "Work", parent: list, filter: .and([.status([.open]), .hasTag(work)])))
    let folder = try store.createView(NewTaskView(title: "Folder", parent: list))
    let deeper = try store.createView(NewTaskView(title: "Deeper", parent: folder))
    try store.createView(NewTaskView(title: "Home", parent: deeper, filter: .hasTag(home)))

    #expect(try store.done(in: list, since: 0, today: today).map(\.id) == [kitchen, office, due], "the stray task no rule selects is left out")
    #expect(try store.done(in: folder, since: 0, today: today).map(\.id) == [kitchen])
}

/// A folder with no list under it has no rule to read, so its strip is empty, an empty folder inside adding none.
@Test func doneOfAViewWithNoRuleAndNoListsIsEmpty() throws {
    let store = try makeStore()
    try finish(store, try store.createTask(NewTask(title: "done")))
    let folder = try store.createView(NewTaskView(title: "Folder"))
    #expect(try store.done(in: folder, since: 0, today: today).isEmpty)
    try store.createView(NewTaskView(title: "Empty", parent: folder))
    #expect(try store.done(in: folder, since: 0, today: today).isEmpty, "an empty folder inside adds no rule")
}

/// A task in the Trash is not done, it is thrown away, and no strip shows it, as no list's read does unless its rule
/// asks for the Trash: then the strip reads what that rule reads.
@Test func doneLeavesTheTrashOutUnlessARuleNamesIt() throws {
    let store = try makeStore()
    let kept = try store.createTask(NewTask(title: "kept"))
    try finish(store, kept)
    let binned = try store.createTask(NewTask(title: "binned"))
    try finish(store, binned)
    try store.trash(task: binned)
    let open = try store.createView(NewTaskView(title: "Open", filter: .status([.open])))

    #expect(try store.done(in: open, since: 0, today: today).map(\.id) == [kept], "the rule lifted selects every task, and the Trash stays out")
    #expect(try store.done(in: BuiltInTaskViews.trash, since: 0, today: today).map(\.id) == [binned])
}

/// The done read is driven by the completion time, from the instant it is given: the tasks a list completed today
/// are a handful among every task its rule selects, done or not. Explained from the function the read calls, as the
/// view statement is in `builtInViewsUseIndexes`, so the guard cannot drift from the query a person waits on.
@Test func theDoneStatementUsesTheCompletedIndex() throws {
    let store = try makeStore()
    let todayRule = try #require(try store.view(BuiltInTaskViews.today)?.filter)
    let statement = Store.doneStatement(rules: [todayRule], since: 0, today: today)
    let plan = try store.sql { () throws(SQLiteError) in
        try store.db.rows("EXPLAIN QUERY PLAN " + statement.sql, statement.params).map { $0[3].string ?? "" }
    }
    let driver = try #require(plan.first)
    #expect(driver.hasPrefix("SEARCH t USING INDEX tasks_completed (completed_at>?)"), "the done read is driven by \(driver): \(plan)")
    #expect(!plan.contains { $0 == "SCAN t" || $0.hasPrefix("SCAN t ") || $0 == "SCAN tt" || $0.hasPrefix("SCAN tt ") }, "\(plan)")
}

/// The done read lifts each rule and keeps each one's own Trash, as a folder's section does: a done task in the
/// Trash is in the strip only by a rule that names the Trash, and not by a sibling's rule that does not.
@Test func doneTakesTheTrashOnlyFromTheRuleThatNamesIt() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let home = try store.createTag(title: "home")
    let office = try store.createTask(NewTask(title: "office", tags: [work]))
    let binnedOffice = try store.createTask(NewTask(title: "binned office", tags: [work]))
    let binnedKitchen = try store.createTask(NewTask(title: "binned kitchen", tags: [home]))
    for task in [office, binnedOffice, binnedKitchen] { try finish(store, task) }
    try store.trash(task: binnedOffice)
    try store.trash(task: binnedKitchen)
    let folder = try store.createView(NewTaskView(title: "Folder"))
    try store.createView(NewTaskView(title: "Work", parent: folder, filter: .and([.status([.open]), .hasTag(work)])))
    try store.createView(NewTaskView(title: "Binned at home", parent: folder, filter: .and([.trashed(true), .hasTag(home)])))

    let done = try store.done(in: folder, since: 0, today: today).map(\.id)
    #expect(done == [binnedKitchen, office], "the binned office task is in neither rule's read")
}
