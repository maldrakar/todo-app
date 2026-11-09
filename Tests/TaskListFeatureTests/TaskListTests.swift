import Testing
import TestSupport
import FeatureModule
import TaskListFeature
import TaskScreenFeature
import TodoCore
import SQLiteKit

private let inbox = BuiltInTaskViews.inbox

/// The route of a list on a view, with the task screen declared over it when a task is named: what a link to the list
/// or to a task in it carries.
private func on(_ view: ViewID, task: TaskID? = nil) -> TaskList.Route {
    TaskList.Route(head: .init(view: view), tail: task.map { .task(TaskScreen.Route(head: $0)) })
}

/// The ids of the rows a model draws, in their order.
private func ids(of model: TaskList.Model) -> [TaskID] {
    rows(of: model).map(\.id)
}

/// The titles of the rows a model draws, in their order.
private func titles(of model: TaskList.Model) -> [String] {
    rows(of: model).map(\.title)
}

/// The model of a list made now on a view, with nothing declared over it, which is what a list is compared with
/// after an event: the rows as a read now answers them on the day, the test's unless another is named, and no
/// sentence.
private func listOn(_ view: ViewID, in store: Store, on day: DeviceDay = testDay) throws -> TaskList.Model {
    try TaskList(store: store, route: on(view), day: day, width: .narrow).model
}

/// The rows are the query's answer in the query's order, which is the rank and not the order the tasks were
/// written in, and a task the view does not select has no row.
@Test func aListShowsTheViewsTasksInQueryOrder() throws {
    let store = try makeStore()
    let first = try store.createTask(NewTask(title: "First"))
    let second = try store.createTask(NewTask(title: "Second"))
    let third = try store.createTask(NewTask(title: "Third"), at: .start)
    try store.createTask(NewTask(title: "Someday", when: Day(year: 2030, month: 1, day: 1)))
    let list = try TaskList(store: store, route: on(inbox), day: testDay, width: .narrow)
    let query = try store.tasks(in: inbox, today: testDay.day)
    #expect(ids(of: list.model) == query.map(\.id))
    #expect(ids(of: list.model) == [third, first, second], "a task with a day is not the Inbox's")
    #expect(titles(of: list.model) == ["Third", "First", "Second"])
    #expect(list.model.problem == nil)
    #expect(list.destination.pushed == nil)
    #expect(list.route == on(inbox))
}

/// The list is titled by its view, as the sidebar names it, which its view draws as the screen's title, so the back
/// button's menu over a task names the list (#126).
@Test func aListIsTitledByItsView() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    #expect(try TaskList(store: store, route: on(inbox), day: testDay, width: .narrow).model.header.title.text == "Inbox")
    #expect(try TaskList(store: store, route: on(work), day: testDay, width: .narrow).model.header.title.text == "Work")
}

/// A list on a view that is gone is not made, and its `init` says which view it looked for: the stack keeps what
/// was open, and the list's opener says so (spec section 2).
@Test func aListOnAGoneViewIsNotMade() throws {
    let store = try makeStore()
    let gone = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    try store.delete(view: gone)
    #expect(throws: StoreError.notFound(gone)) { try TaskList(store: store, route: on(gone), day: testDay, width: .narrow) }
    let unknown = ViewID()
    #expect(throws: StoreError.notFound(unknown)) { try TaskList(store: store, route: on(unknown), day: testDay, width: .narrow) }
}

/// A link to a task, or a window restored onto one, makes the list with the task declared over it, which the
/// window's stack then makes (spec section 3): the list holds no screen and draws none, and its route names the
/// task it declared. Being created afterwards moves nothing, the declaration included.
@Test func aListCreatedWithATaskDeclaresIt() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let route = on(inbox, task: id)
    let list = try TaskList(store: store, route: route, day: testDay, width: .narrow)
    #expect(list.destination.pushed == route.tail)
    #expect(list.model == (try listOn(inbox, in: store)), "the rows and no sentence: the task is the stack's to make")
    #expect(list.route == route)
    let before = list.model
    #expect(list.send(.created) == nil)
    #expect(list.model == before)
    #expect(list.destination.pushed == route.tail)
}

