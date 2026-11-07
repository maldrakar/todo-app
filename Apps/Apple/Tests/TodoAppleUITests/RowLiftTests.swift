import CoreGraphics
import DesignSystemComponents
import FeatureModule
import TaskListFeature
import Testing
@testable import TodoAppleUI
import TodoCore

// The system drag of the list screen, `RowLift`, driven stage by stage as the screen's drop delegate drives it, over
// the blocks a real `TaskList` draws from a store in memory and the frames a layout of them would report: in the list,
// each stacked from the top with the mark's gap where the slot stands, as the screen draws them; on the board, side by
// side, each column's cards scrolled as far as a test says. Each drop is then sent to the module, which is the
// end-to-end case: the task lands where the slot was drawn, by the module's own reading of the drop.
//
// The list every test starts from: "Projects" of open tasks, its own block with A, B, C and D, then the lists inside
// it, House (a tag) with H1 and H2, Office (a tag) with O1 and O2, Empty (a tag) with nothing, and Either (a rule of
// alternatives) with E1, which takes no drop.

/// The first stage of a drag holds what `onDrag` said it carries, with the row's look of a lift, and offers the task's
/// own place until the finger moves.
@Test func aLiftHoldsTheTaskAndBlockItWasDraggedFrom() throws {
    var list = try LiftedList()
    list.press(.began(task: list.h2, block: .list(list.house), at: list.centre(of: list.h2, in: .list(list.house))))
    #expect(list.lift?.task == list.h2)
    #expect(list.lift?.source == .list(list.house))
    #expect(list.lift?.style.indicator != nil)
    #expect(list.lift?.slot == RowLift.Slot(block: .list(list.house), after: list.h1))
}

/// A row with no lift, or one no longer drawn, gone by a peer's change between the press and the first point, lifts
/// nothing, so that nothing dims and nothing drops.
@Test func aRowThatCannotBeLiftedLiftsNothing() throws {
    var list = try LiftedList()
    list.press(.began(task: TaskID(), block: .own(nil), at: .zero))
    #expect(list.lift == nil)
    list.press(.ended)
    #expect(list.drops.isEmpty)
}

/// Over a row of its own block the slot goes before it in its upper half and after it in its lower, the lifted row
/// itself keeping its place, above the first row at the top and below the last at the end. The gap the mark opens moves
/// the rows under a still finger and does not move the slot.
@Test func aMoveOverARowPicksTheSlotBeforeOrAfterIt() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    list.press(.began(task: list.b, block: own, at: list.centre(of: list.b, in: own)))
    list.press(.changed(list.upperHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.c))
    list.press(.changed(list.upperHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.c), "the gap above D moved D down, not the slot")
    list.press(.changed(list.lowerHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.d))
    list.press(.changed(list.lowerHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.d), "the gap below D moved D up, not the slot")
    list.press(.changed(list.centre(of: list.b, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.a), "over itself, its own place")
    list.press(.changed(list.upperHalf(of: list.a, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: nil))
    list.press(.changed(CGPoint(x: 10, y: -500)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: nil), "above the blocks, the first block's top")
    list.press(.changed(list.lowerHalf(of: list.c, in: own)))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(list.b, from: own, in: own, after: list.c)])
    list.sendDrops()
    #expect(list.rowIDs(of: own) == [list.a, list.c, list.b, list.d])
}

/// In another block the module writes no place, a manual list taking the task last and any other standing it by its
/// sort, so wherever the finger is in that block the slot stands at its end.
@Test func aMoveIntoAnotherBlockPicksItsEnd() throws {
    var list = try LiftedList()
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let empty = TaskList.Model.BlockID.list(list.empty)
    list.press(.began(task: list.h1, block: house, at: list.centre(of: list.h1, in: house)))
    list.press(.changed(list.upperHalf(of: list.o1, in: office)))
    #expect(list.lift?.slot == RowLift.Slot(block: office, after: list.o2))
    list.press(.changed(list.top(of: office)))
    #expect(list.lift?.slot == RowLift.Slot(block: office, after: list.o2), "over its header")
    list.press(.changed(list.top(of: empty)))
    #expect(list.lift?.slot == RowLift.Slot(block: empty, after: nil), "a block with no rows has only its top")
    list.press(.changed(list.lowerHalf(of: list.o2, in: office)))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(list.h1, from: house, in: office, after: list.o2)])
    list.sendDrops()
    #expect(Set(list.rowIDs(of: office)) == [list.o1, list.o2, list.h1])
    #expect(list.rowIDs(of: house) == [list.h2])
}

