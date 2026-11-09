// Sources/DesignSystemComponents/EntranceStyle.swift
import DesignSystem

/// How a view comes in when it first appears, a card opening in place or the rows under the Done strip
/// (`Phone.dc.html`, `xIn` and `popIn`): from `opacity`, grown from `scale` about the point `anchorX` and `anchorY` of
/// its size, and moved `offset` down in points, up where negative, it comes to rest over `animation`. A platform that a
/// person asked for less motion draws it at rest.
///
/// `EntranceStyle` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
public struct EntranceStyle: Equatable, Sendable {
    public let opacity: Double
    public let scale: Double
    public let offset: Double
    public let anchorX: Double
    public let anchorY: Double
    public let animation: DesignSystem.Animation

    public init(
        opacity: Double,
        scale: Double,
        offset: Double,
        anchorX: Double,
        anchorY: Double,
        animation: DesignSystem.Animation
    ) {
        self.opacity = opacity
        self.scale = scale
        self.offset = offset
        self.anchorX = anchorX
        self.anchorY = anchorY
        self.animation = animation
    }
}
