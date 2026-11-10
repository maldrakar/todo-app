import CoreGraphics
import FeatureModule
import TaskListFeature
@testable import TodoAppleUI
import TodoCore

/// The list of the tests, the module that draws it, the frames its layout would report and a drag over it, driven as
/// the screen drives one: the system's drag on iOS, by the calls of its delegate, or the pointer's on the Mac.
struct LiftedList {
    let a: TaskID, b: TaskID, c: TaskID, d: TaskID
    let house: ViewID, office: ViewID, empty: ViewID, either: ViewID
    let h1: TaskID, h2: TaskID, o1: TaskID, o2: TaskID, e1: TaskID

    /// The task House and Office both draw, last in each, where a test asks for one.
    let both: TaskID?

    private(set) var lift: RowLift?
    private(set) var drops: [TaskList.UserAction] = []

    /// The pointer's press under way, as the Mac's drag keeps it from its first move to its end.
    private(set) var pointerPress: RowPointerPress?

    /// The part of the content in sight, in its own coordinates, which the Mac's drag lets go of nothing outside: the
    /// whole of what the layout draws until a test scrolls it.
    private(set) var viewport: CGRect

    private var scrolled: [TaskList.Model.BlockID: CGFloat] = [:]
    private var areasLeft: [TaskList.Model.BlockID: CGRect] = [:]
    private var rowsNotLaidOut: Set<BlockRowID> = []
    private var rowsLeft: [BlockRowID: CGRect] = [:]
    private let module: TaskList
    private let layout: Layout

    /// Where the list's blocks stand across and how high a block's header, a row, a block's "+ Add task" and the mark's
    /// gap stand in it; how wide a column is, how far from the next, how high its header and its cards' visible area,
    /// how far in its cards stand, how high a card and its gap.
    private struct Layout {
        let blockX: CGFloat, blockWidth: CGFloat, header: CGFloat, row: CGFloat, addRow: CGFloat, gap: CGFloat
        let columnWidth: CGFloat, columnGap: CGFloat, columnHeader: CGFloat, columnArea: CGFloat
        let cardInset: CGFloat, card: CGFloat, cardGap: CGFloat

        /// The numbers the tests of the phone's drag were written at.
        static let phone = Layout(
            blockX: 0, blockWidth: 400, header: 44, row: 44, addRow: 40, gap: 10, columnWidth: 296, columnGap: 10,
            columnHeader: 44, columnArea: 300, cardInset: 0, card: 60, cardGap: 8
        )

        /// The pane's, its table's (`TaskList.Metrics.pane` and `.paneColumns`) in a pane as wide as its content at
        /// most: the blocks 48 in and 684 wide, 780 less the sides; a block's header 34 high, 14 under what stands
        /// above and 2 above its rows; a row 36 high, "+ Add task" 32 and the mark 10. A column 288 wide and 12 from
        /// the next, its header 36 high, its cards 6 in, each 36 high and 6 apart.
        static let pane = Layout(
            blockX: 48, blockWidth: 684, header: 50, row: 36, addRow: 32, gap: 10, columnWidth: 288, columnGap: 12,
            columnHeader: 36, columnArea: 400, cardInset: 6, card: 36, cardGap: 6
        )
    }

    /// The list, on the board where `columns` says so, in a wide window's pane at the pane's numbers where `pane` does
    /// and in a phone's otherwise, with a task House and Office both draw where `taskInHouseAndOffice` does, and Office
    /// grouping its tasks by day, O1 on the test's day and O2 on the next, where `officeByDay` does.
    init(
        columns: Bool = false, pane: Bool = false, taskInHouseAndOffice: Bool = false, officeByDay: Bool = false
    ) throws {
        let store = try Store.openInMemory(device: "row-lift-tests", now: Store.systemNow)
        let home = try store.createTag(title: "home")
        let work = try store.createTag(title: "work")
        let spare = try store.createTag(title: "spare")
        let x = try store.createTag(title: "x")
        let y = try store.createTag(title: "y")
        let parent = try store.createView(
            NewTaskView(title: "Projects", filter: .status([.open]), sort: [SortKey(.rank)])
        )
        house = try store.createView(NewTaskView(title: "House", parent: parent, filter: .hasTag(home)))
        office = try store.createView(
            NewTaskView(title: "Office", parent: parent, filter: .hasTag(work), groupBy: officeByDay ? .whenDay : nil)
        )
        empty = try store.createView(NewTaskView(title: "Empty", parent: parent, filter: .hasTag(spare)))
        either = try store.createView(
            NewTaskView(title: "Either", parent: parent, filter: .or([.hasTag(x), .hasTag(y)]))
        )
        a = try store.createTask(NewTask(title: "A"))
        b = try store.createTask(NewTask(title: "B"))
        c = try store.createTask(NewTask(title: "C"))
        d = try store.createTask(NewTask(title: "D"))
        h1 = try store.createTask(NewTask(title: "H1", tags: [home]))
        h2 = try store.createTask(NewTask(title: "H2", tags: [home]))
        o1 = try store.createTask(NewTask(title: "O1", when: officeByDay ? testDay.day : nil, tags: [work]))
        o2 = try store.createTask(NewTask(title: "O2", when: officeByDay ? testDay.day.advanced(by: 1) : nil, tags: [work]))
        e1 = try store.createTask(NewTask(title: "E1", tags: [x]))
        both = taskInHouseAndOffice ? try store.createTask(NewTask(title: "Both", tags: [home, work])) : nil
        module = try TaskList(
            store: store, route: TaskList.Route(head: .init(view: parent)), day: testDay, width: pane ? .wide : .narrow
        )
        layout = pane ? .pane : .phone
        // Five blocks, the list's own and the four lists inside, under one another or side by side.
        let board = CGSize(
            width: 5 * (layout.columnWidth + layout.columnGap), height: layout.columnHeader + layout.columnArea
        )
        let list = CGSize(width: 2 * layout.blockX + layout.blockWidth, height: 1_000)
        viewport = CGRect(origin: .zero, size: columns ? board : list)
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
        frames.columns = areasLeft
        var y: CGFloat = 0
        for block in blocks {
            let top = y
            if block.header != nil { y += layout.header }
            if lift?.slot == .place(block.id, after: nil) { y += layout.gap }
            for row in block.rows {
                let id = BlockRowID(block: block.id, task: row.id)
                if !rowsNotLaidOut.contains(id) {
                    frames.rows[id] = rowsLeft[id]
                        ?? CGRect(x: layout.blockX, y: y, width: layout.blockWidth, height: layout.row)
                }
                y += layout.row
                if lift?.slot == .place(block.id, after: row.id) { y += layout.gap }
            }
            if block.addTask != nil { y += layout.addRow }
            frames.blocks[block.id] = CGRect(x: layout.blockX, y: top, width: layout.blockWidth, height: y - top)
        }
        return frames
    }

