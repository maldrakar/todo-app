// Sources/DesignSystemComponents/CheckModel.swift
import DesignSystem

/// A task's check, or a subtask's, as every platform draws it (`Phone.dc.html`, `.cb` in its `.cbh`): a circle
/// `diameter` across, its ring `ringWidth` thick, centred in a tap area `hitWidth` wide and `hitHeight` high, and on it
/// the mark, the canvas's drawn tick, `markSize` across and stroked `markStrokeWidth` thick, in points. An open check
/// draws its colours' ring and is clear inside; a checked one draws their fill as its ring and inside it, with the mark
/// on the fill, and pops on `animation` as it is checked (ADR-0007, amendment of 2026-10-30). Its numbers are the
/// fields of its `CheckStyle`.
public struct CheckModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let style: CheckStyle

    /// The ring, the fill and the mark in the colour of the list the task is drawn in.
    public let colors: DesignSystem.Color.Components.Check

    /// Whether the task is done, or being completed, which the check draws and VoiceOver reads.
    public let isChecked: Bool

    public let animation: DesignSystem.Animation

    /// The words the check reads aloud, which say what a tap on it will do.
    public let accessibilityLabel: String

    /// What a tap on the check sends.
    public let action: Action

    public init(
        style: CheckStyle,
        colors: DesignSystem.Color.Components.Check,
        isChecked: Bool,
        animation: DesignSystem.Animation,
        accessibilityLabel: String,
        action: Action
    ) {
        self.style = style
        self.colors = colors
        self.isChecked = isChecked
        self.animation = animation
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
}
