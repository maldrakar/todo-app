// Sources/DesignSystemComponents/CardHoverStyle.swift
import DesignSystem

/// What a column's card casts while the pointer is over it, as the canvas's `.card:hover` deepens its shadow
/// (`Mac.dc.html`): `shadow` in place of the card's resting one, coming and going on `animation`. A column's style
/// holds one where a pointer can be over its cards, the pane's, and none on the phone, which has no pointer; the card
/// casts a shadow where a row is tinted (`HoverStyle`).
///
/// `CardHoverStyle` was probed free as `HoverStyle` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
public struct CardHoverStyle: Equatable, Sendable {
    public let shadow: DesignSystem.Shadow
    public let animation: DesignSystem.Animation

    public init(shadow: DesignSystem.Shadow, animation: DesignSystem.Animation) {
        self.shadow = shadow
        self.animation = animation
    }
}
