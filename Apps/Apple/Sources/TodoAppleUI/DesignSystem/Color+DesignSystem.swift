// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Color+DesignSystem.swift
import DesignSystem
import SwiftUI
#if os(watchOS)
// UIKit imports on watchOS but has no dynamic colour there, so nothing is imported for it.
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    /// A colour of the look as one `Color` that resolves to its light or its dark shade with the appearance; the one
    /// platform condition among the renderers.
    init(_ color: DesignSystem.Color) {
        #if os(watchOS)
        // watchOS draws in the dark appearance only, and its `UIColor` has no dynamic provider, so the dark shade
        // stands.
        let shade = color.dark
        self.init(.sRGB, red: shade.red, green: shade.green, blue: shade.blue, opacity: shade.opacity)
        #elseif canImport(UIKit)
        // UIKit's trait collection is what carries the appearance on iOS and iPadOS, and `UIColor` resolves the
        // provider again whenever it changes.
        self.init(uiColor: UIColor { traits in
            let shade = traits.userInterfaceStyle == .dark ? color.dark : color.light
            return UIColor(red: shade.red, green: shade.green, blue: shade.blue, alpha: shade.opacity)
        })
        #elseif canImport(AppKit)
        // AppKit has no trait collection; an `NSColor` named by its provider asks the drawing appearance instead.
        self.init(nsColor: NSColor(name: nil) { appearance in
            let shade = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? color.dark : color.light
            return NSColor(srgbRed: shade.red, green: shade.green, blue: shade.blue, alpha: shade.opacity)
        })
        #endif
    }
}
