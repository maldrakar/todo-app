// Sources/DesignSystemComponents/DoneStripModel.swift
import DesignSystem

/// The Done strip at the end of the open list (`Phone.dc.html`, the Done strip; `Mac.dc.html`, the pane's): a capsule
/// `height` high on `background`, with corners of `cornerRadius`, its glyph `leadingPadding` in from its leading edge,
/// then its label and its chevron, each `spacing` after what stands before it, the chevron `trailingPadding` short of
/// its trailing edge; the capsule `topMargin` below the blocks and `leadingMargin` and `trailingMargin` in from the
/// sides; and under it, while the strip is open, the tasks done, in points.
public struct DoneStripModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let icon: IconModel

    /// The label, finished, such as "Done · 3".
    public let label: TextModel

    /// The chevron, which turns as the strip opens and closes.
    public let chevron: AccessoryModel<Action>.Chevron

    public let background: DesignSystem.Color
    public let height: Double
    public let cornerRadius: Double
    public let spacing: Double
    public let leadingPadding: Double
    public let trailingPadding: Double
    public let topMargin: Double
    public let leadingMargin: Double
    public let trailingMargin: Double

    /// Whether the strip is open, which shows its rows and which VoiceOver reads.
    public let isOpen: Bool

    /// The tasks done, as rows, struck, in the order they stand under the capsule while the strip is open.
    public let rows: [TaskRowModel<Action>]

    /// What a tap on the capsule sends.
    public let action: Action

    public init(
        icon: IconModel,
        label: TextModel,
        chevron: AccessoryModel<Action>.Chevron,
        background: DesignSystem.Color,
        height: Double,
        cornerRadius: Double,
        spacing: Double,
        leadingPadding: Double,
        trailingPadding: Double,
        topMargin: Double,
        leadingMargin: Double,
        trailingMargin: Double,
        isOpen: Bool,
        rows: [TaskRowModel<Action>],
        action: Action
    ) {
        self.icon = icon
        self.label = label
        self.chevron = chevron
        self.background = background
        self.height = height
        self.cornerRadius = cornerRadius
        self.spacing = spacing
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
        self.topMargin = topMargin
        self.leadingMargin = leadingMargin
        self.trailingMargin = trailingMargin
        self.isOpen = isOpen
        self.rows = rows
        self.action = action
    }
}