/// Over a block whose rule reads as no edit there is no slot, and a release there drops nothing; moved on, the slot
/// comes back.
@Test func aBlockThatTakesNoDropOffersNoSlot() throws {
    var list = try LiftedList()
    let house = TaskList.Model.BlockID.list(list.house)
    let either = TaskList.Model.BlockID.list(list.either)
    #expect(list.block(either)?.takesDrop == false)
    list.press(.began(task: list.h1, block: house, at: list.centre(of: list.h1, in: house)))
    list.press(.changed(list.centre(of: list.e1, in: either)))
    #expect(list.lift?.slot == nil)
    #expect(list.lift != nil, "still lifted")
    list.press(.changed(list.centre(of: list.h2, in: house)))
    #expect(list.lift?.slot?.block == house)
    list.press(.changed(list.centre(of: list.e1, in: either)))
    list.press(.ended)
    #expect(list.lift == nil)
    #expect(list.drops.isEmpty)
}

/// The release is one drop, and what the delegate hands after it moves nothing.
@Test func aReleaseSendsOneDrop() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    list.press(.began(task: list.a, block: own, at: list.centre(of: list.a, in: own)))
    list.press(.changed(list.lowerHalf(of: list.b, in: own)))
    list.press(.ended)
    #expect(list.lift == nil)
    list.press(.ended)
    list.press(.changed(list.lowerHalf(of: list.c, in: own)))
    list.press(.cancelled)
    #expect(list.lift == nil)
    #expect(list.drops == [.rowDropped(list.a, from: own, in: own, after: list.b)])
}

/// A cancel, the drag leaving the screen's scroll view, drops nothing and clears the lift, which is all a drag cancelled
/// outside it ever says; come back, the drag lifts again and can still drop.
@Test func aCancelDropsNothing() throws {
    var list = try LiftedList()
    let own = TaskList.Model.BlockID.own(nil)
    list.press(.began(task: list.a, block: own, at: list.centre(of: list.a, in: own)))
    list.press(.changed(list.lowerHalf(of: list.b, in: own)))
    list.press(.cancelled)
    #expect(list.lift == nil)
    #expect(list.drops.isEmpty)
    list.press(.began(task: list.a, block: own, at: list.lowerHalf(of: list.c, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.c))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(list.a, from: own, in: own, after: list.c)])
}

/// On the board the point picks the column under it, the nearest in a gap or a margin, whatever its height, a column
/// that takes no drop offering none; in another column at its end, and in its own among the cards in sight: a card
/// scrolled out of its column keeps a frame, under the column's header, and is never the one under the finger.
@Test func aMoveOverAColumnPicksTheColumn() throws {
    var list = try LiftedList(columns: true)
    let own = TaskList.Model.BlockID.own(nil)
    let house = TaskList.Model.BlockID.list(list.house)
    let either = TaskList.Model.BlockID.list(list.either)
    list.press(.began(task: list.b, block: own, at: list.centre(of: list.b, in: own)))
    #expect(list.lift?.style.indicator == nil, "a column's tint marks the drop")
    list.press(.changed(list.centre(of: list.h1, in: house)))
    #expect(list.lift?.slot == RowLift.Slot(block: house, after: list.h2))
    list.press(.changed(CGPoint(x: list.columnFrame(of: house).maxX + 1, y: 5_000)))
    #expect(list.lift?.slot == RowLift.Slot(block: house, after: list.h2), "in the gap after it and below its end")
    list.press(.changed(list.centre(of: list.e1, in: either)))
    #expect(list.lift?.slot == nil)

    list.scrollColumn(own, by: 200)
    let hidden = list.centre(of: list.c, in: own)
    let area = list.visibleArea(of: own)
    #expect(hidden.y < area.minY, "C's frame lies under the header")
    list.press(.changed(hidden))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: nil), "over the header, the top")
    list.press(.changed(CGPoint(x: area.midX, y: area.maxY + 1)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.d), "under the cards in sight, the end")
    list.press(.changed(list.upperHalf(of: list.d, in: own)))
    #expect(list.lift?.slot == RowLift.Slot(block: own, after: list.c))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(list.b, from: own, in: own, after: list.c)])
    list.sendDrops()
    #expect(list.rowIDs(of: own) == [list.a, list.c, list.b, list.d])
}

