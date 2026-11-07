// Sources/DesignSystemComponents/AreaLineModel.swift

/// An area's line in a tree as every platform draws it (`Phone.dc.html`, the area's row): `height` high, from `leading`
/// the label, or the field in its place while the area is being renamed, then the line across the rest, `spacing`
/// after them, then `lineToAccessories` after the line its accessories in the order given, a text as wide as it
/// reads, a chevron, a grip or a check each centred in a cell at least `cellMinimumWidth` wide and as wide as its
/// glyph on its platform, a space as wide as it says and a hidden accessory's room empty, and `endGap` after them
/// short of the right edge of what it is laid out on, in points. The model holds every value its platform needs to
/// draw it, so a view decides nothing but what is the platform's (ADR-0007, amendment of 2026-10-30). Its numbers and
/// its `line` are the fields of its `AreaLineStyle`.
///
/// A class, for the reason a list's row is one (`ListRowModel`): a line is a row's kind and an option of a picker, and
/// some 600 bytes on wasm32. Its `==` compares every stored property, and a test changes them one at a time.
public final class AreaLineModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let style: AreaLineStyle

    /// The label on the line, on one line, and nil where the line stands alone.
    public let label: TextModel?

    /// The field the name is typed into while the area is being renamed, in the label's place, and nil while it is not:
    /// it is as wide as its minimum width, and the line takes the rest.
    public let field: TextFieldModel<Action>?

    /// What stands at the right of the line, after it, in the order given.
    public let accessories: [AccessoryModel<Action>]

    /// What a tap on the line sends.
    public let tap: Action

    /// The menu of the line, and nil where it has none.
    public let menu: MenuModel<Action>?

    public init(
        style: AreaLineStyle,
        label: TextModel?,
        field: TextFieldModel<Action>?,
        accessories: [AccessoryModel<Action>],
        tap: Action,
        menu: MenuModel<Action>?
    ) {
        self.style = style
        self.label = label
        self.field = field
        self.accessories = accessories
        self.tap = tap
        self.menu = menu
    }

    public static func == (lhs: AreaLineModel, rhs: AreaLineModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.style == rhs.style
            && lhs.label == rhs.label
            && lhs.field == rhs.field
            && lhs.accessories == rhs.accessories
            && lhs.tap == rhs.tap
            && lhs.menu == rhs.menu
    }
}
