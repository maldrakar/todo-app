import Testing
import TestSupport
import AppFeature
import QuickEntryFeature
import TaskListFeature
import TaskScreenFeature
import TaskViewListFeature
import TodoCore

private typealias Route = AppModule.Route

private let inbox = BuiltInTaskViews.inbox

/// The titles of the Inbox as the store holds them, where quick entry files what it creates. The Inbox's filter
/// reads no day, so the day asked about is a fixed one and not the wall clock.
private func inboxTitles(of store: Store) throws -> [String] {
    try store.tasks(in: inbox, today: Day(year: 2026, month: 10, day: 16)).map(\.title)
}

/// A view that lists the tasks carrying one tag, with its tag, so that a test can put a task in it.
private func taggedView(_ title: String, in store: Store) throws -> (view: ViewID, tag: TagID) {
    let tag = try store.createTag(title: title.lowercased())
    return (try store.createView(NewTaskView(title: title, filter: .hasTag(tag))), tag)
}

/// A store with one task in the Inbox and one deleted from it, the two a link can name there: the list's own
/// sentence after a link to the deleted one is what a test tells one list instance from another by, since a
/// list opened afresh on the open one starts without it.
private func storeWithAGoneTask() throws -> (store: Store, open: TaskID, gone: TaskID) {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let gone = try store.createTask(NewTask(title: "Call the bank"))
    try store.delete(task: gone)
    return (store, open, gone)
}

/// The default window names no view, so the sidebar chooses the Inbox itself, says so in answer to `.created`,
/// and the pane opens on that answer: the root names no view of its own (ADR-0006, amendment of 2026-10-03).
@Test func theDefaultWindowOpensThePaneOnTheSidebarsChoice() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: .default)
    #expect(app.model.taskViewList.selection == inbox)
    #expect(app.model.taskList == (try TaskList(store: store, route: .init(head: inbox))).model)
    #expect(app.model.taskList?.rows.map(\.title) == ["Buy milk"])
    #expect(app.model.quickEntry == nil)
    #expect(app.model.problem == nil)
    #expect(app.route.text == "/view/\(inbox)")
}

/// A person who deleted the Inbox leaves the sidebar starting on no row: it answers `.created` with nothing, no
/// pane opens, nothing is said, and the launch goes ahead.
@Test func theDefaultWindowWithNoInboxOpensNoPane() throws {
    let store = try makeStore()
    try store.delete(view: inbox)
    let app = try AppModule(store: store, route: .default)
    #expect(app.model.taskViewList.selection == nil)
    #expect(app.model.taskList == nil)
    #expect(app.model.problem == nil)
    #expect(app.route == .default)
}

/// `init` has told the children already, so `.created`, sent to the root once it is made, has nothing left to say.
@Test func theRootsOwnCreatedAnswersNothingAndMovesNothing() throws {
    let (store, open, _) = try storeWithAGoneTask()
    let app = try AppModule(store: store, route: try Route(text: "/view/\(inbox)/task/\(open)?quick-entry"))
    let model = app.model
    let route = app.route
    #expect(app.send(.created) == nil)
    #expect(app.model == model)
    #expect(app.route == route)
}

/// A link made into a window: the sidebar's answer to `.created` opens the pane on the view, and the route's
/// pane, which names the same view, finds it there and opens the task in it (spec section 4). Applied the other
/// way round, the sidebar's answer would reach a list with the task open and close it.
@Test func theRootCreatedFromALinkFindsThePaneAlreadyThere() throws {
    let store = try makeStore()
    let today = BuiltInTaskViews.today
    let id = try store.createTask(NewTask(title: "Call the bank", when: Day(millisSinceEpoch: Store.systemNow())))
    let app = try AppModule(store: store, route: try Route(text: "/view/\(today)/task/\(id)"))
    #expect(app.model.taskViewList.selection == today)
    #expect(app.model.taskList == (try TaskList(store: store, route: .init(head: today, task: .init(head: id)))).model)
    #expect(app.model.taskList?.task?.title == "Call the bank")
    #expect(app.model.problem == nil)
    #expect(app.route.text == "/view/\(today)/task/\(id)")
}

