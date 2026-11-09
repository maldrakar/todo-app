// Sources/DesignSystemComponents/GlassButtonLabelModel.swift

/// The look of a round button on glass over the list screen's content, which its way back and its "…" share
/// (`Phone.dc.html`, `.glass`): `diameter` across, its glyph centred and moved `iconOffset` sideways, casting `shadow`,
/// in points. A platform with glass of its own puts it under the button; one without draws `surface` edged with `line`,
/// the canvas's glass and its hairline. Its numbers, its surface, its line and its shadow are the fields of its
/// `GlassControlStyle`. A button that sends an action is a `GlassButtonModel`; "…" is this look as the label of the
/// menu its screen holds, as `ButtonLabelModel` is a button's and a menu button's.
///
/// A class, for the reason a list's row is one (`ListRowModel`; ADR-0007): with its style's glass and pointer tint it
/// is some 450 bytes on wasm32, and a list's model holds three, back, "…" and the capsule's "+", which a debug build
/// copied onto the 64 KiB stack until a drop's model read overflowed it (`swift test` on wasm32, 2026-11-09).
///
/// `GlassButtonLabelModel` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation
/// and Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-08).
public final class GlassButtonLabelModel: Equatable, Sendable {
    public let icon: IconModel
    public let style: GlassControlStyle

    /// The words the button reads aloud, which say what a tap on it will do.
    public let accessibilityLabel: String

    public init(icon: IconModel, style: GlassControlStyle, accessibilityLabel: String) {
        self.icon = icon
        self.style = style
        self.accessibilityLabel = accessibilityLabel
    }

    public static func == (lhs: GlassButtonLabelModel, rhs: GlassButtonLabelModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.icon == rhs.icon
            && lhs.style == rhs.style
            && lhs.accessibilityLabel == rhs.accessibilityLabel
    }
}
