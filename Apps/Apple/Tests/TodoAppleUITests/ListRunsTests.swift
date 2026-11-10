import TaskListFeature
import Testing
@testable import TodoAppleUI
import TodoCore

// The list screen's blocks cut around the one part that holds a field, `ListRuns`: the parts before it stand in a lazy
// stack, the part itself outside, and the parts after it in a lazy stack again, so that its field is never taken out
// of the window (#196). The blocks are the ones a real `TaskList` draws (`LiftedList`).

/// What a run draws of a block: whether its header, its top mark and its "+ Add task", and its rows, by their tasks.
private struct Drawn: Equatable {
    let block: TaskList.Model.BlockID
    let header: Bool
    let topMark: Bool
    let rows: [TaskID]
    let add: Bool

    /// The whole of a block.
    init(whole block: TaskList.Model.Block) {
        self.init(block.id, header: true, topMark: true, rows: block.rows.map(\.id), add: true)
    }

    init(_ block: TaskList.Model.BlockID, header: Bool, topMark: Bool, rows: [TaskID], add: Bool) {
        self.block = block
        self.header = header
        self.topMark = topMark
        self.rows = rows
        self.add = add
    }
}

private func drawn(_ pieces: [ListRuns.Piece]) -> [Drawn] {
    pieces.map { piece in
        Drawn(
            piece.block.id, header: piece.parts.header, topMark: piece.parts.topMark,
            rows: piece.block.rows[piece.parts.rows].map(\.id), add: piece.parts.add
        )
    }
}

/// With no field open the whole list stands in the first lazy stack, and the second holds only what follows the
/// blocks.
@Test func withNoFieldEveryBlockStandsBeforeIt() throws {
    let list = try LiftedList()
    let runs = ListRuns(list.blocks)
    #expect(drawn(runs.before) == list.blocks.map { Drawn(whole: $0) })
    #expect(runs.field.isEmpty)
    #expect(runs.after.isEmpty)
}

/// An open card in the middle of a block stands alone outside the lazy stacks: before it the blocks above and its
/// block's header and rows above it; after it its block's rows below it and its "+ Add task", and the blocks below.
@Test func anOpenCardStandsAloneBetweenTheRowsAboveAndBelowIt() throws {
    let list = try LiftedList(taskInHouseAndOffice: true)
    let own = TaskList.Model.BlockID.own(nil)
    let house = TaskList.Model.BlockID.list(list.house)
    let both = try #require(list.both)
    list.openCard(on: list.h2)
    #expect(list.rowIDs(of: house) == [list.h1, list.h2, both])
    let blocks = list.blocks
    #expect(blocks.map(\.id).prefix(2) == [own, house])

    let runs = ListRuns(blocks)
    #expect(drawn(runs.before) == [
        Drawn(whole: blocks[0]),
        Drawn(house, header: true, topMark: true, rows: [list.h1], add: false),
    ])
    #expect(drawn(runs.field) == [Drawn(house, header: false, topMark: false, rows: [list.h2], add: false)])
    #expect(drawn(runs.after) == [Drawn(house, header: false, topMark: false, rows: [both], add: true)]
        + blocks.dropFirst(2).map { Drawn(whole: $0) })
}

/// A block's header whose list's name is being typed stands alone outside the lazy stacks, and the rest of its block
/// and the blocks below it after it.
@Test func aHeaderWithAFieldStandsAloneBeforeTheRestOfItsBlock() throws {
    let list = try LiftedList()
    list.addList()
    let blocks = list.blocks
    let named = try #require(blocks.firstIndex { $0.header?.field != nil })
    let block = blocks[named]

    let runs = ListRuns(blocks)
    #expect(drawn(runs.before) == blocks.prefix(named).map { Drawn(whole: $0) })
    #expect(drawn(runs.field) == [Drawn(block.id, header: true, topMark: false, rows: [], add: false)])
    #expect(drawn(runs.after) == [Drawn(block.id, header: false, topMark: true, rows: block.rows.map(\.id), add: true)]
        + blocks.suffix(from: named + 1).map { Drawn(whole: $0) })
}