/// Open full screen on a card declares the card's task, the route a link to it declares, so what the button opens and what
/// a link opens are one thing, and the route says so.
@Test func aTapDeclaresTheTaskAndTheRouteSaysSo() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    try store.createTask(NewTask(title: "Call the bank"))
    let list = try TaskList(store: store, route: on(inbox), day: testDay, width: .narrow)
    #expect(list.send(.action(.rowTapped(id))) == nil)
    #expect(list.destination.pushed == nil, "a tap opens the card in place")
    #expect(list.send(.action(.openFullScreenTapped)) == nil)
    let linked = try TaskList(store: store, route: on(inbox, task: id), day: testDay, width: .narrow)
    #expect(linked.send(.action(.rowTapped(id))) == nil)
    #expect(list.destination.pushed == .task(TaskScreen.Route(head: id)))
    #expect(list.model == linked.model, "what the button opens and what a link opens are one thing")
    #expect(list.route == linked.route)
    #expect(list.route == on(inbox, task: id))
}

/// A row the list does not hold is no row to tap, even for a task the store would open: this one was written
/// after the list read its rows, and its change has not arrived. Nothing moves, the destination and the sentence
/// included.
@Test func aTapOnARowNotInTheListOpensNothing() throws {
    let store = try makeStore()
    let gone = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskList(store: store, route: on(inbox, task: gone), day: testDay, width: .narrow)
    try store.delete(task: gone)
    _ = list.send(.notOpened(.notFound(gone), stillOpen: nil))
    let told = list.model
    #expect(told.problem != nil, "the sentence is the setup; without it this proves nothing about it")
    let unread = try store.createTask(NewTask(title: "Call the bank"))
    #expect(list.send(.action(.rowTapped(unread))) == nil)
    #expect(list.model == told)
    #expect(list.destination.pushed == nil)
    #expect(list.route == on(inbox))
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
    let list = try TaskList(store: store, route: on(inbox, task: open), day: testDay, width: .narrow)
    _ = list.send(.route(on(inbox, task: gone)))
    _ = list.send(.notOpened(.notFound(gone), stillOpen: .task(.init(head: open))))
    #expect(list.destination.pushed == .task(.init(head: open)), "the screen that was open stays; this is the setup")
    let told = list.model
    #expect(told.problem == "The task is gone.", "the sentence is the setup; without it this proves nothing")
    #expect(list.send(.uncovered) == nil)
    #expect(list.destination.pushed == nil)
    #expect(list.model == told)
    #expect(list.route == on(inbox))
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
    let list = try TaskList(store: store, route: on(inbox, task: open), day: testDay, width: .narrow)
    _ = list.send(.route(on(inbox, task: gone)))
    _ = list.send(.notOpened(.notFound(gone), stillOpen: .task(.init(head: open))))
    #expect(list.model.problem == "The task is gone.", "the sentence is the setup; without it this proves nothing")
    #expect(list.send(.route(on(inbox, task: other))) == nil)
    #expect(list.destination.pushed == .task(.init(head: other)))
    #expect(list.model == (try listOn(inbox, in: store)))
    #expect(list.route == on(inbox, task: other))
    #expect(list.send(.changed(try unreadableFilter(on: inbox, in: store))) == nil)
    let layout = list.model.layout
    #expect(list.model.problem == "The tasks could not be read, so this list may be out of date.", "a second sentence, for the next route to take away")
    #expect(list.send(.route(on(inbox))) == nil)
    #expect(list.destination.pushed == nil)
    #expect(list.model.layout == layout)
    #expect(list.model.problem == nil)
    #expect(list.route == on(inbox))
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
    let list = try TaskList(store: store, route: on(inbox, task: open), day: testDay, width: .narrow)
    _ = list.send(.route(on(inbox, task: gone)))
    _ = list.send(.notOpened(.notFound(gone), stillOpen: .task(.init(head: open))))
    #expect(list.model.problem == "The task is gone.", "the sentence is the setup; without it this proves nothing")
    let deleted = try changeSet(of: store) { try store.delete(task: open) }
    #expect(list.send(.changed(deleted)) == nil, "the list's view is still there")
    #expect(ids(of: list.model) == [kept])
    #expect(list.destination.pushed == .task(.init(head: open)), "the change closed nothing: the screen answers for itself")
    let told = list.model
    #expect(list.send(.destinationAnswered(.task(.closeRequested))) == nil)
    #expect(list.destination.pushed == nil)
    #expect(list.model == told)
    #expect(list.route == on(inbox))
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
    let tapped = try TaskList(store: store, route: on(inbox, task: open), day: testDay, width: .narrow)
    let linked = try TaskList(store: store, route: on(inbox, task: gone), day: testDay, width: .narrow)
    let unread = try TaskList(store: store, route: on(inbox, task: open), day: testDay, width: .narrow)
    for list in [tapped, linked, unread] { #expect(list.send(.action(.rowTapped(gone))) == nil) }
    try store.delete(task: gone)
    #expect(tapped.send(.action(.openFullScreenTapped)) == nil)
    #expect(tapped.destination.pushed == .task(.init(head: gone)), "the button declared the task; this is the setup")
    #expect(tapped.send(.notOpened(.notFound(gone), stillOpen: .task(.init(head: open)))) == nil)
    #expect(tapped.destination.pushed == .task(.init(head: open)), "the screen that was open stays")
    #expect(tapped.route == on(inbox, task: open))
    #expect(tapped.model.problem == "The task is gone.")
    #expect(linked.send(.notOpened(.notFound(gone), stillOpen: nil)) == nil)
    #expect(linked.destination.pushed == nil, "made with the task, nothing stands over it")
    #expect(linked.route == on(inbox))
    #expect(linked.model == tapped.model, "a link to the task meets the same refusal")
    #expect(unread.send(.notOpened(.invalid("a read that failed"), stillOpen: .task(.init(head: open)))) == nil)
    #expect(unread.destination.pushed == .task(.init(head: open)))
    #expect(unread.model.layout == tapped.model.layout)
    #expect(unread.model.problem == "The task could not be read.")
}

/// A link to a list over a list, or to one of a list's groups, makes the list with that list declared over it, which
/// the window's stack then makes, as it makes a task (ADR-0009, amendments of 2026-11-01 and 2026-11-02): the list holds
/// no screen, and its route names what it declared.
@Test func aListCreatedWithAListOverItDeclaresIt() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    let route = TaskList.Route(head: .init(view: inbox), tail: .list(on(work)))
    let list = try TaskList(store: store, route: route, day: testDay, width: .narrow)
    #expect(list.destination.pushed == .list(on(work)))
    #expect(list.route == route)
    #expect(list.model == (try listOn(inbox, in: store)), "what stands over the list is the stack's to make")
    let grouped = TaskList.Route(
        head: .init(view: BuiltInTaskViews.upcoming),
        tail: .list(TaskList.Route(head: .init(view: BuiltInTaskViews.upcoming, group: .day(1))))
    )
    #expect(try TaskList(store: store, route: grouped, day: testDay, width: .narrow).destination.pushed == grouped.tail)
}