/// A window made from a link to a view that is gone, or restored onto one: the sidebar holds no row for it and
/// answers `.created` with nothing, the list cannot be made, and the window opens what still exists with a
/// sentence for the rest (spec section 7). Being created afterwards leaves the sentence.
@Test func aWindowMadeOnAViewThatIsGoneOpensNoPaneAndSaysSo() throws {
    let store = try makeStore()
    let gone = try taggedView("Errands", in: store)
    try store.delete(view: gone.view)
    let app = try AppModule(store: store, route: try Route(text: "/view/\(gone.view)"))
    #expect(app.send(.created) == nil)
    #expect(app.model.taskViewList.selection == nil)
    #expect(app.model.taskList == nil)
    #expect(app.model.problem == "The list could not be opened.")
    #expect(app.route == .default)
}

/// A tap is the list's route with the task as its tail (spec section 3, the first flow), and the window's route
/// says so, which is what a relaunch reopens.
@Test func aTapOnATaskOpensItAndTheRouteSaysSo() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: .default)
    #expect(app.send(.action(.taskList(.rowTapped(id)))) == nil)
    #expect(app.model.taskList?.task?.title == "Buy milk")
    #expect(app.route.text == "/view/\(inbox)/task/\(id)")
}

/// The way back is the route without the task, applied (spec section 3, the second flow).
@Test func theBackButtonClosesTheTaskScreenAndTheRouteSaysSo() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(text: "/view/\(inbox)/task/\(id)"))
    #expect(app.send(.action(.taskList(.backButtonTapped))) == nil)
    #expect(app.model.taskList == (try TaskList(store: store, route: .init(head: inbox))).model)
    #expect(app.model.taskList?.task == nil)
    #expect(app.route.text == "/view/\(inbox)")
}

/// A link to a task in another view, while a task of a third is open: the sidebar moves its highlight, and the
/// pane's seat sees another head and replaces the list, which opens its own task from the tail. One event, the
/// whole chain (spec section 3, the third flow). A list's head never changes, so a pane on the other view is a
/// new list.
@Test func aLinkToATaskInAnotherViewMovesTheSidebarAndReplacesThePane() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let home = try taggedView("Home", in: store)
    let report = try store.createTask(NewTask(title: "Write the report", tags: [work.tag]))
    let milk = try store.createTask(NewTask(title: "Buy milk", tags: [home.tag]))
    let app = try AppModule(store: store, route: try Route(text: "/view/\(work.view)/task/\(report)"))
    #expect(app.model.taskList?.task?.title == "Write the report", "the task of the third view is the setup")
    #expect(app.send(.route(try Route(text: "/view/\(home.view)/task/\(milk)"))) == nil)
    #expect(app.model.taskViewList.selection == home.view)
    #expect(app.model.taskList == (try TaskList(store: store, route: .init(head: home.view, task: .init(head: milk)))).model)
    #expect(app.model.taskList?.rows.map(\.title) == ["Buy milk"])
    #expect(app.model.taskList?.task?.title == "Buy milk")
    #expect(app.model.problem == nil)
    #expect(app.route.text == "/view/\(home.view)/task/\(milk)")
}

/// A link to a task deleted since opens what still exists: the list is made, the task screen is not, and the
/// list says why (spec section 3, the fourth flow). The pane was opened, so the root has nothing to say.
@Test func aLinkToADeletedTaskOpensTheListAndASentence() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let kept = try store.createTask(NewTask(title: "Write the report", tags: [work.tag]))
    let gone = try store.createTask(NewTask(title: "File the expenses", tags: [work.tag]))
    try store.delete(task: gone)
    let app = try AppModule(store: store, route: .default)
    #expect(app.send(.route(try Route(text: "/view/\(work.view)/task/\(gone)"))) == nil)
    #expect(app.model.taskViewList.selection == work.view)
    #expect(app.model.taskList?.rows.map(\.id) == [kept])
    #expect(app.model.taskList?.task == nil)
    #expect(app.model.taskList?.problem == "The task is gone.")
    #expect(app.model.problem == nil)
    #expect(app.route.text == "/view/\(work.view)")
}

