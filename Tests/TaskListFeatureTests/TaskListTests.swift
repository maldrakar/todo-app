import Testing
import TestSupport
import TaskListFeature
import TaskScreenFeature
import TodoCore
import SQLiteKit

/// The rows are the query's answer in the query's order, which is the rank and not the order the tasks were
/// written in, and a task the view does not select has no row.
@Test func aListShowsTheViewsTasksInQueryOrder() throws {
    let store = try makeStore()
    let first = try store.createTask(NewTask(title: "First"))
    let second = try store.createTask(NewTask(title: "Second"))
    let third = try store.createTask(NewTask(title: "Third"), at: .start)
    try store.createTask(NewTask(title: "Someday", when: Day(year: 2030, month: 1, day: 1)))
    let list = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox))
    let query = try store.tasks(in: BuiltInTaskViews.inbox, today: Day(millisSinceEpoch: Store.systemNow()))
    #expect(list.model.rows.map(\.id) == query.map(\.id))
    #expect(list.model.rows.map(\.id) == [third, first, second], "a task with a day is not the Inbox's")
    #expect(list.model.rows.map(\.title) == ["Third", "First", "Second"])
    #expect(list.model.task == nil)
    #expect(list.model.problem == nil)
    #expect(list.route == .init(head: BuiltInTaskViews.inbox))
}

/// A list on a view that is gone is not made, and its `init` says which view it looked for: the query refuses a
/// view it does not hold, and the parent keeps what was open and says so (spec section 3).
@Test func aListOnAGoneViewIsNotMade() throws {
    let store = try makeStore()
    let gone = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    try store.delete(view: gone)
    #expect(throws: StoreError.notFound(gone)) { try TaskList(store: store, route: .init(head: gone)) }
    let unknown = ViewID()
    #expect(throws: StoreError.notFound(unknown)) { try TaskList(store: store, route: .init(head: unknown)) }
}

/// A link to a task, or a window restored onto one, makes the list with the task screen open in it, and the
/// route says so; being created afterwards moves nothing, since the screen was made in `init`.
@Test func aListCreatedWithATaskOpensIt() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let route = TaskList.Route(head: BuiltInTaskViews.inbox, task: .init(head: id))
    let list = try TaskList(store: store, route: route)
    #expect(list.model.task == (try TaskScreen(store: store, route: .init(head: id))).model)
    #expect(list.model.task?.title == "Buy milk")
    #expect(list.route == route)
    #expect(list.model.problem == nil)
    let before = list.model
    #expect(list.send(.created) == nil)
    #expect(list.model == before)
}

/// A link to a task deleted since opens what still exists: the list, with no task open and a sentence saying
/// why (spec section 3, the fourth flow). The parent sends `.created` right after `init`, so the sentence has to
/// outlive it to be read at all.
@Test func aListCreatedWithAGoneTaskOpensTheListAndSaysSo() throws {
    let store = try makeStore()
    let kept = try store.createTask(NewTask(title: "Call the bank"))
    let gone = try store.createTask(NewTask(title: "Buy milk"))
    try store.delete(task: gone)
    let list = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox, task: .init(head: gone)))
    #expect(list.model.rows.map(\.id) == [kept])
    #expect(list.model.task == nil)
    #expect(list.route == .init(head: BuiltInTaskViews.inbox), "no task is open, so the route names none")
    #expect(list.model.problem == "The task is gone.")
    let told = list.model
    #expect(list.send(.created) == nil)
    #expect(list.model == told, "being created answers no gesture, so the sentence stays")
}

/// A tap is the route with the task as its tail, applied: the list it leaves is the one a link to the task makes.
@Test func aTapOpensTheTaskAndTheRouteSaysSo() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    try store.createTask(NewTask(title: "Call the bank"))
    let list = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox))
    #expect(list.send(.action(.rowTapped(id))) == nil)
    let linked = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox, task: .init(head: id)))
    #expect(list.model == linked.model, "what a tap opens and what a link opens are one thing")
    #expect(list.model.task?.title == "Buy milk")
    #expect(list.route == .init(head: BuiltInTaskViews.inbox, task: .init(head: id)))
}