/// A list opened over this one asks to be closed when its view is gone, and the stack hands the answer to this list,
/// which declares nothing over it and stays, as it does for the task screen's answer.
@Test func theListOverTheListAnswersToCloseAndEmptiesTheDestination() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    let list = try TaskList(store: store, route: TaskList.Route(head: .init(view: inbox), tail: .list(on(work))), day: testDay, width: .narrow)
    let before = list.model
    #expect(list.send(.destinationAnswered(.list(.closeRequested))) == nil)
    #expect(list.destination.pushed == nil)
    #expect(list.model == before)
    #expect(list.route == on(inbox))
}

/// What the list declared over itself could not be made, and the sentence says what it was, read off what the list
/// declared before it takes back what stays: a list inside that is gone, or that could not be read; a group of a
/// grouping the list does not have, whose tag or parent is gone, or that could not be read; and a task, as before.
@Test func whatCouldNotBeOpenedOverTheListIsWhatTheSentenceNames() throws {
    let store = try makeStore()
    let gone = ViewID()
    let list = try TaskList(store: store, route: on(inbox), day: testDay, width: .narrow)
    let overAList = TaskList.Route(head: .init(view: inbox), tail: .list(on(gone)))
    let overAGroup = TaskList.Route(
        head: .init(view: inbox), tail: .list(TaskList.Route(head: .init(view: inbox, group: .day(1))))
    )
    let cases: [(declared: TaskList.Route, error: StoreError, sentence: String)] = [
        (overAList, .notFound(gone), "The list is gone."),
        (overAList, .viewNeedsNewerApp(gone, kind: "reminder_soon"), "The list could not be opened."),
        (overAGroup, .invalid("not grouped by day"), "This list is not grouped that way, so the group could not be opened."),
        (overAGroup, .notFound(TagID()), "The group is gone."),
        (overAGroup, .sqlite(SQLiteError(code: 1, message: "a read that failed")), "The group could not be opened."),
        (on(inbox, task: TaskID()), .notFound(TaskID()), "The task is gone."),
    ]
    for row in cases {
        _ = list.send(.route(row.declared))
        #expect(list.send(.notOpened(row.error, stillOpen: nil)) == nil)
        #expect(list.model.problem == row.sentence, "after \(row.error)")
        #expect(list.destination.pushed == nil, "what still stands is taken back")
    }
}

