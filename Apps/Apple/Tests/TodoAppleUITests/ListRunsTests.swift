import TaskListFeature
import Testing
@testable import TodoAppleUI
import TodoCore

// The list screen's blocks cut at every part that holds a field, `ListRuns`: each part that holds a field stands
// outside the lazy stacks, so that its field is never taken out of the window, at the head of the run whose lazy stack
// holds the parts after it, the first run holding those before the first field; the Done strip's rows leave their lazy
// stack while one of them holds a field (#196). The blocks are the ones a real `TaskList` draws (`LiftedList`).

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

    init(_ piece: ListRuns.Piece) {
        self.init(
            piece.block.id, header: piece.parts.header, topMark: piece.parts.topMark,
            rows: piece.block.rows[piece.parts.rows].map(\.id), add: piece.parts.add
        )
    }

    init(_ block: TaskList.Model.BlockID, header: Bool, topMark: Bool, rows: [TaskID], add: Bool) {
        self.block = block
        self.header = header
        self.topMark = topMark
        self.rows = rows
        self.add = add
    }
}

/// What a run draws: the part that holds a field at its head, none for the first run, and the pieces in its lazy stack.
private struct DrawnRun: Equatable {
    let field: Drawn?
    let lazy: [Drawn]
}

private func drawn(_ runs: ListRuns) -> [DrawnRun] {
    runs.runs.map { run in DrawnRun(field: run.field.map(Drawn.init), lazy: run.lazy.map(Drawn.init)) }
}

/// With no field open the blocks stand whole in the first run's lazy stack.
@Test func withNoFieldTheBlocksStandInOneLazyRun() throws {
    let list = try LiftedList()
    let runs = ListRuns(list.blocks, doneRows: [])
    #expect(drawn(runs) == [DrawnRun(field: nil, lazy: list.blocks.map { Drawn(whole: $0) })])
    #expect(!runs.doneRowsHoldField)
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

    #expect(drawn(ListRuns(blocks, doneRows: [])) == [
        DrawnRun(
            field: nil,
            lazy: [Drawn(whole: blocks[0]), Drawn(house, header: true, topMark: true, rows: [list.h1], add: false)]
        ),
        DrawnRun(
            field: Drawn(house, header: false, topMark: false, rows: [list.h2], add: false),
            lazy: [Drawn(house, header: false, topMark: false, rows: [both], add: true)]
                + blocks.dropFirst(2).map { Drawn(whole: $0) }
        ),
    ])
}

/// An open card as its block's first row, in a block with no header, stands alone with nothing of its block above it
/// but the mark at its top.
@Test func aCardAsTheFirstRowOfABlockWithNoHeaderStandsAlone() throws {
    let list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    list.openCard(on: list.a)
    let blocks = list.blocks
    #expect(blocks.first?.id == own)
    #expect(blocks.first?.header == nil)

    #expect(drawn(ListRuns(blocks, doneRows: [])) == [
        DrawnRun(field: nil, lazy: [Drawn(own, header: true, topMark: true, rows: [], add: false)]),
        DrawnRun(
            field: Drawn(own, header: false, topMark: false, rows: [list.a], add: false),
            lazy: [Drawn(own, header: false, topMark: false, rows: [list.b, list.c, list.d], add: true)]
                + blocks.dropFirst().map { Drawn(whole: $0) }
        ),
    ])
}

/// A task two blocks draw is open in both, each its block's last row here: each card stands alone outside the lazy
/// stacks, with a lazy run between them.
@Test func eachCardOfATaskTwoBlocksDrawStandsAlone() throws {
    let list = try LiftedList(taskInHouseAndOffice: true)
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let both = try #require(list.both)
    list.openCard(on: both)
    let blocks = list.blocks
    #expect(blocks.map(\.id).dropFirst().prefix(2) == [house, office])

    #expect(drawn(ListRuns(blocks, doneRows: [])) == [
        DrawnRun(
            field: nil,
            lazy: [
                Drawn(whole: blocks[0]),
                Drawn(house, header: true, topMark: true, rows: [list.h1, list.h2], add: false),
            ]
        ),
        DrawnRun(
            field: Drawn(house, header: false, topMark: false, rows: [both], add: false),
            lazy: [
                Drawn(house, header: false, topMark: false, rows: [], add: true),
                Drawn(office, header: true, topMark: true, rows: [list.o1, list.o2], add: false),
            ]
        ),
        DrawnRun(
            field: Drawn(office, header: false, topMark: false, rows: [both], add: false),
            lazy: [Drawn(office, header: false, topMark: false, rows: [], add: true)]
                + blocks.dropFirst(3).map { Drawn(whole: $0) }
        ),
    ])
}

