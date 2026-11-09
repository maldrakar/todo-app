// Sources/DesignSystemComponents/TagChipStyle.swift
import DesignSystem

/// The numbers a `TagChipModel` is drawn with, in points, and its background, which a builder hands over as one value.
/// The background is the list's while the chip is lit, so a lit chip is another instance.
public struct TagChipStyle: Equatable, Sendable {
    public let height: Double
    public let cornerRadius: Double
    public let leadingPadding: Double
    public let trailingPadding: Double
    public let spacing: Double
    public let hitHeight: Double
    public let background: DesignSystem.Color

    /// The motion the chip's colours change on as it lights and goes out.
    public let animation: DesignSystem.Animation

    /// The tint over the chip while the pointer is over it, and nil where there is no pointer to be, the phone's.
    public let hover: HoverStyle?

    public init(
        height: Double,
        cornerRadius: Double,
        leadingPadding: Double,
        trailingPadding: Double,
        spacing: Double,
        hitHeight: Double,
        background: DesignSystem.Color,
        animation: DesignSystem.Animation,
        hover: HoverStyle?
    ) {
        self.height = height
        self.cornerRadius = cornerRadius
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
        self.spacing = spacing
        self.hitHeight = hitHeight
        self.background = background
        self.animation = animation
        self.hover = hover
    }
}
