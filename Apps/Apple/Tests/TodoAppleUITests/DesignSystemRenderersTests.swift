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

/// The look's fonts hold every text style and every weight between them, and each renders as the system font of its
/// style, weight and face, so that it grows with Dynamic Type. A text-style font compares equal to the same one built
/// again, and unequal to one of another style, weight or face (probed 2026-10-26).
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
}

/// A symbol that does not exist draws nothing and says nothing, so the system is asked for the symbol of every icon,
/// the default glyph's among them.
@Test func everyIconNamesASymbolThisSystemHas() {
    for icon in DesignSystem.Icon.allCases {
        let name = Image.systemName(for: icon)
        #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(name)")
    }
}
