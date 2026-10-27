import Testing
import TestSupport
import AppFeature
import FeatureModule
import QuickEntryFeature
import SQLiteKit
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

/// The model of a sidebar made now on a view, which is what the window's sidebar is compared with: the rows as a
/// read now answers them, the highlight on the view, and no sentence.
private func sidebarOn(_ view: ViewID, in store: Store) throws -> TaskViewList.Model {
    try TaskViewList(store: store, route: .init(list: .init(head: view))).model
}

/// The model of a list made now on a view, as an element of the window's stack holds it, which is what a list
/// standing in the window is compared with: the rows as a read now answers them, and no sentence.
private func listOn(_ view: ViewID, in store: Store) throws -> AppModule.ScreenModel {
    .list(try TaskList(store: store, route: .init(head: view)).model)
}

/// The model of a task screen made now on a task, as an element of the window's stack holds it.
private func taskOn(_ id: TaskID, in store: Store) throws -> AppModule.ScreenModel {
    .task(try TaskScreen(store: store, route: .init(head: id)).model)
}

/// The ids of the screens standing over the sidebar, bottom up, whichever the layout: narrow, the one path; wide, the
/// column, when a screen stands there, and the path over it (navigation state spec, section 4). The one place a test
/// reads the layout for what stands, so that a test of something else holds in either width.
private func idsOverTheSidebar(in model: AppModule.Model) -> [StackElementID] {
    switch model.layout {
    case .narrow(let path): path
    case .wide(let column?, let path): [column] + path
    case .wide(nil, let path): path
    }
}

/// The models of the screens standing over the sidebar, bottom up, read the way the root view reads them: each id
/// over the sidebar looked up in `screens`, which holds a model for every such id and none beside.
private func standing(in app: AppModule) throws -> [AppModule.ScreenModel] {
    let model = app.model
    let ids = idsOverTheSidebar(in: model)
    #expect(model.screens.count == ids.count, "a model for every id over the sidebar, and none beside")
    return try ids.map { id in try #require(model.screens[id]) }
}

/// The model of the list standing first over the sidebar, the one a window's tests read rows and sentences off.
private func firstList(in app: AppModule) throws -> TaskList.Model {
    let id = try #require(idsOverTheSidebar(in: app.model).first, "a list stands over the sidebar; this is the setup")
    guard case .list(let list)? = app.model.screens[id] else {
        Issue.record("the first screen over the sidebar is a list, and is \(String(describing: app.model.screens[id]))")
        throw FirstScreenIsNoList()
    }
    return list
}

private struct FirstScreenIsNoList: Error {}

/// The default window names no view, so the sidebar chooses the Inbox itself and declares its list, which the
/// window's stack makes: the root names no view of its own (ADR-0006, amendment of 2026-10-03).
@Test func theDefaultWindowOpensTheListOnTheSidebarsChoice() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, width: .wide)
    #expect(app.model.taskViewList == (try sidebarOn(inbox, in: store)))
    #expect(try standing(in: app) == [listOn(inbox, in: store)])
    #expect(try firstList(in: app).rows.map(\.title) == ["Buy milk"])
    #expect(app.model.quickEntry == nil)
    #expect(app.model.problem == nil)
    #expect(app.route.path == "/view/\(inbox)")
}

/// A root made with no route is the default window's: a caller with no route to hand on spells none (owner's
/// review of #103).
@Test func aRootMadeWithNoRouteIsTheDefaultWindow() throws {
    let store = try makeStore()
    let app = try AppModule(store: store, width: .wide)
    let named = try AppModule(store: store, route: .default, width: .wide)
    #expect(app.model == named.model)
    #expect(app.route == named.route)
}

/// A person who deleted the Inbox leaves the sidebar starting on no row: it declares nothing, nothing stands over
/// it, nothing is said, and the launch goes ahead.
@Test func theDefaultWindowWithNoInboxOpensNoList() throws {
    let store = try makeStore()
    try store.delete(view: inbox)
    let app = try AppModule(store: store, width: .wide)
    #expect(app.model.taskViewList.selection == nil)
    #expect(app.model.taskViewList.problem == nil)
    #expect(idsOverTheSidebar(in: app.model).isEmpty)
    #expect(try standing(in: app).isEmpty)
    #expect(app.route == .default)
}

/// `init` has made the first walk already, so `.created`, sent to the root once it is made, has nothing left to say.
@Test func theRootsOwnCreatedAnswersNothingAndMovesNothing() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(
        store: store, route: try Route(path: "/view/\(inbox)/task/\(open)?quick-entry"), width: .wide
    )
    let model = app.model
    let route = app.route
    #expect(app.send(.created) == nil)
    #expect(app.model == model)
    #expect(app.route == route)
}

/// A link made into a window: the sidebar declares the link's list whole, the stack makes the list, which declares
/// the task in its own `init`, and the stack makes the task over it in the same walk (spec section 3).
@Test func theRootCreatedFromALinkOpensTheTaskOverItsList() throws {
    let store = try makeStore()
    let today = BuiltInTaskViews.today
    let id = try store.createTask(NewTask(title: "Call the bank", when: Day(millisSinceEpoch: Store.systemNow())))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(today)/task/\(id)"), width: .wide)
    #expect(app.model.taskViewList == (try sidebarOn(today, in: store)))
    #expect(try standing(in: app) == [listOn(today, in: store), taskOn(id, in: store)])
    #expect(app.route.path == "/view/\(today)/task/\(id)")
}

