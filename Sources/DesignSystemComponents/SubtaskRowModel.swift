// Sources/DesignSystemComponents/SubtaskRowModel.swift
import DesignSystem

/// A subtask's row in an open card (`Phone.dc.html`, the card's subtasks): its check, then its title, struck through in
/// `strike` where the subtask is done, `height` high, in points. Its numbers and its `strike` are the fields of its
/// `SubtaskRowStyle`, as is the motion its title changes colour on.
public struct SubtaskRowModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let check: CheckModel<Action>

    /// The title, in its colour, the done colour where the subtask is done.
    public let title: TextModel

    public let style: SubtaskRowStyle

    public init(
        check: CheckModel<Action>,
        title: TextModel,
        style: SubtaskRowStyle
    ) {
        self.check = check
        self.title = title
        self.style = style
    }
}
