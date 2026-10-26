// Apps/Apple/Sources/TodoAppleUI/Foundations/ListTile.swift
import SwiftUI
import TodoCore

/// A list's tile: a rounded square of the colour's tile shade with the icon's glyph on it in the glyph shade. The sizes
/// are the caller's: 30 pt, radius 8 and glyph 19 at the root of the phone, 26, 7 and 16 nested, and 20, 6 and 13 in
/// the sidebar (`docs/specs/lists-screen.md`, section 9).
struct ListTile: View {
    private let shades: ListColorShades
    private let symbol: String
    private let size: CGFloat
    private let radius: CGFloat
    private let glyph: CGFloat

    init(color: TaskViewColor?, icon: String?, size: CGFloat, radius: CGFloat, glyph: CGFloat) {
        shades = ListColorShades.shades(of: color)
        symbol = IconSet.symbol(icon)
        self.size = size
        self.radius = radius
        self.glyph = glyph
    }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(shades.tile)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: glyph, weight: .medium))
                    .foregroundStyle(shades.glyph)
            }
            .accessibilityHidden(true)
    }
}