/// A window made from a link to a view that is gone, or restored onto one: the list cannot be made, and the window
/// opens what still exists with the sidebar's sentence for the rest (spec section 7). Being created afterwards
/// leaves the sentence.
@Test func aWindowMadeOnAViewThatIsGoneOpensNoListAndSaysSo() throws {
    let store = try makeStore()
    let gone = try taggedView("Errands", in: store)
    try store.delete(view: gone.view)
    let app = try AppModule(store: store, route: try Route(path: "/view/\(gone.view)"), width: .wide)
    #expect(app.send(.created) == nil)
    #expect(app.model.taskViewList.rows == (try sidebarOn(gone.view, in: store)).rows, "the views, none highlighted")
    #expect(app.model.taskViewList.selection == nil)
    #expect(app.model.taskViewList.problem == "The list could not be opened.")
    #expect(idsOverTheSidebar(in: app.model).isEmpty)
    #expect(app.route == .default)
}

/// The first flow of spec section 8: a tap on a task row, which the root view sends with the id of the list's
/// element. The stack hands it to the list, which declares the task, and the walk after it makes the task screen
/// and pushes it over the list as a new element, the list kept by its id; the route says so, which is what a
/// relaunch reopens.
@Test func aTapOnATaskPushesItOverTheList() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, width: .wide)
    let list = try #require(idsOverTheSidebar(in: app.model).first)
    try #require(idsOverTheSidebar(in: app.model) == [list])
    #expect(app.send(.action(.screen(list, .list(.rowTapped(id))))) == nil)
    let path = idsOverTheSidebar(in: app.model)
    #expect(path.count == 2)
    #expect(path.first == list, "the list stays, by its id")
    #expect(try standing(in: app) == [listOn(inbox, in: store), taskOn(id, in: store)])
    #expect(app.model.taskViewList == (try sidebarOn(inbox, in: store)))
    #expect(app.route.path == "/view/\(inbox)/task/\(id)")
}

/// The second flow of spec section 8, on a narrow window: SwiftUI writes the path one shorter for each Back, and the
/// root view sends it whole. The first closes the task: the list is told it was uncovered and empties its
/// destination, and the route names the list alone. The second reaches the views: the sidebar empties its
/// destination, the highlight goes with it (owner, 2026-10-21), and the route is the default one, which a relaunch
/// opens on the Inbox, as a new window.
@Test func backTwiceClosesTheTaskThenTheListAndTheHighlight() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(id)"), width: .narrow)
    let path = idsOverTheSidebar(in: app.model)
    try #require(path.count == 2)
    #expect(app.send(.action(.wentBack(to: [path[0]]))) == nil)
    #expect(idsOverTheSidebar(in: app.model) == [path[0]])
    #expect(try standing(in: app) == [listOn(inbox, in: store)])
    #expect(app.model.taskViewList == (try sidebarOn(inbox, in: store)))
    #expect(app.route.path == "/view/\(inbox)")
    #expect(app.send(.action(.wentBack(to: []))) == nil)
    #expect(idsOverTheSidebar(in: app.model).isEmpty)
    #expect(try standing(in: app).isEmpty)
    #expect(app.model.taskViewList.rows.map(\.id) == (try sidebarOn(inbox, in: store)).rows.map(\.id))
    #expect(app.model.taskViewList.rows.filter(\.isSelected).isEmpty)
    #expect(app.model.taskViewList.selection == nil)
    #expect(app.model.taskViewList.problem == nil)
    #expect(app.route.path == "/")
    let relaunched = try AppModule(store: store, route: try Route(path: app.route.path), width: .narrow)
    #expect(relaunched.route.path == "/view/\(inbox)")
}

/// The long-press menu on the back button goes back several screens at once, and SwiftUI writes the path it went
/// back to in one write: from the task straight to the views, the list and the task close together, and the
/// highlight with them (spec section 3).
@Test func wentBackFromTheTaskToTheViewsClosesBothAtOnce() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(open)"), width: .narrow)
    try #require(idsOverTheSidebar(in: app.model).count == 2)
    #expect(app.send(.action(.wentBack(to: []))) == nil)
    #expect(idsOverTheSidebar(in: app.model).isEmpty)
    #expect(app.model.screens.isEmpty)
    #expect(app.model.taskViewList.selection == nil)
    #expect(app.route.path == "/")
}

