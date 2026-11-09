// Sources/DesignSystemComponents/GlassCapsuleStyle.swift
import DesignSystem

/// The capsule of glass that holds the Mac pane's "+" and "…" side by side (`Mac.dc.html`, the nav row's `.glass`
/// capsule), in points: `height` high with corners of `cornerRadius`, its items `horizontalPadding` in from its ends and
/// parted by a `divider` of `dividerHeight`. The glass is the capsule's: `surface` edged with `line` and casting
/// `shadow`, where a platform has none of its own, so its items draw none beside it, whatever their own
/// `GlassControlStyle` says.
///
/// `GlassCapsuleStyle` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
public struct GlassCapsuleStyle: Equatable, Sendable {
    public let height: Double
    public let cornerRadius: Double
    public let horizontalPadding: Double
    public let surface: DesignSystem.Color
    public let line: LineStyle
    public let shadow: DesignSystem.Shadow

    /// The rule between the items, whose width is how thick it is.
    public let divider: LineStyle
    public let dividerHeight: Double

    public init(
        height: Double,
        cornerRadius: Double,
        horizontalPadding: Double,
        surface: DesignSystem.Color,
        line: LineStyle,
        shadow: DesignSystem.Shadow,
        divider: LineStyle,
        dividerHeight: Double
    ) {
        self.height = height
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.surface = surface
        self.line = line
        self.shadow = shadow
        self.divider = divider
        self.dividerHeight = dividerHeight
    }
}
