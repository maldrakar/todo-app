// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Text+DesignSystemComponents.swift
import DesignSystemComponents
import SwiftUI

extension Text {
    /// A text as its model describes it: its words as its builder finished them, drawn verbatim, in the model's font
    /// and colour (`TextModel`), so the view formats nothing and picks neither.
    init(_ model: TextModel) {
        self = Text(model.text).font(Font(model.font)).foregroundStyle(Color(model.color))
    }
}
