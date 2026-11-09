// Apps/Apple/Sources/TodoAppleUI/ListScreen/RowPointerPress.swift
import CoreGraphics
import Foundation
import TaskListFeature

/// A press of the pointer on the content of the list or the board, read as the stages of a lift (`RowLift`) for the
/// Mac's drag (`RowPointerDrag`), as `RowDragSessions` reads the calls of the system's drag on iOS: the row it began
/// on, by the frames the rows last reported, among those drawn and on a column only among the cards in sight, since a
/// card scrolled out of it keeps a frame under its header; and a session of its own, a new one for every press, as each
/// of the system's drags has. What each move of the pointer means is one step, `phase(at:lift:)`, which knows no
/// platform (`RowLiftTests`): a press that began on no row lifts nothing at any move, nor does one that began on a row
/// that does not lift, an open card.
///
/// `RowPointerPress` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
struct RowPointerPress {
    /// The row the press began on, and nil where it began on none.
    let row: BlockRowID?

    let session: String

    /// How far the press began from the top left corner of its row, which the row's copy keeps under the pointer.
    private let grab: CGVector

    /// The press that began at the point, in the content's own coordinates, among the blocks drawn and the frames they
    /// last reported, in a session of its own.
    init(
        at point: CGPoint, among blocks: [TaskList.Model.Block], frames: RowLift.Frames,
        session: String = UUID().uuidString
    ) {
        let row = Self.row(at: point, among: blocks, frames: frames)
        let origin = row.flatMap { frames.rows[$0]?.origin } ?? point
        self.row = row
        self.session = session
        grab = CGVector(dx: point.x - origin.x, dy: point.y - origin.y)
    }

    /// The stage a move of the pointer to the point is: the press's row lifted where no task is, the lift moved where
    /// it is the press's, and nothing for a press that began on no row or for another session's lift.
    func phase(at point: CGPoint, lift: RowLift?) -> RowLift.Phase? {
        guard let row else { return nil }
        guard let lift else { return .began(task: row.task, block: row.block, session: session, at: point) }
        return lift.session == session ? .changed(point) : nil
    }

    /// Where the top left corner of the row's copy stands with the pointer at the point: as far from it as the row's
    /// stood from the press, wherever the mark has moved the row itself since.
    func copyOrigin(at point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - grab.dx, y: point.y - grab.dy)
    }

    /// The row whose frame holds the point, among the rows of the blocks drawn, which leaves out those that have left
    /// and kept their frames; and on a column only where the point is in sight of its cards.
    private static func row(
        at point: CGPoint, among blocks: [TaskList.Model.Block], frames: RowLift.Frames
    ) -> BlockRowID? {
        for block in blocks {
            if block.column != nil, let area = frames.columns[block.id], !area.contains(point) { continue }
            for row in block.rows {
                let id = BlockRowID(block: block.id, task: row.id)
                if frames.rows[id]?.contains(point) == true { return id }
            }
        }
        return nil
    }
}
