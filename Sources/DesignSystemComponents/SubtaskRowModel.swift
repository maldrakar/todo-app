// Sources/DesignSystemComponents/SubtaskRowModel.swift
import DesignSystem

/// A subtask's row in an open card (`Phone.dc.html`, the card's subtasks): its check, then its title, struck through
/// where the subtask is done, `height` high, in points.
public struct SubtaskRowModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let check: CheckModel<Action>

    /// The title, in its colour, the done colour where the subtask is done.
    public let title: TextModel

    /// Whether a line is drawn through the title, as it is through a done subtask's.
    public let isStruck: Bool

    public let height: Double

    public init(check: CheckModel<Action>, title: TextModel, isStruck: Bool, height: Double) {
        self.check = check
        self.title = title
        self.isStruck = isStruck
        self.height = height
    }
}