/// The third flow of spec section 8, on a wide window: the change reaches every element, base first; the task
/// screen finds its task gone and asks to be closed, the stack hands that to the list, which empties its
/// destination, and the walk drops the screen, which leaves the list in the column and nothing over it. SwiftUI then
/// writes the detail column's path it pops to, empty, which the root view sends whole and the root reads after the
/// column, a prefix the stack holds, and it moves nothing, nor does the detail's path from before the pop, which
/// holds an id the stack dropped (spec section 3, "A pop the model drove").
@Test func aTaskDeletedUnderItsScreenIsDroppedAndTheWriteAfterwardsMovesNothing() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let kept = try store.createTask(NewTask(title: "Call the bank"))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(id)"), width: .wide)
    let path = idsOverTheSidebar(in: app.model)
    try #require(path.count == 2)
    let deleted = try changeSet(of: store) { try store.delete(task: id) }
    #expect(app.send(.changed(deleted)) == nil)
    #expect(app.model.layout == .wide(column: path[0], path: []))
    #expect(try standing(in: app) == [listOn(inbox, in: store)])
    #expect(try firstList(in: app).rows.map(\.id) == [kept])
    #expect(app.model.taskViewList == (try sidebarOn(inbox, in: store)))
    #expect(app.route.path == "/view/\(inbox)")
    let model = app.model
    for written in [[], [path[1]]] {
        #expect(app.send(.action(.wentBack(to: written))) == nil)
        #expect(app.model == model)
        #expect(app.route.path == "/view/\(inbox)")
    }
}

/// A narrow window, iPhone's or a narrow iPad window, is one stack with the sidebar at its root, so every screen
/// over the sidebar is in the one path the view binds, bottom up (navigation state spec, section 4).
@Test func aNarrowWindowPutsEveryScreenInOnePath() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(id)"), width: .narrow)
    guard case .narrow(let path) = app.model.layout else {
        Issue.record("a window made narrow is laid out narrow, and is \(app.model.layout)")
        return
    }
    #expect(try path.map { try #require(app.model.screens[$0]) } == [listOn(inbox, in: store), taskOn(id, in: store)])
    #expect(app.model.screens.count == path.count, "a model for every id of the path, and none beside")
}

/// A wide window, the Mac's or a wide iPad window, has the sidebar in a column of its own, the first screen over it
/// as the root of the detail column, and the rest in the path the view binds there (navigation state spec, section
/// 4).
@Test func aWideWindowPutsTheFirstScreenInTheColumn() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(id)"), width: .wide)
    guard case .wide(let column?, let path) = app.model.layout else {
        Issue.record("a window made wide with a list open has the list in the column, and is \(app.model.layout)")
        return
    }
    #expect(app.model.screens[column] == (try listOn(inbox, in: store)))
    #expect(try path.map { try #require(app.model.screens[$0]) } == [taskOn(id, in: store)])
    #expect(
        app.model.screens.count == path.count + 1, "a model for the column and every id of the path, and none beside"
    )
}

/// A wide window with nothing over the sidebar, after a person deleted the Inbox, has no column, which the view draws
/// as its placeholder, and nothing in the path.
@Test func aWideWindowWithNothingOverTheSidebarHasNoColumn() throws {
    let store = try makeStore()
    try store.delete(view: inbox)
    let app = try AppModule(store: store, width: .wide)
    #expect(app.model.layout == .wide(column: nil, path: []))
    #expect(app.model.screens.isEmpty)
}

/// A window that narrows or widens is told so, and the layout is recomputed from what stands in the same event: no
/// screen is made or dropped, no sentence moves, and what each module holds for the session, a rename half typed in
/// the sidebar and a draft in quick entry, stays, as does the route (navigation state spec, section 4).
@Test func aWindowThatNarrowsOrWidensKeepsItsScreensAndTheirState() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(id)?quick-entry"), width: .wide)
    #expect(app.send(.action(.taskViewList(.renameMenuItemChosen(BuiltInTaskViews.today)))) == nil)
    #expect(app.send(.action(.taskViewList(.titleFieldChanged("Soon")))) == nil)
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Call the")))) == nil)
    #expect(app.send(.unreadableLink) == nil)
    let wide = app.model
    let route = app.route
    let ids = idsOverTheSidebar(in: wide)
    try #require(ids.count == 2, "the list and the task over it are the setup")
    #expect(app.send(.widthChanged(.narrow)) == nil)
    #expect(app.model.layout == .narrow(path: ids))
    #expect(app.model.taskViewList == wide.taskViewList)
    #expect(app.model.screens == wide.screens)
    #expect(app.model.quickEntry == wide.quickEntry)
    #expect(app.model.problem == wide.problem)
    #expect(app.route == route)
    #expect(app.send(.widthChanged(.wide)) == nil)
    #expect(app.model == wide)
    #expect(app.route == route)
}

/// In a wide window the list is the detail column's root and not in the path the view binds, so the way back
/// SwiftUI can reach stops at the list: the empty path it writes drops the task and keeps the list, and the
/// highlight with it, and the same write again, with nothing over the list, moves nothing, so "in a wide window the
/// highlight cannot be removed" holds by construction (navigation state spec, section 4).
@Test func backInAWideWindowNeverPopsTheColumn() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(id)"), width: .wide)
    guard case .wide(let column?, let path) = app.model.layout, path.count == 1 else {
        Issue.record("the list in the column and the task over it are the setup, and the layout is \(app.model.layout)")
        return
    }
    for _ in 0..<2 {
        #expect(app.send(.action(.wentBack(to: []))) == nil)
        #expect(app.model.layout == .wide(column: column, path: []))
        #expect(try standing(in: app) == [listOn(inbox, in: store)])
        #expect(app.model.taskViewList == (try sidebarOn(inbox, in: store)), "the Inbox still highlighted")
        #expect(app.route.path == "/view/\(inbox)")
    }
}

