// Sources/DesignSystemComponents/PillModel.swift
import DesignSystem

/// One of an open card's pills, its day, its deadline or a tag (`Phone.dc.html`, `.xpill`): `height` high on
/// `background`, with corners of `cornerRadius`, half its height for a capsule, its glyph `leadingPadding` in from its
/// leading edge and `spacing` before its text, and the text `trailingPadding` short of its trailing edge, in points.
/// Its numbers are the fields of its `Style`.
public struct PillModel: Equatable, Sendable {
    /// The numbers the component is drawn with, in points, which a layout holds whole and a builder hands over as one
    /// value.
    public struct Style: Equatable, Sendable {
        public let height: Double
        public let cornerRadius: Double
        public let leadingPadding: Double
        public let trailingPadding: Double
        public let spacing: Double

        public init(
            height: Double,
            cornerRadius: Double,
            leadingPadding: Double,
            trailingPadding: Double,
            spacing: Double
        ) {
            self.height = height
            self.cornerRadius = cornerRadius
            self.leadingPadding = leadingPadding
            self.trailingPadding = trailingPadding
            self.spacing = spacing
        }
    }

    public let icon: IconModel
    public let text: TextModel
    public let background: DesignSystem.Color
    public let style: Style

    public init(
        icon: IconModel,
        text: TextModel,
        background: DesignSystem.Color,
        style: Style
    ) {
        self.icon = icon
        self.text = text
        self.background = background
        self.style = style
    }
}
