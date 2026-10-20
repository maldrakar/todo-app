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

/// The model of a list made now on a view, which is what the list in the window is compared with: the list a
/// link to the view, and to the task in it, would make.
private func listOn(_ view: ViewID, task: TaskID? = nil, in store: Store) throws -> TaskList.Model {
    try TaskList(store: store, route: .init(head: view, task: task.map { TaskScreen.Route(head: $0) })).model
}

/// The rows of the list open in the window, read before a task is written into its view without its change being
/// delivered. The live list keeps the rows it last read, while a list made afresh reads the new task, so a list
/// whose rows still equal these after an event is the same instance: the mark a test tells one list from another
/// by, which only that instance holds and which adds nothing to the module's surface.
private func rowsBeforeAnUnreadTask(in app: AppModule, of store: Store, tags: Set<TagID> = []) throws -> [TaskList.Model.Row] {
    let head = try #require(app.route.sidebar.list?.head, "a list is open; this is the setup")
    let rows = try #require(app.model.taskViewList.taskList?.rows)
    try store.createTask(NewTask(title: "Unread", tags: tags))
    #expect(try listOn(head, in: store).rows.count == rows.count + 1, "a list made now reads the task; without that this proves nothing")
    return rows
}

/// The default window names no view, so the sidebar chooses the Inbox itself and opens its list: the root names
/// no view of its own (ADR-0006, amendment of 2026-10-03).
@Test func theDefaultWindowOpensTheListOnTheSidebarsChoice() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store)
    #expect(app.model.taskViewList.selection == inbox)
    #expect(app.model.taskViewList.taskList == (try listOn(inbox, in: store)))
    #expect(app.model.taskViewList.taskList?.rows.map(\.title) == ["Buy milk"])
    #expect(app.model.taskViewList.problem == nil)
    #expect(app.model.quickEntry == nil)
    #expect(app.route.path == "/view/\(inbox)")
}

/// A root made with no route is the default window's: a caller with no route to hand on spells none (owner's
/// review of #103).
@Test func aRootMadeWithNoRouteIsTheDefaultWindow() throws {
    let store = try makeStore()
    let app = try AppModule(store: store)
    let named = try AppModule(store: store, route: .default)
    #expect(app.model == named.model)
    #expect(app.route == named.route)
}

/// A person who deleted the Inbox leaves the sidebar starting on no row: no list opens, nothing is said, and the
/// launch goes ahead.
@Test func theDefaultWindowWithNoInboxOpensNoList() throws {
    let store = try makeStore()
    try store.delete(view: inbox)
    let app = try AppModule(store: store)
    #expect(app.model.taskViewList.selection == nil)
    #expect(app.model.taskViewList.taskList == nil)
    #expect(app.model.taskViewList.problem == nil)
    #expect(app.route == .default)
}

/// `init` has told the children already, so `.created`, sent to the root once it is made, has nothing left to say.
@Test func theRootsOwnCreatedAnswersNothingAndMovesNothing() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(open)?quick-entry"))
    let model = app.model
    let route = app.route
    #expect(app.send(.created) == nil)
    #expect(app.model == model)
    #expect(app.route == route)
}

/// A link made into a window: the sidebar starts on the view and opens its list on the link's route, and the list
/// opens the task in its own `init` (spec section 3).
@Test func theRootCreatedFromALinkOpensTheTaskInItsList() throws {
    let store = try makeStore()
    let today = BuiltInTaskViews.today
    let id = try store.createTask(NewTask(title: "Call the bank", when: Day(millisSinceEpoch: Store.systemNow())))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(today)/task/\(id)"))
    #expect(app.model.taskViewList.selection == today)
    #expect(app.model.taskViewList.taskList == (try listOn(today, task: id, in: store)))
    #expect(app.model.taskViewList.taskList?.task?.title == "Call the bank")
    #expect(app.model.taskViewList.problem == nil)
    #expect(app.route.path == "/view/\(today)/task/\(id)")
}

/// A window made from a link to a view that is gone, or restored onto one: the list cannot be made, and the window
/// opens what still exists with the sidebar's sentence for the rest (spec section 7). Being created afterwards
/// leaves the sentence.
@Test func aWindowMadeOnAViewThatIsGoneOpensNoListAndSaysSo() throws {
    let store = try makeStore()
    let gone = try taggedView("Errands", in: store)
    try store.delete(view: gone.view)
    let app = try AppModule(store: store, route: try Route(path: "/view/\(gone.view)"))
    #expect(app.send(.created) == nil)
    #expect(app.model.taskViewList.selection == nil)
    #expect(app.model.taskViewList.taskList == nil)
    #expect(app.model.taskViewList.problem == "The list could not be opened.")
    #expect(app.route == .default)
}

