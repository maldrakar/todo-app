// Sources/DesignSystem/DesignSystem.swift

/// The look of the app as values, one entry point for all of it: `DesignSystem.color.sidebar`,
/// `DesignSystem.font.rowTitle(depth:hasChildren:)`, `DesignSystem.motion.popover` (`docs/specs/lists-screen.md`,
/// section 9). Nothing here is a platform's: each platform turns these values into its own colours, fonts,
/// animations and glyphs, and its views take every one of them from here (ADR-0007, amendment of 2026-10-26).
///
/// Every type of the module is nested in this enum, so its one top-level name is `DesignSystem` and none of its names
/// shadows one a consumer's modules own, such as SwiftUI's `Color`, `Font` and `Animation`. `DesignSystem` itself was
/// probed free in a file importing SwiftUI, Foundation and Observation for macOS 14, iOS 17 and watchOS 10 with
/// Xcode 27.1 (2026-10-26).
public enum DesignSystem {
    public static let color = Palette()
    public static let font = Typography()
    public static let motion = Motion()
}
