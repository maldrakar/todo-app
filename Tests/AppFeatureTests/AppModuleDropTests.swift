import Testing
import TestSupport
import AppFeature
import FeatureModule
import TaskListFeature
import TodoCore

// A list the window's stack lets go closes what it has open by the rule of every close, as its own back button does,
// whichever way it goes, and writes nothing when it goes in answer to a change the store committed (#195; ADR-0009,
// amendment of 2026-11-10). One test per acceptance criterion of the issue.

private typealias Route = AppModule.Route

/// A window on the route the path reads as, of the width, made on the test's day with what iPhone's window offers.
private func window(on path: String, in store: Store, width: WindowWidth) throws -> AppModule {
    try AppModule(store: store, route: try Route(path: path), width: width, day: testDay, capabilities: iPhone)
}

/// The task whose card is open in the list standing at `id`, nil when no card is, read over the layout and a row's
/// kind as the list's view reads them.
private func openCard(in app: AppModule, on id: StackElementID) -> TaskID? {
    guard case .list(let list)? = app.model.screens[id] else { return nil }
    let blocks = switch list.layout {
    case .list(let blocks): blocks
    case .columns(let board): board.columns
    }
    return blocks.flatMap(\.rows).lazy.compactMap { row -> TaskID? in
        switch row {
        case .task: nil
        case .card(let task, _): task
        }
    }.first
}

/// How many times the journal holds a write of a task's title, its creation's among them.
private func titleWrites(of id: TaskID, in store: Store) throws -> Int {
    try store.journal(after: 0).count { $0.entity == .task && $0.entityID == id.rawValue && $0.field == "title" }
}

extension AppModule {
    /// What the view of the list standing at `id` sends, which answers nothing out of the window.
    fileprivate func tap(_ action: TaskList.UserAction, on id: StackElementID) {
        #expect(send(.action(.screen(id, .list(action)))) == nil)
    }
}

/// The swipe from the edge on iPhone, the stack's pop, writes what the open card holds as the list goes: the title
/// typed without Return, and the notes.
@Test func theSwipeBackWritesTheOpenCardsTitleAndNotes() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try window(on: "/view/\(inbox)", in: store, width: .narrow)
    let list = try #require(idsOverTheSidebar(in: app.model).first)
    app.tap(.rowTapped(id), on: list)
    app.tap(.titleFieldChanged("Buy oat milk"), on: list)
    app.tap(.notesFieldChanged("two litres"), on: list)
    #expect(app.send(.action(.wentBack(to: []))) == nil)
    #expect(idsOverTheSidebar(in: app.model).isEmpty)
    #expect(try store.task(id)?.title == "Buy oat milk")
    #expect(try store.notes(of: id) == "two litres")
}

/// The swipe after the floating "+" with nothing typed deletes the new task, which nothing was put in.
@Test func theSwipeBackDeletesANewTaskWithNothingInIt() throws {
    let store = try makeStore()
    let app = try window(on: "/view/\(inbox)", in: store, width: .narrow)
    let list = try #require(idsOverTheSidebar(in: app.model).first)
    app.tap(.addTaskButtonTapped, on: list)
    let new = try #require(openCard(in: app, on: list))
    try #require(try store.task(new) != nil, "the \"+\" wrote the task; this is the setup")
    #expect(app.send(.action(.wentBack(to: []))) == nil)
    #expect(try store.task(new) == nil)
}

/// The swipe writes the name of a new list being typed in "+ Add list".
@Test func theSwipeBackWritesTheNameOfANewList() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let app = try window(on: "/view/\(projects)", in: store, width: .narrow)
    let list = try #require(idsOverTheSidebar(in: app.model).first)
    app.tap(.addListTapped, on: list)
    let made = try #require(try store.children(ofView: projects).last)
    app.tap(.listNameFieldChanged("Errands"), on: list)
    #expect(app.send(.action(.wentBack(to: []))) == nil)
    #expect(try store.view(made.id)?.title == "Errands")
}

