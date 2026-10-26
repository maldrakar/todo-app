// Sources/DesignSystemComponents/TileModel.swift
import DesignSystem

/// A list's tile as every platform draws it: a rounded square in the tile shade of the list's colour, with the icon's
/// glyph on it in the glyph shade, at the sizes its placement calls for (`docs/specs/lists-screen.md`, section 9).
/// The model holds every visual parameter of the tile, so a platform's view draws it and decides nothing; the
/// corners are circular, as the canvas's `border-radius` draws them (ADR-0007, amendment of 2026-10-26).
///
/// `TileModel` is the module's one top-level name so far, probed free as `DesignSystem` was: unresolved in a file
/// importing SwiftUI, Foundation and Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-10-26).
public struct TileModel: Equatable, Sendable {
    /// Where the tile sits, which sets its sizes: in a row of the tree at a depth, or in a row of the sidebar.
    public enum Placement: Sendable { case row(depth: Int), sidebar }

    /// The glyph on the tile: its icon, `nil` for the platform's default glyph, in its colour, size and weight.
    public struct Glyph: Equatable, Sendable {
        public let icon: DesignSystem.Icon?
        public let color: DesignSystem.Color
        public let size: Double
        public let weight: DesignSystem.Font.Weight
    }

    /// The length of the tile's side and the radius of its corners, in points.
    public let side: Double
    public let cornerRadius: Double

    /// The tile's own colour, behind the glyph.
    public let color: DesignSystem.Color
    public let glyph: Glyph

    /// A list's tile from its colour and icon, which the caller reads from the store's names, and where it sits. A
    /// list with no colour draws stone's.
    public init(color: DesignSystem.ListColor?, icon: DesignSystem.Icon?, placement: Placement) {
        // The canvas's sizes: the root of the phone's tree and a nested row (`Phone.dc.html`, `tileSize`), and the
        // sidebar's 30 pt row (`Mac.dc.html`). A depth at or below zero reads as the root's, one comparison and no
        // trap, since a depth a view sends is never trusted.
        let glyphSize: Double
        (side, cornerRadius, glyphSize) = switch placement {
        case .row(let depth) where depth > 0: (26, 7, 16)
        case .row: (30, 8, 19)
        case .sidebar: (20, 6, 13)
        }
        // The canvas's `paint` rule (`Phone.dc.html`): the tile is the base at 15 % opacity in the light and 24 % in
        // the dark, and the glyph is the base mixed 20 % toward the ink in the light and 30 % toward white in the dark.
        let base = (color ?? .stone).base
        self.color = DesignSystem.Color(light: base.withOpacity(0.15), dark: base.withOpacity(0.24))
        glyph = Glyph(
            icon: icon,
            color: DesignSystem.Color(
                light: base.mixed(toward: DesignSystem.Color.ink.light, by: 0.2),
                dark: base.mixed(toward: .white, by: 0.3)),
            size: glyphSize,
            weight: .medium)
    }
}
