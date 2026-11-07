// Apps/Apple/Sources/TodoAppleUI/ListScreen/SwipeToDelete.swift
import CoreGraphics
import DesignSystemComponents

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

    private let style: SwipeStyle

    /// Where the row stood when the finger took it, its shift if it was open, and otherwise its place.
    private let start: CGFloat

    /// The swipe after a stage: a row follows the finger from where it stood, and not rightward of its place, nor more
    /// than the threshold past its shift; let go past the threshold it stays moved by its shift, short of it it goes back,
    /// and a pan taken back leaves it where it rested. With no row taken, nothing moves.
    static func after(_ phase: Phase, from swipe: RowSwipe?) -> RowSwipe? {
        switch phase {
        case .began(let row, let style):
            let start: CGFloat = swipe?.row == row ? style.shift : 0
            return RowSwipe(row: row, x: start, style: style, start: start)
        case .changed(let move):
            return swipe?.moved(move)
        case .ended(let move):
            return swipe?.moved(move).resting(isOpen: swipe?.moved(move).isPastThreshold ?? false)
        case .cancelled:
            return swipe?.resting(isOpen: swipe?.start != 0)
        }
    }

    private func moved(_ move: CGFloat) -> RowSwipe {
        RowSwipe(row: row, x: min(0, max(style.shift - style.threshold, start + move)), style: style, start: start)
    }

    private var isPastThreshold: Bool { x < -style.threshold }

    private func resting(isOpen: Bool) -> RowSwipe? {
        isOpen ? RowSwipe(row: row, x: style.shift, style: style, start: style.shift) : nil
    }
}
