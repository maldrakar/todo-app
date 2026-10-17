import Testing
import TestSupport
import FeatureModule
import TaskScreenFeature
import TodoCore

/// The screen shows the title its task has in the store, and answers being created, and a route onto the task
/// it is already on, with nothing: it has no tail to move and nothing to choose.
@Test func aTaskScreenShowsTheTitle() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let screen = try TaskScreen(store: store, route: .init(head: id))
    #expect(screen.model.title == "Buy milk")
    #expect(screen.route == .init(head: id))
    let before = screen.model
    #expect(screen.send(.created) == nil)
    #expect(screen.send(.route(.init(head: id))) == nil)
    #expect(screen.model == before)
}

/// A screen on a task that is gone is not made, and its `init` says which task it looked for: the parent keeps
/// what was open and says so in its own model (spec section 3).
@Test func aTaskScreenOnAGoneTaskIsNotMade() throws {
    let store = try makeStore()
    let gone = try store.createTask(NewTask(title: "Buy milk"))
    try store.delete(task: gone)
    #expect(throws: StoreError.notFound(gone)) { try TaskScreen(store: store, route: .init(head: gone)) }
    let unknown = TaskID()
    #expect(throws: StoreError.notFound(unknown)) { try TaskScreen(store: store, route: .init(head: unknown)) }
}

@Test func aChangeNamingTheTaskRereadsTheTitle() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let screen = try TaskScreen(store: store, route: .init(head: id))
    let renamed = try changeSet(of: store) { try store.update(task: id, [.title("Buy oat milk")]) }
    #expect(screen.send(.changed(renamed)) == nil)
    #expect(screen.model == (try TaskScreen(store: store, route: .init(head: id))).model, "the screen a link would make now")
    #expect(screen.model.title == "Buy oat milk")
}

/// The rename below is written without its change being delivered, and the change of another task is delivered
/// in its place: a screen that read on any change would have seen the rename.
@Test func aChangeNamingAnotherTaskReadsNothing() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let screen = try TaskScreen(store: store, route: .init(head: id))
    let before = screen.model
    try store.update(task: id, [.title("Buy oat milk")])
    let other = try changeSet(of: store) { try store.createTask(NewTask(title: "Call the bank")) }
    #expect(screen.send(.changed(other)) == nil)
    #expect(screen.model == before, "the rename is missing, which is how a read that never ran shows")
}

/// A screen whose subject is gone asks to be closed, and its parent drops it (spec section 3). Nothing else
/// moves: the title it showed is the last one the task had.
@Test func aTaskDeletedUnderTheScreenAsksToClose() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let screen = try TaskScreen(store: store, route: .init(head: id))
    let before = screen.model
    let deleted = try changeSet(of: store) { try store.delete(task: id) }
    #expect(screen.send(.changed(deleted)) == .closeRequested)
    #expect(screen.model == before)
}

/// A task as the command line prints its id, fixed so that a refusal can name it.
private let task = TaskID("0d9e8f7a-6b5c-4d3e-9f2a-1b0c9d8e7f6a")

/// The screen's route owns `task/<id>` in a window's path: it reads them from the front and leaves what follows
/// for its parent, which knows the words around it, and it writes them as the command line prints the id.
@Test func theRouteReadsAndWritesTaskAndItsID() throws {
    var path: ArraySlice = ["task", task.rawValue, "edit"]
    let route = try TaskScreen.Route(reading: &path)
    #expect(route == .init(head: task))
    #expect(path == ["edit"])
    #expect(route.segments == ["task", task.rawValue])
    var shouted: ArraySlice = ["task", task.rawValue.uppercased()]
    #expect(try TaskScreen.Route(reading: &shouted) == route, "an id reads in either case and is kept lowercase")
}

/// What stands where the id must and does not read whole as one is refused as written, nothing at all is an empty
/// id, and a path that does not begin with the screen's word is not the screen's.
@Test func theRouteRefusesWhatIsNotItsWordAndAnID() {
    for (segments, error) in [
        (["task", "42"], RouteError.notAnID("42")),
        (["task"], .notAnID("")),
        (["task", ""], .unknownSegment("")),
        (["task", "\(task)\u{0}"], .notAnID("\(task)\u{0}")),
        (["note", task.rawValue], .unknownSegment("note")),
    ] {
        var path = ArraySlice(segments)
        #expect(throws: error, "reading \(segments)") { try TaskScreen.Route(reading: &path) }
    }
}