/// One pop of several screens lets a list go with the screen over it, and the list closes what it has open as it goes:
/// a list whose card stayed open under the list inside it that its block's title pushed writes the card's title, and
/// a list whose card's Open full screen pushed the task screen deletes its new task with nothing in it. On iPhone such
/// a pop is the long-press menu of a task screen's back, since a list screen hides its bar: the pop of the two lists
/// is what that menu does with a task screen on top of them, which the stack lets go first.
@Test func aListLetGoWithTheScreenOverItClosesWhatItHasOpen() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let house = try store.createView(NewTaskView(title: "House", parent: projects, filter: .status([.open])))
    let id = try store.createTask(NewTask(title: "Fix the door"))
    let app = try window(on: "/view/\(projects)", in: store, width: .narrow)
    let outer = try #require(idsOverTheSidebar(in: app.model).first)
    app.tap(.rowTapped(id), on: outer)
    app.tap(.titleFieldChanged("Fix the back door"), on: outer)
    app.tap(.blockTitleTapped(.list(house)), on: outer)
    try #require(idsOverTheSidebar(in: app.model).count == 2, "House over Projects, the card open under it; the setup")
    try #require(openCard(in: app, on: outer) == id)
    #expect(app.send(.action(.wentBack(to: []))) == nil)
    #expect(idsOverTheSidebar(in: app.model).isEmpty)
    #expect(try store.task(id)?.title == "Fix the back door")

    let full = try window(on: "/view/\(inbox)", in: store, width: .narrow)
    let list = try #require(idsOverTheSidebar(in: full.model).first)
    full.tap(.addTaskButtonTapped, on: list)
    let new = try #require(openCard(in: full, on: list))
    full.tap(.openFullScreenTapped, on: list)
    try #require(idsOverTheSidebar(in: full.model).count == 2, "the task screen over the list; this is the setup")
    #expect(full.send(.action(.wentBack(to: []))) == nil)
    #expect(idsOverTheSidebar(in: full.model).isEmpty)
    #expect(try store.task(new) == nil)
}

/// In a wide window the way back is the stack's pop over the column: on the Mac the toolbar's back, which pops one
/// screen, and on the iPad a task screen's back, which the system keeps, and its long-press menu, which pops several. A
/// list over the column's list closes what it has open as it goes, by one pop its card's title and notes written, and
/// by a pop of several its new task with nothing in it deleted from under the task screen. The column's list stays.
@Test func theWayBackOverAListInAWideWindowClosesWhatTheListHasOpen() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let house = try store.createView(NewTaskView(title: "House", parent: projects, filter: .status([.open])))
    let id = try store.createTask(NewTask(title: "Fix the door"))
    let app = try window(on: "/view/\(projects)/view/\(house)", in: store, width: .wide)
    let ids = idsOverTheSidebar(in: app.model)
    try #require(ids.count == 2)
    try #require(app.model.layout == .wide(column: ids[0], path: [ids[1]]), "a list over the column's; the setup")
    app.tap(.rowTapped(id), on: ids[1])
    app.tap(.titleFieldChanged("Fix the back door"), on: ids[1])
    app.tap(.notesFieldChanged("the hinge"), on: ids[1])
    #expect(app.send(.action(.wentBack(to: []))) == nil)
    #expect(idsOverTheSidebar(in: app.model) == [ids[0]])
    #expect(try store.task(id)?.title == "Fix the back door")
    #expect(try store.notes(of: id) == "the hinge")

    app.tap(.blockTitleTapped(.list(house)), on: ids[0])
    let inner = try #require(idsOverTheSidebar(in: app.model).last)
    try #require(idsOverTheSidebar(in: app.model) == [ids[0], inner], "House over the column again; the setup")
    app.tap(.addTaskButtonTapped, on: inner)
    let new = try #require(openCard(in: app, on: inner))
    app.tap(.openFullScreenTapped, on: inner)
    try #require(idsOverTheSidebar(in: app.model).count == 3, "the task screen over House; this is the setup")
    #expect(app.send(.action(.wentBack(to: []))) == nil)
    #expect(idsOverTheSidebar(in: app.model) == [ids[0]])
    #expect(try store.task(new) == nil)
}

