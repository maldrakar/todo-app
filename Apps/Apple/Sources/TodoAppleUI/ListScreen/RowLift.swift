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
/// since the task would keep to its own group wherever it was let go. In another block the module writes no place, a
/// manual list taking the task last and any other standing it by its order, so the slot is that block, which its tint
/// marks, and no place in it (the owner's review of #177, 2026-11-08).
struct RowLift: Equatable {
    /// A stage of the drag, as its drop's delegate reports it (`RowDragSessions`) or the Mac's pointer does
    /// (`RowPointerPress`), with the point in the content's own coordinates where it has one: the drag is first seen,
    /// moves, is let go once, or leaves. The drag's item says what is carried (`RowSystemDrag`) and the first point
    /// over the scroll view says where, since the drag has no other beginning that a press which opens the menu instead
    /// does not also have (spike #174); the pointer's press says both at its first move.
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
    /// its place by: each row's frame, each block's or column's, a list's block's the union of its parts' (`report`),
    /// and the part of each column its cards are seen through.
    struct Frames {
        var rows: [BlockRowID: CGRect] = [:]
        var blocks: [TaskList.Model.BlockID: CGRect] = [:]
        var columns: [TaskList.Model.BlockID: CGRect] = [:]

        /// A part of a list's block, which stands in the list's lazy stack on its own, with no view of the block round
        /// it (`ListSurface`): the block's header, a row by its task, or its "+ Add task".
        enum BlockPart: Hashable {
            case header
            case row(TaskID)
            case add
        }

        /// The frames the parts of each list's block last reported, a part out of sight keeping its own.
        private var parts: [TaskList.Model.BlockID: [BlockPart: CGRect]] = [:]

        /// Keeps the frame a part of a list's block reported, in place of the one it reported before, and makes the
        /// block's frame the union of its parts'.
        mutating func report(_ part: BlockPart, of block: TaskList.Model.BlockID, _ frame: CGRect) {
            parts[block, default: [:]][part] = frame
            blocks[block] = Self.union(of: parts[block])
        }

        /// Forgets the parts the list's blocks no longer draw, a row that left its block and a block's rows and "+ Add
        /// task" folded away, and makes each block's frame the union of those it draws, and none where it reported
        /// none, whatever a board left: a folded block kept its rows' frames, which stood over the blocks under it and
        /// took their drops and their tint (#196). A block no longer drawn has neither parts nor frame, so that what
        /// is kept is never more than the list draws.
        mutating func forgetParts(notDrawnBy drawn: [TaskList.Model.Block]) {
            let ids = Set(drawn.map(\.id))
            parts = parts.filter { ids.contains($0.key) }
            blocks = blocks.filter { ids.contains($0.key) }
            for block in drawn {
                let rows = Set(block.rows.map(\.id))
                let kept = parts[block.id]?.filter { part, _ in
                    switch part {
                    case .header: block.header != nil
                    case .row(let task): rows.contains(task)
                    case .add: block.addTask != nil
                    }
                }
                parts[block.id] = kept
                blocks[block.id] = Self.union(of: kept)
            }
        }

        private static func union(of parts: [BlockPart: CGRect]?) -> CGRect? {
            parts?.values.reduce(nil) { union, frame in union?.union(frame) ?? frame }
        }

        /// Where the mark's line ends in a block, from the block's own leading edge, where the mark is drawn: the
        /// block's width, and nothing before the block has reported. Its right edge in the content is not it, since a
        /// block of the pane stands in from the content's side, and the line that long widened the block it stood in
        /// by that inset while a row was carried (the Mac, 2026-11-09).
        func lineEnd(in block: TaskList.Model.BlockID) -> CGFloat {
            blocks[block]?.width ?? 0
        }

        /// The row whose frame holds the point, among the rows of the blocks drawn, which leaves out those that have
        /// left and kept their frames; and on a column only where the point is in sight of its cards, since a card
        /// scrolled out of it keeps a frame under its header.
        func row(at point: CGPoint, among drawn: [TaskList.Model.Block]) -> BlockRowID? {
            for block in drawn {
                if block.column != nil, let area = columns[block.id], !area.contains(point) { continue }
                for row in block.rows {
                    let id = BlockRowID(block: block.id, task: row.id)
                    if rows[id]?.contains(point) == true { return id }
                }
            }
            return nil
        }
    }

    let task: TaskID

    /// The block it was dragged from, which names one of the two that draw a task both select.
    let source: TaskList.Model.BlockID

    /// The drag's session, which `RowDragSessions` tells apart from any other press, and on the Mac the pointer's
    /// press's own.
    let session: String

    /// Where it would land, and nil over a block that takes no drop and over its own where it keeps no dropped place.
    private(set) var slot: Slot?

