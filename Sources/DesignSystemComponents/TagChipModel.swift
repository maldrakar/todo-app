// Sources/DesignSystemComponents/TagChipModel.swift
import DesignSystem

/// A tag's chip on the tag bar (`Phone.dc.html`, `.chip` in its `.tchip`): `height` high on `background`, with corners
/// of `cornerRadius`, half its height for a capsule, its glyph `leadingPadding` in from its leading edge and `spacing`
/// before its title, and the title `trailingPadding` short of its trailing edge, in a tap area `hitHeight` high, in
/// points. A lit chip, whose tag is picked, is drawn in the colours it is given, the list's check fill and mark, and an
/// unlit one in the fill and the inks. Its numbers are the fields of its `Style`.
public struct TagChipModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The numbers the component is drawn with, in points, which a layout holds whole and a builder hands over as one
    /// value.
    public struct Style: Equatable, Sendable {
        public let height: Double
        public let cornerRadius: Double
        public let leadingPadding: Double
        public let trailingPadding: Double
        public let spacing: Double
        public let hitHeight: Double

        public init(
            height: Double,
            cornerRadius: Double,
            leadingPadding: Double,
            trailingPadding: Double,
            spacing: Double,
            hitHeight: Double
        ) {
            self.height = height
            self.cornerRadius = cornerRadius
            self.leadingPadding = leadingPadding
            self.trailingPadding = trailingPadding
            self.spacing = spacing
            self.hitHeight = hitHeight
        }
    }

    public let icon: IconModel
    public let title: TextModel
    public let background: DesignSystem.Color
    public let style: Style

    /// Whether the chip's tag is picked, which its colours already show and VoiceOver reads.
    public let isLit: Bool

    /// What a tap on the chip sends.
    public let action: Action

    public init(
        icon: IconModel,
        title: TextModel,
        background: DesignSystem.Color,
        style: Style,
        isLit: Bool,
        action: Action
    ) {
        self.icon = icon
        self.title = title
        self.background = background
        self.style = style
        self.isLit = isLit
        self.action = action
    }
}
