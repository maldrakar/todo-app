import TaskListFeature
import Testing
@testable import TodoAppleUI
import TodoCore

// The list screen's blocks cut into runs, `ListRuns`: each part that holds a field stands outside the lazy stacks, so
// that its field is never taken out of the window, at the head of the run whose lazy stack holds the parts after it,
// the first run holding those before the first cut; a run's start, once made, is kept while its part is drawn, the
// part heading its run's lazy stack once its field has closed, so that no row changes runs as a field closes, and a
// start whose part is gone moves to the part that followed it, so that none changes runs then either; the Done strip's
// rows leave their lazy stack while one of them holds a field (#196). The blocks are the ones a real `TaskList`
// draws (`LiftedList`).

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

/// The runs as the screen draws them, pass after pass: each pass is handed the cuts the pass before it drew, as the
/// screen keeps them (`ListCuts`).
private struct Passes {
    private var kept: [ListRuns.Start] = []

    mutating func draw(_ list: LiftedList) -> ListRuns {
        let runs = ListRuns(list.blocks, doneRows: list.doneRows, cuts: kept)
        kept = runs.cuts
        return runs
    }
}

/// The run each row stands in, the part at a run's head and the rows of its lazy stack alike.
private func runOfEachRow(_ runs: ListRuns) -> [BlockRowID: ListRuns.Run.ID] {
    var found: [BlockRowID: ListRuns.Run.ID] = [:]
    for run in runs.runs {
        for piece in [run.field].compactMap(\.self) + run.lazy {
            for row in piece.block.rows[piece.parts.rows] {
                found[BlockRowID(block: piece.block.id, task: row.id)] = run.id
            }
        }
    }
    return found
}

/// With no field open the blocks stand whole in the first run's lazy stack.
@Test func withNoFieldTheBlocksStandInOneLazyRun() throws {
    let list = try LiftedList()
    let runs = ListRuns(list.blocks, doneRows: [], cuts: [])
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

    #expect(drawn(ListRuns(blocks, doneRows: [], cuts: [])) == [
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

    #expect(drawn(ListRuns(blocks, doneRows: [], cuts: [])) == [
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

    #expect(drawn(ListRuns(blocks, doneRows: [], cuts: [])) == [
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

    #expect(drawn(ListRuns(blocks, doneRows: [], cuts: [])) == [
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

/// A run's start, once made, is kept: as its field closes the part heads its run's lazy stack, a plain row now, the
/// run keeps its id, and every row stands in the run it stood in, so that none is made anew out of sight.
@Test func aFieldsRunKeepsItsIdAndItsRowsAsTheFieldCloses() throws {
    let list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    let card = ListRuns.Run.ID.row(BlockRowID(block: own, task: list.b))
    var passes = Passes()
    list.openCard(on: list.b)
    let open = passes.draw(list)
    #expect(open.runs.map(\.id) == [.start, card])
    list.tapBackground()
    let closed = passes.draw(list)
    let blocks = list.blocks

    #expect(closed.runs.map(\.id) == [.start, card])
    #expect(runOfEachRow(closed) == runOfEachRow(open))
    #expect(drawn(closed) == [
        DrawnRun(field: nil, lazy: [Drawn(own, header: true, topMark: true, rows: [list.a], add: false)]),
        DrawnRun(
            field: nil,
            lazy: [Drawn(own, header: false, topMark: false, rows: [list.b, list.c, list.d], add: true)]
                + blocks.dropFirst().map { Drawn(whole: $0) }
        ),
    ])
    #expect(closed.cuts.map(\.id) == [card])
}

/// A field opened below a cut, or above it, keeps the cut: the rows between them stay in the run they stood in, and
/// only the rows from the new field down start a run.
@Test func aFieldOpenedBelowOrAboveACutKeepsIt() throws {
    let list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    let house = TaskList.Model.BlockID.list(list.house)
    let first = ListRuns.Run.ID.row(BlockRowID(block: own, task: list.b))
    let below = ListRuns.Run.ID.row(BlockRowID(block: house, task: list.h1))
    let above = ListRuns.Run.ID.row(BlockRowID(block: own, task: list.a))
    var passes = Passes()
    list.openCard(on: list.b)
    _ = passes.draw(list)
    list.openCard(on: list.h1)
    let second = passes.draw(list)
    #expect(second.runs.map(\.id) == [.start, first, below])
    let rows = runOfEachRow(second)
    #expect(rows[BlockRowID(block: own, task: list.a)] == .start)
    #expect([list.b, list.c, list.d].map { rows[BlockRowID(block: own, task: $0)] } == [first, first, first])
    #expect([list.h1, list.h2].map { rows[BlockRowID(block: house, task: $0)] } == [below, below])
    #expect(second.runs.map { $0.field != nil } == [false, false, true], "only the open card stands outside")

    list.openCard(on: list.a)
    let third = passes.draw(list)
    #expect(third.runs.map(\.id) == [.start, above, first, below])
    #expect(runOfEachRow(third).filter { $0.key.task != list.a } == rows.filter { $0.key.task != list.a })
}