/// A task two blocks draw has a row in each, and each has its own frame: lifted from one, it reorders by that one's
/// frames, and dropped in a third it leaves only the block it was dragged from.
@Test func aTaskTwoBlocksDrawLeavesOnlyTheOneItWasDraggedFrom() throws {
    var list = try LiftedList(taskInHouseAndOffice: true)
    let house = TaskList.Model.BlockID.list(list.house)
    let office = TaskList.Model.BlockID.list(list.office)
    let empty = TaskList.Model.BlockID.list(list.empty)
    let both = try #require(list.both)
    #expect(list.rowIDs(of: house).contains(both) && list.rowIDs(of: office).contains(both))
    #expect(list.frames.rows[BlockRowID(block: house, task: both)] != list.frames.rows[BlockRowID(block: office, task: both)])

    list.press(.began(task: both, block: office, at: list.centre(of: both, in: office)))
    #expect(list.lift?.slot == RowLift.Slot(block: office, after: list.o2), "its place in the block it was lifted from")
    list.press(.changed(list.upperHalf(of: list.o2, in: office)))
    #expect(list.lift?.slot == RowLift.Slot(block: office, after: list.o1))
    list.press(.cancelled)

    list.press(.began(task: both, block: house, at: list.centre(of: both, in: house)))
    list.press(.changed(list.top(of: office)))
    #expect(list.lift?.slot == RowLift.Slot(block: office, after: list.o2), "its own row there is no place to stand after")
    list.press(.changed(list.top(of: empty)))
    list.press(.ended)
    #expect(list.drops == [.rowDropped(both, from: house, in: empty, after: nil)])
    list.sendDrops()
    #expect(!list.rowIDs(of: house).contains(both))
    #expect(list.rowIDs(of: office).contains(both))
    #expect(list.rowIDs(of: empty) == [both])
}

/// The list of the tests, the module that draws it, the frames its layout would report and a drag over it, driven as
/// the screen drives one.
private struct LiftedList {
    let a: TaskID, b: TaskID, c: TaskID, d: TaskID
    let house: ViewID, office: ViewID, empty: ViewID, either: ViewID
    let h1: TaskID, h2: TaskID, o1: TaskID, o2: TaskID, e1: TaskID

    /// The task House and Office both draw, last in each, where a test asks for one.
    let both: TaskID?

    private(set) var lift: RowLift?
    private(set) var drops: [TaskList.UserAction] = []
    private var scrolled: [TaskList.Model.BlockID: CGFloat] = [:]
    private let module: TaskList

    /// How high a block's header, a row, a block's "+ Add task" and the mark's gap stand in the list; how wide a column
    /// is, how far from the next, how high its header and its cards' visible area, how high a card and its gap.
    private static let header: CGFloat = 44, row: CGFloat = 44, addRow: CGFloat = 40, gap: CGFloat = 10
    private static let columnWidth: CGFloat = 296, columnGap: CGFloat = 10, columnHeader: CGFloat = 44
    private static let columnArea: CGFloat = 300, card: CGFloat = 60, cardGap: CGFloat = 8

    init(columns: Bool = false, taskInHouseAndOffice: Bool = false) throws {
        let store = try Store.openInMemory(device: "row-lift-tests", now: Store.systemNow)
        let home = try store.createTag(title: "home")
        let work = try store.createTag(title: "work")
        let spare = try store.createTag(title: "spare")
        let x = try store.createTag(title: "x")
        let y = try store.createTag(title: "y")
        let parent = try store.createView(NewTaskView(title: "Projects", filter: .status([.open]), sort: [SortKey(.rank)]))
        house = try store.createView(NewTaskView(title: "House", parent: parent, filter: .hasTag(home)))
        office = try store.createView(NewTaskView(title: "Office", parent: parent, filter: .hasTag(work)))
        empty = try store.createView(NewTaskView(title: "Empty", parent: parent, filter: .hasTag(spare)))
        either = try store.createView(NewTaskView(title: "Either", parent: parent, filter: .or([.hasTag(x), .hasTag(y)])))
        a = try store.createTask(NewTask(title: "A"))
        b = try store.createTask(NewTask(title: "B"))
        c = try store.createTask(NewTask(title: "C"))
        d = try store.createTask(NewTask(title: "D"))
        h1 = try store.createTask(NewTask(title: "H1", tags: [home]))
        h2 = try store.createTask(NewTask(title: "H2", tags: [home]))
        o1 = try store.createTask(NewTask(title: "O1", tags: [work]))
        o2 = try store.createTask(NewTask(title: "O2", tags: [work]))
        e1 = try store.createTask(NewTask(title: "E1", tags: [x]))
        both = taskInHouseAndOffice ? try store.createTask(NewTask(title: "Both", tags: [home, work])) : nil
        module = try TaskList(store: store, route: TaskList.Route(head: .init(view: parent)), day: testDay)
        if columns {
            _ = module.send(.action(.showAsChosen(.columns)))
        }
    }

