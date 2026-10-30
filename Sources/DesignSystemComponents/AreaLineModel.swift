// Sources/DesignSystemComponents/AreaLineModel.swift
import DesignSystem

/// An area's line in a tree as every platform draws it (`Phone.dc.html`, the area's row): `height` high, from `leading`
/// to `trailing` short of the right edge of the tree on screen, the label, or the field in its place while the area is
/// being renamed, then the line across the rest, then the grip where there is one, `spacing` apart, in points. The model
/// holds every value its platform needs to draw it, so a view decides nothing but what is the platform's
/// (ADR-0007, amendment of 2026-10-30).
public struct AreaLineModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let height: Double
    public let leading: Double
    public let trailing: Double
    public let spacing: Double

    /// The label on the line, on one line, and nil where the line stands alone.
    public let label: TextModel?

    /// The field the name is typed into while the area is being renamed, in the label's place, and nil while it is not:
    /// it is as wide as its minimum width, and the line takes the rest.
    public let field: FieldModel?

    /// The line, its colour and how thick it is.
    public let line: StrokeModel

    /// The grip, which says the line drags, and nil where it does not.
    public let grip: IconModel?

    /// What a tap on the line sends.
    public let tap: Action

    /// The menu of the line, and nil where it has none.
    public let menu: MenuModel<Action>?

    public init(
        height: Double,
        leading: Double,
        trailing: Double,
        spacing: Double,
        label: TextModel?,
        field: FieldModel?,
        line: StrokeModel,
        grip: IconModel?,
        tap: Action,
        menu: MenuModel<Action>?
    ) {
        self.height = height
        self.leading = leading
        self.trailing = trailing
        self.spacing = spacing
        self.label = label
        self.field = field
        self.line = line
        self.grip = grip
        self.tap = tap
        self.menu = menu
    }
}
