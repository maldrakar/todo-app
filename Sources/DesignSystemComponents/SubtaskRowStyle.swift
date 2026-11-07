// Sources/DesignSystemComponents/SubtaskRowStyle.swift
import DesignSystem

/// The numbers a `SubtaskRowModel` is drawn with, in points, and the line through its title, which a builder hands over
/// as one value. The line goes with whether the subtask is open, so a done one is another instance.
public struct SubtaskRowStyle: Equatable, Sendable {
    public let height: Double

    /// The colour of the line through the title, the canvas's ink 3 through a done subtask's, and nil for a title with
    /// no line through it.
    public let strike: DesignSystem.Color?

    public init(height: Double, strike: DesignSystem.Color?) {
        self.height = height
        self.strike = strike
    }
}
