import Testing
import TestSupport
import FeatureModule
import TaskListFeature
import TaskScreenFeature
import TodoCore
import SQLiteKit

private let inbox = BuiltInTaskViews.inbox

/// The model of a list made now on a view, with nothing declared over it, which is what a list is compared with
/// after an event: the rows as a read now answers them and no sentence.
private func listOn(_ view: ViewID, in store: Store) throws -> TaskList.Model {
    try TaskList(store: store, route: .init(head: view)).model
}

/// The rows are the query's answer in the query's order, which is the rank and not the order the tasks were
/// written in, and a task the view does not select has no row.
@Test func aListShowsTheViewsTasksInQueryOrder() throws {
    let store = try makeStore()
    let first = try store.createTask(NewTask(title: "First"))
    let second = try store.createTask(NewTask(title: "Second"))
    let third = try store.createTask(NewTask(title: "Third"), at: .start)
    try store.createTask(NewTask(title: "Someday", when: Day(year: 2030, month: 1, day: 1)))
    let list = try TaskList(store: store, route: .init(head: inbox))
    let query = try store.tasks(in: inbox, today: Day(millisSinceEpoch: Store.systemNow()))
    #expect(list.model.rows.map(\.id) == query.map(\.id))
    #expect(list.model.rows.map(\.id) == [third, first, second], "a task with a day is not the Inbox's")
    #expect(list.model.rows.map(\.title) == ["Third", "First", "Second"])
    #expect(list.model.problem == nil)
    #expect(list.destination.pushed == nil)
    #expect(list.route == .init(head: inbox))
}

/// A list on a view that is gone is not made, and its `init` says which view it looked for: the stack keeps what
/// was open, and the list's opener says so (spec section 2).
@Test func aListOnAGoneViewIsNotMade() throws {
    let store = try makeStore()
    let gone = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    try store.delete(view: gone)
    #expect(throws: StoreError.notFound(gone)) { try TaskList(store: store, route: .init(head: gone)) }
    let unknown = ViewID()
    #expect(throws: StoreError.notFound(unknown)) { try TaskList(store: store, route: .init(head: unknown)) }
}

/// A link to a task, or a window restored onto one, makes the list with the task declared over it, which the
/// window's stack then makes (spec section 3): the list holds no screen and draws none, and its route names the
/// task it declared. Being created afterwards moves nothing, the declaration included.
@Test func aListCreatedWithATaskDeclaresIt() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let route = TaskList.Route(head: inbox, task: .init(head: id))
    let list = try TaskList(store: store, route: route)
    #expect(list.destination.pushed == route.task)
    #expect(list.model == (try listOn(inbox, in: store)), "the rows and no sentence: the task is the stack's to make")
    #expect(list.route == route)
    let before = list.model
    #expect(list.send(.created) == nil)
    #expect(list.model == before)
    #expect(list.destination.pushed == route.task)
}

/// A tap on a row declares the row's task, the route a link to it declares, so what a tap opens and what a link
/// opens are one thing, and the route says so.
@Test func aTapDeclaresTheTaskAndTheRouteSaysSo() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    try store.createTask(NewTask(title: "Call the bank"))
    let list = try TaskList(store: store, route: .init(head: inbox))
    #expect(list.send(.action(.rowTapped(id))) == nil)
    let linked = try TaskList(store: store, route: .init(head: inbox, task: .init(head: id)))
    #expect(list.destination.pushed == TaskScreen.Route(head: id))
    #expect(list.model == linked.model, "what a tap opens and what a link opens are one thing")
    #expect(list.route == linked.route)
    #expect(list.route == .init(head: inbox, task: .init(head: id)))
}

/// A row the list does not hold is no row to tap, even for a task the store would open: this one was written
/// after the list read its rows, and its change has not arrived. Nothing moves, the destination and the sentence
/// included.
@Test func aTapOnARowNotInTheListOpensNothing() throws {
    let store = try makeStore()
    let gone = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskList(store: store, route: .init(head: inbox, task: .init(head: gone)))
    try store.delete(task: gone)
    _ = list.send(.notOpened(.notFound(gone), stillOpen: nil))
    let told = list.model
    #expect(told.problem != nil, "the sentence is the setup; without it this proves nothing about it")
    let unread = try store.createTask(NewTask(title: "Call the bank"))
    #expect(list.send(.action(.rowTapped(unread))) == nil)
    #expect(list.model == told)
    #expect(list.destination.pushed == nil)
    #expect(list.route == .init(head: inbox))
}

