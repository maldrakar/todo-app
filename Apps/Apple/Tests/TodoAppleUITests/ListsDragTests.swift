import CoreGraphics
import FeatureModule
import Testing
import TaskViewListFeature
@testable import TodoAppleUI
import TodoCore

// The drag of the Lists screen, `ListsDrag`, driven stage by stage as the screen drives it, over the rows a real
// `TaskViewList` draws from a store in memory, with the tree's indent its model gives and the frames a layout of those
// rows would report, each as high as its model says, a list's row 46 pt, a named area's line 36 and the slot 52,
// stacked from the top. Each drop the drag reports is then sent to the module, which is the end-to-end case: the row
// lands where the slot was drawn, by the module's own reading of the drop
// (`TaskViewList.dropTarget(of:after:depth:in:)`).
//
// The tree every test starts from, its drawn depths in brackets: Inbox, Today, Upcoming, Logbook and Trash [0], then the
// root's list A [0]; the area W, with C [0] holding D [1], then E [0]; and the area H, with F [0].

/// A press over the top of the tree lets the row go at the start of the root: nothing before it, depth 0, which the
/// module reads as the first item of the root.
@Test func aListLetGoAboveTheFirstRowGoesToTheTopOfTheTree() throws {
    var tree = try DraggedTree()
    tree.press(.began(tree.centre(of: tree.a)))
    tree.press(.changed(CGPoint(x: tree.centre(of: tree.a).x + 200, y: -10)))
    #expect(tree.drag?.slot == 0)
    #expect(tree.drag?.depth == 0, "no row stands before the top, so nothing deeper than the root is offered")
    tree.press(.ended)

    #expect(tree.drops == [.rowDropped(tree.a, after: nil, depth: 0)])
    tree.sendDrops()
    #expect(tree.rowIDs.first == tree.a)
}

/// Right after an area's line the only depth is the line's own, 0, however far the finger goes, and the module puts the
/// row first among the area's lists.
@Test func aListLetGoRightAfterAnAreasLineStaysAtTheLinesDepth() throws {
    var tree = try DraggedTree()
    let start = tree.centre(of: tree.e)
    tree.press(.began(start))
    tree.press(.changed(tree.lowerHalf(of: tree.w, x: start.x + 300)))
    #expect(tree.drag?.depth == 0)
    tree.press(.ended)

    #expect(tree.drops == [.rowDropped(tree.e, after: tree.w, depth: 0)])
    tree.sendDrops()
    #expect(tree.rows(from: tree.w) == [tree.w, tree.e, tree.c, tree.d, tree.h, tree.f])
    #expect(tree.depth(of: tree.e) == 0)
}

/// Between two rows the depth runs from the row after the slot's to one past the row before it, and a finger beyond
/// either end is held to it: after D [1] and before E [0], from 0 to 2.
@Test func aListsDepthIsBoundedByTheRowsAroundTheSlot() throws {
    var tree = try DraggedTree()
    let start = tree.centre(of: tree.f)
    tree.press(.began(start))
    tree.press(.changed(tree.lowerHalf(of: tree.d, x: start.x - 300)))
    #expect(tree.drag?.depth == 0, "no shallower than E, the row after the slot")
    tree.press(.changed(tree.lowerHalf(of: tree.d, x: start.x + 300)))
    #expect(tree.drag?.depth == 2, "no deeper than one past D, the row before the slot")
    tree.press(.changed(tree.lowerHalf(of: tree.d, x: start.x + tree.indent)))
    #expect(tree.drag?.depth == 1, "a level for each indent the finger travels")
    tree.press(.changed(tree.lowerHalf(of: tree.d, x: start.x + 2 * tree.indent)))
    tree.press(.ended)

    #expect(tree.drops == [.rowDropped(tree.f, after: tree.d, depth: 2)])
    tree.sendDrops()
    #expect(tree.rows(from: tree.w) == [tree.w, tree.c, tree.d, tree.f, tree.e, tree.h])
    #expect(tree.depth(of: tree.f) == 2, "the first list inside D")
}

/// An area's slot stands only right before another line or at the end of the tree: over another area's lists, or over
/// the root's lists above the first line, it stays where it was. Let go before W, it goes to the root right after A, its
/// lists with it.
@Test func anAreasSlotStandsOnlyBeforeALineOrAtTheEnd() throws {
    var tree = try DraggedTree()
    let start = tree.centre(of: tree.h)
    tree.press(.began(start))
    let atTheEnd = tree.drag?.slot
    tree.press(.changed(tree.lowerHalf(of: tree.c)))
    #expect(tree.drag?.slot == atTheEnd, "among W's lists, the slot stays at the end")
    tree.press(.changed(tree.upperHalf(of: tree.a)))
    #expect(tree.drag?.slot == atTheEnd, "above the root's last list, the slot stays too")
    tree.press(.changed(tree.upperHalf(of: tree.w, x: start.x + 300)))
    #expect(tree.drag?.depth == 0)
    tree.press(.ended)

    #expect(tree.drops == [.rowDropped(tree.h, after: tree.a, depth: 0)])
    tree.sendDrops()
    #expect(tree.rows(from: tree.a) == [tree.a, tree.h, tree.f, tree.w, tree.c, tree.d, tree.e])
}