/// Applying a route reconciles and never rebuilds (spec section 3): a link into a task of the view that is open
/// keeps the sidebar with the name half typed in it, and keeps the list, which opens the task.
@Test func aLinkIntoTheOpenListKeepsItsSessionState() throws {
    let (store, open, gone) = try storeWithAGoneTask()
    let app = try AppModule(store: store, route: try Route(text: "/view/\(inbox)/task/\(gone)"))
    let sentence = try #require(app.model.taskList?.problem, "the list's own sentence tells the instance; without it this proves nothing")
    #expect(app.send(.action(.taskViewList(.renameMenuItemChosen(BuiltInTaskViews.today)))) == nil)
    #expect(app.send(.action(.taskViewList(.titleFieldChanged("Soon")))) == nil)
    #expect(app.send(.route(try Route(text: "/view/\(inbox)/task/\(open)"))) == nil)
    #expect(app.model.taskViewList.rows.first { $0.id == BuiltInTaskViews.today }?.draft == "Soon")
    #expect(app.model.taskViewList.selection == inbox)
    #expect(app.model.taskList?.task?.title == "Buy milk")
    #expect(app.model.taskList?.problem == sentence, "the same list, since a list opened afresh says nothing")
    #expect(app.route.text == "/view/\(inbox)/task/\(open)")
}

/// The list whose view was deleted asks to be closed, and the root drops it: the root reads the store for
/// nothing of its own (spec section 3, ADR-0006, amendment of 2026-10-14). The sidebar lets its highlight go
/// with the row, so the window's route names nothing.
@Test func aViewDeletedUnderThePaneClosesItThroughTheChild() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let app = try AppModule(store: store, route: try Route(text: "/view/\(work.view)"))
    #expect(app.model.taskList != nil, "the pane is open on the view before it goes")
    let deleted = try changeSet(of: store) { try store.delete(view: work.view) }
    #expect(app.send(.changed(deleted)) == nil)
    #expect(app.model.taskList == nil)
    #expect(app.model.taskViewList.selection == nil)
    #expect(app.model.problem == nil)
    #expect(app.route == .default)
}

/// Every child takes `.changed` and decides for itself whether the change is one it reads: the sidebar rereads
/// the views, the list its tasks, the task screen its task, and quick entry, which reads nothing, keeps its draft.
@Test func aChangeReachesEveryChild() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(text: "/view/\(inbox)/task/\(id)?quick-entry"))
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Call the")))) == nil)
    let changes = try [
        changeSet(of: store) { try store.createView(NewTaskView(title: "Docs")) },
        changeSet(of: store) { try store.createTask(NewTask(title: "Water the plants")) },
        changeSet(of: store) { try store.update(task: id, [.title("Buy oat milk")]) },
    ]
    for change in changes { #expect(app.send(.changed(change)) == nil) }
    #expect(app.model.taskViewList.rows.last?.title == "Docs")
    #expect(app.model.taskList?.rows.map(\.title) == ["Buy oat milk", "Water the plants"])
    #expect(app.model.taskList?.task?.title == "Buy oat milk")
    #expect(app.model.quickEntry?.draft == "Call the")
}

/// A module never writes to the store in answer to `.changed`, which is what lets a change reach an idle window
/// inside another window's event (spec section 5): every child is live here, and every change leaves the
/// journal as it was.
@Test func theRootNeverWritesOnChanged() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let id = try store.createTask(NewTask(title: "Write the report", tags: [work.tag]))
    let app = try AppModule(store: store, route: try Route(text: "/view/\(work.view)/task/\(id)?quick-entry"))
    let changes = try [
        changeSet(of: store) { try store.createTask(NewTask(title: "File the expenses", tags: [work.tag])) },
        changeSet(of: store) { try store.update(task: id, [.title("Write the summary")]) },
        changeSet(of: store) { try store.update(view: work.view, [.title("Job")]) },
        changeSet(of: store) { try store.delete(task: id) },
        changeSet(of: store) { try store.delete(view: work.view) },
    ]
    let written = try store.journal(after: 0).count
    for change in changes {
        #expect(app.send(.changed(change)) == nil)
        #expect(try store.journal(after: 0).count == written)
    }
}

/// The toolbar's button opens quick entry, the sheet draws its model, and quick entry asks to be closed once its
/// task exists, which the root does; the pane learns of the task from the change the write produced, delivered
/// after the `send` that wrote, as it learns of a peer's (spec section 5).
@Test func quickEntryOpensDrawsAndClosesWhenItAsks() throws {
    let store = try makeStore()
    let app = try AppModule(store: store, route: .default)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.model.quickEntry?.draft == "")
    #expect(app.route.text == "/view/\(inbox)?quick-entry")
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Buy milk")))) == nil)
    #expect(app.model.quickEntry?.draft == "Buy milk")
    let created = try changeSet(of: store) { #expect(app.send(.action(.quickEntry(.addButtonTapped))) == nil) }
    #expect(app.model.quickEntry == nil)
    #expect(app.route.text == "/view/\(inbox)")
    #expect(try inboxTitles(of: store) == ["Buy milk"])
    #expect(app.send(.changed(created)) == nil)
    #expect(app.model.taskList?.rows.map(\.title) == ["Buy milk"])
}

