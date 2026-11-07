// Sources/DesignSystemComponents/TagChipModel.swift
import DesignSystem

/// A tag's chip on the tag bar (`Phone.dc.html`, `.chip` in its `.tchip`): `height` high on `background`, with corners
/// of `cornerRadius`, half its height for a capsule, its glyph `leadingPadding` in from its leading edge and `spacing`
/// before its title, and the title `trailingPadding` short of its trailing edge, in a tap area `hitHeight` high, in
/// points. A lit chip, whose tag is picked, is drawn in the colours it is given, the list's check fill and mark, and an
/// unlit one in the fill and the inks, moving between the two on `animation`. Its numbers, its `background` and its
/// `animation` are the fields of its `TagChipStyle`.
public struct TagChipModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let icon: IconModel
    public let title: TextModel
    public let style: TagChipStyle

    /// Whether the chip's tag is picked, which its colours already show and VoiceOver reads.
    public let isLit: Bool

    /// What a tap on the chip sends.
    public let action: Action

    public init(
        icon: IconModel,
        title: TextModel,
        style: TagChipStyle,
        isLit: Bool,
        action: Action
    ) {
        self.icon = icon
        self.title = title
        self.style = style
        self.isLit = isLit
        self.action = action
    }
}
