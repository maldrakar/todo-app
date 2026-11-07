// Sources/DesignSystemComponents/CardStyle.swift
import DesignSystem

/// The numbers a `CardModel` is drawn with, in points, and the card's background, shadow and entrance, which the
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

    /// How the card comes in as it opens in its row's place.
    public let entrance: EntranceStyle

    /// How far the subtasks, the row that adds one and the field of the one being typed stand outside the body's
    /// leading edge, so that their checks stand under the card's own.
    public let subtasksOutdent: Double

    /// How far the notes stand below the card's top row (`Phone.dc.html`, the notes' `margin`).
    public let titleToNotes: Double

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
        entrance: EntranceStyle,
        subtasksOutdent: Double,
        titleToNotes: Double,
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
        self.entrance = entrance
        self.subtasksOutdent = subtasksOutdent
        self.titleToNotes = titleToNotes
        self.notesToSubtasks = notesToSubtasks
        self.subtaskDraftCircle = subtaskDraftCircle
    }
}
