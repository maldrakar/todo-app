// Sources/DesignSystemComponents/GlassBarStyle.swift
import DesignSystem

/// How the list screen's glass buttons stand over its content (`Phone.dc.html`, the fade and the buttons' row), in
/// points, the one thing here that is no component's model: the buttons stand at the safe area's top, `edgeInset` in
/// from the screen's sides, over a fade of `fadeColor` that runs from the screen's top to `fadeHeight` under the safe
/// area's top, solid down to `fadeSolidDepth` under it and clear at its end, so that what scrolls under the buttons
/// leaves by it; and the content starts `contentTop` under the safe area's top, below the buttons.
///
/// The canvas draws a 108 fade over a 54 status bar, solid to 64 % (69.12) and clear at the end, so on a device,
/// whose status bar is the safe area's, it is 54 under it and solid to 15.12 under it; the content starts at 110, 56
/// under the status bar, the buttons' 44 and 12 more.
public struct GlassBarStyle: Equatable, Sendable {
    public let edgeInset: Double
    public let fadeColor: DesignSystem.Color
    public let fadeHeight: Double
    public let fadeSolidDepth: Double
    public let contentTop: Double

    public init(
        edgeInset: Double,
        fadeColor: DesignSystem.Color,
        fadeHeight: Double,
        fadeSolidDepth: Double,
        contentTop: Double
    ) {
        self.edgeInset = edgeInset
        self.fadeColor = fadeColor
        self.fadeHeight = fadeHeight
        self.fadeSolidDepth = fadeSolidDepth
        self.contentTop = contentTop
    }
}
