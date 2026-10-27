// Sources/FeatureModule/WindowWidth.swift

/// The width class of a window, which only its view can know and which it reports without deciding anything by it
/// (`docs/style.md`, "Views"; navigation state spec, section 4): narrow, iPhone's and a narrow iPad window, and wide,
/// the Mac's and a wide iPad window.
///
/// Here and not in the root, because the root and the sidebar read the same value: the root cuts the window's layout
/// by it, and the sidebar builds its rows' tiles and title fonts for it (`docs/specs/lists-screen.md`, sections 8 and
/// 9). A child never imports the root (ADR-0007), so a class the root owned would have to be mapped onto a second enum
/// of the sidebar's with the same two cases, two statements where one does (`docs/style.md`, "One shape everywhere it
/// fits"; ADR-0007, amendment of 2026-10-27).
///
/// Probed free as `TileModel` was: unresolved in a file importing SwiftUI, Foundation and Observation, with AppKit on
/// the Mac and UIKit on iOS, for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-10-27).
public enum WindowWidth: Equatable, Sendable {
    case narrow
    case wide
}