/// The person went back to the list: the task screen is gone already, so the list empties its destination, which
/// it cannot keep (spec section 3). It is a gesture on the screen that covered the list, so it leaves the list's
/// sentence: one written while the screen was up, here by a link to a task that is gone, is first seen when the
/// list is uncovered.
@Test func uncoveredEmptiesTheDestinationAndLeavesTheSentence() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let gone = try store.createTask(NewTask(title: "Call the bank"))
    try store.delete(task: gone)
    let list = try TaskList(store: store, route: .init(head: inbox, task: .init(head: open)))
    _ = list.send(.route(.init(head: inbox, task: .init(head: gone))))
    _ = list.send(.notOpened(.notFound(gone), stillOpen: .init(head: open)))
    #expect(list.destination.pushed == .init(head: open), "the screen that was open stays; this is the setup")
    let told = list.model
    #expect(told.problem == "The task is gone.", "the sentence is the setup; without it this proves nothing")
    #expect(list.send(.uncovered) == nil)
    #expect(list.destination.pushed == nil)
    #expect(list.model == told)
    #expect(list.route == .init(head: inbox))
}

/// A route the stack hands a list it keeps, a link or a click on the list's view in the sidebar, declares the
/// route's task, another one or none, and takes the sentence away at its start, as a tap does: the sentence on
/// screen answered something earlier (owner, 2026-10-16). A task the route names that cannot be made is the
/// stack's to find, and its `.notOpened` writes a fresh sentence.
@Test func aRouteDeclaresItsTaskAndTakesTheSentenceAway() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let other = try store.createTask(NewTask(title: "Call the bank"))
    let gone = try store.createTask(NewTask(title: "File the expenses"))
    try store.delete(task: gone)
    let list = try TaskList(store: store, route: .init(head: inbox, task: .init(head: open)))
    _ = list.send(.route(.init(head: inbox, task: .init(head: gone))))
    _ = list.send(.notOpened(.notFound(gone), stillOpen: .init(head: open)))
    #expect(list.model.problem == "The task is gone.", "the sentence is the setup; without it this proves nothing")
    #expect(list.send(.route(.init(head: inbox, task: .init(head: other)))) == nil)
    #expect(list.destination.pushed == .init(head: other))
    #expect(list.model == (try listOn(inbox, in: store)))
    #expect(list.route == .init(head: inbox, task: .init(head: other)))
    #expect(list.send(.changed(try unreadableFilter(on: inbox, in: store))) == nil)
    let rows = list.model.rows
    #expect(list.model.problem == "The tasks could not be read, so this list may be out of date.", "a second sentence, for the next route to take away")
    #expect(list.send(.route(.init(head: inbox))) == nil)
    #expect(list.destination.pushed == nil)
    #expect(list.model.rows == rows)
    #expect(list.model.problem == nil)
    #expect(list.route == .init(head: inbox))
}

/// The task screen asks to be closed when its task is gone, and the stack hands the answer to the list, which
/// empties its destination and stays, its sentence with it, since the answer is no gesture. The change that
/// deleted the task rereads the rows and leaves the destination to the screen's answer: what the screen shows is
/// the screen's to read, and the change reaches it from the window, not through the list (ADR-0009, amendment of
/// 2026-10-22, point 2).
@Test func theTasksAnswerToCloseEmptiesTheDestination() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let kept = try store.createTask(NewTask(title: "Call the bank"))
    let gone = try store.createTask(NewTask(title: "File the expenses"))
    try store.delete(task: gone)
    let list = try TaskList(store: store, route: .init(head: inbox, task: .init(head: open)))
    _ = list.send(.route(.init(head: inbox, task: .init(head: gone))))
    _ = list.send(.notOpened(.notFound(gone), stillOpen: .init(head: open)))
    #expect(list.model.problem == "The task is gone.", "the sentence is the setup; without it this proves nothing")
    let deleted = try changeSet(of: store) { try store.delete(task: open) }
    #expect(list.send(.changed(deleted)) == nil, "the list's view is still there")
    #expect(list.model.rows.map(\.id) == [kept])
    #expect(list.destination.pushed == .init(head: open), "the change closed nothing: the screen answers for itself")
    let told = list.model
    #expect(list.send(.answered(.closeRequested)) == nil)
    #expect(list.destination.pushed == nil)
    #expect(list.model == told)
    #expect(list.route == .init(head: inbox))
}