/// A tap is the list's route with the task as its tail (spec section 3, the first flow), reaching the list through
/// the sidebar, and the window's route says so, which is what a relaunch reopens.
@Test func aTapOnATaskOpensItAndTheRouteSaysSo() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store)
    #expect(app.send(.action(.taskViewList(.taskList(.rowTapped(id))))) == nil)
    #expect(app.model.taskViewList.taskList?.task?.title == "Buy milk")
    #expect(app.route.path == "/view/\(inbox)/task/\(id)")
}

/// The way back is the route without the task, applied (spec section 3, the second flow).
@Test func theBackButtonClosesTheTaskScreenAndTheRouteSaysSo() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(id)"))
    #expect(app.send(.action(.taskViewList(.taskList(.backButtonTapped)))) == nil)
    #expect(app.model.taskViewList.taskList == (try listOn(inbox, in: store)))
    #expect(app.model.taskViewList.taskList?.task == nil)
    #expect(app.route.path == "/view/\(inbox)")
}

/// A link to a task in another view, while a task of a third is open: the sidebar moves its highlight, and its
/// list's seat sees another head and replaces the list, which opens its own task from the tail. One event, the
/// whole chain (spec section 3, the third flow). A list's head never changes, so a list on the other view is a new
/// one.
@Test func aLinkToATaskInAnotherViewMovesTheSidebarAndReplacesTheList() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let home = try taggedView("Home", in: store)
    let report = try store.createTask(NewTask(title: "Write the report", tags: [work.tag]))
    let milk = try store.createTask(NewTask(title: "Buy milk", tags: [home.tag]))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(work.view)/task/\(report)"))
    #expect(app.model.taskViewList.taskList?.task?.title == "Write the report", "the task of the third view is the setup")
    #expect(app.send(.route(try Route(path: "/view/\(home.view)/task/\(milk)"))) == nil)
    #expect(app.model.taskViewList.selection == home.view)
    #expect(app.model.taskViewList.taskList == (try listOn(home.view, task: milk, in: store)))
    #expect(app.model.taskViewList.taskList?.rows.map(\.title) == ["Buy milk"])
    #expect(app.model.taskViewList.taskList?.task?.title == "Buy milk")
    #expect(app.model.taskViewList.problem == nil)
    #expect(app.route.path == "/view/\(home.view)/task/\(milk)")
}

/// A link to a task deleted since opens what still exists: the list is made, the task screen is not, and the
/// list says why (spec section 3, the fourth flow). The list was opened, so the sidebar has nothing to say.
@Test func aLinkToADeletedTaskOpensTheListAndASentence() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let kept = try store.createTask(NewTask(title: "Write the report", tags: [work.tag]))
    let gone = try store.createTask(NewTask(title: "File the expenses", tags: [work.tag]))
    try store.delete(task: gone)
    let app = try AppModule(store: store)
    #expect(app.send(.route(try Route(path: "/view/\(work.view)/task/\(gone)"))) == nil)
    #expect(app.model.taskViewList.selection == work.view)
    #expect(app.model.taskViewList.taskList?.rows.map(\.id) == [kept])
    #expect(app.model.taskViewList.taskList?.task == nil)
    #expect(app.model.taskViewList.taskList?.problem == "The task is gone.")
    #expect(app.model.taskViewList.problem == nil)
    #expect(app.route.path == "/view/\(work.view)")
}

/// Applying a route reconciles and never rebuilds (spec section 3): a link into a task of the view that is open
/// keeps the sidebar with the name half typed in it, and keeps the list, which opens the task.
@Test func aLinkIntoTheOpenListKeepsItsSessionState() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store)
    let rows = try rowsBeforeAnUnreadTask(in: app, of: store)
    #expect(app.send(.action(.taskViewList(.renameMenuItemChosen(BuiltInTaskViews.today)))) == nil)
    #expect(app.send(.action(.taskViewList(.titleFieldChanged("Soon")))) == nil)
    #expect(app.send(.route(try Route(path: "/view/\(inbox)/task/\(open)"))) == nil)
    #expect(app.model.taskViewList.rows.first { $0.id == BuiltInTaskViews.today }?.draft == "Soon")
    #expect(app.model.taskViewList.selection == inbox)
    #expect(app.model.taskViewList.taskList?.task?.title == "Buy milk")
    #expect(app.model.taskViewList.taskList?.rows == rows, "the same list, since a list made afresh reads the task written since")
    #expect(app.route.path == "/view/\(inbox)/task/\(open)")
}

