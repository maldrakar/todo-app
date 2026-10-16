import Testing
import TestSupport
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