/// A row the list does not hold is no row to tap, even for a task the store would open: this one was written
/// after the list read its rows, and its change has not arrived. Nothing moves, the sentence included.
@Test func aTapOnARowNotInTheListOpensNothing() throws {
    let store = try makeStore()
    let gone = try store.createTask(NewTask(title: "Buy milk"))
    try store.delete(task: gone)
    let list = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox, task: .init(head: gone)))
    let told = list.model
    #expect(told.problem != nil, "the sentence is the setup; without it this proves nothing about it")
    let unread = try store.createTask(NewTask(title: "Call the bank"))
    #expect(list.send(.action(.rowTapped(unread))) == nil)
    #expect(list.model == told)
    #expect(list.route == .init(head: BuiltInTaskViews.inbox))
}

/// The way back is the route without the task, applied: the list it leaves is the one with nothing open.
@Test func dismissingTheTaskScreenClosesIt() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox, task: .init(head: id)))
    #expect(list.send(.action(.taskScreenDismissed)) == nil)
    #expect(list.model == (try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox))).model)
    #expect(list.model.task == nil)
    #expect(list.route == .init(head: BuiltInTaskViews.inbox))
}

/// The way back is a gesture on the screen that covered the list, so it leaves the list's sentence: one written
/// while the screen was up, here by a link to a task that is gone, is first seen when the list is uncovered.
@Test func dismissingTheTaskScreenLeavesTheSentenceWrittenUnderIt() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let gone = try store.createTask(NewTask(title: "Call the bank"))
    try store.delete(task: gone)
    let list = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox, task: .init(head: open)))
    #expect(list.send(.route(.init(head: BuiltInTaskViews.inbox, task: .init(head: gone)))) == nil)
    #expect(list.model.task?.title == "Buy milk", "the screen that was open stays; this is the setup")
    #expect(list.model.problem == "The task is gone.")
    #expect(list.send(.action(.taskScreenDismissed)) == nil)
    #expect(list.model.task == nil)
    #expect(list.route == .init(head: BuiltInTaskViews.inbox))
    #expect(list.model.problem == "The task is gone.")
}

/// With no screen open the way back has nothing to close, as with the nil the platform writes after a pop the
/// model drove, and it moves nothing at all, the sentence included: the sidebar ignores a field action with no
/// field open for the same reason (#81).
@Test func dismissingWithNoTaskScreenOpenMovesNothing() throws {
    let store = try makeStore()
    let gone = try store.createTask(NewTask(title: "Buy milk"))
    try store.delete(task: gone)
    let list = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox, task: .init(head: gone)))
    let told = list.model
    #expect(told.problem != nil, "the sentence is the setup; without it this proves nothing about it")
    #expect(list.send(.action(.taskScreenDismissed)) == nil)
    #expect(list.model == told)
    #expect(list.route == .init(head: BuiltInTaskViews.inbox))
}

/// A link to another task while one is open: the seat sees another head and replaces the screen (spec
/// section 3, the third flow).
@Test func aRouteWithAnotherTaskReplacesTheOpenOne() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let other = try store.createTask(NewTask(title: "Call the bank"))
    let list = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox, task: .init(head: open)))
    let route = TaskList.Route(head: BuiltInTaskViews.inbox, task: .init(head: other))
    #expect(list.send(.route(route)) == nil)
    #expect(list.model == (try TaskList(store: store, route: route)).model)
    #expect(list.model.task?.title == "Call the bank")
    #expect(list.route == route)
}

@Test func aRouteWithNoTaskClosesIt() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox, task: .init(head: id)))
    #expect(list.send(.route(.init(head: BuiltInTaskViews.inbox))) == nil)
    #expect(list.model == (try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox))).model)
    #expect(list.route == .init(head: BuiltInTaskViews.inbox))
}