/// What the list declared could not be made, and the stack says why and what still stands over the list, which
/// the list takes back as its destination, so that the declaration is tried once (spec section 2, and "Risks"). A
/// task that is gone reads as "The task is gone.", which is what a link written before a delete, or a tap on a row
/// a peer's delete has not yet reached, looks like from here; any other refusal is the store failing to read a task
/// that may well be there, and calling that "gone" would put on screen something that is not true. The task was
/// deleted after the lists read their rows, so its row is still there to tap.
@Test func aTaskThatCouldNotBeOpenedSaysWhyAndTakesBackWhatStays() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let gone = try store.createTask(NewTask(title: "Call the bank"))
    let tapped = try TaskList(store: store, route: .init(head: inbox, task: .init(head: open)))
    let linked = try TaskList(store: store, route: .init(head: inbox, task: .init(head: gone)))
    let unread = try TaskList(store: store, route: .init(head: inbox, task: .init(head: open)))
    try store.delete(task: gone)
    #expect(tapped.send(.action(.rowTapped(gone))) == nil)
    #expect(tapped.destination.pushed == .init(head: gone), "the tap declared the task; this is the setup")
    #expect(tapped.send(.notOpened(.notFound(gone), stillOpen: .init(head: open))) == nil)
    #expect(tapped.destination.pushed == .init(head: open), "the screen that was open stays")
    #expect(tapped.route == .init(head: inbox, task: .init(head: open)))
    #expect(tapped.model.problem == "The task is gone.")
    #expect(linked.send(.notOpened(.notFound(gone), stillOpen: nil)) == nil)
    #expect(linked.destination.pushed == nil, "made with the task, nothing stands over it")
    #expect(linked.route == .init(head: inbox))
    #expect(linked.model == tapped.model, "a link to the task meets the same refusal")
    #expect(unread.send(.notOpened(.invalid("a read that failed"), stillOpen: .init(head: open))) == nil)
    #expect(unread.destination.pushed == .init(head: open))
    #expect(unread.model.rows == tapped.model.rows)
    #expect(unread.model.problem == "The task could not be read.")
}

/// A change answers for nobody, so it leaves the sentence, and the next tap on a row the list holds takes it away.
@Test func theSentenceOutlivesAChangeAndGoesWithTheNextTap() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let gone = try store.createTask(NewTask(title: "Call the bank"))
    try store.delete(task: gone)
    let list = try TaskList(store: store, route: .init(head: inbox, task: .init(head: gone)))
    _ = list.send(.notOpened(.notFound(gone), stillOpen: nil))
    let created = try changeSet(of: store) { try store.createTask(NewTask(title: "Write it down")) }
    #expect(list.send(.changed(created)) == nil)
    #expect(list.model.rows.map(\.title) == ["Buy milk", "Write it down"], "the change was read")
    #expect(list.model.problem == "The task is gone.", "and it left the sentence")
    #expect(list.send(.action(.rowTapped(id))) == nil)
    #expect(list.model == (try listOn(inbox, in: store)))
    #expect(list.destination.pushed == .init(head: id))
}

@Test func aChangeNamingATaskRereadsTheRows() throws {
    let store = try makeStore()
    let list = try TaskList(store: store, route: .init(head: inbox))
    let created = try changeSet(of: store) { try store.createTask(NewTask(title: "Buy milk")) }
    #expect(list.send(.changed(created)) == nil)
    #expect(list.model == (try listOn(inbox, in: store)))
    #expect(list.model.rows.map(\.title) == ["Buy milk"])
}

/// The task below is written without its change being delivered, and the change of another view is delivered in
/// its place: a list that read on any change would have seen the task.
@Test func aChangeNamingOnlyAnotherViewReadsNothing() throws {
    let store = try makeStore()
    let list = try TaskList(store: store, route: .init(head: inbox))
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

/// A peer deleted the view and the task declared in it, and sync brings both in one change. The list asks to be
/// closed at once, since its opener empties its destination and the stack drops the list with whatever stands
/// over it: it rereads nothing, or the row would be gone, and its destination stays as it was.
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
    #expect(list.destination.pushed == .init(head: id))
}

/// The view is still there and its tasks can no longer be listed. The list keeps the rows and what it declared,
/// says the tasks could not be read and the list may be out of date, and the next tap on a row it holds takes the
/// sentence away.
@Test func aRereadThatFailsKeepsTheRowsAndSaysSo() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskList(store: store, route: .init(head: work, task: .init(head: id)))
    let before = list.model
    #expect(list.send(.changed(try unreadableFilter(on: work, in: store))) == nil, "the view is there, so the list stays")
    #expect(list.model.rows == before.rows)
    #expect(list.model.problem == "The tasks could not be read, so this list may be out of date.")
    #expect(list.destination.pushed == .init(head: id))
    #expect(list.send(.action(.rowTapped(id))) == nil)
    #expect(list.model == before)
    #expect(list.destination.pushed == .init(head: id))
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
    _ = list.send(.route(.init(head: work, task: .init(head: gone))))
    _ = list.send(.notOpened(.notFound(gone), stillOpen: nil))
    #expect(list.model.problem == "The task is gone.", "the sentence is the setup; without it this proves nothing")
    let told = list.model
    #expect(list.send(.changed(try unreadableFilter(on: work, in: store))) == nil)
    #expect(list.model == told)
}


