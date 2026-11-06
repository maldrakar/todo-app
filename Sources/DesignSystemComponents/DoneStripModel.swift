// Sources/DesignSystemComponents/DoneStripModel.swift
import DesignSystem

/// The Done strip at the end of the open list (`Phone.dc.html`, the Done strip; `Mac.dc.html`, the pane's): a capsule
/// `height` high on `background`, with corners of `cornerRadius`, its glyph `leadingPadding` in from its leading edge,
/// then its label and its chevron, each `spacing` after what stands before it, the chevron `trailingPadding` short of
/// its trailing edge; the capsule `topMargin` below the blocks and `leadingMargin` and `trailingMargin` in from the
/// sides, in points. The tasks done under it, while the strip is open, are the feature module's rows, each a row or the
/// open card, so the model holds none (list screen spec, section 3). Its numbers are the fields of its `Style`.
///
/// A class, for the reason a list's row is one (`ListRowModel`): the screen's model holds one, every copy and comparison of
/// that model copies and compares it, and inline it is some 500 bytes on wasm32. Its `==` compares every stored property,
/// and a test changes them one at a time.
public final class DoneStripModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The numbers the component is drawn with, in points, which a layout holds whole and a builder hands over as one
    /// value.
    public struct Style: Equatable, Sendable {
        public let height: Double
        public let cornerRadius: Double
        public let spacing: Double
        public let leadingPadding: Double
        public let trailingPadding: Double
        public let topMargin: Double
        public let leadingMargin: Double
        public let trailingMargin: Double

        public init(
            height: Double,
            cornerRadius: Double,
            spacing: Double,
            leadingPadding: Double,
            trailingPadding: Double,
            topMargin: Double,
            leadingMargin: Double,
            trailingMargin: Double
        ) {
            self.height = height
            self.cornerRadius = cornerRadius
            self.spacing = spacing
            self.leadingPadding = leadingPadding
            self.trailingPadding = trailingPadding
            self.topMargin = topMargin
            self.leadingMargin = leadingMargin
            self.trailingMargin = trailingMargin
        }
    }

    public let icon: IconModel

    /// The label, finished, such as "Done today · 3".
    public let label: TextModel

    /// The chevron, which turns as the strip opens and closes.
    public let chevron: AccessoryModel<Action>.Chevron

    public let background: DesignSystem.Color
    public let style: Style

    /// Whether the strip is open, which shows its rows and which VoiceOver reads.
    public let isOpen: Bool

    /// What a tap on the capsule sends.
    public let action: Action

    public init(
        icon: IconModel,
        label: TextModel,
        chevron: AccessoryModel<Action>.Chevron,
        background: DesignSystem.Color,
        style: Style,
        isOpen: Bool,
        action: Action
    ) {
        self.icon = icon
        self.label = label
        self.chevron = chevron
        self.background = background
        self.style = style
        self.isOpen = isOpen
        self.action = action
    }

    public static func == (lhs: DoneStripModel, rhs: DoneStripModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.icon == rhs.icon
            && lhs.label == rhs.label
            && lhs.chevron == rhs.chevron
            && lhs.background == rhs.background
            && lhs.style == rhs.style
            && lhs.isOpen == rhs.isOpen
            && lhs.action == rhs.action
    }
}