/// The list whose view was deleted asks the sidebar to close it, and the sidebar drops it: neither the root nor the
/// sidebar reads the store for the list (spec section 3, ADR-0006, amendment of 2026-10-14). The sidebar lets its
/// highlight go with the row, so the window's route names nothing.
@Test func aViewDeletedUnderTheListClosesItThroughTheChild() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let app = try AppModule(store: store, route: try Route(path: "/view/\(work.view)"))
    #expect(app.model.taskViewList.taskList != nil, "the list is open on the view before it goes")
    let deleted = try changeSet(of: store) { try store.delete(view: work.view) }
    #expect(app.send(.changed(deleted)) == nil)
    #expect(app.model.taskViewList.taskList == nil)
    #expect(app.model.taskViewList.selection == nil)
    #expect(app.model.taskViewList.problem == nil)
    #expect(app.route == .default)
}

/// Every child takes `.changed` and decides for itself whether the change is one it reads: the sidebar rereads
/// the views and hands the change to its list, which rereads its tasks and hands it to the task screen, and quick
/// entry, which reads nothing, keeps its draft.
@Test func aChangeReachesEveryModuleInTheWindow() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(id)?quick-entry"))
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Call the")))) == nil)
    let changes = try [
        changeSet(of: store) { try store.createView(NewTaskView(title: "Docs")) },
        changeSet(of: store) { try store.createTask(NewTask(title: "Water the plants")) },
        changeSet(of: store) { try store.update(task: id, [.title("Buy oat milk")]) },
    ]
    for change in changes { #expect(app.send(.changed(change)) == nil) }
    #expect(app.model.taskViewList.rows.last?.title == "Docs")
    #expect(app.model.taskViewList.taskList?.rows.map(\.title) == ["Buy oat milk", "Water the plants"])
    #expect(app.model.taskViewList.taskList?.task?.title == "Buy oat milk")
    #expect(app.model.quickEntry?.draft == "Call the")
}

/// A module never writes to the store in answer to `.changed`, which is what lets a change reach an idle window
/// inside another window's event (spec section 5): every module is live here, and every change leaves the
/// journal as it was.
@Test func theWindowNeverWritesOnChanged() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let id = try store.createTask(NewTask(title: "Write the report", tags: [work.tag]))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(work.view)/task/\(id)?quick-entry"))
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
/// task exists, which the root does; the list learns of the task from the change the write produced, delivered
/// after the `send` that wrote, as it learns of a peer's (spec section 5).
@Test func quickEntryOpensDrawsAndClosesWhenItAsks() throws {
    let store = try makeStore()
    let app = try AppModule(store: store)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.model.quickEntry?.draft == "")
    #expect(app.route.path == "/view/\(inbox)?quick-entry")
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Buy milk")))) == nil)
    #expect(app.model.quickEntry?.draft == "Buy milk")
    let created = try changeSet(of: store) { #expect(app.send(.action(.quickEntry(.addButtonTapped))) == nil) }
    #expect(app.model.quickEntry == nil)
    #expect(app.route.path == "/view/\(inbox)")
    #expect(try inboxTitles(of: store) == ["Buy milk"])
    #expect(app.send(.changed(created)) == nil)
    #expect(app.model.taskViewList.taskList?.rows.map(\.title) == ["Buy milk"])
}

/// The button pressed a second time keeps the quick entry that is up, with its draft, since it has no head to
/// differ by (spec section 3).
@Test func theQuickEntryButtonKeepsTheOneThatIsUp() throws {
    let app = try AppModule(store: try makeStore())
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Buy milk")))) == nil)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.model.quickEntry?.draft == "Buy milk")
}

/// Cancel, the swipe down and Esc are one action, quick entry's own, which it answers by asking to be closed;
/// the draft goes with it and nothing is written.
@Test func quickEntrysCancelButtonClosesIt() throws {
    let store = try makeStore()
    let app = try AppModule(store: store)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Buy milk")))) == nil)
    let written = try store.journal(after: 0).count
    #expect(app.send(.action(.quickEntry(.cancelButtonTapped))) == nil)
    #expect(app.model.quickEntry == nil)
    #expect(app.route.path == "/view/\(inbox)")
    #expect(try store.journal(after: 0).count == written)
}

