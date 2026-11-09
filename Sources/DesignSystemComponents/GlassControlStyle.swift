// Sources/DesignSystemComponents/GlassControlStyle.swift
import DesignSystem

/// The numbers a `GlassButtonLabelModel` is drawn with, in points, and its glass where it stands alone, which a builder
/// hands over as one value.
public struct GlassControlStyle: Equatable, Sendable {
    /// What a platform with no glass of its own draws under glass: a surface over the material, edged with a hairline
    /// whose width is how thick it is, casting a shadow. A control that stands alone has one, and a capsule has one for
    /// the controls inside it (`GlassCapsuleStyle`).
    public struct Glass: Equatable, Sendable {
        public let surface: DesignSystem.Color
        public let line: LineStyle
        public let shadow: DesignSystem.Shadow

        public init(surface: DesignSystem.Color, line: LineStyle, shadow: DesignSystem.Shadow) {
            self.surface = surface
            self.line = line
            self.shadow = shadow
        }
    }

    /// How far the glyph is moved from the centre, rightward where positive: the back chevron sits 2 pt left of it on
    /// the phone and 1 pt on the Mac (`Phone.dc.html` and `Mac.dc.html`, the back button's `margin-left`), so that it
    /// looks centred, and "…" sits at 0.
    public let iconOffset: Double

    /// How wide the button is across: a circle's diameter, or an item of the Mac's capsule's width.
    public let diameter: Double

    /// How high the button is: the same as `diameter` for a circle, and 28 against 30 across for an item of the Mac's
    /// capsule (`GlassCapsuleStyle`).
    public let height: Double

    /// The glass under the button, and nil for one inside a capsule, which has the glass of its own.
    public let glass: Glass?

    /// The tint over the button while the pointer is over it, and nil where there is none: the phone's, and the pane's
    /// back, which the canvas does not tint.
    public let hover: HoverStyle?

    public init(
        iconOffset: Double,
        diameter: Double,
        height: Double,
        glass: Glass?,
        hover: HoverStyle?
    ) {
        self.iconOffset = iconOffset
        self.diameter = diameter
        self.height = height
        self.glass = glass
        self.hover = hover
    }
}