/// A change answers for nobody, so it leaves the sentence, and the next tap on a row the list holds takes it away.
@Test func theSentenceOutlivesAChangeAndGoesWithTheNextTap() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let gone = try store.createTask(NewTask(title: "Call the bank"))
    try store.delete(task: gone)
    let list = try TaskList(store: store, route: on(inbox, task: gone), day: testDay, width: .narrow)
    _ = list.send(.notOpened(.notFound(gone), stillOpen: nil))
    let created = try changeSet(of: store) { try store.createTask(NewTask(title: "Write it down")) }
    #expect(list.send(.changed(created)) == nil)
    #expect(titles(of: list.model) == ["Buy milk", "Write it down"], "the change was read")
    #expect(list.model.problem == "The task is gone.", "and it left the sentence")
    #expect(list.send(.action(.rowTapped(id))) == nil)
    #expect(list.model.problem == nil, "the tap took it")
    #expect(list.send(.action(.backgroundTapped)) == nil)
    #expect(list.model == (try listOn(inbox, in: store)))
}

@Test func aChangeNamingATaskRereadsTheRows() throws {
    let store = try makeStore()
    let list = try TaskList(store: store, route: on(inbox), day: testDay, width: .narrow)
    let created = try changeSet(of: store) { try store.createTask(NewTask(title: "Buy milk")) }
    #expect(list.send(.changed(created)) == nil)
    #expect(list.model == (try listOn(inbox, in: store)))
    #expect(titles(of: list.model) == ["Buy milk"])
}

/// A rename of the view, in the sidebar or by a peer, is a change naming the view, and the read that tells the list
/// whether its view is still there gives it the new title.
@Test func aRenameOfTheViewRetitlesTheList() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskList(store: store, route: on(work), day: testDay, width: .narrow)
    let renamed = try changeSet(of: store) { try store.update(view: work, [.title("Office")]) }
    #expect(list.send(.changed(renamed)) == nil)
    #expect(list.model.header.title.text == "Office")
    #expect(list.model == (try listOn(work, in: store)))
}

/// A peer renames the view and gives it a filter this app cannot read, and both arrive in one change: the view's
/// read answers the new title, which the list takes, and the read of its tasks fails, so the rows stay and the list
/// says they may be out of date.
@Test func aRenameTakesWhenTheRereadOfTheTasksFails() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskList(store: store, route: on(work), day: testDay, width: .narrow)
    let before = list.model
    #expect(list.send(.changed(try unreadableFilter(on: work, in: store, renamedTo: "Office"))) == nil)
    #expect(list.model.header.title.text == "Office")
    #expect(list.model.layout == before.layout)
    #expect(list.model.problem == "The tasks could not be read, so this list may be out of date.")
}

/// A deleted tag selects nothing any more, so a view filtered by it loses its tasks, while the change names the
/// tag alone: which tasks a view holds is the query's to say, and the list rereads on a tag too.
@Test func aDeletedTagRereadsTheRowsOfAViewFilteredByIt() throws {
    let store = try makeStore()
    let errand = try store.createTag(title: "Errand")
    let errands = try store.createView(NewTaskView(title: "Errands", filter: .hasTag(errand)))
    let id = try store.createTask(NewTask(title: "Buy milk", tags: [errand]))
    let list = try TaskList(store: store, route: on(errands), day: testDay, width: .narrow)
    #expect(ids(of: list.model) == [id], "the tag is what puts the task in the view; this is the setup")
    let deleted = try changeSet(of: store) { try store.delete(tag: errand) }
    #expect(deleted.tasks.isEmpty && deleted.views.isEmpty, "the change names the tag and nothing else")
    #expect(list.send(.changed(deleted)) == nil)
    #expect(ids(of: list.model).isEmpty)
}

/// A peer deleted the view and the task declared in it, and sync brings both in one change. The list asks to be
/// closed at once, since its opener empties its destination and the stack drops the list with whatever stands
/// over it: it rereads nothing, or the row would be gone, and its destination stays as it was.
@Test func aViewDeletedUnderTheListAsksToClose() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskList(store: store, route: on(work, task: id), day: testDay, width: .narrow)
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
    #expect(list.destination.pushed == .task(.init(head: id)))
}

/// The view is still there and its tasks can no longer be listed. The list keeps the rows and what it declared,
/// says the tasks could not be read and the list may be out of date, and the next tap on a row it holds takes the
/// sentence away.
@Test func aRereadThatFailsKeepsTheRowsAndSaysSo() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskList(store: store, route: on(work, task: id), day: testDay, width: .narrow)
    let before = list.model
    #expect(list.send(.changed(try unreadableFilter(on: work, in: store))) == nil, "the view is there, so the list stays")
    #expect(list.model.layout == before.layout)
    #expect(list.model.problem == "The tasks could not be read, so this list may be out of date.")
    #expect(list.destination.pushed == .task(.init(head: id)))
    #expect(list.send(.action(.rowTapped(id))) == nil)
    #expect(list.model.problem == nil, "the tap took the sentence away")
    #expect(list.send(.action(.openFullScreenTapped)) == nil)
    #expect(list.destination.pushed == .task(.init(head: id)))
}

