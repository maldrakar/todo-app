// Apps/Apple/Sources/TodoAppleUI/ListScreen/RowSwipe.swift
import CoreGraphics
import DesignSystemComponents
import TaskListFeature

/// The row a swipe has moved aside, or that one is moving, as far as it stands now. It is the view's own state, which
/// nothing else can know, and each stage of the swipe moves it through one step, `after(_:from:)`, which knows no
/// platform, so that it is tested on the host (`RowSwipeTests`). Only one row stands aside: another taken starts from
/// rest, and the one open goes back. The numbers are the row's `SwipeStyle`.
struct RowSwipe: Equatable {
    /// A stage of the pan: a row taken, with the look of its swipe, and how far the finger has moved since, leftward
    /// negative, as it moves and where it is let go; or a pan the system took back.
    enum Phase {
        case began(BlockRowID, SwipeStyle)
        case changed(CGFloat)
        case ended(CGFloat)
        case cancelled
    }

    let row: BlockRowID

    /// How far the row stands from its place, leftward negative.
    let x: CGFloat

    /// Whether a finger is moving it, which it follows at once, and otherwise it comes to rest on its motion.
    let isFollowingFinger: Bool

    private let style: SwipeStyle

    /// Where the row stood when the finger took it, its shift if it was open, and otherwise its place.
    private let start: CGFloat

    /// The swipe after a stage: a row follows the finger from where it stood, and not rightward of its place, nor more
    /// than the threshold past its shift; let go past the threshold it stays moved by its shift, short of it it goes
    /// back, and a pan taken back leaves it where it rested. With no row taken, nothing moves.
    static func after(_ phase: Phase, from swipe: RowSwipe?) -> RowSwipe? {
        switch phase {
        case .began(let row, let style):
            let start: CGFloat = swipe?.row == row ? style.shift : 0
            return RowSwipe(row: row, x: start, isFollowingFinger: true, style: style, start: start)
        case .changed(let move):
            return swipe?.moved(move)
        case .ended(let move):
            let moved = swipe?.moved(move)
            return moved?.resting(isOpen: moved?.isPastThreshold ?? false)
        case .cancelled:
            return swipe?.resting(isOpen: swipe?.start != 0)
        }
    }

    /// The row a pan that started at the point may take, having moved so far, with the look of its swipe: the row under
    /// the point by the frames the last layout reported, where it has a swipe, leftward, or either way where it is the
    /// one standing open. Otherwise nil, and the scroll has the pan.
    static func row(
        at point: CGPoint, moved: CGFloat, from swipe: RowSwipe?, among blocks: [TaskList.Model.Block],
        frames: RowLift.Frames
    ) -> (row: BlockRowID, style: SwipeStyle)? {
        guard let row = frames.rows.first(where: { $0.value.contains(point) })?.key,
              let drawn = blocks.first(where: { $0.id == row.block })?.rows.first(where: { $0.id == row.task }),
              let style = drawn.swipe?.style,
              moved < 0 || swipe?.row == row
        else { return nil }
        return (row, style)
    }

    private func moved(_ move: CGFloat) -> RowSwipe {
        RowSwipe(
            row: row, x: min(0, max(style.shift - style.threshold, start + move)), isFollowingFinger: true,
            style: style, start: start
        )
    }

    private var isPastThreshold: Bool { x < -style.threshold }

    private func resting(isOpen: Bool) -> RowSwipe? {
        guard isOpen else { return nil }
        return RowSwipe(row: row, x: style.shift, isFollowingFinger: false, style: style, start: style.shift)
    }
}
