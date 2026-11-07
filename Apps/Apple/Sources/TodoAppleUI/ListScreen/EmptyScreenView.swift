// Apps/Apple/Sources/TodoAppleUI/ListScreen/EmptyScreenView.swift
import DesignSystemComponents
import SwiftUI

/// What a list with nothing to draw shows as its model describes it (`EmptyScreenModel`; `Phone.dc.html`, the list
/// screen's empty state): its tile, its title and the line that says what to do, centred.
struct EmptyScreenView: View {
    private let model: EmptyScreenModel

    init(_ model: EmptyScreenModel) {
        self.model = model
    }

    var body: some View {
        VStack(spacing: 0) {
            ListTile(model.tile)
            Text(model.title)
                .multilineTextAlignment(.center)
                .padding(.top, model.style.tileToTitle)
            Text(model.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: model.style.maxWidth)
                .padding(.top, model.style.titleToText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, model.style.topPadding)
        .padding(.horizontal, model.style.horizontalPadding)
    }
}
