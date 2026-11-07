import CoreGraphics
import FeatureModule
import TaskListFeature
@testable import TodoAppleUI
import TodoCore

/// The list of the tests, the module that draws it, the frames its layout would report and a drag over it, driven as
/// the screen drives one.
struct LiftedList {
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
        let parent = try store.createView(
            NewTaskView(title: "Projects", filter: .status([.open]), sort: [SortKey(.rank)])
        )
        house = try store.createView(NewTaskView(title: "House", parent: parent, filter: .hasTag(home)))
        office = try store.createView(NewTaskView(title: "Office", parent: parent, filter: .hasTag(work)))
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
                let id = BlockRowID(block: block.id, task: row.id)
                frames.rows[id] = CGRect(x: 0, y: y, width: 400, height: Self.row)
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
            frames.columns[block.id] = CGRect(
                x: x, y: Self.columnHeader, width: Self.columnWidth, height: Self.columnArea
            )
            var y = Self.columnHeader - (scrolled[block.id] ?? 0)
            for row in block.rows {
                let id = BlockRowID(block: block.id, task: row.id)
                frames.rows[id] = CGRect(x: x, y: y, width: Self.columnWidth, height: Self.card)
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

    /// Folds or unfolds a block.
    func toggleFold(of id: TaskList.Model.BlockID) {
        _ = module.send(.action(.blockChevronTapped(id)))
    }

    /// Opens a task's card in place of its row.
    func openCard(on task: TaskID) {
        _ = module.send(.action(.rowTapped(task)))
    }

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

    /// What the module has to say after what it was sent, nil where nothing went wrong.
    var problem: String? { module.model.problem }

    /// Sends every drop the drag reported to the module.
    func sendDrops() {
        for drop in drops { _ = module.send(.action(drop)) }
    }
}
