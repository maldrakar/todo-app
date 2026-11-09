// Apps/Apple/Sources/TodoAppleUI/ListScreen/RowLift.swift
import CoreGraphics
import Foundation
import TaskListFeature
import TodoCore

/// A row of a block by the block that draws it and its task, since a task two blocks both select has a row in each.
///
/// `BlockRowID` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
struct BlockRowID: Hashable {
    let block: TaskList.Model.BlockID
    let task: TaskID
}

/// A task lifted out of a block, by the system's drag on iOS (spike #174, y1), from its first point over the screen's
/// scroll view to its release there, or by the pointer's on the Mac (`RowPointerDrag`), from its first move to its
/// release: which task, the block it was dragged from, and where it would land. It is the view's own state, which
/// nothing else can know, and it sends nothing until the release, which reports `rowDropped` once; what the drop means
/// is the module's to read. Each stage of the drag moves it through one step, `after(_:from:among:frames:)`, which
/// knows no platform, so that the drag is tested on the host (`RowLiftTests`).
///
/// The point picks the block whose frame holds it, or the nearest where none does: a list's blocks stand under one
/// another and a board's side by side, so one rule reads both, a point above the first block being the first block's
/// and one in the gap between two columns the nearer column's. A block that takes no drop offers no slot. In its own
/// block the task takes the place the point names, the upper half of a row being before it and the lower half after it,
/// read by the rows' middles alone, so that the gap the mark opens, which moves the rows under a still finger, does not
/// move the slot; on a column only among the cards in sight, since a card scrolled out of it keeps a frame under its
/// header. A block that keeps no dropped place, a list inside whose tasks stand in more than one group, offers none,
/// since the task would keep to its own group wherever it was let go. In another block the module writes no place, a manual list taking the
/// task last and any other standing it by its order, so the slot is that block, which its tint marks, and no place in
/// it (the owner's review of #177, 2026-11-08).
struct RowLift: Equatable {
    /// A stage of the drag, as its drop delegate reports it (`RowDragSessions`) or the Mac's pointer does
    /// (`RowPointerPress`), with the point in the content's own coordinates where it has one: the drag is first seen,
    /// moves, is let go once, or leaves. `onDrag` says what is carried and the first point over the scroll view says
    /// where, since the drag has no other beginning that a press which opens the menu instead does not also have (spike
    /// #174); the pointer's press says both at its first move.
    enum Phase {
        case began(task: TaskID, block: TaskList.Model.BlockID, session: String, at: CGPoint)
        case changed(CGPoint)
        case ended
        case cancelled
    }

    /// Where the task would land: at a place in the block it was dragged from, after a row there or at its top where
    /// `after` is nil, or in another block, wherever that block's rule and order stand it.
    enum Slot: Equatable {
        case place(TaskList.Model.BlockID, after: TaskID?)
        case into(TaskList.Model.BlockID)

        var block: TaskList.Model.BlockID {
            switch self {
            case .place(let block, _), .into(let block): block
            }
        }
    }

    /// What the screen's rows, blocks and columns last reported, in the content's own coordinates, which a drag finds
    /// its place by: each row's frame, each block's or column's, and the part of each column its cards are seen
    /// through.
    struct Frames {
        var rows: [BlockRowID: CGRect] = [:]
        var blocks: [TaskList.Model.BlockID: CGRect] = [:]
        var columns: [TaskList.Model.BlockID: CGRect] = [:]
    }

    let task: TaskID

    /// The block it was dragged from, which names one of the two that draw a task both select.
    let source: TaskList.Model.BlockID

    /// The drag's session, which `RowDragSessions` tells apart from any other press, and on the Mac the pointer's
    /// press's own.
    let session: String

    /// Where it would land, and nil over a block that takes no drop and over its own where it keeps no dropped place.
    private(set) var slot: Slot?

    /// The drag after a stage, among the blocks drawn and the frames they last reported, and the drop that
    /// stage reports: the first point lifts the row `onDrag` named, where it is still drawn and lifts; a move moves the
    /// slot; the release reports the drop once, where there is a slot, and puts the task down; and a cancel puts it
    /// down and reports nothing. A stage with no task lifted moves nothing.
    static func after(
        _ phase: Phase, from lift: RowLift?, among blocks: [TaskList.Model.Block], frames: Frames
    ) -> (lift: RowLift?, drop: TaskList.UserAction?) {
        switch phase {
        case .began(let task, let block, let session, let point):
            (
                RowLift(lifting: task, from: block, session: session, among: blocks)?
                    .moved(to: point, among: blocks, frames: frames),
                nil
            )
        case .changed(let point):
            (lift?.moved(to: point, among: blocks, frames: frames), nil)
        case .ended:
            (nil, lift?.drop)
        case .cancelled:
            (nil, nil)
        }
    }

