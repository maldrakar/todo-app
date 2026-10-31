// Sources/FeatureModule/WindowCapabilities.swift

/// What the platform of a window offers that a module builds its model by, which the window's view reads once when the
/// window is made and hands the root as it hands the width class, so that the policy is the host's
/// (`docs/style.md`, "A lower layer holds no policy of its client"): whether a window can open beside this one, which
/// Open in New Window needs (`docs/specs/navigation.md`, section 5), and whether the platform has edit mode, the
/// phone's and the iPad's way of editing the Lists screen's tree, which the Mac does without, its rows dragged at any
/// time (Lists screen spec, sections 7 and 8). Neither changes while the app runs, so no event moves them.
///
/// Here and not in the root, because the root is made with them and hands them to the sidebar, as it does the width
/// (`WindowWidth`). Two facts in one value, so that the second does not become a second `Bool` threaded through every
/// `init` the way the first was (Lists screen plan, Task 9; the final review of #161).
///
/// Probed free as `WindowWidth` was: unresolved in a file importing SwiftUI, Foundation and Observation for macOS 14,
/// iOS 17 and watchOS 10 with Xcode 27.1 (2026-10-31).
public struct WindowCapabilities: Equatable, Sendable {
    /// Whether a window can open beside this one: SwiftUI's `supportsMultipleWindows`, true on the Mac and on the iPad.
    public let opensWindowsBeside: Bool

    /// Whether the platform has edit mode, false on the Mac alone.
    public let hasEditMode: Bool

    public init(opensWindowsBeside: Bool, hasEditMode: Bool) {
        self.opensWindowsBeside = opensWindowsBeside
        self.hasEditMode = hasEditMode
    }
}