/// After a close the model drove, the sheet's binding writes false and the view sends Cancel to a quick entry
/// that is already gone: the empty seat answers nothing, and nothing moves, the sidebar's sentence included. Here
/// a link to a view that is gone closed quick entry and wrote the sentence in one event, and the Cancel that
/// follows it leaves the sentence for the person to read.
@Test func aCancelWithNoQuickEntryOpenMovesNothing() throws {
    let store = try makeStore()
    let gone = try taggedView("Errands", in: store)
    try store.delete(view: gone.view)
    let app = try AppModule(store: store)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Buy milk")))) == nil)
    #expect(app.send(.route(try Route(path: "/view/\(gone.view)"))) == nil)
    #expect(app.model.quickEntry == nil, "the link closed quick entry; this is the setup")
    #expect(app.model.taskViewList.problem == "The list could not be opened.", "the sentence is the setup; without it this proves nothing")
    let model = app.model
    let route = app.route
    let written = try store.journal(after: 0).count
    #expect(app.send(.action(.quickEntry(.cancelButtonTapped))) == nil)
    #expect(app.model == model)
    #expect(app.route == route)
    #expect(try store.journal(after: 0).count == written)
}

/// The sidebar's sentence goes with the sidebar's own gestures and a route, and a gesture in one of the other
/// modules of the window leaves it: quick entry is a sheet over the window, and the list is the sidebar's child,
/// whose gestures are its own, as a gesture on the task screen leaves the list's sentence.
@Test func aGestureInQuickEntryOrInTheListLeavesTheSidebarsSentence() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let report = try store.createTask(NewTask(title: "Write the report", tags: [work.tag]))
    let gone = try taggedView("Errands", in: store)
    try store.delete(view: gone.view)
    let app = try AppModule(store: store, route: try Route(path: "/view/\(work.view)?quick-entry"))
    #expect(app.send(.route(try Route(path: "/view/\(gone.view)?quick-entry"))) == nil)
    let sentence = try #require(app.model.taskViewList.problem, "the sentence is the setup; without it this proves nothing")
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Buy milk")))) == nil)
    #expect(app.model.quickEntry?.draft == "Buy milk", "quick entry took the keystroke")
    #expect(app.send(.action(.taskViewList(.taskList(.rowTapped(report))))) == nil)
    #expect(app.model.taskViewList.taskList?.task?.title == "Write the report", "the list took the tap")
    #expect(app.model.taskViewList.problem == sentence)
}

/// A route with no quick entry closes the one that is up, a link from outside included, and its draft goes with
/// it: a half-typed quick entry is session state, which no route carries (spec section 2).
@Test func aLinkWithoutQuickEntryClosesTheOpenOne() throws {
    let store = try makeStore()
    let app = try AppModule(store: store)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Buy milk")))) == nil)
    #expect(app.send(.route(try Route(path: "/view/\(inbox)"))) == nil)
    #expect(app.model.quickEntry == nil)
    #expect(try inboxTitles(of: store).isEmpty)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.model.quickEntry?.draft == "", "the draft went with the quick entry the link closed")
}

/// A new window is the platform's to open, so the sidebar's request climbs and leaves the root under the root's
/// own name, with the sidebar's own route for the window (spec section 4, the rule of bubbling): the root never
/// spells its grandchild's route. Nothing else moves in the window that asked.
@Test func openInNewWindowClimbsToTheRoot() throws {
    let app = try AppModule(store: try makeStore())
    let model = app.model
    let route = app.route
    let today = BuiltInTaskViews.today
    let output = app.send(.action(.taskViewList(.openInNewWindowMenuItemChosen(today))))
    guard case .openWindow(let window)? = output else {
        Issue.record("the root answers with a window to open, and answered \(String(describing: output))")
        return
    }
    #expect(window.path == "/view/\(today)")
    #expect(window == Route(sidebar: .init(list: .init(head: today)), quickEntry: nil))
    #expect(app.model == model)
    #expect(app.route == route)
}