/// A block's header whose list's name is being typed stands alone outside the lazy stacks, and the rest of its block
/// and the blocks below it after it; with a card open too, each stands alone.
@Test func aHeaderWithAFieldAndACardEachStandAlone() throws {
    let list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    list.addList()
    list.openCard(on: list.b)
    let blocks = list.blocks
    let named = try #require(blocks.firstIndex { $0.header?.field != nil })
    let block = blocks[named]
    #expect(named > 1)
    #expect(blocks.first?.id == own)

    #expect(drawn(ListRuns(blocks, doneRows: [])) == [
        DrawnRun(field: nil, lazy: [Drawn(own, header: true, topMark: true, rows: [list.a], add: false)]),
        DrawnRun(
            field: Drawn(own, header: false, topMark: false, rows: [list.b], add: false),
            lazy: [Drawn(own, header: false, topMark: false, rows: [list.c, list.d], add: true)]
                + blocks[1..<named].map { Drawn(whole: $0) }
        ),
        DrawnRun(
            field: Drawn(block.id, header: true, topMark: false, rows: [], add: false),
            lazy: [Drawn(block.id, header: false, topMark: true, rows: block.rows.map(\.id), add: true)]
                + blocks.suffix(from: named + 1).map { Drawn(whole: $0) }
        ),
    ])
}

/// A run is known by the part that holds the field at its head, and the first, which has none, by being first: a field
/// keeps its view whatever opens or closes above or below it, and the first run, which holds the rows above the first
/// field, keeps its view whatever opens or closes below its start. A list's name being typed keeps its run's id as a
/// card opens above it and closes again; a card opened above a name's field keeps its run's id as the name then goes.
@Test func aFieldsRunKeepsItsIdWhateverOpensOrClosesAboveOrBelowIt() throws {
    let list = try LiftedList()
    let card = ListRuns.Run.ID.row(BlockRowID(block: .own(nil), task: list.b))
    func ids() -> [ListRuns.Run.ID] { ListRuns(list.blocks, doneRows: []).runs.map(\.id) }
    #expect(ids() == [.start])
    list.openCard(on: list.b)
    #expect(ids() == [.start, card], "a card below the first run's start")
    list.addList()
    let named = try #require(list.blocks.first { $0.header?.field != nil }?.id)
    let name = ListRuns.Run.ID.header(named)
    #expect(ids() == [.start, name], "the card closed by adding a list")
    list.openCard(on: list.b)
    #expect(ids() == [.start, card, name], "a card above the name")
    list.tapBackground()
    #expect(ids() == [.start, name], "the card above closed")
    list.openCard(on: list.b)
    list.submitListName()
    #expect(ids() == [.start, card], "the name below settled")
    list.tapBackground()
    #expect(ids() == [.start], "the card closed")
}

/// The Done strip's rows stand in a lazy stack, and outside it while one of them is the open card.
@Test func theDoneRowsLeaveTheirLazyStackWhileACardIsAmongThem() throws {
    let list = try LiftedList()
    list.check(list.a)
    list.toggleDoneStrip()
    #expect(list.doneRows.map(\.id) == [list.a])
    #expect(!ListRuns(list.blocks, doneRows: list.doneRows).doneRowsHoldField)
    list.openCard(on: list.a)
    #expect(list.doneRows.map(\.id) == [list.a])
    #expect(ListRuns(list.blocks, doneRows: list.doneRows).doneRowsHoldField)
}
