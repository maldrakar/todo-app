// Sources/DesignSystemComponents/HoverStyle.swift
import DesignSystem

/// What a control draws over its own box while the pointer is over it, under its words and glyphs, as the canvas's
/// inset shadow of `--hover` does (`Mac.dc.html`, `.mc-tap:hover` and `.mc-trow:hover`): `color` in the control's
/// shape, coming and going on `animation`. A style holds one where a pointer can be over its control, the pane's, and
/// none on the phone, which has no pointer.
///
/// `HoverStyle` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
public struct HoverStyle: Equatable, Sendable {
    public let color: DesignSystem.Color
    public let animation: DesignSystem.Animation

    public init(color: DesignSystem.Color, animation: DesignSystem.Animation) {
        self.color = color
        self.animation = animation
    }
}
