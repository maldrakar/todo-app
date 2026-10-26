// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Font+DesignSystem.swift
import DesignSystem
import SwiftUI

extension Font {
    /// A font of the look as the system font of its text style, which grows with the size a person sets (Dynamic
    /// Type). Each `switch` below names every case with no `default`, so a style or a weight added to the look stops
    /// this compiling until it is drawn.
    init(_ font: DesignSystem.Font) {
        self = .system(Self.style(font.style), design: font.rounded ? .rounded : .default, weight: Self.weight(font.weight))
    }

    private static func style(_ style: DesignSystem.Font.TextStyle) -> TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .subheadline: .subheadline
        case .caption: .caption
        }
    }

    private static func weight(_ weight: DesignSystem.Font.Weight) -> Weight {
        switch weight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .heavy: .heavy
        }
    }
}
