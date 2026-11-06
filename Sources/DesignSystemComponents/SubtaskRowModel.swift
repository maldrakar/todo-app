// Sources/DesignSystemComponents/SubtaskRowModel.swift
import DesignSystem

/// A subtask's row in an open card (`Phone.dc.html`, the card's subtasks): its check, then its title, struck through in
/// `strike` where the subtask is done, `height` high, in points. Its numbers are the fields of its `Style`.
public struct SubtaskRowModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The numbers the component is drawn with, in points, which a layout holds whole and a builder hands over as one
    /// value.
    public struct Style: Equatable, Sendable {
        public let height: Double

        public init(height: Double) {
            self.height = height
        }
    }

    public let check: CheckModel<Action>

    /// The title, in its colour, the done colour where the subtask is done.
    public let title: TextModel

    /// The colour of the line through the title, the canvas's ink 3 through a done subtask's, and nil for a title with
    /// no line through it.
    public let strike: DesignSystem.Color?

    public let style: Style

    public init(
        check: CheckModel<Action>,
        title: TextModel,
        strike: DesignSystem.Color?,
        style: Style
    ) {
        self.check = check
        self.title = title
        self.strike = strike
        self.style = style
    }
}
