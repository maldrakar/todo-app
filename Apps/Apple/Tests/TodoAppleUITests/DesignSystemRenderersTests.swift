import AppKit
import DesignSystem
import SwiftUI
import Testing
@testable import TodoAppleUI

/// On the main actor because `Color.resolve(in:)` reaches AppKit's dynamic provider, which answers on the main actor
/// only: a nonisolated version of this test hung `swift test` with no output (2026-10-26).
@Test @MainActor func aDynamicColourResolvesToEachAppearancesShade() {
    let paper = DesignSystem.Color.paper
    let color = Color(paper)
    for (scheme, want) in [(ColorScheme.light, paper.light), (ColorScheme.dark, paper.dark)] {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let got = color.resolve(in: environment)
        #expect(abs(Double(got.red) - want.red) < 0.01, "\(scheme)")
        #expect(abs(Double(got.green) - want.green) < 0.01, "\(scheme)")
        #expect(abs(Double(got.blue) - want.blue) < 0.01, "\(scheme)")
    }
}

/// The look's fonts hold every text style and every weight but bold between them, and each renders as the system font
/// of its style, weight and face, so that it grows with Dynamic Type. A text-style font compares equal to the same one
/// built again, and unequal to one of another style, weight or face (probed 2026-10-26).
@Test func aFontRendersItsTextStyleWeightAndFace() {
    #expect(Font(.largeTitle) == .system(.largeTitle, design: .rounded, weight: .heavy))
    #expect(Font(.sectionTitle) == .system(.headline, design: .rounded, weight: .heavy))
    #expect(Font(.rowTitle) == .system(.body, design: .default, weight: .regular))
    #expect(Font(.rowTitleEmphasized) == .system(.body, design: .default, weight: .semibold))
    #expect(Font(.nestedRowTitle) == .system(.callout, design: .default, weight: .regular))
    #expect(Font(.nestedRowTitleEmphasized) == .system(.callout, design: .default, weight: .semibold))
    #expect(Font(.count) == .system(.subheadline, design: .default, weight: .regular))
    #expect(Font(.meta) == .system(.caption, design: .default, weight: .medium))
    #expect(Font(.areaLabel) == .system(.footnote, design: .default, weight: .medium))
    #expect(Font(.barLabel) == .system(.subheadline, design: .default, weight: .semibold))
    #expect(Font(.hint) == .system(.footnote, design: .default, weight: .regular))
    #expect(Font(.search) == .system(.body, design: .default, weight: .regular))
    #expect(Font(.addRow) == .system(.subheadline, design: .default, weight: .medium))
    #expect(Font(.notes) == .system(.subheadline, design: .default, weight: .regular))
    #expect(Font(.pill) == .system(.footnote, design: .default, weight: .semibold))
    #expect(Font(.emptyStateTitle) == .system(.title3, design: .rounded, weight: .heavy))
}

/// Each weight of the look renders as SwiftUI's weight of its name, bold among them, which only a glyph's model takes,
/// Done's check and the picker's.
@Test func aWeightRendersAsSwiftUIsOfItsName() {
    #expect(Font.Weight(.regular) == .regular)
    #expect(Font.Weight(.medium) == .medium)
    #expect(Font.Weight(.semibold) == .semibold)
    #expect(Font.Weight(.bold) == .bold)
    #expect(Font.Weight(.heavy) == .heavy)
}

/// Each motion renders as SwiftUI's animation of the same curve and duration, delayed by its delay. A delayed
/// animation compares equal to the same one built again and unequal to one of another delay, curve or duration, and
/// one delayed by 0 is unequal to the same one undelayed (probed 2026-10-26), so every motion is compared delayed.
@Test func aMotionRendersItsCurveDurationAndDelay() {
    #expect(Animation(.check) == .spring(duration: 0.45).delay(0))
    #expect(Animation(.rowLeaves) == .easeIn(duration: 0.32).delay(0.7))
    #expect(Animation(.pushPop) == .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.32).delay(0))
    #expect(Animation(.popover) == .spring(duration: 0.2).delay(0))
    #expect(Animation(.quickEntry) == .spring(duration: 0.42).delay(0))
    #expect(Animation(.cardOpens) == .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.26).delay(0))
    #expect(Animation(.drop) == .spring(duration: 0.32).delay(0))
    #expect(Animation(.swipe) == .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.25).delay(0))
    #expect(Animation(.fold) == .timingCurve(0.25, 0.1, 0.25, 1, duration: 0.22).delay(0))
    #expect(Animation(.fresh) == .timingCurve(0.25, 0.1, 0.25, 1, duration: 1.6).delay(0))
}

/// A symbol that does not exist draws nothing and says nothing, so the system is asked for the symbol of every icon,
/// the default glyph's and the chrome's among them, the list screen's six too.
@Test func everyIconNamesASymbolThisSystemHas() {
    for icon in DesignSystem.Icon.allCases {
        let name = Image.systemName(for: icon)
        #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(name)")
    }
}

/// The list screen's glyphs draw the symbols looked up for them in `name_availability.plist`, each on iOS 17, macOS 14
/// and watchOS 10, so that a symbol that exists but is not the one checked, a filled flag for the flag, fails here.
@Test func everyListScreenGlyphDrawsTheSymbolCheckedForIt() {
    let symbols: [DesignSystem.Icon: String] = [
        .flag: "flag", .hash: "number", .note: "note.text", .expand: "arrow.up.left.and.arrow.down.right",
        .columns: "rectangle.split.3x1", .chevronLeft: "chevron.left",
    ]
    for (icon, symbol) in symbols {
        #expect(Image.systemName(for: icon) == symbol, "\(icon)")
    }
}

/// The chrome's glyphs draw the symbols the Lists screen drew before its component models named them (Task 7), so
/// that the screen looks as it did: the bar's, the menus', a row's, a line's and the picker's.
@Test func everyChromeGlyphDrawsTheSymbolTheScreenDrew() {
    let symbols: [DesignSystem.Icon: String] = [
        .ellipsis: "ellipsis", .plus: "plus", .check: "checkmark", .chevron: "chevron.down",
        .grip: "line.3.horizontal", .magnifier: "magnifyingglass", .microphone: "mic",
        .newWindow: "macwindow.badge.plus", .checkCircle: "checkmark.circle", .divider: "rectangle.split.1x2",
    ]
    for (icon, symbol) in symbols {
        #expect(Image.systemName(for: icon) == symbol, "\(icon)")
    }
}
