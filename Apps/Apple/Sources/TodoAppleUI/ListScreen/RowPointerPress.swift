// Apps/Apple/Sources/TodoAppleUI/ListScreen/RowPointerPress.swift
import CoreGraphics
import Foundation
import TaskListFeature

/// A press of the pointer on the content of the list or the board, read as the stages of a lift (`RowLift`) for the
/// Mac's drag (`RowPointerDrag`), as `RowDragSessions` reads the calls of the system's drag on iOS: the row it began
/// on, by the frames the rows last reported, among those drawn and on a column only among the cards in sight, since a
/// card scrolled out of it keeps a frame under its header; and a session of its own, a new one for every press, as each
/// of the system's drags has. What each event of the gesture means is one step,
/// `after(_:from:lift:among:frames:viewport:)`, which knows no platform (`RowPointerTests`): a press that began on no
/// row lifts nothing at any move, nor does one that began on a row that does not lift, an open card.
///
/// Outside the part of the content in sight, over the sidebar, the window's bar or beyond the window, the pointer lets
/// go of nothing, as the system's drag does once it leaves the screen's scroll view: its lift is put down, the mark and
/// the tint with it, and a release there drops nothing; come back, it lifts the row again in the same session (the
/// controller's ruling R218). The nearest block, which a point in sight lands in, may be out of sight from there.
///
/// `RowPointerPress` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
struct RowPointerPress {
    /// An event of the pointer's drag, as the gesture hands it on: the pointer, pressed at a point, has moved to
    /// another past SwiftUI's distance; it is let go; or SwiftUI has cancelled the drag.
    enum Event {
        case moved(from: CGPoint, to: CGPoint)
        case released
        case cancelled
    }

    /// The row the press began on, and nil where it began on none.
    let row: BlockRowID?

    let session: String

    /// How far the press began from the top left corner of its row, which the row's copy keeps under the pointer.
    private let grab: CGVector

    /// How large its row stood when the press began, which the copy grows from.
    private let size: CGSize

    /// The press that began at the point, in the content's own coordinates, among the blocks drawn and the frames they
    /// last reported, in a session of its own.
    private init(at point: CGPoint, among blocks: [TaskList.Model.Block], frames: RowLift.Frames) {
        let row = frames.row(at: point, among: blocks)
        let frame = row.flatMap { frames.rows[$0] } ?? CGRect(origin: point, size: .zero)
        self.row = row
        session = UUID().uuidString
        grab = CGVector(dx: point.x - frame.minX, dy: point.y - frame.minY)
        size = frame.size
    }

    /// The press an event of the drag leaves, nil once the drag is over, and the stage of the lift it makes, among the
    /// blocks drawn, the frames they last reported and the part of the content in sight, all in the content's own
    /// coordinates: the first move begins the press where the pointer went down and every move is what the press reads
    /// of its point; the release drops the press's own lift and puts down any other, a lift no press holds now,
    /// which a drag whose state SwiftUI dropped would leave drawn; a cancel puts the lift down.
    static func after(
        _ event: Event, from press: RowPointerPress?, lift: RowLift?, among blocks: [TaskList.Model.Block],
        frames: RowLift.Frames, viewport: CGRect
    ) -> (press: RowPointerPress?, phase: RowLift.Phase?) {
        switch event {
        case .moved(let start, let point):
            let press = press ?? RowPointerPress(at: start, among: blocks, frames: frames)
            return (press, press.phase(at: point, lift: lift, viewport: viewport))
        case .released:
            let isItsLift = lift != nil && lift?.session == press?.session
            return (nil, isItsLift ? .ended : .cancelled)
        case .cancelled:
            return (nil, .cancelled)
        }
    }

    /// The stage a move of the pointer to the point is: outside the content in sight the press's lift put down; in it
    /// the press's row lifted where no task is, the lift moved where it is the press's; and nothing for a press that
    /// began on no row or for another session's lift.
    private func phase(at point: CGPoint, lift: RowLift?, viewport: CGRect) -> RowLift.Phase? {
        guard let row else { return nil }
        let isItsLift = lift?.session == session
        guard viewport.contains(point) else { return isItsLift ? .cancelled : nil }
        guard lift != nil else { return .began(task: row.task, block: row.block, session: session, at: point) }
        return isItsLift ? .changed(point) : nil
    }

    /// Where the top left corner of the row's copy stands with the pointer at the point: as far from it as the row's
    /// stood from the press, wherever the mark has moved the row itself since.
    func copyOrigin(at point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - grab.dx, y: point.y - grab.dy)
    }

    /// The point the copy grows about, as fractions of its size: the one the press grabbed, which so stays under the
    /// pointer as the copy grows to its lift's scale.
    var copyAnchor: CGPoint {
        CGPoint(x: size.width > 0 ? grab.dx / size.width : 0.5, y: size.height > 0 ? grab.dy / size.height : 0.5)
    }
}
