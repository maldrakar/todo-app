// Sources/DesignSystemComponents/ChevronStyle.swift
import DesignSystem

/// How an accessory's chevron is turned and moved, which a builder hands over as one value: its glyph turned by
/// `rotation` degrees, clockwise when positive, as CSS and SwiftUI turn, moving to a new turn on `animation`.
public struct ChevronStyle: Equatable, Sendable {
    public let rotation: Double
    public let animation: DesignSystem.Animation

    public init(rotation: Double, animation: DesignSystem.Animation) {
        self.rotation = rotation
        self.animation = animation
    }
}