/// A view and a task as the command line prints their ids, the lowercase UUID string of `EntityID`. Fixed, so
/// that a refusal can name them and a failure reads the same on every run.
private let view = ViewID("6f1c2d3e-4a5b-4c6d-8e7f-0a1b2c3d4e5f")
private let task = TaskID("0d9e8f7a-6b5c-4d3e-9f2a-1b0c9d8e7f6a")

/// The list's route reads the path with the list's head at the front, so a path is these segments.
private func read(_ segments: [String]) throws(RouteError) -> TaskList.Route {
    var path = ArraySlice(segments)
    return try TaskList.Route(reading: &path)
}

/// The list's route owns `view/<id>` in a window's path and hands what follows `task` to the task screen's route:
/// it reads the path whole and writes its part and the screen's, ids as the command line prints them.
@Test func theRouteReadsAndWritesViewAndItsIDAndHandsTheRestToTheTask() throws {
    let list = try read(["view", view.rawValue])
    #expect(list == .init(head: view))
    #expect(list.segments == ["view", view.rawValue])
    let open = try read(["view", view.rawValue, "task", task.rawValue])
    #expect(open == .init(head: view, task: .init(head: task)))
    #expect(open.segments == ["view", view.rawValue, "task", task.rawValue])
    #expect(try read(["view", view.rawValue.uppercased(), "task", task.rawValue.uppercased()]) == open, "ids read in either case")
}

/// A task is opened inside a view's list, so it has no place before one (spec section 2).
@Test func theRouteRefusesTaskBeforeView() {
    #expect(throws: RouteError.segmentOutOfPlace("task")) { try read(["task", task.rawValue]) }
    #expect(throws: RouteError.segmentOutOfPlace("task")) { try read(["task", task.rawValue, "view", view.rawValue]) }
}

/// A segment the list's route has no place for refuses the whole route and is named, wherever it stands, and a
/// word is case-sensitive.
@Test func theRouteRefusesASegmentItHasNoPlaceFor() {
    #expect(throws: RouteError.unknownSegment("list")) { try read(["list", view.rawValue]) }
    #expect(throws: RouteError.unknownSegment("tag")) { try read(["view", view.rawValue, "tag", task.rawValue]) }
    #expect(throws: RouteError.unknownSegment("edit")) { try read(["view", view.rawValue, "task", task.rawValue, "edit"]) }
    #expect(throws: RouteError.unknownSegment("View")) { try read(["View", view.rawValue]) }
}

/// What stands where the view's id must and does not read whole as one is refused as written, and `view` with
/// nothing after it has an empty one; `UUID(uuidString:)` stops reading at a NUL, so an id with one is refused
/// too. The task's id is read by the task screen's route (`TaskScreenTests`), and its refusal reaches this route's
/// reader as thrown.
@Test func theRouteRefusesWhatIsNotAnID() {
    #expect(throws: RouteError.notAnID("inbox")) { try read(["view", "inbox"]) }
    #expect(throws: RouteError.notAnID("\(view)x")) { try read(["view", "\(view)x"]) }
    #expect(throws: RouteError.notAnID("")) { try read(["view"]) }
    #expect(throws: RouteError.notAnID("\(view)\u{0}junk")) { try read(["view", "\(view)\u{0}junk"]) }
    #expect(throws: RouteError.notAnID("42")) { try read(["view", view.rawValue, "task", "42"]) }
}

/// A list has one view and one task open in it, so `view` and `task` each have one place, and a second one is
/// out of it, as `view` is after the task.
@Test func theRouteRefusesAWordASecondTime() {
    #expect(throws: RouteError.segmentOutOfPlace("view")) { try read(["view", view.rawValue, "view", view.rawValue]) }
    #expect(throws: RouteError.segmentOutOfPlace("task")) { try read(["view", view.rawValue, "task", task.rawValue, "task", task.rawValue]) }
    #expect(throws: RouteError.segmentOutOfPlace("view")) { try read(["view", view.rawValue, "task", task.rawValue, "view", view.rawValue]) }
}

/// The empty segment a doubled or trailing slash leaves is no segment the route has a place for, the place of an
/// id included.
@Test func theRouteRefusesAnEmptySegment() {
    #expect(throws: RouteError.unknownSegment("")) { try read(["", "view", view.rawValue]) }
    #expect(throws: RouteError.unknownSegment("")) { try read(["view", ""]) }
    #expect(throws: RouteError.unknownSegment("")) { try read(["view", "", view.rawValue]) }
    #expect(throws: RouteError.unknownSegment("")) { try read(["view", view.rawValue, ""]) }
    #expect(throws: RouteError.unknownSegment("")) { try read(["view", view.rawValue, "", "task", task.rawValue]) }
    #expect(throws: RouteError.unknownSegment("")) { try read(["view", view.rawValue, "task", task.rawValue, ""]) }
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