/// `/` on a live window names no list, so the sidebar leaves its highlight and its list alone: the highlight, the
/// list and the task open in it stay, by the same list instance, and quick entry, which `/` does not name, closes.
@Test func aRouteThatNamesNoListKeepsTheOneOpen() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let report = try store.createTask(NewTask(title: "Write the report", tags: [work.tag]))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(work.view)/task/\(report)?quick-entry"))
    let rows = try rowsBeforeAnUnreadTask(in: app, of: store, tags: [work.tag])
    #expect(app.send(.route(.default)) == nil)
    #expect(app.model.taskViewList.selection == work.view)
    #expect(app.model.taskViewList.taskList?.task?.title == "Write the report")
    #expect(app.model.taskViewList.taskList?.rows == rows, "the same list, since a list made afresh reads the task written since")
    #expect(app.model.quickEntry == nil)
    #expect(app.route.path == "/view/\(work.view)/task/\(report)")
}

/// A click on the highlighted view is the list's route with no task, applied to the list that is there, so the
/// task open in it closes and the list stays, as System Settings does on the Mac and a second tap on a tab does
/// on iOS (owner's decision of 2026-10-16).
@Test func aClickOnTheHighlightedViewReturnsToItsList() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(open)"))
    let rows = try rowsBeforeAnUnreadTask(in: app, of: store)
    #expect(app.send(.action(.taskViewList(.rowSelected(inbox)))) == nil)
    #expect(app.model.taskViewList.taskList?.task == nil)
    #expect(app.model.taskViewList.taskList?.rows == rows, "the same list, since a list made afresh reads the task written since")
    #expect(app.route.path == "/view/\(inbox)")
}

/// A link to a view that is gone leaves the list that was open, and the sidebar says so in its own model (spec
/// section 3). The sidebar holds no row for a view that is gone, so its highlight stays where it was too.
@Test func aLinkToAViewThatIsGoneLeavesTheListAndASentence() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let gone = try taggedView("Errands", in: store)
    try store.delete(view: gone.view)
    let app = try AppModule(store: store, route: try Route(path: "/view/\(work.view)"))
    let before = app.model.taskViewList
    #expect(app.send(.route(try Route(path: "/view/\(gone.view)"))) == nil)
    #expect(app.model.taskViewList.problem == "The list could not be opened.")
    #expect(app.model.taskViewList.taskList == before.taskList)
    #expect(app.model.taskViewList.selection == before.selection)
    #expect(app.route.path == "/view/\(work.view)")
}

/// The root's own sentence, for a link the composition root could not read (the owner, 2026-10-16, answering the
/// spec's open question; `docs/specs/navigation.md`, section 7).
private let linkSentence = "The link could not be opened."

/// A link that does not read moves nothing in the window: the sidebar, the list, by the same instance, the task open in
/// it and quick entry with its draft stay as they were, and so does the route. The root says so in a sentence of its
/// own, since what failed is no child's.
@Test func anUnreadableLinkLeavesTheWindowAndSaysSo() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(open)?quick-entry"))
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Call the")))) == nil)
    let rows = try rowsBeforeAnUnreadTask(in: app, of: store)
    let before = app.model
    let route = app.route
    #expect(before.problem == nil, "nothing is said before the link; without that this proves nothing")
    #expect(app.send(.unreadableLink) == nil)
    #expect(app.model.taskViewList == before.taskViewList)
    #expect(app.model.taskViewList.taskList?.rows == rows, "the same list, since a list made afresh reads the task written since")
    #expect(app.model.quickEntry == before.quickEntry)
    #expect(app.model.problem == linkSentence)
    #expect(app.route == route)
}

/// Every link that does not read says so: a second one in a row leaves the window as one did, and one after the
/// sentence was taken away says it again.
@Test func everyUnreadableLinkSaysSo() throws {
    let store = try makeStore()
    let app = try AppModule(store: store)
    let once = try AppModule(store: store)
    #expect(once.send(.unreadableLink) == nil)
    #expect(once.model.problem == linkSentence, "one link said so; this is the setup")
    #expect(app.send(.unreadableLink) == nil)
    #expect(app.send(.unreadableLink) == nil)
    #expect(app.model == once.model)
    #expect(app.send(.route(.default)) == nil)
    #expect(app.model.problem == nil, "the route took the sentence away; this is the setup")
    #expect(app.send(.unreadableLink) == nil)
    #expect(app.model == once.model)
}