/// A folded list lifts alone, the lists it hides not being drawn, and the module moves them with it.
@Test func aFoldedListLiftsAloneAndTakesItsListsWithIt() throws {
    var tree = try DraggedTree()
    tree.fold(tree.c)
    #expect(!tree.rowIDs.contains(tree.d))
    let start = tree.centre(of: tree.c)
    tree.press(.began(start))
    tree.press(.changed(tree.lowerHalf(of: tree.e, x: start.x)))
    #expect(tree.drag?.depth == 0)
    tree.press(.ended)

    #expect(tree.drops == [.rowDropped(tree.c, after: tree.e, depth: 0)])
    tree.sendDrops()
    tree.fold(tree.c)
    #expect(tree.rows(from: tree.w) == [tree.w, tree.e, tree.c, tree.d, tree.h, tree.f])
}

/// The release reports the drop once and puts the row down, and a stage after it reports nothing; a cancel puts the row
/// down and reports nothing; and a press over no row lifts nothing, so its release reports nothing either.
@Test func theReleaseReportsOneDropAndACancelNone() throws {
    var released = try DraggedTree()
    released.press(.began(released.centre(of: released.a)))
    released.press(.changed(released.lowerHalf(of: released.e)))
    released.press(.ended)
    #expect(released.drag == nil)
    released.press(.ended)
    #expect(released.drops.count == 1)

    var cancelled = try DraggedTree()
    cancelled.press(.began(cancelled.centre(of: cancelled.a)))
    cancelled.press(.changed(cancelled.lowerHalf(of: cancelled.e)))
    cancelled.press(.cancelled)
    #expect(cancelled.drag == nil)
    #expect(cancelled.drops.isEmpty)

    var missed = try DraggedTree()
    missed.press(.began(CGPoint(x: 100, y: 10_000)))
    #expect(missed.drag == nil)
    missed.press(.changed(missed.centre(of: missed.a)))
    missed.press(.ended)
    #expect(missed.drops.isEmpty)
}

/// The tree of the tests, the module that draws it, and a drag over it, driven as the screen drives one: each stage of
/// the press is handed to `ListsDrag.after(_:from:among:frames:indent:)` with the items as drawn with no row lifted,
/// the frames of what the screen draws at that moment, the slot among them while a row is lifted, and the tree's
/// indent.
private struct DraggedTree {
    let a: ViewID, w: ViewID, c: ViewID, d: ViewID, e: ViewID, h: ViewID, f: ViewID
    private(set) var drag: ListsDrag?
    private(set) var drops: [TaskViewList.UserAction] = []
    private let module: TaskViewList

    init() throws {
        let store = try Store.openInMemory(device: "lists-drag-tests", now: Store.systemNow)
        a = try store.createView(NewTaskView(title: "A"))
        w = try store.createView(NewTaskView(title: "W", kind: .area))
        c = try store.createView(NewTaskView(title: "C", parent: w))
        d = try store.createView(NewTaskView(title: "D", parent: c))
        e = try store.createView(NewTaskView(title: "E", parent: w))
        h = try store.createView(NewTaskView(title: "H", kind: .area))
        f = try store.createView(NewTaskView(title: "F", parent: h))
        module = try TaskViewList(
            store: store, route: TaskViewList.Route(list: nil), width: .narrow, supportsMultipleWindows: false
        )
        _ = module.send(.action(.editMenuItemChosen))
    }

    /// The items the screen draws with no row lifted.
    var items: [ListsTreeItem] { ListsTreeItem.items(of: module.model.rows) }

    /// How far a finger carries a lifted row sideways to change its depth by one, the step of the tree's indent.
    var indent: CGFloat { module.model.drag.indent.step }

    /// The ids of the rows as drawn.
    var rowIDs: [ViewID] { module.model.rows.map(\.id) }

    /// The ids of the drawn rows from the given one to the end.
    func rows(from id: ViewID) -> [ViewID] { Array(rowIDs.drop { $0 != id }) }

    /// The drawn depth of a row.
    func depth(of id: ViewID) -> Int? { module.model.rows.first { $0.id == id }?.depth }

    /// The frames of what the screen draws now, stacked from the top, each item as high as its model says.
    var frames: [ListsTreeItem.ID: CGRect] {
        var y: CGFloat = 0
        var frames: [ListsTreeItem.ID: CGRect] = [:]
        for item in drag?.drawn(items) ?? items {
            let height: CGFloat = switch item {
            case .list(_, let list): list.height
            case .area(_, let line): line.height
            case .slot: module.model.drag.slot.height
            }
            frames[item.id] = CGRect(x: 0, y: y, width: 400, height: height)
            y += height
        }
        return frames
    }

    func centre(of id: ViewID) -> CGPoint { point(in: id, at: 0.5, x: nil) }
    func upperHalf(of id: ViewID, x: CGFloat? = nil) -> CGPoint { point(in: id, at: 0.25, x: x) }
    func lowerHalf(of id: ViewID, x: CGFloat? = nil) -> CGPoint { point(in: id, at: 0.75, x: x) }

    private func point(in id: ViewID, at fraction: CGFloat, x: CGFloat?) -> CGPoint {
        let frame = frames[.row(id)] ?? .zero
        return CGPoint(x: x ?? frame.midX, y: frame.minY + frame.height * fraction)
    }

    /// One stage of the press, as the screen hands it on.
    mutating func press(_ phase: ListsDrag.Phase) {
        let step = ListsDrag.after(phase, from: drag, among: items, frames: frames, indent: module.model.drag.indent)
        if let drop = step.drop { drops.append(drop) }
        drag = step.drag
    }

    /// Sends every drop the drag reported to the module.
    func sendDrops() {
        for drop in drops { _ = module.send(.action(drop)) }
        #expect(module.model.problem == nil)
    }

    /// Folds or unfolds a list.
    func fold(_ id: ViewID) {
        _ = module.send(.action(.disclosureTapped(id)))
    }
}
