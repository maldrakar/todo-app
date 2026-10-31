// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Font+DesignSystem.swift
import DesignSystem
import SwiftUI

extension Font {
    /// A font of the look as the system font of its text style, which grows with the size a person sets (Dynamic
    /// Type).
    init(_ font: DesignSystem.Font) {
        self = .system(TextStyle(font.style), design: font.rounded ? .rounded : .default, weight: Weight(font.weight))
    }
}

extension Font.TextStyle {
    /// A text style of the look as SwiftUI's. The `switch` names every case with no `default`, so a style added to the
    /// look stops this compiling until it is drawn.
    fileprivate init(_ style: DesignSystem.Font.TextStyle) {
        self = switch style {
        case .largeTitle: .largeTitle
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .subheadline: .subheadline
        case .footnote: .footnote
        case .caption: .caption
        }
    }
}

extension Font.Weight {
    /// A weight of the look as SwiftUI's. The `switch` names every case with no `default`, so a weight added to the
    /// look stops this compiling until it is drawn.
    init(_ weight: DesignSystem.Font.Weight) {
        self = switch weight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
    }
}