    private var boardFrames: RowLift.Frames {
        var frames = RowLift.Frames()
        for (index, block) in blocks.enumerated() {
            let x = CGFloat(index) * (layout.columnWidth + layout.columnGap)
            let height = layout.columnHeader + layout.columnArea
            frames.blocks[block.id] = CGRect(x: x, y: 0, width: layout.columnWidth, height: height)
            frames.columns[block.id] = CGRect(
                x: x, y: layout.columnHeader, width: layout.columnWidth, height: layout.columnArea
            )
            var y = layout.columnHeader - (scrolled[block.id] ?? 0)
            for row in block.rows {
                let id = BlockRowID(block: block.id, task: row.id)
                frames.rows[id] = CGRect(
                    x: x + layout.cardInset, y: y, width: layout.columnWidth - 2 * layout.cardInset, height: layout.card
                )
                y += layout.card + layout.cardGap
            }
        }
        return frames
    }

    /// The area a column's cards were seen through on a board this list was shown as, which stays in the frames as a
    /// frame of anything that has left does.
    mutating func leaveColumnArea(of id: TaskList.Model.BlockID, _ area: CGRect) { areasLeft[id] = area }

    /// A row of the list a lazy stack has not laid out, which has reported no frame.
    mutating func leaveNotLaidOut(_ task: TaskID, in id: TaskList.Model.BlockID) {
        rowsNotLaidOut.insert(BlockRowID(block: id, task: task))
    }

    /// A row of the list out of sight, whose frame stays where it was last laid out, as a frame of anything that has
    /// left does.
    mutating func leaveFrame(of task: TaskID, in id: TaskList.Model.BlockID, at frame: CGRect) {
        rowsLeft[BlockRowID(block: id, task: task)] = frame
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

    /// Folds or unfolds a block.
    func toggleFold(of id: TaskList.Model.BlockID) {
        _ = module.send(.action(.blockChevronTapped(id)))
    }

    /// Opens a task's card in place of its row.
    func openCard(on task: TaskID) {
        _ = module.send(.action(.rowTapped(task)))
    }

    /// Adds a list inside, whose name's field stands in its block's header.
    func addList() {
        _ = module.send(.action(.addListTapped))
    }

    /// Closes the open card by a tap on what stands behind the controls.
    func tapBackground() {
        _ = module.send(.action(.backgroundTapped))
    }

    /// Settles the name typed into a new list's field, as Return does.
    func submitListName() {
        _ = module.send(.action(.listNameFieldSubmitted))
    }

    /// Checks a task, which writes it done.
    func check(_ task: TaskID) {
        _ = module.send(.action(.checkTapped(task)))
    }

    /// Opens or closes the Done strip.
    func toggleDoneStrip() {
        _ = module.send(.action(.doneStripTapped))
    }

    /// The rows under the Done strip, none while it is closed.
    var doneRows: [TaskList.Model.Row] { module.model.doneRows }

    /// A call of the drop's delegate, in a session, handed on as the screen's delegate hands it, where it means a
    /// stage.
    mutating func hear(_ call: RowDragSessions.Call, session: String?, in sessions: RowDragSessions) {
        if let phase = sessions.phase(for: call, session: session, lift: lift) { press(phase) }
    }

    /// One stage of the drag, as the screen's delegate hands it on, over the frames of what is drawn now.
    mutating func press(_ phase: RowLift.Phase) {
        let step = RowLift.after(phase, from: lift, among: blocks, frames: frames)
        if let drop = step.drop { drops.append(drop) }
        lift = step.lift
    }

    /// An event of the pointer's drag, handed on as the Mac's drag hands it on (`RowPointerDrag`): the press it leaves
    /// and the stage it makes, over the frames of what is drawn now and the part of it in sight.
    mutating func pointer(_ event: RowPointerPress.Event) {
        let step = RowPointerPress.after(
            event, from: pointerPress, lift: lift, among: blocks, frames: frames, viewport: viewport
        )
        pointerPress = step.press
        if let phase = step.phase { press(phase) }
    }

    /// The pointer's press lost with the gesture's state, which SwiftUI may drop, its lift left drawn.
    mutating func losePointerPress() { pointerPress = nil }

    /// The content scrolled so that what is in sight begins at the height.
    mutating func scroll(to y: CGFloat) { viewport.origin.y = y }

    /// What the module has to say after what it was sent, nil where nothing went wrong.
    var problem: String? { module.model.problem }

    /// Sends every drop the drag reported to the module.
    func sendDrops() {
        for drop in drops { _ = module.send(.action(drop)) }
    }
}
