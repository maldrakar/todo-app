// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Glyph.swift
import DesignSystemComponents
import SwiftUI

/// A glyph outside a tile as its model describes it: the icon's symbol at the model's size and weight in its colour,
/// every value the model's (`IconModel`), so the view adds no visual choice of its own. Its size is in points and stays
/// as it is at every text size, as the model's does.
///
/// `Glyph` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and Observation
/// for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-10-30).
struct Glyph: View {
    private let model: IconModel

    init(_ model: IconModel) {
        self.model = model
    }

    var body: some View {
        Image(model.icon)
            .font(.system(size: model.size, weight: Font.Weight(model.weight)))
            .foregroundStyle(Color(model.color))
    }
}
