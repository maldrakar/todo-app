// Sources/DesignSystemComponents/TaskRowModel.swift
import DesignSystem

/// A task's row as every platform draws it (`Phone.dc.html`, the list screen's row; `Mac.dc.html`, the pane's row), and
/// a card of a column in the card look: `leading` in from its leading edge its check, then its title, `titleLeading`
/// after the check's tap area and `titleTrailing` short of the row's `trailing`, with `verticalPadding` above and below
/// it, struck through in `strike` where the task is done; under the title, `titleToMeta` below it, the meta line, its
/// items `metaSpacing` apart and its lines `metaLineSpacing` apart where it wraps; at least `minimumHeight` high, with
/// what it draws under itself rounded by `cornerRadius`, in points. The model holds every value its platform needs to
/// draw it, so a view decides nothing but what is the platform's: the gestures, the swipe and the lift as they move,
/// focus and Reduce Motion (ADR-0007, amendment of 2026-10-30). It holds no id of the store's: the feature module's row
/// carries the task's id beside it. Its numbers and its `freshAnimation` are the fields of its `TaskRowStyle`.
///
/// A class, for the reason a list's row is one (`ListRowModel`): a block holds many, every comparison of the screen's
/// model compares them, and inline, its check, swipe and lift with it, a row is some 1,160 bytes on wasm32. Its `==`
/// compares every stored property, and a test changes them one at a time.
public final class TaskRowModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let check: CheckModel<Action>

    /// The title, in its colour, the done colour where the task is done.
    public let title: TextModel

    /// The colour of the line through the title, the canvas's ink 3 through a done task's (`.tt-done`), and nil for a
    /// title with no line through it.
    public let strike: DesignSystem.Color?

    /// The items of the meta line in the order they stand, and none for a row with no meta line.
    public let meta: [MetaItemModel]

    public let style: TaskRowStyle

    /// The swipe that uncovers the row's Delete, and nil for a row that is not swiped.
    public let swipe: SwipeModel<Action>?

    /// How the row looks while it is lifted to be moved, and nil for a row that cannot be.
    public let lift: TaskLiftModel?

    /// The colour under the row where it was just dropped, which fades out over its style's `freshAnimation` from the
    /// moment it lands, and nil under any other row. The motion is held while the colour is nil too, so the fade does
    /// not stop when the colour goes.
    public let fresh: DesignSystem.Color?

    /// What a tap on the row, beside its check, sends.
    public let tap: Action

    /// The menu of the row, and nil where it has none.
    public let menu: MenuModel<Action>?

    public init(
        check: CheckModel<Action>,
        title: TextModel,
        strike: DesignSystem.Color?,
        meta: [MetaItemModel],
        style: TaskRowStyle,
        swipe: SwipeModel<Action>?,
        lift: TaskLiftModel?,
        fresh: DesignSystem.Color?,
        tap: Action,
        menu: MenuModel<Action>?
    ) {
        self.check = check
        self.title = title
        self.strike = strike
        self.meta = meta
        self.style = style
        self.swipe = swipe
        self.lift = lift
        self.fresh = fresh
        self.tap = tap
        self.menu = menu
    }

    public static func == (lhs: TaskRowModel, rhs: TaskRowModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.check == rhs.check
            && lhs.title == rhs.title
            && lhs.strike == rhs.strike
            && lhs.meta == rhs.meta
            && lhs.style == rhs.style
            && lhs.swipe == rhs.swipe
            && lhs.lift == rhs.lift
            && lhs.fresh == rhs.fresh
            && lhs.tap == rhs.tap
            && lhs.menu == rhs.menu
    }
}
