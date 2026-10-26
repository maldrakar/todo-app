// Apps/Apple/Sources/TodoAppleUI/DesignSystem/ListTile.swift
import DesignSystemComponents
import SwiftUI

/// A list's tile as its model describes it: a rounded square in its colour's background with the glyph on it in its
/// colour's glyph colour, every size, colour and weight the model's (`TileModel`), so the view adds no visual choice of
/// its own. The model arrives built by the feature module of the screen the tile stands in, at the sizes that screen
/// calls for (`docs/specs/lists-screen.md`, section 9; ADR-0007, amendment of 2026-10-26).
struct ListTile: View {
    private let model: TileModel

    init(_ model: TileModel) {
        self.model = model
    }

    var body: some View {
        // Circular corners, as the canvas's `border-radius` draws them and the model's radius describes; SwiftUI's
        // default is the continuous style (Xcode 27.1's SDKs), so the circular one is named.
        RoundedRectangle(cornerRadius: model.cornerRadius, style: .circular)
            .fill(Color(model.color.background))
            .frame(width: model.side, height: model.side)
            .overlay {
                Image(model.glyph.icon)
                    .font(.system(size: model.glyph.size, weight: Font.Weight(model.glyph.weight)))
                    .foregroundStyle(Color(model.color.glyph))
            }
    }
}
