// Apps/Apple/Sources/TodoAppleUI/DesignSystem/ListTile.swift
import DesignSystemComponents
import SwiftUI

/// A list's tile as its model describes it: a rounded square of the tile's colour with the glyph on it, every size,
/// colour and weight the model's (`TileModel`), so the view adds no visual choice of its own. The caller builds the
/// model from the row's colour and icon names and where the tile sits (`docs/specs/lists-screen.md`, section 9).
struct ListTile: View {
    private let model: TileModel

    init(_ model: TileModel) {
        self.model = model
    }

    var body: some View {
        // Circular corners, as the canvas's `border-radius` draws them and the model's radius describes; SwiftUI's
        // default is the continuous style (Xcode 27.1's SDKs), so the circular one is named.
        RoundedRectangle(cornerRadius: model.cornerRadius, style: .circular)
            .fill(Color(model.color))
            .frame(width: model.side, height: model.side)
            .overlay {
                Image(model.glyph.icon)
                    .font(.system(size: model.glyph.size, weight: Font.Weight(model.glyph.weight)))
                    .foregroundStyle(Color(model.glyph.color))
            }
    }
}