/// A way back is read against the layout the root has when the write arrives, and not the one the view bound it
/// from; the two differ only when the width moved between the binding and the write. On 2026-10-24, in the iOS 26.3
/// simulator, no write crossed a change of tree, so this pins what such a write does, and a change to it is a
/// deliberate one. The empty path a wide window's detail column writes, landing after the window narrowed, reads as
/// the narrow window's and closes the list and the task, the highlight with them, as Back to the views does. The narrow
/// path holding the list alone, landing after the window widened, reads as the list over the column, a path the stack
/// holds whole, and moves nothing.
@Test func aWayBackIsReadAgainstTheLayoutTheRootHasWhenItArrives() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let route = try Route(path: "/view/\(inbox)/task/\(id)")

    let narrowed = try AppModule(store: store, route: route, width: .wide)
    let backToTheViews = try AppModule(store: store, route: route, width: .narrow)
    #expect(narrowed.send(.widthChanged(.narrow)) == nil)
    #expect(narrowed.send(.action(.wentBack(to: []))) == nil)
    #expect(backToTheViews.send(.action(.wentBack(to: []))) == nil)
    #expect(narrowed.model.layout == .narrow(path: []), "the list and the task closed")
    #expect(narrowed.model.taskViewList.selection == nil, "and the highlight with them")
    #expect(narrowed.model == backToTheViews.model)
    #expect(narrowed.route == backToTheViews.route)
    #expect(narrowed.route.path == "/")

    let widened = try AppModule(store: store, route: route, width: .narrow)
    let list = try #require(idsOverTheSidebar(in: widened.model).first)
    #expect(widened.send(.widthChanged(.wide)) == nil)
    let model = widened.model
    let widenedRoute = widened.route
    #expect(widened.send(.action(.wentBack(to: [list]))) == nil)
    #expect(widened.model == model)
    #expect(widened.route == widenedRoute)
    #expect(try standing(in: widened) == [listOn(inbox, in: store), taskOn(id, in: store)], "the task still open")
}

/// The width a window already has, reported again, moves nothing, in either width: a view that reports its width
/// when it first draws, as the window's view does, tells a window made with that width nothing new.
@Test func theSameWidthAgainMovesNothing() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    for width in [WindowWidth.narrow, .wide] {
        let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(id)"), width: width)
        let model = app.model
        let route = app.route
        #expect(app.send(.widthChanged(width)) == nil)
        #expect(app.model == model)
        #expect(app.route == route)
    }
}

/// A link to a task in another view, while a task of a third is open: the sidebar declares the other view's list
/// whole, the stack sees another head and replaces the list and the task over it, and the new list declares its own
/// task from the link. One event, the whole chain (spec section 3, the third flow); the screens are new, with ids
/// never handed out before.
@Test func aLinkToATaskInAnotherViewMovesTheSidebarAndReplacesTheList() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let home = try taggedView("Home", in: store)
    let report = try store.createTask(NewTask(title: "Write the report", tags: [work.tag]))
    let milk = try store.createTask(NewTask(title: "Buy milk", tags: [home.tag]))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(work.view)/task/\(report)"), width: .wide)
    let replaced = idsOverTheSidebar(in: app.model)
    try #require(replaced.count == 2, "the task of the third view is the setup")
    #expect(app.send(.route(try Route(path: "/view/\(home.view)/task/\(milk)"))) == nil)
    #expect(app.model.taskViewList == (try sidebarOn(home.view, in: store)))
    #expect(try standing(in: app) == [listOn(home.view, in: store), taskOn(milk, in: store)])
    #expect(try firstList(in: app).rows.map(\.title) == ["Buy milk"])
    #expect(idsOverTheSidebar(in: app.model).allSatisfy { !replaced.contains($0) })
    #expect(app.route.path == "/view/\(home.view)/task/\(milk)")
}

/// A link to a task deleted since opens what still exists: the list is made, the task screen is not, and the list
/// says why (spec section 3, the fourth flow). The list was opened, so the sidebar has nothing to say.
@Test func aLinkToADeletedTaskOpensTheListAndASentence() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let kept = try store.createTask(NewTask(title: "Write the report", tags: [work.tag]))
    let gone = try store.createTask(NewTask(title: "File the expenses", tags: [work.tag]))
    try store.delete(task: gone)
    let app = try AppModule(store: store, width: .wide)
    #expect(app.send(.route(try Route(path: "/view/\(work.view)/task/\(gone)"))) == nil)
    #expect(app.model.taskViewList == (try sidebarOn(work.view, in: store)))
    #expect(idsOverTheSidebar(in: app.model).count == 1)
    let list = try firstList(in: app)
    #expect(list.rows.map(\.id) == [kept])
    #expect(list.problem == "The task is gone.")
    #expect(app.route.path == "/view/\(work.view)")
}