/// The button pressed a second time keeps the quick entry that is up, with its draft, since it has no head to
/// differ by (spec section 3).
@Test func theQuickEntryButtonKeepsTheOneThatIsUp() throws {
    let app = try AppModule(store: try makeStore(), route: .default)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Buy milk")))) == nil)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.model.quickEntry?.draft == "Buy milk")
}

/// Cancel, the swipe down and Esc are one action, quick entry's own, which it answers by asking to be closed;
/// the draft goes with it and nothing is written.
@Test func quickEntrysCancelButtonClosesIt() throws {
    let store = try makeStore()
    let app = try AppModule(store: store, route: .default)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Buy milk")))) == nil)
    let written = try store.journal(after: 0).count
    #expect(app.send(.action(.quickEntry(.cancelButtonTapped))) == nil)
    #expect(app.model.quickEntry == nil)
    #expect(app.route.text == "/view/\(inbox)")
    #expect(try store.journal(after: 0).count == written)
}

/// After a close the model drove, the sheet's binding writes false and the view sends Cancel to a quick entry
/// that is already gone: the empty seat answers nothing, and nothing moves.
@Test func aCancelWithNoQuickEntryOpenMovesNothing() throws {
    let store = try makeStore()
    let app = try AppModule(store: store, route: .default)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Buy milk")))) == nil)
    #expect(app.send(.action(.quickEntry(.addButtonTapped))) == nil)
    let model = app.model
    let route = app.route
    let written = try store.journal(after: 0).count
    #expect(app.send(.action(.quickEntry(.cancelButtonTapped))) == nil)
    #expect(app.model == model)
    #expect(app.route == route)
    #expect(try store.journal(after: 0).count == written)
}

/// A route with no quick entry closes the one that is up, a link from outside included, and its draft goes with
/// it: a half-typed quick entry is session state, which no route carries (spec section 2).
@Test func aLinkWithoutQuickEntryClosesTheOpenOne() throws {
    let store = try makeStore()
    let app = try AppModule(store: store, route: .default)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Buy milk")))) == nil)
    #expect(app.send(.route(try Route(text: "/view/\(inbox)"))) == nil)
    #expect(app.model.quickEntry == nil)
    #expect(try inboxTitles(of: store).isEmpty)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.model.quickEntry?.draft == "", "the draft went with the quick entry the link closed")
}

/// A new window is the platform's to open, so the sidebar's request climbs and leaves the root under the root's
/// own name, with the route of a window on the view (spec section 4, the rule of bubbling). The window that
/// asked moves nothing.
@Test func openInNewWindowClimbsToTheRoot() throws {
    let app = try AppModule(store: try makeStore(), route: .default)
    let model = app.model
    let route = app.route
    let today = BuiltInTaskViews.today
    let output = app.send(.action(.taskViewList(.openInNewWindowMenuItemChosen(today))))
    guard case .openWindow(let window)? = output else {
        Issue.record("the root answers with a window to open, and answered \(String(describing: output))")
        return
    }
    #expect(window.text == "/view/\(today)")
    #expect(window == Route(sidebar: .init(selection: today), detail: .init(head: today), quickEntry: nil))
    #expect(app.model == model)
    #expect(app.route == route)
}