    private init?(
        lifting task: TaskID, from source: TaskList.Model.BlockID, session: String, among blocks: [TaskList.Model.Block]
    ) {
        self.task = task
        self.source = source
        self.session = session
        guard row(among: blocks)?.lift != nil else { return nil }
    }

    /// The task's row in the block it was dragged from, among the blocks drawn, and nil where it is drawn no longer.
    func row(among blocks: [TaskList.Model.Block]) -> TaskList.Model.Row? {
        blocks.first { $0.id == source }?.rows.first { $0.id == task }
    }

    private func moved(to point: CGPoint, among blocks: [TaskList.Model.Block], frames: Frames) -> RowLift {
        var moved = self
        moved.slot = Self.block(at: point, among: blocks, frames: frames).flatMap { block in
            guard block.takesDrop else { return nil }
            guard block.id == source else { return .into(block.id) }
            guard block.keepsDroppedPlace else { return nil }
            let rows = block.rows.map(\.id).filter { $0 != task }
            return .place(block.id, after: Self.place(at: point.y, among: rows, of: block, frames: frames))
        }
        return moved
    }

    /// The block whose frame holds the point, or the nearest, and nil with no block laid out.
    private static func block(
        at point: CGPoint, among blocks: [TaskList.Model.Block], frames: Frames
    ) -> TaskList.Model.Block? {
        let laidOut = blocks.compactMap { block in frames.blocks[block.id].map { (block, $0) } }
        return laidOut.min { distance(from: point, to: $0.1) < distance(from: point, to: $1.1) }?.0
    }

    private static func distance(from point: CGPoint, to frame: CGRect) -> CGFloat {
        let x = max(frame.minX - point.x, 0, point.x - frame.maxX)
        let y = max(frame.minY - point.y, 0, point.y - frame.maxY)
        return hypot(x, y)
    }

    /// The row a task let go at the height stands after, among the rest of its own block, above a column's cards in
    /// sight its top and below them its end. A list's block is no column, though a board it was shown as left its area
    /// in the frames.
    private static func place(
        at y: CGFloat, among rows: [TaskID], of block: TaskList.Model.Block, frames: Frames
    ) -> TaskID? {
        if block.column != nil, let area = frames.columns[block.id] {
            if y < area.minY { return nil }
            if y >= area.maxY { return rows.last }
        }
        return rows.prefix { row in
            frames.rows[BlockRowID(block: block.id, task: row)].map { $0.midY <= y } ?? false
        }.last
    }

    /// The drag's one report, on release, and nil where there is no slot.
    private var drop: TaskList.UserAction? {
        switch slot {
        case .place(let block, let after)?: .rowDropped(task, from: source, in: block, after: after)
        case .into(let block)?: .rowDropped(task, from: source, in: block, after: nil)
        case nil: nil
        }
    }
}

/// The drags `onDrag` has begun on a screen, each by the token its item provider carries, which reaches the drop's
/// delegate through `DropInfo` (`NSItemProvider.suggestedName`; the iOS 26.3 simulator, 2026-11-07), so that a lift is
/// tied to its drag: a second finger pressing another row begins another session and takes nothing from the first, and
/// another window's drag of the private type names a session this screen did not begin. What each call of the delegate
/// means is one step, `phase(for:session:lift:)`, which knows no platform (`RowLiftTests`). A press that opens the menu
/// asks `onDrag` too, so a session is no drag until the delegate hears it; they are all forgotten at a drop. A session
/// outlives a lift that ended with no release: the drag may come back, or go quiet and be let go.
///
/// `RowDragSessions` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
struct RowDragSessions {
    /// A call of the drop's delegate: the drag at a point in the content's own coordinates, let go, or gone.
    enum Call {
        case moved(CGPoint)
        case released
        case left
    }

    private var rows: [String: BlockRowID] = [:]

    /// Begins a session for what `onDrag` carries, and answers its token.
    mutating func begin(_ row: BlockRowID) -> String {
        let session = UUID().uuidString
        rows[session] = row
        return session
    }

    mutating func forget() {
        rows = [:]
    }

    /// The stage a call of the delegate is, in the session it names, nil for one that moves nothing: a session this
    /// screen did not begin, or any other than the one a lift stands for.
    func phase(for call: Call, session: String?, lift: RowLift?) -> RowLift.Phase? {
        guard let session, let row = rows[session] else { return nil }
        let isItsLift = lift?.session == session
        switch call {
        case .moved(let point):
            if lift == nil { return .began(task: row.task, block: row.block, session: session, at: point) }
            return isItsLift ? .changed(point) : nil
        case .released:
            return isItsLift ? .ended : nil
        case .left:
            return isItsLift ? .cancelled : nil
        }
    }
}
