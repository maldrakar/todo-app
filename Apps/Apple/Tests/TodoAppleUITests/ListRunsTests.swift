import TaskListFeature
import Testing
@testable import TodoAppleUI
import TodoCore

// The list screen's blocks cut at every part that holds a field, `ListRuns`: the parts between two such parts stand in
// a lazy stack, and each part that holds a field stands outside the lazy stacks, so that its field is never taken out
// of the window; the Done strip's rows leave their lazy stack while one of them holds a field (#196). The blocks are
// the ones a real `TaskList` draws (`LiftedList`).

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

/// What a run draws: the pieces in its lazy stack, and the part that holds a field after them, none for the last.
private struct DrawnRun: Equatable {
    let lazy: [Drawn]
    let field: Drawn?
}

private func drawn(_ runs: ListRuns) -> [DrawnRun] {
    runs.runs.map { run in DrawnRun(lazy: run.lazy.map(Drawn.init), field: run.field.map(Drawn.init)) }
}

/// With no field open the blocks stand whole in one lazy run.
@Test func withNoFieldTheBlocksStandInOneLazyRun() throws {
    let list = try LiftedList()
    let runs = ListRuns(list.blocks, doneRows: [])
    #expect(drawn(runs) == [DrawnRun(lazy: list.blocks.map { Drawn(whole: $0) }, field: nil)])
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
            lazy: [Drawn(whole: blocks[0]), Drawn(house, header: true, topMark: true, rows: [list.h1], add: false)],
            field: Drawn(house, header: false, topMark: false, rows: [list.h2], add: false)
        ),
        DrawnRun(
            lazy: [Drawn(house, header: false, topMark: false, rows: [both], add: true)]
                + blocks.dropFirst(2).map { Drawn(whole: $0) },
            field: nil
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
        DrawnRun(
            lazy: [Drawn(own, header: true, topMark: true, rows: [], add: false)],
            field: Drawn(own, header: false, topMark: false, rows: [list.a], add: false)
        ),
        DrawnRun(
            lazy: [Drawn(own, header: false, topMark: false, rows: [list.b, list.c, list.d], add: true)]
                + blocks.dropFirst().map { Drawn(whole: $0) },
            field: nil
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
            lazy: [
                Drawn(whole: blocks[0]), Drawn(house, header: true, topMark: true, rows: [list.h1, list.h2], add: false),
            ],
            field: Drawn(house, header: false, topMark: false, rows: [both], add: false)
        ),
        DrawnRun(
            lazy: [
                Drawn(house, header: false, topMark: false, rows: [], add: true),
                Drawn(office, header: true, topMark: true, rows: [list.o1, list.o2], add: false),
            ],
            field: Drawn(office, header: false, topMark: false, rows: [both], add: false)
        ),
        DrawnRun(
            lazy: [Drawn(office, header: false, topMark: false, rows: [], add: true)]
                + blocks.dropFirst(3).map { Drawn(whole: $0) },
            field: nil
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
        DrawnRun(
            lazy: [Drawn(own, header: true, topMark: true, rows: [list.a], add: false)],
            field: Drawn(own, header: false, topMark: false, rows: [list.b], add: false)
        ),
        DrawnRun(
            lazy: [Drawn(own, header: false, topMark: false, rows: [list.c, list.d], add: true)]
                + blocks[1..<named].map { Drawn(whole: $0) },
            field: Drawn(block.id, header: true, topMark: false, rows: [], add: false)
        ),
        DrawnRun(
            lazy: [Drawn(block.id, header: false, topMark: true, rows: block.rows.map(\.id), add: true)]
                + blocks.suffix(from: named + 1).map { Drawn(whole: $0) },
            field: nil
        ),
    ])
}

/// A run is known by the part that holds its field, the last by being last, so that a field keeps its view whatever
/// opens or closes above or below it: a list's name being typed, with a card opening above it and closing again, and a
/// card, with a name's field appearing below it and going.
@Test func aFieldsRunKeepsItsIdWhateverOpensOrClosesAboveOrBelowIt() throws {
    let list = try LiftedList()
    let card = ListRuns.Run.ID.row(BlockRowID(block: .own(nil), task: list.b))
    func ids() -> [ListRuns.Run.ID] { ListRuns(list.blocks, doneRows: []).runs.map(\.id) }
    #expect(ids() == [.end])
    list.openCard(on: list.b)
    #expect(ids() == [card, .end])
    list.addList()
    let named = try #require(list.blocks.first { $0.header?.field != nil }?.id)
    let name = ListRuns.Run.ID.header(named)
    #expect(ids() == [name, .end], "the card closed by adding a list")
    list.openCard(on: list.b)
    #expect(ids() == [card, name, .end], "a card above the name")
    list.tapBackground()
    #expect(ids() == [name, .end], "the card above closed")
    list.openCard(on: list.b)
    list.submitListName()
    #expect(ids() == [card, .end], "the name below settled")
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
