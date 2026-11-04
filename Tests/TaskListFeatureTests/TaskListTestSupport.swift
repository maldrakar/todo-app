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

/// A row's model, read over its kind as a view reads it.
func row(_ row: TaskList.Model.Row) -> TaskRowModel<TaskList.UserAction> {
    switch row {
    case .task(_, let model): model
    }
}

/// The rows a model draws, block by block and flattened, as their ids and their titles.
func rows(of model: TaskList.Model) -> [(id: TaskID, title: String)] {
    blocks(of: model).flatMap(\.rows).map { ($0.id, row($0).title.text) }
}
