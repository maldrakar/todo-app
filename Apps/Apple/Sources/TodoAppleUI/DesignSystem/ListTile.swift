// Apps/Apple/Sources/TodoAppleUI/DesignSystem/ListTile.swift
import DesignSystem
import SwiftUI
import TodoCore

/// A list's tile: a rounded square of the colour's tile shade with the icon's glyph on it in the glyph shade. The
/// colour and the icon are the row's as the store holds them, and the sizes are the caller's: 30 pt, radius 8 and
/// glyph 19 at the root of the phone, 26, 7 and 16 nested, and 20, 6 and 13 in the sidebar
/// (`docs/specs/lists-screen.md`, section 9).
struct ListTile: View {
    private let colors: DesignSystem.TileColors
    private let icon: DesignSystem.IconSet?
    private let size: CGFloat
    private let radius: CGFloat
    private let glyph: CGFloat

    init(color: TaskViewColor?, icon: String?, size: CGFloat, radius: CGFloat, glyph: CGFloat) {
        colors = DesignSystem.color.list(color)
        self.icon = icon.flatMap(DesignSystem.IconSet.init(rawValue:))
        self.size = size
        self.radius = radius
        self.glyph = glyph
    }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color(colors.tile))
            .frame(width: size, height: size)
            .overlay {
                Image(icon)
                    .font(.system(size: glyph, weight: Font.Weight(DesignSystem.font.tileGlyphWeight)))
                    .foregroundStyle(Color(colors.glyph))
            }
    }
}
