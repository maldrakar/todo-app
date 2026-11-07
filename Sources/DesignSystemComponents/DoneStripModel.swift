// Sources/DesignSystemComponents/DoneStripModel.swift
import DesignSystem

/// The Done strip at the end of the open list (`Phone.dc.html`, the Done strip; `Mac.dc.html`, the pane's): a capsule
/// `height` high on `background`, with corners of `cornerRadius`, its glyph `leadingPadding` in from its leading edge,
/// then its label and its chevron, each `spacing` after what stands before it, the chevron `trailingPadding` short of
/// its trailing edge; the capsule `topMargin` below the blocks and `leadingMargin` and `trailingMargin` in from the
/// sides, in points. The tasks done under it, while the strip is open, are the feature module's rows, each a row or the
/// open card, so the model holds none (list screen spec, section 3); they come in by `rowsEntrance`. Its numbers, its
/// `background` and that entrance are the fields of its `DoneStripStyle`.
///
/// A class, for the reason a list's row is one (`ListRowModel`): the screen's model holds one, every copy and
/// comparison of that model copies and compares it, and inline it is some 500 bytes on wasm32. Its `==` compares every
/// stored property, and a test changes them one at a time.
public final class DoneStripModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let icon: IconModel

    /// The label, finished, such as "Done today · 3".
    public let label: TextModel

    /// The chevron, which turns as the strip opens and closes.
    public let chevron: AccessoryModel<Action>.Chevron

    public let style: DoneStripStyle

    /// Whether the strip is open, which shows its rows and which VoiceOver reads.
    public let isOpen: Bool

    /// What a tap on the capsule sends.
    public let action: Action

    public init(
        icon: IconModel,
        label: TextModel,
        chevron: AccessoryModel<Action>.Chevron,
        style: DoneStripStyle,
        isOpen: Bool,
        action: Action
    ) {
        self.icon = icon
        self.label = label
        self.chevron = chevron
        self.style = style
        self.isOpen = isOpen
        self.action = action
    }

    public static func == (lhs: DoneStripModel, rhs: DoneStripModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.icon == rhs.icon
            && lhs.label == rhs.label
            && lhs.chevron == rhs.chevron
            && lhs.style == rhs.style
            && lhs.isOpen == rhs.isOpen
            && lhs.action == rhs.action
    }
}
