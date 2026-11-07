// Sources/DesignSystemComponents/PillModel.swift
import DesignSystem

/// One of an open card's pills, its day, its deadline or a tag (`Phone.dc.html`, `.xpill`): `height` high on
/// `background`, with corners of `cornerRadius`, half its height for a capsule, its glyph `leadingPadding` in from its
/// leading edge and `spacing` before its text, and the text `trailingPadding` short of its trailing edge, in points.
/// Its numbers and its `background` are the fields of its `PillStyle`.
public struct PillModel: Equatable, Sendable {
    public let icon: IconModel
    public let text: TextModel
    public let style: PillStyle

    public init(
        icon: IconModel,
        text: TextModel,
        style: PillStyle
    ) {
        self.icon = icon
        self.text = text
        self.style = style
    }
}