/// Following a route reconciles and never rebuilds (spec section 3): a link into a task of the view that is open
/// keeps the sidebar with the name half typed in it, and keeps the list, by its id, which declares the task.
@Test func aLinkIntoTheOpenListKeepsItsSessionState() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, width: .wide)
    let list = try #require(idsOverTheSidebar(in: app.model).first)
    #expect(app.send(.action(.taskViewList(.renameMenuItemChosen(BuiltInTaskViews.today)))) == nil)
    #expect(app.send(.action(.taskViewList(.titleFieldChanged("Soon")))) == nil)
    #expect(app.send(.route(try Route(path: "/view/\(inbox)/task/\(open)"))) == nil)
    #expect(app.model.taskViewList.rows.first { $0.id == BuiltInTaskViews.today }?.draft == "Soon")
    #expect(app.model.taskViewList.selection == inbox)
    #expect(idsOverTheSidebar(in: app.model).first == list, "the same list, by its id")
    #expect(try standing(in: app) == [listOn(inbox, in: store), taskOn(open, in: store)])
    #expect(app.route.path == "/view/\(inbox)/task/\(open)")
}

/// The list whose view was deleted asks to be closed, the stack hands that to the sidebar, which empties its
/// destination, and the walk drops the list: neither the root nor the sidebar reads the store for the list (spec
/// section 3, ADR-0006, amendment of 2026-10-14). The highlight went with the row, so the window's route names
/// nothing.
@Test func aViewDeletedUnderTheListClosesItThroughItsAnswer() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let app = try AppModule(store: store, route: try Route(path: "/view/\(work.view)"), width: .wide)
    try #require(idsOverTheSidebar(in: app.model).count == 1, "the list is open on the view before it goes")
    let deleted = try changeSet(of: store) { try store.delete(view: work.view) }
    #expect(app.send(.changed(deleted)) == nil)
    #expect(idsOverTheSidebar(in: app.model).isEmpty)
    #expect(app.model.screens.isEmpty)
    #expect(app.model.taskViewList == (try sidebarOn(ViewID(), in: store)), "the views, nothing highlighted and nothing said")
    #expect(app.route == .default)
}

/// Every module of the window takes `.changed` and decides for itself whether the change is one it reads: the
/// sidebar rereads the views, the list its tasks and the task screen its title, each handed the change by the root
/// through the stack, base first, and quick entry, which reads nothing, keeps its draft.
@Test func aChangeReachesEveryModuleInTheWindow() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(id)?quick-entry"), width: .wide)
    let path = idsOverTheSidebar(in: app.model)
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Call the")))) == nil)
    let changes = try [
        changeSet(of: store) { try store.createView(NewTaskView(title: "Docs")) },
        changeSet(of: store) { try store.createTask(NewTask(title: "Water the plants")) },
        changeSet(of: store) { try store.update(task: id, [.title("Buy oat milk")]) },
    ]
    for change in changes { #expect(app.send(.changed(change)) == nil) }
    #expect(app.model.taskViewList == (try sidebarOn(inbox, in: store)))
    #expect(app.model.taskViewList.rows.last?.title == "Docs")
    #expect(idsOverTheSidebar(in: app.model) == path)
    #expect(try standing(in: app) == [listOn(inbox, in: store), taskOn(id, in: store)])
    #expect(try firstList(in: app).rows.map(\.title) == ["Buy oat milk", "Water the plants"])
    #expect(app.model.quickEntry?.draft == "Call the")
}

/// A module never writes to the store in answer to `.changed`, which is what lets a change reach an idle window
/// inside another window's event (spec section 5): every module is live here, and every change leaves the
/// journal as it was.
@Test func theWindowNeverWritesOnChanged() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let id = try store.createTask(NewTask(title: "Write the report", tags: [work.tag]))
    let app = try AppModule(
        store: store, route: try Route(path: "/view/\(work.view)/task/\(id)?quick-entry"), width: .wide
    )
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
    let app = try AppModule(store: store, width: .wide)
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
    #expect(try standing(in: app) == [listOn(inbox, in: store)])
    #expect(try firstList(in: app).rows.map(\.title) == ["Buy milk"])
}

/// The button pressed a second time keeps the quick entry that is up, with its draft, since it has no head to
/// differ by (spec section 3).
@Test func theQuickEntryButtonKeepsTheOneThatIsUp() throws {
    let app = try AppModule(store: try makeStore(), width: .wide)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Buy milk")))) == nil)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.model.quickEntry?.draft == "Buy milk")
}

