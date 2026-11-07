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
/// carries the task's id beside it. Its numbers, its `strike`, its `lift`, its `fresh`, its motions and how it leaves
/// are the fields of its `TaskRowStyle`.
///
/// A class, for the reason a list's row is one (`ListRowModel`): a block holds many, every comparison of the screen's
/// model compares them, and inline, its check, swipe and style with it, a row is some 1,160 bytes on wasm32. Its `==`
/// compares every stored property, and a test changes them one at a time.
public final class TaskRowModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let check: CheckModel<Action>

    /// The title, in its colour, the done colour where the task is done.
    public let title: TextModel

    /// The items of the meta line in the order they stand, and none for a row with no meta line.
    public let meta: [MetaItemModel]

    public let style: TaskRowStyle

    /// The swipe that uncovers the row's Delete, and nil for a row that is not swiped.
    public let swipe: SwipeModel<Action>?

    /// What a tap on the row, beside its check, sends.
    public let tap: Action

    /// The menu of the row, and nil where it has none.
    public let menu: MenuModel<Action>?

    public init(
        check: CheckModel<Action>,
        title: TextModel,
        meta: [MetaItemModel],
        style: TaskRowStyle,
        swipe: SwipeModel<Action>?,
        tap: Action,
        menu: MenuModel<Action>?
    ) {
        self.check = check
        self.title = title
        self.meta = meta
        self.style = style
        self.swipe = swipe
        self.tap = tap
        self.menu = menu
    }

    public static func == (lhs: TaskRowModel, rhs: TaskRowModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.check == rhs.check
            && lhs.title == rhs.title
            && lhs.meta == rhs.meta
            && lhs.style == rhs.style
            && lhs.swipe == rhs.swipe
            && lhs.tap == rhs.tap
            && lhs.menu == rhs.menu
    }
}