/// A change answers for nobody, so a reread that fails says nothing over a sentence already on screen, here the
/// one a link to a task that is gone left: that sentence answered something, and "may be out of date" would take
/// its place, as the sidebar has it.
@Test func aRereadThatFailsLeavesTheSentenceOnScreen() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    let gone = try store.createTask(NewTask(title: "Buy milk"))
    try store.delete(task: gone)
    let list = try TaskList(store: store, route: on(work), day: testDay, width: .narrow)
    _ = list.send(.route(on(work, task: gone)))
    _ = list.send(.notOpened(.notFound(gone), stillOpen: nil))
    #expect(list.model.problem == "The task is gone.", "the sentence is the setup; without it this proves nothing")
    let told = list.model
    #expect(list.send(.changed(try unreadableFilter(on: work, in: store))) == nil)
    #expect(list.model == told)
}

/// A list reads its view's tasks by the day it is given, the device's, and never by a clock of its own (spec section
/// 8): a task due on the test's day is Today's on that day, and on the day before it is tomorrow's, which Today does
/// not select.
@Test func aListReadsItsTasksByTheDayItIsGiven() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Call the bank", when: testDay.day))
    let today = BuiltInTaskViews.today
    #expect(titles(of: try listOn(today, in: store)) == ["Call the bank"])
    #expect(ids(of: try listOn(today, in: store, on: deviceDay(testDay.day.advanced(by: -1)))).isEmpty)
}

/// A new day rereads the tasks, since which tasks a view selects can depend on the day, and moves nothing else: the
/// list is the one made on the new day, and the task declared over it stays declared. It answers nothing.
@Test func aNewDayRereadsTheTasks() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Call the bank", when: testDay.day))
    let route = on(BuiltInTaskViews.today, task: id)
    let list = try TaskList(store: store, route: route, day: deviceDay(testDay.day.advanced(by: -1)), width: .narrow)
    #expect(ids(of: list.model).isEmpty, "the task is tomorrow's; this is the setup")
    #expect(list.send(.dayChanged(testDay)) == nil)
    #expect(list.model == (try listOn(BuiltInTaskViews.today, in: store)))
    #expect(titles(of: list.model) == ["Call the bank"])
    #expect(list.destination.pushed == route.tail)
}

/// A new day answers nobody, so the sentence on screen stays while the rows are read again: here the one a link to a
/// task that is gone left, which answered something the person did.
@Test func aNewDayLeavesTheSentenceOnScreen() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Call the bank", when: testDay.day))
    let gone = try store.createTask(NewTask(title: "Buy milk"))
    try store.delete(task: gone)
    let today = BuiltInTaskViews.today
    let list = try TaskList(store: store, route: on(today), day: deviceDay(testDay.day.advanced(by: -1)), width: .narrow)
    _ = list.send(.route(on(today, task: gone)))
    _ = list.send(.notOpened(.notFound(gone), stillOpen: nil))
    #expect(list.model.problem == "The task is gone.", "the sentence is the setup; without it this proves nothing")
    #expect(ids(of: list.model).isEmpty, "the task is tomorrow's; this is the setup")
    #expect(list.send(.dayChanged(testDay)) == nil)
    #expect(titles(of: list.model) == ["Call the bank"])
    #expect(list.model.problem == "The task is gone.")
}

/// The day the list already has, told again, reads nothing: a task written since, with no change sent, stays out of
/// the rows, where a list made anew reads it, so a reread would have shown it. A new day then reads it.
@Test func theSameDayAgainReadsNothing() throws {
    let store = try makeStore()
    let list = try TaskList(store: store, route: on(inbox), day: testDay, width: .narrow)
    let before = list.model
    try store.createTask(NewTask(title: "Buy milk"))
    #expect(list.send(.dayChanged(testDay)) == nil)
    #expect(list.model == before)
    #expect(list.model != (try listOn(inbox, in: store)), "a list made anew reads the task")
    let next = deviceDay(testDay.day.advanced(by: 1))
    #expect(list.send(.dayChanged(next)) == nil)
    #expect(list.model == (try listOn(inbox, in: store, on: next)))
}

