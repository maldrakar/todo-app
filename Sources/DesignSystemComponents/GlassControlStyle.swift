// Sources/DesignSystemComponents/GlassControlStyle.swift
import DesignSystem

/// The numbers a `GlassButtonModel` is drawn with, in points, and its surface, hairline and shadow, which a builder
/// hands over as one value.
public struct GlassControlStyle: Equatable, Sendable {
    /// How far the glyph is moved from the centre, rightward where positive: the back chevron sits 2 pt left of it on
    /// the phone and 1 pt on the Mac (`Phone.dc.html` and `Mac.dc.html`, the back button's `margin-left`), so that it
    /// looks centred, and "…" sits at 0.
    public let iconOffset: Double

    public let diameter: Double
    public let surface: DesignSystem.Color

    /// The hairline round the button, whose width is how thick it is.
    public let line: LineStyle

    public let shadow: DesignSystem.Shadow

    public init(
        iconOffset: Double,
        diameter: Double,
        surface: DesignSystem.Color,
        line: LineStyle,
        shadow: DesignSystem.Shadow
    ) {
        self.iconOffset = iconOffset
        self.diameter = diameter
        self.surface = surface
        self.line = line
        self.shadow = shadow
    }
}
