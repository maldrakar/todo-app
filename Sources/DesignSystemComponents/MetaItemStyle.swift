// Sources/DesignSystemComponents/MetaItemStyle.swift
import DesignSystem

/// The gap between a `MetaItemModel`'s glyph and its text, in points, and the capsule it stands on, which a builder
/// hands over as one value.
public struct MetaItemStyle: Equatable, Sendable {
    /// The capsule under an item, `height` high on `background`, with corners of `cornerRadius`, half its height for a
    /// capsule, the item `leadingPadding` in from its leading edge and `trailingPadding` short of its trailing one, in
    /// points, as a pill is: the Mac draws a tag on one (`Mac.dc.html`, the row's tag), where the phone writes it out
    /// as "#home".
    public struct Capsule: Equatable, Sendable {
        public let background: DesignSystem.Color
        public let height: Double
        public let cornerRadius: Double
        public let leadingPadding: Double
        public let trailingPadding: Double

        public init(
            background: DesignSystem.Color, height: Double, cornerRadius: Double, leadingPadding: Double,
            trailingPadding: Double
        ) {
            self.background = background
            self.height = height
            self.cornerRadius = cornerRadius
            self.leadingPadding = leadingPadding
            self.trailingPadding = trailingPadding
        }
    }

    public let spacing: Double

    /// The capsule the item stands on, and nil for an item that stands on the row.
    public let capsule: Capsule?

    public init(spacing: Double, capsule: Capsule?) {
        self.spacing = spacing
        self.capsule = capsule
    }
}