    /// The blocks the model draws, whichever its layout, read over the layout's shapes as the screen reads them.
    var blocks: [TaskList.Model.Block] {
        switch module.model.layout {
        case .list(let blocks): blocks
        case .columns(let board): board.columns
        }
    }

    func block(_ id: TaskList.Model.BlockID) -> TaskList.Model.Block? { blocks.first { $0.id == id } }

    func rowIDs(of id: TaskList.Model.BlockID) -> [TaskID] { block(id)?.rows.map(\.id) ?? [] }

    /// The frames of what the screen draws now.
    var frames: RowLift.Frames {
        switch module.model.layout {
        case .list: listFrames
        case .columns: boardFrames
        }
    }

    private var listFrames: RowLift.Frames {
        var frames = RowLift.Frames()
        var y: CGFloat = 0
        for block in blocks {
            let top = y
            if block.header != nil { y += Self.header }
            if lift?.slot == RowLift.Slot(block: block.id, after: nil) { y += Self.gap }
            for row in block.rows {
                frames.rows[BlockRowID(block: block.id, task: row.id)] = CGRect(x: 0, y: y, width: 400, height: Self.row)
                y += Self.row
                if lift?.slot == RowLift.Slot(block: block.id, after: row.id) { y += Self.gap }
            }
            if block.addTask != nil { y += Self.addRow }
            frames.blocks[block.id] = CGRect(x: 0, y: top, width: 400, height: y - top)
        }
        return frames
    }

    private var boardFrames: RowLift.Frames {
        var frames = RowLift.Frames()
        for (index, block) in blocks.enumerated() {
            let x = CGFloat(index) * (Self.columnWidth + Self.columnGap)
            let height = Self.columnHeader + Self.columnArea
            frames.blocks[block.id] = CGRect(x: x, y: 0, width: Self.columnWidth, height: height)
            frames.columns[block.id] = CGRect(x: x, y: Self.columnHeader, width: Self.columnWidth, height: Self.columnArea)
            var y = Self.columnHeader - (scrolled[block.id] ?? 0)
            for row in block.rows {
                frames.rows[BlockRowID(block: block.id, task: row.id)] = CGRect(x: x, y: y, width: Self.columnWidth, height: Self.card)
                y += Self.card + Self.cardGap
            }
        }
        return frames
    }

    /// A column's cards scrolled up by so much.
    mutating func scrollColumn(_ id: TaskList.Model.BlockID, by offset: CGFloat) { scrolled[id] = offset }

    func columnFrame(of id: TaskList.Model.BlockID) -> CGRect { frames.blocks[id] ?? .zero }

    func visibleArea(of id: TaskList.Model.BlockID) -> CGRect { frames.columns[id] ?? .zero }

    func centre(of task: TaskID, in id: TaskList.Model.BlockID) -> CGPoint { point(in: task, of: id, at: 0.5) }
    func upperHalf(of task: TaskID, in id: TaskList.Model.BlockID) -> CGPoint { point(in: task, of: id, at: 0.25) }
    func lowerHalf(of task: TaskID, in id: TaskList.Model.BlockID) -> CGPoint { point(in: task, of: id, at: 0.75) }

    /// A point at the very top of a block, over its header where it has one.
    func top(of id: TaskList.Model.BlockID) -> CGPoint {
        let frame = frames.blocks[id] ?? .zero
        return CGPoint(x: frame.midX, y: frame.minY + 1)
    }

    private func point(in task: TaskID, of id: TaskList.Model.BlockID, at fraction: CGFloat) -> CGPoint {
        let frame = frames.rows[BlockRowID(block: id, task: task)] ?? .zero
        return CGPoint(x: frame.midX, y: frame.minY + frame.height * fraction)
    }

    /// One stage of the drag, as the screen's delegate hands it on, over the frames of what is drawn now.
    mutating func press(_ phase: RowLift.Phase) {
        let step = RowLift.after(phase, from: lift, among: blocks, frames: frames)
        if let drop = step.drop { drops.append(drop) }
        lift = step.lift
    }

    /// Sends every drop the drag reported to the module.
    func sendDrops() {
        for drop in drops { _ = module.send(.action(drop)) }
        #expect(module.model.problem == nil)
    }
}
