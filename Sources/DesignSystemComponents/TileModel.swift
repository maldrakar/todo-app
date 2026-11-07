// Sources/DesignSystemComponents/TileModel.swift
import DesignSystem

/// A list's tile as every platform draws it: a rounded square in its colour's background, with the icon's glyph on it
/// in its colour's glyph colour (`docs/specs/lists-screen.md`, section 9). The model and its style hold every visual
/// parameter of the tile, so a platform's view draws it and decides nothing; the corners are circular, as the canvas's
/// `border-radius` draws them (ADR-0007, amendment of 2026-10-26). It is plain data: the colour, the icon and the sizes
/// are its caller's, the feature module that builds its screen's model and knows the layout the tile stands in. Its
/// colour, its sides and the size and weight of its glyph are the fields of its `TileStyle`.
///
/// `TileModel` was the module's first top-level name, probed free as `DesignSystem` was: unresolved in a file importing
/// SwiftUI, Foundation and Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-10-26). The names
/// beside it were probed the same way, fifteen on 2026-10-30, and `ButtonLabelModel`, `MenuButtonModel`,
/// `AccessoryModel` and `TextFieldModel`, the name `FieldModel` took, and later `FillModel`, now `ControlFillStyle`, on
/// 2026-10-31.
public struct TileModel: Equatable, Sendable {
    /// The glyph on the tile.
    public let icon: DesignSystem.Icon
    public let style: TileStyle

    public init(icon: DesignSystem.Icon, style: TileStyle) {
        self.icon = icon
        self.style = style
    }
}
