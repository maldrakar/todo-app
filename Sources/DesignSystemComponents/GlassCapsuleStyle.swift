// Sources/DesignSystemComponents/GlassCapsuleStyle.swift
import DesignSystem

/// The capsule of glass that holds the Mac pane's "+" and "…" side by side (`Mac.dc.html`, the nav row's `.glass`
/// capsule), in points: `height` high with corners of `cornerRadius`, its items `horizontalPadding` in from its ends
/// and parted by a `divider` of `dividerHeight`. Its glass, the surface, the hairline and the shadow, is its items' own
/// `GlassControlStyle`, the same on both and on the back button, held once there: a platform draws it round the capsule
/// and none round each item.
///
/// `GlassCapsuleStyle` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
public struct GlassCapsuleStyle: Equatable, Sendable {
    public let height: Double
    public let cornerRadius: Double
    public let horizontalPadding: Double
    /// The rule between the items, whose width is how thick it is.
    public let divider: LineStyle
    public let dividerHeight: Double

    public init(
        height: Double,
        cornerRadius: Double,
        horizontalPadding: Double,
        divider: LineStyle,
        dividerHeight: Double
    ) {
        self.height = height
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.divider = divider
        self.dividerHeight = dividerHeight
    }
}
