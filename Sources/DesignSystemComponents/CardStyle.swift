// Sources/DesignSystemComponents/CardStyle.swift
import DesignSystem

/// The numbers a `CardModel` is drawn with, in points, and the card's background, shadow and animation, which the
/// layout knows whole and a builder hands over as one value.
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
    public let background: DesignSystem.Color
    public let animation: DesignSystem.Animation

    /// How far the subtasks, the row that adds one and the field of the one being typed stand outside the body's
    /// leading edge, so that their checks stand under the card's own.
    public let subtasksOutdent: Double

    /// How far the subtasks stand below the notes.
    public let notesToSubtasks: Double

    /// The circle before the field of the subtask being typed: a check's ring in the list's colour and nothing in it,
    /// the shape of a subtask's check with no task yet to mark.
    public let subtaskDraftCircle: CheckStyle

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
        shadow: DesignSystem.Shadow,
        background: DesignSystem.Color,
        animation: DesignSystem.Animation,
        subtasksOutdent: Double,
        notesToSubtasks: Double,
        subtaskDraftCircle: CheckStyle
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
        self.background = background
        self.animation = animation
        self.subtasksOutdent = subtasksOutdent
        self.notesToSubtasks = notesToSubtasks
        self.subtaskDraftCircle = subtaskDraftCircle
    }
}