/// `/` on a live window names no pane, so the pane follows the sidebar, whose highlight it leaves alone: the
/// highlight, the list and the task open in it stay, and quick entry, which `/` does not name, closes.
@Test func aRouteThatNamesNoPaneKeepsTheOneOpen() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let report = try store.createTask(NewTask(title: "Write the report", tags: [work.tag]))
    let gone = try store.createTask(NewTask(title: "File the expenses", tags: [work.tag]))
    try store.delete(task: gone)
    let app = try AppModule(store: store, route: try Route(text: "/view/\(work.view)/task/\(report)?quick-entry"))
    #expect(app.send(.route(try Route(text: "/view/\(work.view)/task/\(gone)?quick-entry"))) == nil)
    #expect(app.model.taskList?.task?.title == "Write the report", "the task that was open stays; this is the setup")
    let sentence = try #require(app.model.taskList?.problem, "the list's own sentence tells the instance; without it this proves nothing")
    #expect(app.send(.route(.default)) == nil)
    #expect(app.model.taskViewList.selection == work.view)
    #expect(app.model.taskList?.task?.title == "Write the report")
    #expect(app.model.taskList?.problem == sentence, "the same list, since a list opened afresh says nothing")
    #expect(app.model.quickEntry == nil)
    #expect(app.route.text == "/view/\(work.view)/task/\(report)")
}

/// A click on the highlighted view is the list's route with no task, applied to the list that is there, so the
/// task open in it closes and the list stays, as System Settings does on the Mac and a second tap on a tab does
/// on iOS (owner's decision of 2026-10-16).
@Test func aClickOnTheHighlightedViewReturnsToItsList() throws {
    let (store, open, gone) = try storeWithAGoneTask()
    let app = try AppModule(store: store, route: try Route(text: "/view/\(inbox)/task/\(open)"))
    #expect(app.send(.route(try Route(text: "/view/\(inbox)/task/\(gone)"))) == nil)
    #expect(app.model.taskList?.task?.title == "Buy milk", "the task that was open stays; this is the setup")
    let sentence = try #require(app.model.taskList?.problem, "the list's own sentence tells the instance; without it this proves nothing")
    #expect(app.send(.action(.taskViewList(.rowSelected(inbox)))) == nil)
    #expect(app.model.taskList?.task == nil)
    #expect(app.model.taskList?.problem == sentence, "the same list, since a list opened afresh says nothing")
    #expect(app.route.text == "/view/\(inbox)")
}

/// A pane that cannot be made leaves the one that was open, and the root says so in its own model (spec section
/// 3). The sidebar holds no row for a view that is gone, so its highlight stays where it was too.
@Test func aPaneThatCannotBeOpenedLeavesTheOldOneAndASentence() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let gone = try taggedView("Errands", in: store)
    try store.delete(view: gone.view)
    let app = try AppModule(store: store, route: try Route(text: "/view/\(work.view)"))
    let before = app.model
    #expect(app.send(.route(try Route(text: "/view/\(gone.view)"))) == nil)
    #expect(app.model.problem == "The list could not be opened.")
    #expect(app.model.taskList == before.taskList)
    #expect(app.model.taskViewList == before.taskViewList)
    #expect(app.route.text == "/view/\(work.view)")
}

/// A click on a view a peer deleted, before the change saying so has arrived: the sidebar still holds the row
/// and answers the click, the list cannot be made, and the pane that was open stays with a sentence beside it,
/// which the click's own reaction writes after the click has taken the old one away.
@Test func aClickOnAViewThatIsGoneLeavesThePaneAndASentence() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let errands = try taggedView("Errands", in: store)
    let app = try AppModule(store: store, route: try Route(text: "/view/\(work.view)"))
    let pane = app.model.taskList
    try store.delete(view: errands.view)
    #expect(app.send(.action(.taskViewList(.rowSelected(errands.view)))) == nil)
    #expect(app.model.problem == "The list could not be opened.")
    #expect(app.model.taskList == pane)
    #expect(app.route.detail == .init(head: work.view))
}

/// The sentence answers what the last action or route asked for, and only the next action takes it away: a
/// route, a change and being created answer no gesture, so a sentence would go before the person read it.
@Test func theNextActionTakesTheSentenceAway() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let gone = try taggedView("Errands", in: store)
    try store.delete(view: gone.view)
    let app = try AppModule(store: store, route: try Route(text: "/view/\(work.view)"))
    #expect(app.send(.route(try Route(text: "/view/\(gone.view)"))) == nil)
    let sentence = try #require(app.model.problem, "the sentence is the setup; without it this proves nothing")
    #expect(app.send(.route(try Route(text: "/view/\(work.view)"))) == nil)
    let created = try changeSet(of: store) { try store.createTask(NewTask(title: "Write the report", tags: [work.tag])) }
    #expect(app.send(.changed(created)) == nil)
    #expect(app.send(.created) == nil)
    #expect(app.model.problem == sentence)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.model.problem == nil)
}
