// Sources/DesignSystemComponents/CardModel.swift
import DesignSystem

/// A task's card, its row opened in place (`Phone.dc.html`, the open card; `Mac.dc.html`, the pane's): `topMargin`
/// below what stands before it, `horizontalMargin` in from either side and `bottomMargin` above what follows, on
/// `background` with corners of `cornerRadius`, casting `shadow`, opening on `animation`. Along its top stand its
/// check, its title's field and the button that opens it full screen, centred in a square cell `expandHitSide` on a
/// side; under them its body, `bodyLeading` in from its leading edge, under the title, and `bodyTrailing` from its
/// trailing edge, ending `bodyBottom` above its bottom: the notes' field, the subtasks, the field of the subtask being
/// typed where there is one, the row that adds a subtask, and `subtasksToPills` under them its pills, `pillSpacing`
/// apart, in points. Its numbers and its `shadow` are the fields of its `Style`.
///
/// The actions the typed text of its three fields sends are not here, as no field's is (`TextFieldModel`): a card's
/// view takes them beside the model. It holds no id of the store's: the feature module's row carries the task's id
/// beside it.
///
/// A class, for the reason a list's row is one (`ListRowModel`): a block holds it among its rows, every comparison of
/// the screen's model compares it, and inline, with its three fields, it is some 2,070 bytes on wasm32. Its `==`
/// compares every stored property, and a test changes them one at a time.
public final class CardModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The numbers the component is drawn with, in points, and the card's shadow, which the layout knows whole and a builder hands
    /// over as one value.
    public struct Style: Equatable, Sendable {
        public let expandHitSide: Double
        public let cornerRadius: Double
        public let topMargin: Double
        public let horizontalMargin: Double
        public let bottomMargin: Double
        public let bodyLeading: Double
        public let bodyTrailing: Double
        public let bodyBottom: Double
        public let subtasksToPills: Double
        public let pillSpacing: Double
        public let shadow: DesignSystem.Shadow

        public init(
            expandHitSide: Double,
            cornerRadius: Double,
            topMargin: Double,
            horizontalMargin: Double,
            bottomMargin: Double,
            bodyLeading: Double,
            bodyTrailing: Double,
            bodyBottom: Double,
            subtasksToPills: Double,
            pillSpacing: Double,
            shadow: DesignSystem.Shadow
        ) {
            self.expandHitSide = expandHitSide
            self.cornerRadius = cornerRadius
            self.topMargin = topMargin
            self.horizontalMargin = horizontalMargin
            self.bottomMargin = bottomMargin
            self.bodyLeading = bodyLeading
            self.bodyTrailing = bodyTrailing
            self.bodyBottom = bodyBottom
            self.subtasksToPills = subtasksToPills
            self.pillSpacing = pillSpacing
            self.shadow = shadow
        }
    }

    public let check: CheckModel<Action>
    public let title: TextFieldModel<Action>
    public let notes: TextFieldModel<Action>

    /// The subtasks, in their order.
    public let subtasks: [SubtaskRowModel<Action>]

    /// The field a new subtask is typed into, under the subtasks, and nil while none is being typed.
    public let subtaskField: TextFieldModel<Action>?

    public let addSubtask: AddRowModel<Action>

    /// The pills, its day, its deadline and its tags, in the order they stand.
    public let pills: [PillModel]

    /// The button that opens the task full screen.
    public let expand: ButtonModel<Action>

    public let background: DesignSystem.Color
    public let style: Style
    public let animation: DesignSystem.Animation

    /// What a tap on the screen's background beside the card sends, a tap the view the card stands in takes.
    public let backgroundTapped: Action

    public init(
        check: CheckModel<Action>,
        title: TextFieldModel<Action>,
        notes: TextFieldModel<Action>,
        subtasks: [SubtaskRowModel<Action>],
        subtaskField: TextFieldModel<Action>?,
        addSubtask: AddRowModel<Action>,
        pills: [PillModel],
        expand: ButtonModel<Action>,
        background: DesignSystem.Color,
        style: Style,
        animation: DesignSystem.Animation,
        backgroundTapped: Action
    ) {
        self.check = check
        self.title = title
        self.notes = notes
        self.subtasks = subtasks
        self.subtaskField = subtaskField
        self.addSubtask = addSubtask
        self.pills = pills
        self.expand = expand
        self.background = background
        self.style = style
        self.animation = animation
        self.backgroundTapped = backgroundTapped
    }

    public static func == (lhs: CardModel, rhs: CardModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.check == rhs.check
            && lhs.title == rhs.title
            && lhs.notes == rhs.notes
            && lhs.subtasks == rhs.subtasks
            && lhs.subtaskField == rhs.subtaskField
            && lhs.addSubtask == rhs.addSubtask
            && lhs.pills == rhs.pills
            && lhs.expand == rhs.expand
            && lhs.style == rhs.style
            && lhs.background == rhs.background
            && lhs.animation == rhs.animation
            && lhs.backgroundTapped == rhs.backgroundTapped
    }
}
