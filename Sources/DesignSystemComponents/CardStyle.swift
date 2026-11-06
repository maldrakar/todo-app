// Sources/DesignSystemComponents/CardStyle.swift
import DesignSystem

/// The numbers a `CardModel` is drawn with, in points, and the card's shadow, which the layout knows whole and a
/// builder hands over as one value.
public struct CardStyle: Equatable, Sendable {
    public let expandHitSide: Double
    public let cornerRadius: Double
    public let topMargin: Double
    public let horizontalMargin: Double
    public let bottomMargin: Double
    public let bodyLeading: Double
    public let bodyTrailing: Double
    public let bodyBottom: Double
    public let subtasksToPills: Double
    public let pillSpacing: Double
    public let shadow: DesignSystem.Shadow

    public init(
        expandHitSide: Double,
        cornerRadius: Double,
        topMargin: Double,
        horizontalMargin: Double,
        bottomMargin: Double,
        bodyLeading: Double,
        bodyTrailing: Double,
        bodyBottom: Double,
        subtasksToPills: Double,
        pillSpacing: Double,
        shadow: DesignSystem.Shadow
    ) {
        self.expandHitSide = expandHitSide
        self.cornerRadius = cornerRadius
        self.topMargin = topMargin
        self.horizontalMargin = horizontalMargin
        self.bottomMargin = bottomMargin
        self.bodyLeading = bodyLeading
        self.bodyTrailing = bodyTrailing
        self.bodyBottom = bodyBottom
        self.subtasksToPills = subtasksToPills
        self.pillSpacing = pillSpacing
        self.shadow = shadow
    }
}