/// A new day whose read fails leaves the rows on screen, as a change's reread that fails does, and says they may be
/// out of date, since no sentence was on screen.
@Test func aNewDayWhoseReadFailsKeepsTheRowsAndSaysSo() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", filter: .status([.open])))
    try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskList(store: store, route: on(work), day: testDay, width: .narrow)
    let before = list.model
    _ = try unreadableFilter(on: work, in: store)
    #expect(list.send(.dayChanged(deviceDay(testDay.day.advanced(by: 1)))) == nil)
    #expect(list.model.layout == before.layout)
    #expect(list.model.problem == "The tasks could not be read, so this list may be out of date.")
}

/// A view, a second one, a task and a tag as the command line prints their ids, the lowercase UUID string of
/// `EntityID`. Fixed, so that a refusal can name them and a failure reads the same on every run.
private let view = ViewID("6f1c2d3e-4a5b-4c6d-8e7f-0a1b2c3d4e5f")
private let other = ViewID("2b3c4d5e-6f70-4182-93a4-b5c6d7e8f901")
private let task = TaskID("0d9e8f7a-6b5c-4d3e-9f2a-1b0c9d8e7f6a")
private let tag = TagID("7a6b5c4d-3e2f-4a1b-8c9d-0e1f2a3b4c5d")

/// The list's route reads the path with the list's head at the front, so a path is these segments.
private func read(_ segments: [String]) throws(RouteError) -> TaskList.Route {
    var path = ArraySlice(segments)
    return try TaskList.Route(reading: &path)
}

/// The route of one of a list's own groups opened over the list, with the task screen over the group when a task is
/// named: what `view/<id>/<word>/<key>` reads as.
private func group(_ group: TaskList.Route.Group, of view: ViewID, task: TaskID? = nil) -> TaskList.Route {
    TaskList.Route(
        head: .init(view: view),
        tail: .list(TaskList.Route(head: .init(view: view, group: group), tail: task.map { .task(.init(head: $0)) }))
    )
}

/// The list's route owns `view/<id>` in a window's path and hands what follows `task` to the task screen's route:
/// it reads the path whole and writes its part and the screen's, ids as the command line prints them.
@Test func theRouteReadsAndWritesViewAndItsIDAndHandsTheRestToTheTask() throws {
    let list = try read(["view", view.rawValue])
    #expect(list == on(view))
    #expect(list.segments == ["view", view.rawValue])
    let open = try read(["view", view.rawValue, "task", task.rawValue])
    #expect(open == on(view, task: task))
    #expect(open.segments == ["view", view.rawValue, "task", task.rawValue])
    #expect(try read(["view", view.rawValue.uppercased(), "task", task.rawValue.uppercased()]) == open, "ids read in either case")
}

/// A list opened over a list, a block's title tapped, is `view/…` after the list's own `view/<id>`, and the list over
/// it holds its own part of the path, a group of its own among it (ADR-0009, amendments of 2026-11-01 and 2026-11-02).
@Test func theRouteReadsAListOverAList() throws {
    let path = ["view", view.rawValue, "view", other.rawValue]
    let chain = try read(path)
    #expect(chain == TaskList.Route(head: .init(view: view), tail: .list(on(other))))
    #expect(chain.segments == path)
    let grouped = ["view", view.rawValue, "view", other.rawValue, "day", "+1"]
    #expect(try read(grouped) == TaskList.Route(head: .init(view: view), tail: .list(group(.day(1), of: other))))
    #expect(try read(grouped).segments == grouped, "a group stands over the list before it, the inner one")
}

/// `/view/a/view/b/task/t` is list a over which list b stands over which task t stands (ADR-0009, amendment of
/// 2026-11-01).
@Test func theRouteReadsATaskOverAListOverAList() throws {
    let path = ["view", view.rawValue, "view", other.rawValue, "task", task.rawValue]
    let chain = try read(path)
    #expect(chain == TaskList.Route(head: .init(view: view), tail: .list(on(other, task: task))))
    #expect(chain.segments == path)
}

/// The task screen holds nothing over itself, so after `view/<id>/task/<id>` a third word has no place, whichever of
/// the route's words it is, and a word the route does not know is unknown.
@Test func theRouteRefusesAThirdWord() {
    #expect(throws: RouteError.segmentOutOfPlace("view")) { try read(["view", view.rawValue, "task", task.rawValue, "view", view.rawValue]) }
    #expect(throws: RouteError.segmentOutOfPlace("task")) { try read(["view", view.rawValue, "task", task.rawValue, "task", task.rawValue]) }
    #expect(throws: RouteError.segmentOutOfPlace("day")) { try read(["view", view.rawValue, "task", task.rawValue, "day", "+1"]) }
    #expect(throws: RouteError.segmentOutOfPlace("status")) {
        try read(["view", view.rawValue, "view", other.rawValue, "task", task.rawValue, "status", "open"])
    }
    #expect(throws: RouteError.unknownSegment("edit")) { try read(["view", view.rawValue, "task", task.rawValue, "edit"]) }
}

