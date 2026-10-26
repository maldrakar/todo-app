// Sources/DesignSystem/DesignSystem.swift

/// The look's design decisions as values: the colours, the list colours' bases, the type, the motion and the icons
/// (`docs/specs/lists-screen.md`, section 9). Each is a static member of its own type, the way SwiftUI has
/// `Color.red`: `DesignSystem.Color.sidebar`, `DesignSystem.Font.rowTitle(depth:hasChildren:)`,
/// `DesignSystem.Animation.popover`, `DesignSystem.Icon.sun`, and where a call site expects the type the prefix goes,
/// as in a SwiftUI view's `Color(.sidebar)`. Nothing here is a platform's: each platform turns these values into its
/// own colours, fonts, animations and glyphs, and its views take every one of them from here. Nothing here knows the
/// domain either, so the module depends on nothing, and what a component makes of these decisions, such as a list's
/// tile, is `DesignSystemComponents`' (ADR-0007, amendment of 2026-10-26).
///
/// Every type of the module is nested in this enum, so its one top-level name is `DesignSystem` and none of its names
/// shadows one a consumer's modules own, such as SwiftUI's `Color`, `Font` and `Animation`. `DesignSystem` itself was
/// probed free in a file importing SwiftUI, Foundation and Observation for macOS 14, iOS 17 and watchOS 10 with
/// Xcode 27.1 (2026-10-26).
public enum DesignSystem {}
