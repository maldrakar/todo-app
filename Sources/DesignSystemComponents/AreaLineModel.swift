// Sources/DesignSystemComponents/AreaLineModel.swift
import DesignSystem

/// An area's line in a tree as every platform draws it (`Phone.dc.html`, the area's row): `height` high, from `leading`
/// the label, or the field in its place while the area is being renamed, then the line across the rest, `spacing`
/// after them, then `lineToAccessories` after the line its accessories in the order given, a count as wide as it
/// reads, a chevron, a grip or a check each centred in a cell `cellWidth` wide and a space as wide as it says, and
/// `endGap` after them short of the right edge of what it is laid out on, in points. The model holds every value its
/// platform needs to draw it, so a view decides nothing but what is the platform's (ADR-0007, amendment of
/// 2026-10-30).
///
/// A class, for the reason a list's row is one (`ListRowModel`): a line is a row's kind and an option of a picker, and
/// some 600 bytes on wasm32. Its `==` compares every stored property, and a test changes them one at a time.
public final class AreaLineModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let height: Double
    public let leading: Double
    public let spacing: Double

    /// The label on the line, on one line, and nil where the line stands alone.
    public let label: TextModel?

    /// The field the name is typed into while the area is being renamed, in the label's place, and nil while it is not:
    /// it is as wide as its minimum width, and the line takes the rest.
    public let field: TextFieldModel<Action>?

    /// The line, its colour and how thick it is.
    public let line: StrokeModel

    /// The gap between the end of the line and the accessories, and the end where there are none.
    public let lineToAccessories: Double

    /// What stands at the right of the line, after it, in the order given.
    public let accessories: [AccessoryModel<Action>]

    public let cellWidth: Double
    public let endGap: Double

    /// What a tap on the line sends.
    public let tap: Action

    /// The menu of the line, and nil where it has none.
    public let menu: MenuModel<Action>?

    public init(
        height: Double,
        leading: Double,
        spacing: Double,
        label: TextModel?,
        field: TextFieldModel<Action>?,
        line: StrokeModel,
        lineToAccessories: Double,
        accessories: [AccessoryModel<Action>],
        cellWidth: Double,
        endGap: Double,
        tap: Action,
        menu: MenuModel<Action>?
    ) {
        self.height = height
        self.leading = leading
        self.spacing = spacing
        self.label = label
        self.field = field
        self.line = line
        self.lineToAccessories = lineToAccessories
        self.accessories = accessories
        self.cellWidth = cellWidth
        self.endGap = endGap
        self.tap = tap
        self.menu = menu
    }

    public static func == (lhs: AreaLineModel, rhs: AreaLineModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.height == rhs.height
            && lhs.leading == rhs.leading
            && lhs.spacing == rhs.spacing
            && lhs.label == rhs.label
            && lhs.field == rhs.field
            && lhs.line == rhs.line
            && lhs.lineToAccessories == rhs.lineToAccessories
            && lhs.accessories == rhs.accessories
            && lhs.cellWidth == rhs.cellWidth
            && lhs.endGap == rhs.endGap
            && lhs.tap == rhs.tap
            && lhs.menu == rhs.menu
    }
}