/// A list let go because its opener declared another screen over itself writes what its card holds: in a wide window,
/// another list chosen in the sidebar while the pane's list has a card open, and a link to another list.
@Test func aListAnotherScreenReplacesWritesWhatItsCardHolds() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let app = try window(on: "/view/\(inbox)", in: store, width: .wide)
    let list = try #require(idsOverTheSidebar(in: app.model).first)
    app.tap(.rowTapped(id), on: list)
    app.tap(.titleFieldChanged("Buy oat milk"), on: list)
    #expect(app.send(.action(.taskViewList(.rowSelected(projects)))) == nil)
    let chosen = idsOverTheSidebar(in: app.model)
    #expect(chosen.count == 1 && chosen != [list], "Projects replaced the Inbox")
    #expect(try store.task(id)?.title == "Buy oat milk")

    let linked = try window(on: "/view/\(inbox)", in: store, width: .narrow)
    let first = try #require(idsOverTheSidebar(in: linked.model).first)
    linked.tap(.rowTapped(id), on: first)
    linked.tap(.titleFieldChanged("Buy soy milk"), on: first)
    #expect(linked.send(.route(try Route(path: "/view/\(projects)"))) == nil)
    let opened = idsOverTheSidebar(in: linked.model)
    #expect(opened.count == 1 && opened != [first], "the link's list replaced the Inbox")
    #expect(try store.task(id)?.title == "Buy soy milk")
}

/// A list let go because its opener emptied its destination at a person's gesture writes what its card holds, once:
/// the glass back of a list over a list closes the card itself before it answers, so the drop that follows finds
/// nothing open and the title is written once; and a click on the view already highlighted in a wide window empties
/// the column's list's destination, which lets go of the list over it, which writes its card's title.
@Test func aListItsOpenerClosesWritesWhatItsCardHoldsOnce() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let house = try store.createView(NewTaskView(title: "House", parent: projects, filter: .status([.open])))
    let id = try store.createTask(NewTask(title: "Fix the door"))
    let app = try window(on: "/view/\(projects)/view/\(house)", in: store, width: .narrow)
    let path = idsOverTheSidebar(in: app.model)
    try #require(path.count == 2)
    app.tap(.rowTapped(id), on: path[1])
    app.tap(.titleFieldChanged("Fix the back door"), on: path[1])
    let written = try titleWrites(of: id, in: store)
    app.tap(.backButtonTapped, on: path[1])
    #expect(idsOverTheSidebar(in: app.model) == [path[0]])
    #expect(try store.task(id)?.title == "Fix the back door")
    #expect(try titleWrites(of: id, in: store) == written + 1, "by the back button, and not again by the drop")

    let wide = try window(on: "/view/\(projects)/view/\(house)", in: store, width: .wide)
    let ids = idsOverTheSidebar(in: wide.model)
    try #require(ids.count == 2)
    wide.tap(.rowTapped(id), on: ids[1])
    wide.tap(.titleFieldChanged("Fix the front door"), on: ids[1])
    #expect(wide.send(.action(.taskViewList(.rowSelected(projects)))) == nil)
    #expect(idsOverTheSidebar(in: wide.model) == [ids[0]], "the column's list stays, with nothing over it")
    #expect(try store.task(id)?.title == "Fix the front door")
}

/// A list let go in answer to a change the store committed writes nothing, since no module writes in answer to
/// `.changed`, which a change reaching every window inside another window's event rests on (ADR-0009): its view
/// deleted through the store, the change handed to the window, the text typed in its card is not in the store. The
/// owner accepted that loss.
@Test func aListLetGoInAnswerToAChangeWritesNothing() throws {
    let store = try makeStore()
    let work = try taggedView("Work", in: store)
    let id = try store.createTask(NewTask(title: "Write the report", tags: [work.tag]))
    let app = try window(on: "/view/\(work.view)", in: store, width: .narrow)
    let list = try #require(idsOverTheSidebar(in: app.model).first)
    app.tap(.rowTapped(id), on: list)
    app.tap(.titleFieldChanged("Write the summary"), on: list)
    let deleted = try changeSet(of: store) { try store.delete(view: work.view) }
    let written = try store.journal(after: 0).count
    #expect(app.send(.changed(deleted)) == nil)
    #expect(idsOverTheSidebar(in: app.model).isEmpty, "the list went with its view")
    #expect(try store.journal(after: 0).count == written)
    #expect(try store.task(id)?.title == "Write the report")
}