/// Cancel, the swipe down and Esc are one action, quick entry's own, which it answers by asking to be closed;
/// the draft goes with it and nothing is written.
@Test func quickEntrysCancelButtonClosesIt() throws {
    let store = try makeStore()
    let app = try AppModule(store: store, width: .wide)
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
    let app = try AppModule(store: store, width: .wide)
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
/// modules of the window leaves it: quick entry is a sheet over the window, and a tap in the list is the list's,
/// as a gesture on the task screen leaves the list's sentence.
@Test func aGestureInQuickEntryOrInTheListLeavesTheSidebarsSentence() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let report = try store.createTask(NewTask(title: "Write the report", tags: [work.tag]))
    let gone = try taggedView("Errands", in: store)
    try store.delete(view: gone.view)
    let app = try AppModule(store: store, route: try Route(path: "/view/\(work.view)?quick-entry"), width: .wide)
    let list = try #require(idsOverTheSidebar(in: app.model).first)
    #expect(app.send(.route(try Route(path: "/view/\(gone.view)?quick-entry"))) == nil)
    let sentence = try #require(app.model.taskViewList.problem, "the sentence is the setup; without it this proves nothing")
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Buy milk")))) == nil)
    #expect(app.model.quickEntry?.draft == "Buy milk", "quick entry took the keystroke")
    #expect(app.send(.action(.screen(list, .list(.rowTapped(report))))) == nil)
    #expect(try standing(in: app) == [listOn(work.view, in: store), taskOn(report, in: store)], "the list took the tap")
    #expect(app.model.taskViewList.problem == sentence)
}

/// A route with no quick entry closes the one that is up, a link from outside included, and its draft goes with
/// it: a half-typed quick entry is session state, which no route carries (spec section 2).
@Test func aLinkWithoutQuickEntryClosesTheOpenOne() throws {
    let store = try makeStore()
    let app = try AppModule(store: store, width: .wide)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Buy milk")))) == nil)
    #expect(app.send(.route(try Route(path: "/view/\(inbox)"))) == nil)
    #expect(app.model.quickEntry == nil)
    #expect(try inboxTitles(of: store).isEmpty)
    #expect(app.send(.action(.quickEntryButtonTapped)) == nil)
    #expect(app.model.quickEntry?.draft == "", "the draft went with the quick entry the link closed")
}

/// A new window is the platform's to open, so the sidebar's request climbs out of the stack and leaves the root
/// under the root's own name, with the sidebar's own route for the window (spec section 4, the rule of bubbling):
/// the root never spells the list's route. Nothing else moves in the window that asked.
@Test func openInNewWindowClimbsToTheRoot() throws {
    let app = try AppModule(store: try makeStore(), width: .wide)
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

/// `/` on a live window names no list, so the sidebar declares nothing: the list and the task over it stay, by
/// their ids, and quick entry, which `/` does not name, closes. Nothing is written again either: after Back has
/// closed the task, the sidebar's declaration still names the task its link opened, a declaration that has aged,
/// and writing it again would be a new one, which the stack would hand the list, reopening the task the person
/// closed.
@Test func aRouteThatNamesNoListKeepsTheOneOpen() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let report = try store.createTask(NewTask(title: "Write the report", tags: [work.tag]))
    let app = try AppModule(
        store: store, route: try Route(path: "/view/\(work.view)/task/\(report)?quick-entry"), width: .narrow
    )
    let path = idsOverTheSidebar(in: app.model)
    try #require(path.count == 2)
    #expect(app.send(.route(.default)) == nil)
    #expect(app.model.taskViewList == (try sidebarOn(work.view, in: store)))
    #expect(idsOverTheSidebar(in: app.model) == path, "the same list and the same task, by their ids")
    #expect(try standing(in: app) == [listOn(work.view, in: store), taskOn(report, in: store)])
    #expect(app.model.quickEntry == nil)
    #expect(app.model.problem == nil)
    #expect(app.route.path == "/view/\(work.view)/task/\(report)")
    #expect(app.send(.action(.wentBack(to: [path[0]]))) == nil)
    #expect(app.send(.route(.default)) == nil)
    #expect(app.model.taskViewList == (try sidebarOn(work.view, in: store)))
    #expect(idsOverTheSidebar(in: app.model) == [path[0]], "the same list, by its id, and no task")
    #expect(try standing(in: app) == [listOn(work.view, in: store)])
    #expect(app.model.quickEntry == nil)
    #expect(app.model.problem == nil)
    #expect(app.route.path == "/view/\(work.view)")
}

/// A click on the highlighted view declares its list again, a new declaration of the head that stands, so the stack
/// keeps the list, by its id, and hands it the declaration, whose empty tail closes the task open in it, as System
/// Settings does on the Mac and a second tap on a tab does on iOS (owner's decision of 2026-10-16).
@Test func aClickOnTheHighlightedViewReturnsToItsList() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(open)"), width: .wide)
    let path = idsOverTheSidebar(in: app.model)
    try #require(path.count == 2)
    #expect(app.send(.action(.taskViewList(.rowSelected(inbox)))) == nil)
    #expect(idsOverTheSidebar(in: app.model) == [path[0]], "the same list, by its id, and the task closed")
    #expect(try standing(in: app) == [listOn(inbox, in: store)])
    #expect(app.model.taskViewList == (try sidebarOn(inbox, in: store)))
    #expect(app.route.path == "/view/\(inbox)")
}