/// A path is data from outside, so a chain of lists is read and written by loops over the path and the chain, never a
/// recursion over them (`docs/style.md`): the longest chain a route holds, thirty-two lists with the first, a task over
/// the last, read and walked from the base to the top, and written back as the path; and the same with a group of the
/// thirty-first list as the thirty-second.
@Test func aChainOfListsIsReadAndWrittenWithoutRecursion() throws {
    let lists = (0..<31).map { _ in ViewID() }
    let path = ["view", view.rawValue] + lists.flatMap { ["view", $0.rawValue] } + ["task", task.rawValue]
    let chain = try read(path)
    #expect(chain.segments == path)
    var heads: [ViewID] = [chain.head.view]
    var tail = chain.tail
    while case .list(let route)? = tail {
        heads.append(route.head.view)
        tail = route.tail
    }
    #expect(heads == [view] + lists)
    #expect(tail == .task(.init(head: task)))
}

/// A chain holds at most thirty-two lists, the first included and a group's screen counting as one, since the stack
/// makes a screen for each and comparing and releasing a chain walk it by recursion: the word that would make the
/// thirty-third, a list's or a group's, has no place there (the controller's ruling on #175, 2026-11-04, after the
/// filter's bound, `maximumDepth`).
@Test func aChainLongerThanTheBoundIsRefused() throws {
    let lists = (0..<31).map { _ in ViewID() }
    let longest = ["view", view.rawValue] + lists.flatMap { ["view", $0.rawValue] }
    #expect(try read(longest).segments == longest, "thirty-two lists read")
    #expect(throws: RouteError.segmentOutOfPlace("view")) { try read(longest + ["view", other.rawValue]) }
    #expect(throws: RouteError.segmentOutOfPlace("day")) { try read(longest + ["day", "+1"]) }
    let grouped = Array(longest.dropLast(2)) + ["day", "+1"]
    #expect(try read(grouped).segments == grouped, "a group as the thirty-second list reads")
}

/// A group's address is its grouping's word and its key after its list's `view/<id>`, written alone since its view is
/// its list's, and every address reads back as itself (ADR-0009, amendment of 2026-11-02): a distance signed, `0`
/// today, or `none`, an id as the command line prints it or `none`, a status by its name. A distance is anything a
/// day offset of `Int32` holds.
@Test func theRouteReadsAndWritesEveryGroupsAddress() throws {
    let table: [(word: String, key: String, group: TaskList.Route.Group)] = [
        ("day", "+1", .day(1)), ("day", "0", .day(0)), ("day", "-2", .day(-2)), ("day", "none", .day(nil)),
        ("day", "+2147483647", .day(.max)), ("day", "-2147483648", .day(.min)),
        ("deadline", "+7", .deadline(7)), ("deadline", "0", .deadline(0)), ("deadline", "-1", .deadline(-1)),
        ("deadline", "none", .deadline(nil)),
        ("tag", tag.rawValue, .tag(tag)), ("tag", "none", .tag(nil)),
        ("parent", task.rawValue, .parent(task)), ("parent", "none", .parent(nil)),
        ("status", "open", .status(.open)), ("status", "done", .status(.done)), ("status", "canceled", .status(.canceled)),
    ]
    for row in table {
        let path = ["view", view.rawValue, row.word, row.key]
        #expect(try read(path) == group(row.group, of: view), "reading \(path)")
        #expect(group(row.group, of: view).segments == path)
        let opened = path + ["task", task.rawValue]
        #expect(try read(opened) == group(row.group, of: view, task: task), "reading \(opened)")
        #expect(group(row.group, of: view, task: task).segments == opened)
    }
    #expect(try read(["view", view.rawValue, "tag", tag.rawValue.uppercased()]) == group(.tag(tag), of: view), "ids read in either case")
}

