import Testing
import TestSupport
import DesignSystemComponents
import TaskListFeature
import TodoCore

// The helpers the target's test files share: one shape for reading a list's model, as a view reads it (`docs/style.md`,
// "One shape everywhere it fits").

/// The day `offset` days from the test's, Wednesday, September 10, 2025.
func day(_ offset: Int) -> Day {
    testDay.day.advanced(by: offset)
}

/// A list made now on the route, on the day, the test's unless another is named.
func list(_ route: TaskList.Route, in store: Store, on day: DeviceDay = testDay) throws -> TaskList {
    try TaskList(store: store, route: route, day: day)
}

/// A list made now on a view, with nothing declared over it.
func list(_ view: ViewID, in store: Store, on day: DeviceDay = testDay) throws -> TaskList {
    try list(TaskList.Route(head: .init(view: view)), in: store, on: day)
}

/// The blocks a model draws, whichever its layout: a list's, or the board's columns, read over the layout's shapes as
/// the list's view reads them.
func blocks(of model: TaskList.Model) -> [TaskList.Model.Block] {
    switch model.layout {
    case .list(let blocks): blocks
    case .columns(let board): board.columns
    }
}

/// A row's model, read over its kind as a view reads it, for a row a test knows is no open card.
func row(_ row: TaskList.Model.Row) -> TaskRowModel<TaskList.UserAction> {
    switch row {
    case .task(_, let model): model
    case .card: preconditionFailure("the test reads a row where a card is open")
    }
}

/// The rows a model draws, block by block and flattened, as their ids and their titles, a card's title its field's.
func rows(of model: TaskList.Model) -> [(id: TaskID, title: String)] {
    blocks(of: model).flatMap(\.rows).map { row in
        switch row {
        case .task(let id, let model): (id, model.title.text)
        case .card(let id, let card): (id, card.title.text)
        }
    }
}

/// The ids of the rows a block of a model draws, in their order, and none for a block the model does not draw.
func rowIDs(of block: TaskList.Model.BlockID, in model: TaskList.Model) -> [TaskID] {
    blocks(of: model).first { $0.id == block }?.rows.map(\.id) ?? []
}

/// The block of a model by its id.
func block(_ id: TaskList.Model.BlockID, of model: TaskList.Model) -> TaskList.Model.Block? {
    blocks(of: model).first { $0.id == id }
}

/// The open card a model draws, in a block or under the strip, and its task's id, and nil while none is open.
func openCard(in model: TaskList.Model) -> (id: TaskID, card: CardModel<TaskList.UserAction>)? {
    for row in blocks(of: model).flatMap(\.rows) + model.doneRows {
        if case .card(let id, let card) = row { return (id, card) }
    }
    return nil
}

/// How many transactions a run of writes commits, each one `.changed` a window rereads for.
func commits(of store: Store, during writes: () throws -> Void) rethrows -> Int {
    var commits = 0
    store.onChange = { _ in commits += 1 }
    defer { store.onChange = nil }
    try writes()
    return commits
}

/// A task read back from the store, which a test expects there.
func stored(_ id: TaskID, in store: Store) throws -> TodoTask {
    try #require(try store.task(id))
}

extension TaskList {
    /// Sends a view's action, which answers nothing: what it moves is read from the model and the store.
    func tap(_ action: UserAction, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(send(.action(action)) == nil, sourceLocation: sourceLocation)
    }
}
