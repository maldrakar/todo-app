// Sources/DesignSystemComponents/TaskLiftModel.swift
import DesignSystem

/// How a task looks while it is lifted to be moved (`Phone.dc.html`, `.tlift` and the drop's slot): grown to `scale`
/// and drawn at `opacity`, on `background` with corners of `cornerRadius`, casting `shadow`; and `indicator`, the mark
/// of the place where it would land, placed from the rows' leading edge. The lift itself, which task is lifted and
/// where the mark stands, is the platform's, since only the platform has the finger or the pointer; this is its look,
/// as `DragModel` is a tree's.
public struct TaskLiftModel: Equatable, Sendable {
    public let scale: Double

    /// How opaque the lifted task is drawn, from 0 to 1: a row lifts whole, at 1, and a column's card dims to 0.35
    /// where it is dragged from (`Phone.dc.html`, the dragged card's `opacity`).
    public let opacity: Double

    public let cornerRadius: Double
    public let background: DesignSystem.Color
    public let shadow: DesignSystem.Shadow

    /// The mark of the place where the task would land between two rows, the Finder's line and circle, and nil where
    /// the drop is marked otherwise: a column's card is dropped into a column that its tint marks (`ColumnModel`).
    public let indicator: DropIndicatorModel?

    public init(
        scale: Double,
        opacity: Double,
        cornerRadius: Double,
        background: DesignSystem.Color,
        shadow: DesignSystem.Shadow,
        indicator: DropIndicatorModel?
    ) {
        self.scale = scale
        self.opacity = opacity
        self.cornerRadius = cornerRadius
        self.background = background
        self.shadow = shadow
        self.indicator = indicator
    }
}
