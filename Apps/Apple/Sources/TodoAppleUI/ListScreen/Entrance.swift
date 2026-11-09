// Apps/Apple/Sources/TodoAppleUI/ListScreen/Entrance.swift
import DesignSystemComponents
import SwiftUI

/// A view coming in when it first appears, as its style describes it (`EntranceStyle`), and at rest from the first
/// where a person asked for less motion. It plays on appearing and not as a transition, so that it needs no animation
/// of the change that brought the view in, which a tap on a row, opening a card in its place, does not have.
struct Entrance: ViewModifier {
    private let style: EntranceStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAtRest = false

    init(_ style: EntranceStyle) {
        self.style = style
    }

    func body(content: Content) -> some View {
        let atRest = isAtRest || reduceMotion
        content
            .opacity(atRest ? 1 : style.opacity)
            .scaleEffect(atRest ? 1 : style.scale, anchor: UnitPoint(x: style.anchorX, y: style.anchorY))
            .offset(y: atRest ? 0 : style.offset)
            .onAppear {
                withAnimation(Animation(style.animation)) { isAtRest = true }
            }
    }
}