/// A link that reads is applied as every route is, and takes the root's sentence away, a route the sidebar cannot open
/// included, which the sidebar answers with a sentence of its own: the window then draws what a window that never had
/// the link that did not read draws (the owner, 2026-10-16: a successful route clears a sentence at its start).
@Test func aRouteTakesTheRootsSentenceAway() throws {
    let store = try makeStore()
    let gone = try taggedView("Errands", in: store)
    try store.delete(view: gone.view)
    let app = try AppModule(store: store)
    let twin = try AppModule(store: store)
    for route in [try Route(path: "/view/\(BuiltInTaskViews.today)?quick-entry"), try Route(path: "/view/\(gone.view)")] {
        #expect(app.send(.unreadableLink) == nil)
        #expect(app.model.problem == linkSentence, "the sentence is the setup; without it this proves nothing")
        #expect(app.send(.route(route)) == nil)
        #expect(twin.send(.route(route)) == nil)
        #expect(app.model == twin.model)
        #expect(app.route == twin.route)
    }
    #expect(app.model.taskViewList.problem == "The list could not be opened.", "the sidebar said why it opened nothing")
}

/// The Quick Entry button is the root's own gesture, so it takes the root's sentence away, with quick entry down and
/// with it up, which the button keeps with its draft (the owner's rule of 2026-10-16 that a module's sentence goes with
/// its own gestures, and their decision of 2026-10-20 for the root's).
@Test func theQuickEntryButtonTakesTheRootsSentenceAway() throws {
    let store = try makeStore()
    let app = try AppModule(store: store)
    let twin = try AppModule(store: store)
    let presses: [[AppModule.UserAction]] = [
        [.quickEntryButtonTapped],
        [.quickEntry(.titleFieldChanged("Buy milk")), .quickEntryButtonTapped],
    ]
    for actions in presses {
        #expect(app.send(.unreadableLink) == nil)
        #expect(app.model.problem == linkSentence, "the sentence is the setup; without it this proves nothing")
        for action in actions {
            #expect(app.send(.action(action)) == nil)
            #expect(twin.send(.action(action)) == nil)
        }
        #expect(app.model == twin.model)
    }
    #expect(app.model.quickEntry?.draft == "Buy milk", "the second press found quick entry up and kept it")
}

/// A gesture in one of the root's children is that child's, so it leaves the root's sentence, as a gesture in the list
/// leaves the sidebar's: a choice in the sidebar, a tap in the list it opened and a keystroke in quick entry each move
/// their own module, as they do in a window that never had the link, and the sentence stays.
@Test func aGestureInAChildLeavesTheRootsSentence() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/?quick-entry"))
    let twin = try AppModule(store: store, route: try Route(path: "/?quick-entry"))
    #expect(app.send(.unreadableLink) == nil)
    let gestures: [AppModule.UserAction] = [
        .taskViewList(.rowSelected(BuiltInTaskViews.today)),
        .taskViewList(.rowSelected(inbox)),
        .taskViewList(.taskList(.rowTapped(open))),
        .quickEntry(.titleFieldChanged("Call the bank")),
    ]
    for gesture in gestures {
        #expect(app.send(.action(gesture)) == nil)
        #expect(twin.send(.action(gesture)) == nil)
    }
    #expect(twin.model.taskViewList.taskList?.task?.title == "Buy milk", "the gestures moved the window; this is the setup")
    #expect(twin.model.quickEntry?.draft == "Call the bank", "and quick entry took the keystroke")
    #expect(app.model.taskViewList == twin.model.taskViewList)
    #expect(app.model.quickEntry == twin.model.quickEntry)
    #expect(app.model.problem == linkSentence)
    #expect(app.route == twin.route)
}

/// A change another window or another device made answers nothing a person was told, and neither does being created,
/// so both leave the root's sentence while the change is read as in any window.
@Test func aChangeOrBeingCreatedLeavesTheRootsSentence() throws {
    let store = try makeStore()
    let app = try AppModule(store: store)
    let twin = try AppModule(store: store)
    #expect(app.send(.unreadableLink) == nil)
    let changes = try changeSet(of: store) { try store.createTask(NewTask(title: "Buy milk")) }
    for event in [AppModule.Event.changed(changes), .created] {
        #expect(app.send(event) == nil)
        #expect(twin.send(event) == nil)
    }
    #expect(twin.model.taskViewList.taskList?.rows.map(\.title) == ["Buy milk"], "the change was read; this is the setup")
    #expect(app.model.taskViewList == twin.model.taskViewList)
    #expect(app.model.quickEntry == twin.model.quickEntry)
    #expect(app.model.problem == linkSentence)
}
