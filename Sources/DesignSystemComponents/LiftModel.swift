// Sources/DesignSystemComponents/LiftModel.swift
import DesignSystem

/// How a task's row looks while it is lifted to be moved (`Phone.dc.html`, `.tlift` and the drop's slot): grown to
/// `scale` and drawn at `opacity`, on `background` with corners of `cornerRadius`, casting `shadow`; and the slot that
/// marks where it would land, `slotHeight` high, from `slotLeading` after the leading edge of the rows to
/// `slotTrailing` short of their trailing edge, a circle `slotDot` across ringed with `slot` and a line of `slot` from
/// it, in points. The lift itself, which row is lifted and where the slot stands, is the platform's, since only the
/// platform has the finger or the pointer; this is its look, as `DragModel` is a tree's.
public struct LiftModel: Equatable, Sendable {
    public let scale: Double

    /// How opaque the lifted row is drawn, from 0 to 1: a row lifts whole, at 1, and a column's card dims to 0.35 where
    /// it is dragged from (`Phone.dc.html`, the dragged card's `opacity`).
    public let opacity: Double

    public let cornerRadius: Double
    public let background: DesignSystem.Color
    public let shadow: DesignSystem.Shadow

    /// The ring of the slot's circle and its line, in the list's check fill, whose width is how thick both are.
    public let slot: StrokeModel

    public let slotDot: Double
    public let slotHeight: Double
    public let slotLeading: Double
    public let slotTrailing: Double

    public init(
        scale: Double,
        opacity: Double,
        cornerRadius: Double,
        background: DesignSystem.Color,
        shadow: DesignSystem.Shadow,
        slot: StrokeModel,
        slotDot: Double,
        slotHeight: Double,
        slotLeading: Double,
        slotTrailing: Double
    ) {
        self.scale = scale
        self.opacity = opacity
        self.cornerRadius = cornerRadius
        self.background = background
        self.shadow = shadow
        self.slot = slot
        self.slotDot = slotDot
        self.slotHeight = slotHeight
        self.slotLeading = slotLeading
        self.slotTrailing = slotTrailing
    }
}