/// A key that does not read is refused as written, so that a link has one spelling: a distance only as `+n`, `0` or
/// `-n`, never `1`, `+0`, `-0` or with a leading zero, and one a day offset of `Int32` holds; a status by one of its
/// three names; and an id read whole through the core, as every id is, with nothing or an empty segment where it must
/// stand refused as the view's id is.
@Test func theRouteRefusesAGroupKeyThatDoesNotRead() {
    for key in ["1", "+0", "-0", "+01", "x", "+", "-", "++1", "+2147483648", "-2147483649", "+99999999999999999999", ""] {
        #expect(throws: RouteError.unknownSegment(key), "day/\(key)") { try read(["view", view.rawValue, "day", key]) }
        #expect(throws: RouteError.unknownSegment(key), "deadline/\(key)") { try read(["view", view.rawValue, "deadline", key]) }
    }
    #expect(throws: RouteError.unknownSegment("")) { try read(["view", view.rawValue, "day"]) }
    #expect(throws: RouteError.unknownSegment("later")) { try read(["view", view.rawValue, "status", "later"]) }
    #expect(throws: RouteError.unknownSegment("none")) { try read(["view", view.rawValue, "status", "none"]) }
    #expect(throws: RouteError.unknownSegment("Open")) { try read(["view", view.rawValue, "status", "Open"]) }
    #expect(throws: RouteError.unknownSegment("")) { try read(["view", view.rawValue, "tag", ""]) }
    #expect(throws: RouteError.notAnID("")) { try read(["view", view.rawValue, "tag"]) }
    #expect(throws: RouteError.notAnID("work")) { try read(["view", view.rawValue, "tag", "work"]) }
    #expect(throws: RouteError.notAnID("42")) { try read(["view", view.rawValue, "parent", "42"]) }
}

/// A group holds no lists, so after a group only the task screen's part may follow: `view` or a second group's word
/// there is out of place (ADR-0009, amendment of 2026-11-02).
@Test func onlyATaskFollowsAGroup() throws {
    #expect(throws: RouteError.segmentOutOfPlace("view")) { try read(["view", view.rawValue, "day", "+1", "view", other.rawValue]) }
    #expect(throws: RouteError.segmentOutOfPlace("day")) { try read(["view", view.rawValue, "day", "+1", "day", "0"]) }
    #expect(throws: RouteError.segmentOutOfPlace("tag")) { try read(["view", view.rawValue, "day", "+1", "tag", "none"]) }
    #expect(try read(["view", view.rawValue, "day", "+1", "task", task.rawValue]) == group(.day(1), of: view, task: task))
}

/// A task is opened inside a view's list, so it has no place before one (spec section 2), and neither has a group.
@Test func theRouteRefusesTaskBeforeView() {
    #expect(throws: RouteError.segmentOutOfPlace("task")) { try read(["task", task.rawValue]) }
    #expect(throws: RouteError.segmentOutOfPlace("task")) { try read(["task", task.rawValue, "view", view.rawValue]) }
    #expect(throws: RouteError.segmentOutOfPlace("day")) { try read(["day", "+1"]) }
}

/// A segment the list's route has no place for refuses the whole route and is named, wherever it stands, and a
/// word is case-sensitive.
@Test func theRouteRefusesASegmentItHasNoPlaceFor() {
    #expect(throws: RouteError.unknownSegment("list")) { try read(["list", view.rawValue]) }
    #expect(throws: RouteError.unknownSegment("note")) { try read(["view", view.rawValue, "note", task.rawValue]) }
    #expect(throws: RouteError.unknownSegment("Day")) { try read(["view", view.rawValue, "Day", "+1"]) }
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
    #expect(throws: RouteError.notAnID("inbox")) { try read(["view", view.rawValue, "view", "inbox"]) }
    #expect(throws: RouteError.notAnID("")) { try read(["view", view.rawValue, "view"]) }
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
    #expect(throws: RouteError.unknownSegment("")) { try read(["view", view.rawValue, "view", ""]) }
    #expect(throws: RouteError.unknownSegment("")) { try read(["view", view.rawValue, "day", "+1", ""]) }
}

/// A newer app on a peer gives the view a filter this one cannot read, and the change of that write comes back:
/// the view is still there, so the list stays, and `tasks(in:today:)` refuses it with `.viewNeedsNewerApp`. Given a
/// title, the same peer renames the view in the same change.
private func unreadableFilter(on view: ViewID, in store: Store, renamedTo title: String? = nil) throws -> ChangeSet {
    let peer = Store.newDeviceID()
    let millis: Int64 = 1_800_000_000_000
    let filter = JournalOperation(
        entity: .view, entityID: view.rawValue, field: "filter", value: .text("{\"kind\":\"reminder_soon\"}"),
        clock: HLC(millis: millis, counter: 0), device: peer
    )
    let rename = title.map {
        JournalOperation(
            entity: .view, entityID: view.rawValue, field: "title", value: .text($0),
            clock: HLC(millis: millis, counter: 1), device: peer
        )
    }
    return try changeSet(of: store) { _ = try store.apply([filter] + (rename.map { [$0] } ?? [])) }
}