/// A link to a view that is gone leaves the list that was open, by its id, and the sidebar takes back its
/// highlight and says so in its own model (spec section 3).
@Test func aLinkToAViewThatIsGoneLeavesTheListAndASentence() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let gone = try taggedView("Errands", in: store)
    try store.delete(view: gone.view)
    let app = try AppModule(store: store, route: try Route(path: "/view/\(work.view)"), width: .wide)
    let path = idsOverTheSidebar(in: app.model)
    let before = app.model.taskViewList
    #expect(app.send(.route(try Route(path: "/view/\(gone.view)"))) == nil)
    #expect(app.model.taskViewList.problem == "The list could not be opened.")
    #expect(app.model.taskViewList.rows == before.rows)
    #expect(app.model.taskViewList.selection == before.selection)
    #expect(idsOverTheSidebar(in: app.model) == path)
    #expect(try standing(in: app) == [listOn(work.view, in: store)])
    #expect(app.route.path == "/view/\(work.view)")
}

/// A click on a view a peer deleted, before the change saying so has arrived: the row is still there and the click
/// declares its list, which the stack cannot make, so the list that was open stays, by its id, and the sidebar
/// takes it back as its destination, and the highlight with it, and says so (spec, "Open questions"). A link to the
/// same view ends in the same window.
@Test func aListThatCannotBeOpenedLeavesTheOpenOneHighlighted() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let gone = try taggedView("Errands", in: store)
    let app = try AppModule(store: store, route: try Route(path: "/view/\(work.view)"), width: .wide)
    let twin = try AppModule(store: store, route: try Route(path: "/view/\(work.view)"), width: .wide)
    let list = try #require(idsOverTheSidebar(in: app.model).first)
    try store.delete(view: gone.view)
    #expect(app.send(.action(.taskViewList(.rowSelected(gone.view)))) == nil)
    #expect(idsOverTheSidebar(in: app.model) == [list])
    #expect(try standing(in: app) == [listOn(work.view, in: store)])
    #expect(app.model.taskViewList.selection == work.view)
    #expect(app.model.taskViewList.rows.filter(\.isSelected).map(\.id) == [work.view])
    #expect(app.model.taskViewList.problem == "The list could not be opened.")
    #expect(app.route.path == "/view/\(work.view)")
    #expect(twin.send(.route(try Route(path: "/view/\(gone.view)"))) == nil)
    #expect(twin.model == app.model)
}

/// A link to a view that has not synced to this device yet: the sidebar declares its list, the stack cannot make
/// it, and the sidebar takes back nothing and says so. When the view arrives from the peer, its row is not
/// highlighted, since nothing declares it, and no list opens beside it (spec, "Open questions").
@Test func aLinkToAViewNotYetHereStaysUnhighlightedWhenItArrives() throws {
    let store = try makeStore()
    let linked = ViewID()
    let app = try AppModule(store: store, route: try Route(path: "/view/\(linked)"), width: .wide)
    #expect(idsOverTheSidebar(in: app.model).isEmpty, "no view, no list; this is the setup")
    #expect(app.model.taskViewList.problem == "The list could not be opened.")
    let peer = Store.newDeviceID()
    let later = HLC(millis: 1_800_000_000_000, counter: 0)
    let fields: [(String, Value)] = [
        ("title", .text("Work")), ("parent", .null), ("rank", .text(Rank.initial)), ("deleted", Value(false)),
    ]
    let synced = try changeSet(of: store) {
        _ = try store.apply(fields.map {
            JournalOperation(entity: .view, entityID: linked.rawValue, field: $0.0, value: $0.1, clock: later, device: peer)
        })
    }
    #expect(app.send(.changed(synced)) == nil)
    #expect(app.model.taskViewList.rows.map(\.id).contains(linked), "the view arrived; without it this proves nothing")
    #expect(app.model.taskViewList.selection == nil, "a highlight beside no list")
    #expect(app.model.taskViewList.rows.filter(\.isSelected).isEmpty)
    #expect(app.model.taskViewList.problem == "The list could not be opened.", "a change answers nothing a person was told")
    #expect(idsOverTheSidebar(in: app.model).isEmpty)
    #expect(app.route == .default)
}

/// An action sent with the id of a screen the stack has dropped since its view read it, a tap on a row of a list
/// that another view's list replaced, moves nothing and answers nothing: the view can send one after a change the
/// model drove.
@Test func anActionForAScreenThatIsGoneMovesNothing() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, width: .wide)
    let replaced = try #require(idsOverTheSidebar(in: app.model).first)
    #expect(app.send(.action(.taskViewList(.rowSelected(BuiltInTaskViews.today)))) == nil)
    let model = app.model
    #expect(!idsOverTheSidebar(in: model).contains(replaced), "the Inbox's list was replaced; this is the setup")
    #expect(app.send(.action(.screen(replaced, .list(.rowTapped(id))))) == nil)
    #expect(app.model == model)
    #expect(app.route.path == "/view/\(BuiltInTaskViews.today)")
}

/// The window's route is written from what stands, each screen's route over the one standing above it (spec
/// section 3): after Back closes the task, the sidebar still declares the list with the task its link named, a
/// declaration that has aged, and the route names the list alone, so a relaunch opens what stood and not the task
/// the person closed.
@Test func theRouteIsWrittenFromWhatStands() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/view/\(inbox)/task/\(id)"), width: .narrow)
    let path = idsOverTheSidebar(in: app.model)
    try #require(path.count == 2)
    #expect(app.send(.action(.wentBack(to: [path[0]]))) == nil)
    #expect(app.route.path == "/view/\(inbox)")
    let relaunched = try AppModule(store: store, route: try Route(path: app.route.path), width: .narrow)
    #expect(relaunched.model == app.model, "a relaunch opens what stood")
    #expect(relaunched.route == app.route)
}

