// Sources/DesignSystemComponents/BlockDropStyle.swift
import DesignSystem

/// How a block of a list looks while a task dragged from another block would land in it, which has no place of its own
/// to mark there: tinted `tint` and ringed inside its edge in `ring`, `ringWidth` thick, rounded by `cornerRadius` and
/// standing `inset` in from the block's sides, in points, the tint and the ring coming and going on `animation`, as a
/// column of the board is tinted and ringed (`ColumnStyle`). The tint and the ring's colour are the block's list's, so
/// a block in another list's colour is another instance.
///
/// `BlockDropStyle` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-08).
public struct BlockDropStyle: Equatable, Sendable {
    public let tint: DesignSystem.Color
    public let ring: DesignSystem.Color
    public let ringWidth: Double
    public let cornerRadius: Double
    public let inset: Double
    public let animation: DesignSystem.Animation

    public init(
        tint: DesignSystem.Color,
        ring: DesignSystem.Color,
        ringWidth: Double,
        cornerRadius: Double,
        inset: Double,
        animation: DesignSystem.Animation
    ) {
        self.tint = tint
        self.ring = ring
        self.ringWidth = ringWidth
        self.cornerRadius = cornerRadius
        self.inset = inset
        self.animation = animation
    }
}
