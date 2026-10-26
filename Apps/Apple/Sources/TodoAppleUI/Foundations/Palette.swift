// Apps/Apple/Sources/TodoAppleUI/Foundations/Palette.swift
import SwiftUI
#if os(watchOS)
// UIKit imports on watchOS but has no dynamic colour there, so nothing is imported for it.
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A colour as the canvas writes it, in sRGB with channels from 0 to 1, kept apart from `Color` so that the rules that
/// mix and fade colours can be tested on numbers (`docs/specs/lists-screen.md`, section 9). `RGB` was probed free in a
/// file importing SwiftUI, Foundation and Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1.
struct RGB: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    /// This colour moved `amount` of the way toward `other`, channel by channel, keeping its own opacity.
    func mixed(toward other: RGB, by amount: Double) -> RGB {
        RGB(
            red: red + (other.red - red) * amount,
            green: green + (other.green - green) * amount,
            blue: blue + (other.blue - blue) * amount,
            opacity: opacity)
    }

    /// A literal with no appearance of its own: only `Palette.dynamic` follows the theme.
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity) }
}

extension RGB {
    /// `0xRRGGBB`, as the canvas's files spell a colour.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity)
    }
}

/// The canvas's colours, one `Color` each that follows the light or dark appearance (`Phone.dc.html`, `Main.dc.html`).
/// A view reads a colour from here and never spells a hex, so a view holds no condition on the appearance.
enum Palette {
    static let paper = dynamic(light: RGB(hex: 0xFAF7F2), dark: darkPaper)
    static let surface = dynamic(light: RGB(hex: 0xFFFFFF), dark: RGB(hex: 0x24221F))
    static let sidebar = dynamic(light: RGB(hex: 0xF2EDE5), dark: RGB(hex: 0x1F1E1B))
    static let fill = dynamic(light: RGB(hex: 0xF0EBE3), dark: RGB(hex: 0x2E2B27))
    static let line = dynamic(light: RGB(hex: 0xE8E2D8), dark: RGB(hex: 0x35322D))
    static let ink = dynamic(light: RGB(hex: 0x1F1D1A), dark: RGB(hex: 0xEEEAE3))
    static let ink2 = dynamic(light: RGB(hex: 0x625C53), dark: RGB(hex: 0xABA498))
    static let ink3 = dynamic(light: RGB(hex: 0xA39C90), dark: RGB(hex: 0x6F6A62))
    static let red = dynamic(light: RGB(hex: 0xC2362B), dark: RGB(hex: 0xF07468))

    /// The same blue in both appearances.
    static let accent = accentRGB.color

    /// In the dark the canvas lays the accent at 24 % over the paper; the opaque colour that comes to is mixed here,
    /// so that nothing behind the view shows through it.
    static let accentSoft = dynamic(light: RGB(hex: 0xE7EAF9), dark: darkPaper.mixed(toward: accentRGB, by: 0.24))

    private static let darkPaper = RGB(hex: 0x1A1917)
    private static let accentRGB = RGB(hex: 0x3653C9)

    /// One `Color` that resolves to the light or the dark shade with the appearance; the one platform condition in the
    /// foundations.
    static func dynamic(light: RGB, dark: RGB) -> Color {
        #if os(watchOS)
        // watchOS draws in the dark appearance only, and its `UIColor` has no dynamic provider, so the dark shade stands.
        return dark.color
        #elseif canImport(UIKit)
        // UIKit's trait collection is what carries the appearance on iOS and iPadOS, and `UIColor` resolves the
        // provider again whenever it changes.
        return Color(uiColor: UIColor { traits in
            let shade = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: shade.red, green: shade.green, blue: shade.blue, alpha: shade.opacity)
        })
        #elseif canImport(AppKit)
        // AppKit has no trait collection; an `NSColor` named by its provider asks the drawing appearance instead.
        return Color(nsColor: NSColor(name: nil) { appearance in
            let shade = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: shade.red, green: shade.green, blue: shade.blue, alpha: shade.opacity)
        })
        #endif
    }
}