/// The root's own sentence, for a link the composition root could not read (the owner, 2026-10-16, answering the
/// spec's open question; `docs/specs/navigation.md`, section 7).
private let linkSentence = "The link could not be opened."

/// A link that does not read moves nothing in the window: the sidebar, the list and the task over it, by their ids,
/// and quick entry with its draft stay as they were, and so does the route. The root says so in a sentence of its
/// own, since what failed is no child's.
@Test func anUnreadableLinkLeavesTheWindowAndSaysSo() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(
        store: store, route: try Route(path: "/view/\(inbox)/task/\(open)?quick-entry"), width: .wide
    )
    #expect(app.send(.action(.quickEntry(.titleFieldChanged("Call the")))) == nil)
    let before = app.model
    let route = app.route
    #expect(before.problem == nil, "nothing is said before the link; without that this proves nothing")
    #expect(app.send(.unreadableLink) == nil)
    #expect(app.model.taskViewList == before.taskViewList)
    #expect(app.model.layout == before.layout)
    #expect(app.model.screens == before.screens)
    #expect(app.model.quickEntry == before.quickEntry)
    #expect(app.model.problem == linkSentence)
    #expect(app.route == route)
}

/// Every link that does not read says so: a second one in a row leaves the window as one did, and one after the
/// sentence was taken away says it again.
@Test func everyUnreadableLinkSaysSo() throws {
    let store = try makeStore()
    let app = try AppModule(store: store, width: .wide)
    let once = try AppModule(store: store, width: .wide)
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
    let app = try AppModule(store: store, width: .wide)
    let twin = try AppModule(store: store, width: .wide)
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
    let app = try AppModule(store: store, width: .wide)
    let twin = try AppModule(store: store, width: .wide)
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

/// A gesture in one of the window's modules other than the root is that module's, so it leaves the root's sentence,
/// as a gesture in the list leaves the sidebar's: a choice in the sidebar, a tap in the list it declared, the way
/// back from the task it pushed and a keystroke in quick entry each move their own module, as they do in a window
/// that never had the link, and the sentence stays.
@Test func aGestureInAChildLeavesTheRootsSentence() throws {
    let store = try makeStore()
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let app = try AppModule(store: store, route: try Route(path: "/?quick-entry"), width: .narrow)
    let twin = try AppModule(store: store, route: try Route(path: "/?quick-entry"), width: .narrow)
    #expect(app.send(.unreadableLink) == nil)
    let choices: [AppModule.UserAction] = [
        .taskViewList(.rowSelected(BuiltInTaskViews.today)),
        .taskViewList(.rowSelected(inbox)),
    ]
    for window in [app, twin] {
        for choice in choices { #expect(window.send(.action(choice)) == nil) }
        let list = try #require(idsOverTheSidebar(in: window.model).first)
        #expect(window.send(.action(.screen(list, .list(.rowTapped(open))))) == nil)
        #expect(try standing(in: window) == [listOn(inbox, in: store), taskOn(open, in: store)], "the tap pushed the task; this is the setup")
        #expect(window.send(.action(.wentBack(to: [list]))) == nil)
        #expect(window.send(.action(.quickEntry(.titleFieldChanged("Call the bank")))) == nil)
    }
    #expect(try standing(in: twin) == [listOn(inbox, in: store)], "the way back closed the task; this is the setup")
    #expect(twin.model.quickEntry?.draft == "Call the bank", "and quick entry took the keystroke")
    #expect(app.model.taskViewList == twin.model.taskViewList)
    #expect(app.model.layout == twin.model.layout)
    #expect(app.model.screens == twin.model.screens)
    #expect(app.model.quickEntry == twin.model.quickEntry)
    #expect(app.model.problem == linkSentence)
    #expect(app.route == twin.route)
}

/// A change another window or another device made answers nothing a person was told, and neither does being created,
/// so both leave the root's sentence while the change is read as in any window.
@Test func aChangeOrBeingCreatedLeavesTheRootsSentence() throws {
    let store = try makeStore()
    let app = try AppModule(store: store, width: .wide)
    let twin = try AppModule(store: store, width: .wide)
    #expect(app.send(.unreadableLink) == nil)
    let changes = try changeSet(of: store) { try store.createTask(NewTask(title: "Buy milk")) }
    for event in [AppModule.Event.changed(changes), .created] {
        #expect(app.send(event) == nil)
        #expect(twin.send(event) == nil)
    }
    #expect(try firstList(in: twin).rows.map(\.title) == ["Buy milk"], "the change was read; this is the setup")
    #expect(app.model.taskViewList == twin.model.taskViewList)
    #expect(app.model.layout == twin.model.layout)
    #expect(app.model.screens == twin.model.screens)
    #expect(app.model.quickEntry == twin.model.quickEntry)
    #expect(app.model.problem == linkSentence)
}