/// A screen that cannot be made leaves the one that was open, and the list says so (spec section 3), whether a
/// tap or a link asked for it. The task was deleted by a peer whose change has not arrived, so its row is still
/// there to tap.
@Test func aTaskThatCannotBeMadeLeavesTheOpenOneAndSaysSo() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let gone = try store.createTask(NewTask(title: "Call the bank"))
    let tapped = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox, task: .init(head: open)))
    let linked = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox, task: .init(head: open)))
    try store.delete(task: gone)
    #expect(tapped.send(.action(.rowTapped(gone))) == nil)
    #expect(tapped.model.task?.title == "Buy milk", "the screen that was open stays")
    #expect(tapped.route == .init(head: BuiltInTaskViews.inbox, task: .init(head: open)))
    #expect(tapped.model.problem == "The task is gone.")
    #expect(linked.send(.route(.init(head: BuiltInTaskViews.inbox, task: .init(head: gone)))) == nil)
    #expect(linked.model == tapped.model, "a link to the task meets the same refusal")
    #expect(linked.route == tapped.route)
}

/// A sentence answers what a person did, so the events of the world leave it, a route that opens a task and a
/// change that rereads the rows among them, and the next tap on a row the list holds takes it away.
@Test func theSentenceOutlivesEventsOfTheWorldAndGoesWithTheNextTap() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let gone = try store.createTask(NewTask(title: "Call the bank"))
    try store.delete(task: gone)
    let list = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox, task: .init(head: gone)))
    #expect(list.send(.route(.init(head: BuiltInTaskViews.inbox, task: .init(head: id)))) == nil)
    #expect(list.model.task?.title == "Buy milk", "the route opened the task")
    let created = try changeSet(of: store) { try store.createTask(NewTask(title: "Write it down")) }
    #expect(list.send(.changed(created)) == nil)
    #expect(list.model.rows.map(\.title) == ["Buy milk", "Write it down"], "the change was read")
    #expect(list.model.problem == "The task is gone.", "and neither event took the sentence away")
    #expect(list.send(.action(.rowTapped(id))) == nil)
    #expect(list.model.problem == nil)
    #expect(list.model == (try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox, task: .init(head: id)))).model)
}

@Test func aChangeNamingATaskRereadsTheRows() throws {
    let store = try makeStore()
    let list = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox))
    let created = try changeSet(of: store) { try store.createTask(NewTask(title: "Buy milk")) }
    #expect(list.send(.changed(created)) == nil)
    #expect(list.model == (try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox))).model)
    #expect(list.model.rows.map(\.title) == ["Buy milk"])
}

/// The task below is written without its change being delivered, and the change of another view is delivered in
/// its place: a list that read on any change would have seen the task.
@Test func aChangeNamingOnlyAnotherViewReadsNothing() throws {
    let store = try makeStore()
    let list = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox))
    let before = list.model
    try store.createTask(NewTask(title: "Buy milk"))
    let other = try changeSet(of: store) { try store.createView(NewTaskView(title: "Work")) }
    #expect(list.send(.changed(other)) == nil)
    #expect(list.model == before, "the task is missing, which is how a read that never ran shows")
}

/// A deleted tag selects nothing any more, so a view filtered by it loses its tasks, while the change names the
/// tag alone: which tasks a view holds is the query's to say, and the list rereads on a tag too.
@Test func aDeletedTagRereadsTheRowsOfAViewFilteredByIt() throws {
    let store = try makeStore()
    let errand = try store.createTag(title: "Errand")
    let errands = try store.createView(NewTaskView(title: "Errands", filter: .hasTag(errand)))
    let id = try store.createTask(NewTask(title: "Buy milk", tags: [errand]))
    let list = try TaskList(store: store, route: .init(head: errands))
    #expect(list.model.rows.map(\.id) == [id], "the tag is what puts the task in the view; this is the setup")
    let deleted = try changeSet(of: store) { try store.delete(tag: errand) }
    #expect(deleted.tasks.isEmpty && deleted.views.isEmpty, "the change names the tag and nothing else")
    #expect(list.send(.changed(deleted)) == nil)
    #expect(list.model.rows.isEmpty)
}

