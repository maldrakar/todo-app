import Testing
import TestSupport
import DesignSystem
import TodoCore

/// Every icon the store seeds its built-in views with reads as an icon of the design system, so no built-in falls back
/// to the default glyph. The names are read from a seeded store, so the test follows the seed.
@Test func theStoresIconNamesReadAsIcons() throws {
    let views = try makeStore().views()
    #expect(!views.isEmpty)
    for view in views {
        #expect(view.icon.flatMap(DesignSystem.Icon.init(rawValue:)) != nil, "\(view.title)")
    }
}

/// A name another version of the app wrote, or an empty one, reads as no icon, for which the feature module that builds
/// a tile picks the default glyph, `.bullets`. A symbol's name is not an icon's either: the raw value is the name the
/// store keeps.
@Test func aNameThisAppDoesNotKnowReadsAsNoIcon() {
    #expect(DesignSystem.Icon(rawValue: "no-such-icon") == nil)
    #expect(DesignSystem.Icon(rawValue: "") == nil)
    #expect(DesignSystem.Icon(rawValue: "sun.max") == nil)
}
