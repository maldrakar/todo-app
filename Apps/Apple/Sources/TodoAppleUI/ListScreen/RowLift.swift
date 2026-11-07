// Apps/Apple/Sources/TodoAppleUI/ListScreen/RowLift.swift
import CoreGraphics
import DesignSystemComponents
import SwiftUI
import TaskListFeature
import TodoCore

/// A row of a block by the block that draws it and its task, since a task two blocks both select has a row in each.
///
/// `BlockRowID` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and Observation
/// for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
struct BlockRowID: Hashable {
    let block: TaskList.Model.BlockID
    let task: TaskID
}

/// A task lifted out of a block by the system's drag (spike #174, y1), from its first point over the screen's scroll
/// view to its release there: which task, the block it was dragged from, how its row looks lifted, and where it would
/// land. It is the view's own state, which nothing else can know, and it sends nothing until the release, which reports
/// `rowDropped` once; what the drop means is the module's to read. Each stage of the drag moves it through one step,
/// `after(_:from:among:frames:)`, which knows no platform, so that the drag is tested on the host (`RowLiftTests`).
///
/// The point picks the block whose frame holds it, or the nearest where none does: a list's blocks stand under one
/// another and a board's side by side, so one rule reads both, a point above the first block being the first block's and
/// one in the gap between two columns the nearer column's. A block that takes no drop offers no slot. In its own block
/// the task takes the place the point names, the upper half of a row being before it and the lower half after it, read
/// by the rows' middles alone, so that the gap the mark opens, which moves the rows under a still finger, does not move
/// the slot; on a column only among the cards in sight, since a card scrolled out of it keeps a frame under its header.
/// In another block the module writes no place, a manual list taking the task last and any other standing it by its
/// sort, so wherever the finger is in that block the slot stands at its end.
struct RowLift: Equatable {
    /// A stage of the drag, as its drop delegate reports it, with the point in the content's own coordinates where it
    /// has one: the drag is first seen, moves, is let go once, or leaves. `onDrag` says what is carried and the first
    /// point over the scroll view says where, since the drag has no other beginning that a press which opens the menu
    /// instead does not also have (spike #174).
    enum Phase {
        case began(task: TaskID, block: TaskList.Model.BlockID, at: CGPoint)
        case changed(CGPoint)
        case ended
        case cancelled
    }

    /// Where the task would land: in a block, after a row there, nil for the top.
    struct Slot: Equatable {
        let block: TaskList.Model.BlockID
        let after: TaskID?
    }

    /// What the last layout reported, in the content's own coordinates, which a drag finds its place by: each row's frame,
    /// each block's or column's, and the part of each column its cards are seen through.
    struct Frames {
        var rows: [BlockRowID: CGRect] = [:]
        var blocks: [TaskList.Model.BlockID: CGRect] = [:]
        var columns: [TaskList.Model.BlockID: CGRect] = [:]
    }

    let task: TaskID

    /// The block it was dragged from, which names one of the two that draw a task both select.
    let source: TaskList.Model.BlockID

    /// How its row looks lifted, its mark of the drop's place for a block with no row of its own to give one.
    let style: TaskLiftStyle

    /// Where it would land, and nil over a block that takes no drop.
    private(set) var slot: Slot?

    /// The drag after a stage, among the blocks drawn and the frames their last layout reported, and the drop that
    /// stage reports: the first point lifts the row `onDrag` named, where it is still drawn and lifts; a move moves the
    /// slot; the release reports the drop once, where there is a slot, and puts the task down; and a cancel puts it down
    /// and reports nothing. A stage with no task lifted moves nothing.
    static func after(
        _ phase: Phase, from lift: RowLift?, among blocks: [TaskList.Model.Block], frames: Frames
    ) -> (lift: RowLift?, drop: TaskList.UserAction?) {
        switch phase {
        case .began(let task, let block, let point):
            (RowLift(lifting: task, from: block, among: blocks)?.moved(to: point, among: blocks, frames: frames), nil)
        case .changed(let point):
            (lift?.moved(to: point, among: blocks, frames: frames), nil)
        case .ended:
            (nil, lift?.drop)
        case .cancelled:
            (nil, nil)
        }
    }

    private init?(lifting task: TaskID, from source: TaskList.Model.BlockID, among blocks: [TaskList.Model.Block]) {
        let row = blocks.first { $0.id == source }?.rows.first { $0.id == task }
        guard let style = row?.lift else { return nil }
        self.task = task
        self.source = source
        self.style = style
    }

    private func moved(to point: CGPoint, among blocks: [TaskList.Model.Block], frames: Frames) -> RowLift {
        var moved = self
        moved.slot = Self.block(at: point, among: blocks, frames: frames).flatMap { block in
            guard block.takesDrop else { return nil }
            let rows = block.rows.map(\.id).filter { $0 != task }
            let after = block.id == source ? Self.place(at: point.y, among: rows, of: block.id, frames: frames) : rows.last
            return Slot(block: block.id, after: after)
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

    /// The row a task let go at the height stands after, among the rest of its own block, above a column's cards in sight
    /// its top and below them its end.
    private static func place(
        at y: CGFloat, among rows: [TaskID], of block: TaskList.Model.BlockID, frames: Frames
    ) -> TaskID? {
        if let area = frames.columns[block] {
            if y < area.minY { return nil }
            if y >= area.maxY { return rows.last }
        }
        return rows.prefix { row in
            frames.rows[BlockRowID(block: block, task: row)].map { $0.midY <= y } ?? false
        }.last
    }

    /// The drag's one report, on release, and nil over a block that takes no drop.
    private var drop: TaskList.UserAction? {
        slot.map { .rowDropped(task, from: source, in: $0.block, after: $0.after) }
    }
}

extension TaskList.Model.Row {
    /// How the row looks lifted, and nil for one that cannot be: an open card, which is neither lifted nor has a menu, and
    /// a row with no menu, by the module's one rule (`TaskRowStyle.lift`).
    var lift: TaskLiftStyle? {
        switch self {
        case .task(_, let row): row.style.lift
        case .card: nil
        }
    }
}