/// A start whose part the list no longer draws moves to the part that followed it, keeping its run's id, and no row
/// changes runs: the floating "+" makes an empty task, the first row of the first block, which has no header, and a tap
/// on the background deletes it; the first run stays as it was, holding nothing above, where the rows of a start
/// dropped joined it, at the far end of a stack that had measured none of them. The start moves again as that part
/// goes, a row checked away, and a field opened on the part it stands at keeps its id.
@Test func aStartWhosePartGoesMovesToThePartThatFollowedIt() throws {
    let list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    var passes = Passes()
    list.addTaskFromButton()
    let new = try #require(list.rowIDs(of: own).first)
    #expect(list.rowIDs(of: own) == [new, list.a, list.b, list.c, list.d])
    let start = ListRuns.Run.ID.row(BlockRowID(block: own, task: new))
    let open = passes.draw(list)
    #expect(open.runs.map(\.id) == [.start, start])

    list.tapBackground()
    #expect(list.rowIDs(of: own) == [list.a, list.b, list.c, list.d], "the empty task deleted")
    let closed = passes.draw(list)
    let blocks = list.blocks
    #expect(closed.runs.map(\.id) == [.start, start])
    #expect(runOfEachRow(closed) == runOfEachRow(open).filter { $0.key.task != new })
    #expect(drawn(closed) == [
        DrawnRun(field: nil, lazy: [Drawn(own, header: true, topMark: true, rows: [], add: false)]),
        DrawnRun(
            field: nil,
            lazy: [Drawn(own, header: false, topMark: false, rows: [list.a, list.b, list.c, list.d], add: true)]
                + blocks.dropFirst().map { Drawn(whole: $0) }
        ),
    ])

    list.check(list.a)
    let checked = passes.draw(list)
    #expect(checked.runs.map(\.id) == [.start, start], "moved again, to B")
    #expect(runOfEachRow(checked) == runOfEachRow(closed).filter { $0.key.task != list.a })

    list.openCard(on: list.b)
    let field = passes.draw(list)
    #expect(field.runs.map(\.id) == [.start, start], "B's card at the head of the run that stands at B")
    let card = Drawn(own, header: false, topMark: false, rows: [list.b], add: false)
    #expect(field.runs.last?.field.map(Drawn.init) == card)
    #expect(runOfEachRow(field) == runOfEachRow(checked))
}

/// A start whose part goes while the part that followed it starts a run itself is dropped, and nothing moves: its run
/// held that part alone.
@Test func aStartWhosePartGoesBeforeAnotherStartIsDropped() throws {
    let list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    let first = ListRuns.Run.ID.row(BlockRowID(block: own, task: list.b))
    let second = ListRuns.Run.ID.row(BlockRowID(block: own, task: list.c))
    var passes = Passes()
    list.openCard(on: list.b)
    _ = passes.draw(list)
    list.openCard(on: list.c)
    _ = passes.draw(list)
    list.tapBackground()
    let both = passes.draw(list)
    #expect(both.runs.map(\.id) == [.start, first, second])

    list.check(list.b)
    #expect(list.rowIDs(of: own) == [list.a, list.c, list.d])
    let dropped = passes.draw(list)
    #expect(dropped.runs.map(\.id) == [.start, second])
    #expect(runOfEachRow(dropped) == runOfEachRow(both).filter { $0.key.task != list.b })
}

