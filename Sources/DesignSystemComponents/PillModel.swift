// Sources/DesignSystemComponents/PillModel.swift
import DesignSystem

/// One of an open card's pills, its day, its deadline or a tag (`Phone.dc.html`, `.xpill`): `height` high on
/// `background`, with corners of `cornerRadius`, half its height for a capsule, its glyph `leadingPadding` in from its
/// leading edge and `spacing` before its text, and the text `trailingPadding` short of its trailing edge, in points.
public struct PillModel: Equatable, Sendable {
    public let icon: IconModel
    public let text: TextModel
    public let background: DesignSystem.Color
    public let height: Double
    public let cornerRadius: Double
    public let leadingPadding: Double
    public let trailingPadding: Double
    public let spacing: Double

    public init(
        icon: IconModel,
        text: TextModel,
        background: DesignSystem.Color,
        height: Double,
        cornerRadius: Double,
        leadingPadding: Double,
        trailingPadding: Double,
        spacing: Double
    ) {
        self.icon = icon
        self.text = text
        self.background = background
        self.height = height
        self.cornerRadius = cornerRadius
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
        self.spacing = spacing
    }
}
