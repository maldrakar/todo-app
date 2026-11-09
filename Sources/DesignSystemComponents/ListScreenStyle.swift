// Sources/DesignSystemComponents/ListScreenStyle.swift
import DesignSystem

/// How the list screen itself stands, the values that belong to no component on it (`Phone.dc.html`, the fade, the
/// buttons' row and the scroller's padding), in points: all of it on `background`; the glass buttons at the safe area's
/// top, `edgeInset` in from the screen's sides, over a `fade` where the screen has one, so that what scrolls under the
/// buttons leaves by it; the content starting `contentTop` under the safe area's top, below the buttons, and a list's
/// ending `contentBottom` above the safe area's bottom, clear of the floating "+", where the board's own padding stands
/// instead.
///
/// The list has the fade and the board has none: the board's buttons stand in the flow above a header that does not
/// scroll, so nothing passes under them. The canvas draws the list's fade 108 over a 54 status bar, solid to 64 %
/// (69.12) and clear at the end, so on a device, whose status bar is the safe area's, it is 54 under it and solid to
/// 15.12 under it. The content starts at 110 on the list, 56 under the status bar, the buttons' 44 and 12 more, and
/// the board's header at 54 + 44 + 12 = 110, the same. The list ends 150 above the screen's bottom (`.ph-scroll`'s
/// padding), 116 above a safe area 34 high.
///
/// The Mac's pane stands the same way with more of its own: its content is `contentMaxWidth` wide at most, centred,
/// `contentHorizontalPadding` in from the pane's sides, and its buttons stand in a row `barHeight` high, `barSpacing`
/// apart, the "+" and the "…" in one glass `capsule`. The phone has no capsule, no cap on its content and none of
/// that padding, and its row is as high as its circles.
///
/// `ListScreenStyle` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
public struct ListScreenStyle: Equatable, Sendable {
    /// A fade of `color` from the screen's top to `height` under the safe area's top, solid down to `solidDepth` under
    /// it and the same colour clear at its end.
    public struct Fade: Equatable, Sendable {
        public let color: DesignSystem.Color
        public let height: Double
        public let solidDepth: Double

        public init(color: DesignSystem.Color, height: Double, solidDepth: Double) {
            self.color = color
            self.height = height
            self.solidDepth = solidDepth
        }
    }

    public let edgeInset: Double

    /// The fade under the buttons, and nil on the board, which has none.
    public let fade: Fade?

    public let contentTop: Double
    public let contentBottom: Double
    public let background: DesignSystem.Color

    /// How far the content stands in from the screen's sides, which the header and the blocks draw their own margins
    /// inside of.
    public let contentHorizontalPadding: Double

    /// The widest the content gets, centred when the screen is wider, and nil for none.
    public let contentMaxWidth: Double?

    /// How high the row of glass buttons is.
    public let barHeight: Double

    /// The gap between the back button and the capsule where there is a capsule.
    public let barSpacing: Double

    /// The glass capsule round "+" and "…", and nil where the "+" floats and "…" stands alone.
    public let capsule: GlassCapsuleStyle?

    public init(
        edgeInset: Double,
        fade: Fade?,
        contentTop: Double,
        contentBottom: Double,
        background: DesignSystem.Color,
        contentHorizontalPadding: Double,
        contentMaxWidth: Double?,
        barHeight: Double,
        barSpacing: Double,
        capsule: GlassCapsuleStyle?
    ) {
        self.edgeInset = edgeInset
        self.fade = fade
        self.contentTop = contentTop
        self.contentBottom = contentBottom
        self.background = background
        self.contentHorizontalPadding = contentHorizontalPadding
        self.contentMaxWidth = contentMaxWidth
        self.barHeight = barHeight
        self.barSpacing = barSpacing
        self.capsule = capsule
    }
}