    /// The drag after a stage, among the blocks drawn and the frames they last reported, and the drop that stage
    /// reports: the first point lifts the row the drag's item named, where it is still drawn and lifts; a move moves
    /// the slot; the release reports the drop once, where there is a slot, and puts the task down; and a cancel puts it
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
    /// in the frames. Otherwise it is read by the row whose middle is nearest the height among those with a frame:
    /// after that row where its middle is at or above the height, and else after the row before it, framed or not, or
    /// at the top before the first. Not by the rows from the top down to the height, since in a lazy stack a block's
    /// upper rows may never have been laid out, after a jump and not a finger's scroll, and a row out of sight keeps a
    /// frame a change above it may have left far from where it stands (#196).
    private static func place(
        at y: CGFloat, among rows: [TaskID], of block: TaskList.Model.Block, frames: Frames
    ) -> TaskID? {
        if block.column != nil, let area = frames.columns[block.id] {
            if y < area.minY { return nil }
            if y >= area.maxY { return rows.last }
        }
        let framed = rows.indices.compactMap { index in
            frames.rows[BlockRowID(block: block.id, task: rows[index])].map { (index: index, middle: $0.midY) }
        }
        guard let nearest = framed.min(by: { abs($0.middle - y) < abs($1.middle - y) }) else { return nil }
        if nearest.middle <= y { return rows[nearest.index] }
        return nearest.index > 0 ? rows[nearest.index - 1] : nil
    }

    /// The drag's one report, on release, and nil where there is no slot.
    private var drop: TaskList.UserAction? {
        switch slot {
        case .place(let block, let after)?: .rowDropped(task, from: source, in: block, after: after)
        case .into(let block)?: .rowDropped(task, from: source, in: block, after: nil)
        case nil: nil
        }
    }

    /// Where the copy of the task goes once the drag is let go (#211): onto the row the task stands as, or toward a
    /// point in sight where that row cannot show it.
    enum Settling: Equatable {
        /// Onto the row at its frame, which stands hidden under the copy until the copy is there.
        case onto(BlockRowID, CGRect)

        /// Toward the point, where the copy fades as it goes.
        case toward(CGPoint)
    }

    /// Where the copy goes, this being the lift as the release found it, among the blocks drawn and the frames their
    /// layout reports once the drop has been made, and with the part of the content in sight, all in the content's own
    /// coordinates. The row is the one the task landed as, in the block of its slot, or its own where nothing landed.
    /// Whose middle is in sight, on a column among the cards in sight or, with none of them in sight, on the board, the
    /// copy settles onto it; out of sight, toward the edge of what is in sight nearest it; not laid out, toward the
    /// middle of what of its block is in sight, the block's tinted area, or the edge nearest the block; and with
    /// neither laid out, nowhere, nil.
    func settling(among blocks: [TaskList.Model.Block], frames: Frames, inSight sight: CGRect) -> Settling? {
        Self.settling(
            onto: BlockRowID(block: slot?.block ?? source, task: task), among: blocks, frames: frames, inSight: sight
        )
    }

    /// Where a copy goes to settle onto the row, as `settling(among:frames:inSight:)` reads it: a lift's own where the
    /// drag it stood for has put it down, and its copy goes back to the row it was dragged from.
    static func settling(
        onto row: BlockRowID, among blocks: [TaskList.Model.Block], frames: Frames, inSight sight: CGRect
    ) -> Settling? {
        let isColumn = blocks.first { $0.id == row.block }?.column != nil
        let cardsSeen = isColumn ? frames.columns[row.block].map(sight.intersection) : nil
        let seen = cardsSeen.flatMap { $0.isNull ? nil : $0 } ?? sight
        if let frame = frames.rows[row] {
            let middle = CGPoint(x: frame.midX, y: frame.midY)
            return seen.contains(middle) ? .onto(row, frame) : .toward(nearest(to: middle, in: seen))
        }
        guard let block = frames.blocks[row.block] else { return nil }
        let blockSeen = block.intersection(seen)
        if blockSeen.isNull { return .toward(nearest(to: CGPoint(x: block.midX, y: block.midY), in: seen)) }
        return .toward(CGPoint(x: blockSeen.midX, y: blockSeen.midY))
    }

    /// The point of the area nearest the point, the point itself where the area holds it.
    private static func nearest(to point: CGPoint, in area: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, area.minX), area.maxX), y: min(max(point.y, area.minY), area.maxY))
    }
}

/// The drags the system's drag has begun on a screen's rows (`RowSystemDrag`), each by the token its item carries,
/// which reaches the drop's delegate through the drag's local item, so that a lift is tied to its drag: a second finger
/// pressing another row begins another session and takes nothing from the first, and another window's drag of the
/// private type names a session this screen did not begin. What each call of the delegate means is one step,
/// `phase(for:session:lift:)`, which knows no platform (`RowLiftTests`). A session is no drag until the delegate hears
/// it, and they are all forgotten at a drop. A session outlives a lift that ended with no release, the drag having left
/// the scroll view: it may come back.
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

    /// Begins a session for the row the drag carries, and answers its token.
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