/// A peer deleted the view and the task open in it, and sync brings both in one change. The list asks to be
/// closed at once, since its parent drops it with its seat: it rereads nothing, or the row would be gone, and
/// hands the change to nobody, or the screen would be.
@Test func aViewDeletedUnderTheListAsksToClose() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskList(store: store, route: .init(head: work, task: .init(head: id)))
    let before = list.model
    let peer = Store.newDeviceID()
    let later = HLC(millis: 1_800_000_000_000, counter: 0)
    let deleted = try changeSet(of: store) {
        _ = try store.apply([
            JournalOperation(entity: .view, entityID: work.rawValue, field: "deleted", value: Value(true), clock: later, device: peer),
            JournalOperation(entity: .task, entityID: id.rawValue, field: "deleted", value: Value(true), clock: later, device: peer),
        ])
    }
    #expect(list.send(.changed(deleted)) == .closeRequested)
    #expect(list.model == before)
}

/// The task screen asks to be closed, and the list drops it and stays, on the rows read again without the task.
@Test func aTaskDeletedUnderTheOpenScreenClosesItAndKeepsTheList() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let kept = try store.createTask(NewTask(title: "Call the bank"))
    let list = try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox, task: .init(head: id)))
    let deleted = try changeSet(of: store) { try store.delete(task: id) }
    #expect(list.send(.changed(deleted)) == nil, "the list's view is still there")
    #expect(list.model == (try TaskList(store: store, route: .init(head: BuiltInTaskViews.inbox))).model)
    #expect(list.model.rows.map(\.id) == [kept])
    #expect(list.route == .init(head: BuiltInTaskViews.inbox))
}

/// The view is still there and its tasks can no longer be listed. The list keeps the rows and the open task, says
/// the tasks could not be read and the list may be out of date, and the next tap on a row it holds takes the
/// sentence away.
@Test func aRereadThatFailsKeepsTheRowsAndSaysSo() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskList(store: store, route: .init(head: work, task: .init(head: id)))
    let before = list.model
    #expect(list.send(.changed(try unreadableFilter(on: work, in: store))) == nil, "the view is there, so the list stays")
    #expect(list.model.rows == before.rows)
    #expect(list.model.task == before.task)
    #expect(list.model.problem == "The tasks could not be read, so this list may be out of date.")
    #expect(list.send(.action(.rowTapped(id))) == nil)
    #expect(list.model == before)
}

/// A change answers for nobody, so a reread that fails says nothing over a sentence already on screen, here the
/// one a link to a task that is gone left: that sentence answered something, and "may be out of date" would take
/// its place, as the sidebar has it.
@Test func aRereadThatFailsLeavesTheSentenceOnScreen() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    let gone = try store.createTask(NewTask(title: "Buy milk"))
    try store.delete(task: gone)
    let list = try TaskList(store: store, route: .init(head: work))
    #expect(list.send(.route(.init(head: work, task: .init(head: gone)))) == nil)
    #expect(list.model.problem == "The task is gone.", "the sentence is the setup; without it this proves nothing")
    let told = list.model
    #expect(list.send(.changed(try unreadableFilter(on: work, in: store))) == nil)
    #expect(list.model == told)
}

/// A newer app on a peer gives the view a filter this one cannot read, and the change of that write comes back:
/// the view is still there, so the list stays, and `tasks(in:today:)` refuses it with `.viewNeedsNewerApp`.
private func unreadableFilter(on view: ViewID, in store: Store) throws -> ChangeSet {
    try changeSet(of: store) {
        _ = try store.apply([
            JournalOperation(
                entity: .view, entityID: view.rawValue, field: "filter", value: .text("{\"kind\":\"reminder_soon\"}"),
                clock: HLC(millis: 1_800_000_000_000, counter: 0), device: Store.newDeviceID()
            ),
        ])
    }
}