/// A start whose part and the part that followed it both go is dropped, and its rows join the run before it: a block
/// folded, whose rows come back into the run its header stands in.
@Test func aStartWhosePartAndTheNextBothGoIsDropped() throws {
    let list = try LiftedList()
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let start = ListRuns.Run.ID.row(BlockRowID(block: house, task: list.h1))
    var passes = Passes()
    list.openCard(on: list.h1)
    _ = passes.draw(list)
    list.tapBackground()
    let kept = passes.draw(list)
    #expect(kept.runs.map(\.id) == [.start, start])
    #expect(runOfEachRow(kept)[BlockRowID(block: office, task: list.o1)] == start)

    list.toggleFold(of: house)
    let folded = passes.draw(list)
    #expect(folded.runs.map(\.id) == [.start])
    #expect(runOfEachRow(folded)[BlockRowID(block: office, task: list.o1)] == .start)
    list.toggleFold(of: house)
    let unfolded = passes.draw(list)
    #expect(list.rowIDs(of: house) == [list.h1, list.h2])
    #expect(unfolded.runs.map(\.id) == [.start], "a start once dropped is not made again")
    #expect(drawn(unfolded) == [DrawnRun(field: nil, lazy: list.blocks.map { Drawn(whole: $0) })])
}

/// The first run is known by being first, whatever opens and closes below its start, and a field's run by its part,
/// whatever opens and closes above or below it: a list's name being typed keeps its run's id as a card opens above it
/// and closes, and the card's run keeps its own as the name settles, the header then heading its run's lazy stack.
@Test func theFirstRunAndAFieldsRunKeepTheirIdsWhateverOpensOrCloses() throws {
    let list = try LiftedList()
    let card = ListRuns.Run.ID.row(BlockRowID(block: .own(nil), task: list.b))
    var passes = Passes()
    func ids() -> [ListRuns.Run.ID] { passes.draw(list).runs.map(\.id) }
    #expect(ids() == [.start])
    list.openCard(on: list.b)
    #expect(ids() == [.start, card], "a card below the first run's start")
    list.addList()
    let named = try #require(list.blocks.first { $0.header?.field != nil }?.id)
    let name = ListRuns.Run.ID.header(named)
    #expect(ids() == [.start, card, name], "the card closed by adding a list, its cut kept")
    list.openCard(on: list.b)
    #expect(ids() == [.start, card, name], "the card open again above the name")
    list.tapBackground()
    #expect(ids() == [.start, card, name], "the card above closed")
    list.submitListName()
    let settled = passes.draw(list)
    #expect(settled.runs.map(\.id) == [.start, card, name], "the name settled")
    #expect(settled.runs.map { $0.field == nil } == [true, true, true], "no field is left")
    #expect(settled.runs.last?.lazy.first.map(Drawn.init) == list.block(named).map { Drawn(whole: $0) })
}

/// A list's name being typed and a card open in that same list, "+ Add task" tapped under the name: its block falls
/// into three runs, its header alone at the head of one, the mark at its rows' top in that run's lazy stack, and the
/// card at the head of the next, with the block's "+ Add task" after it.
@Test func aHeadersFieldAndACardInItsOwnBlockEachStandAlone() throws {
    let list = try LiftedList()
    list.addList()
    let named = try #require(list.blocks.firstIndex { $0.header?.field != nil })
    let id = list.blocks[named].id
    list.addTask(in: id)
    let blocks = list.blocks
    let block = blocks[named]
    #expect(block.header?.field != nil, "the name is still being typed")
    let new = try #require(block.rows.first?.id)
    #expect(block.rows.count == 1)

    let runs = ListRuns(blocks, doneRows: [], cuts: [])
    #expect(runs.runs.map(\.id) == [.start, .header(id), .row(BlockRowID(block: id, task: new))])
    #expect(drawn(runs) == [
        DrawnRun(field: nil, lazy: blocks[..<named].map { Drawn(whole: $0) }),
        DrawnRun(
            field: Drawn(id, header: true, topMark: false, rows: [], add: false),
            lazy: [Drawn(id, header: false, topMark: true, rows: [], add: false)]
        ),
        DrawnRun(
            field: Drawn(id, header: false, topMark: false, rows: [new], add: false),
            lazy: [Drawn(id, header: false, topMark: false, rows: [], add: true)]
                + blocks.suffix(from: named + 1).map { Drawn(whole: $0) }
        ),
    ])
}

/// The Done strip's rows stand in a lazy stack, and outside it while one of them is the open card.
@Test func theDoneRowsLeaveTheirLazyStackWhileACardIsAmongThem() throws {
    let list = try LiftedList()
    list.check(list.a)
    list.toggleDoneStrip()
    #expect(list.doneRows.map(\.id) == [list.a])
    #expect(!ListRuns(list.blocks, doneRows: list.doneRows, cuts: []).doneRowsHoldField)
    list.openCard(on: list.a)
    #expect(list.doneRows.map(\.id) == [list.a])
    #expect(ListRuns(list.blocks, doneRows: list.doneRows, cuts: []).doneRowsHoldField)
}
