import AppKit
import DesignSystem
import SwiftUI
import Testing
@testable import TodoAppleUI

/// On the main actor because `Color.resolve(in:)` reaches AppKit's dynamic provider, which answers on the main actor
/// only: a nonisolated version of this test hung `swift test` with no output (2026-10-26).
@Test @MainActor func aDynamicColourResolvesToEachAppearancesShade() {
    let paper = DesignSystem.color.paper
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
    let font = DesignSystem.font
    #expect(Font(font.largeTitle) == .system(.largeTitle, design: .rounded, weight: .heavy))
    #expect(Font(font.sectionTitle) == .system(.headline, design: .rounded, weight: .heavy))
    #expect(Font(font.rowTitle(depth: 0, hasChildren: true)) == .system(.body, design: .default, weight: .semibold))
    #expect(Font(font.rowTitle(depth: 1, hasChildren: false)) == .system(.callout, design: .default, weight: .regular))
    #expect(Font(font.count) == .system(.subheadline, design: .default, weight: .regular))
    #expect(Font(font.meta) == .system(.caption, design: .default, weight: .medium))
}

/// Each kind of motion renders as SwiftUI's animation of the same curve and duration.
@Test func aMotionRendersItsCurveAndDuration() {
    let motion = DesignSystem.motion
    #expect(Animation(motion.check) == .spring(duration: 0.45))
    #expect(Animation(motion.rowLeaves) == .easeIn(duration: 0.32))
    #expect(Animation(motion.pushPop) == .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.32))
}

/// A symbol that does not exist draws nothing and says nothing, so the system is asked for the symbol of every icon
/// and of none.
@Test func everyIconNamesASymbolThisSystemHas() {
    let icons: [DesignSystem.IconSet?] = DesignSystem.IconSet.allCases + [nil]
    for icon in icons {
        let name = Image.systemName(for: icon)
        #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(name)")
    }
}

@Test func noIconDrawsTheBulletedList() {
    #expect(Image.systemName(for: nil) == "list.bullet")
}
