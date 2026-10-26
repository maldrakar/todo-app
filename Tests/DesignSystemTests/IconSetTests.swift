import Testing
import TestSupport
import DesignSystem
import TodoCore

/// Every icon the store seeds its built-in views with reads as an icon of the set, so no built-in draws the default
/// glyph. The names are read from a seeded store, so the test follows the seed.
@Test func theStoresIconNamesReadAsIcons() throws {
    let views = try makeStore().views()
    #expect(!views.isEmpty)
    for view in views {
        #expect(view.icon.flatMap(DesignSystem.IconSet.init(rawValue:)) != nil, "\(view.title)")
    }
}

/// A name another version of the app wrote, or an empty one, reads as no icon, which a platform draws as its default
/// glyph. A symbol's name is not an icon's either: the raw value is the name the store keeps.
@Test func aNameThisAppDoesNotKnowReadsAsNoIcon() {
    #expect(DesignSystem.IconSet(rawValue: "no-such-icon") == nil)
    #expect(DesignSystem.IconSet(rawValue: "") == nil)
    #expect(DesignSystem.IconSet(rawValue: "sun.max") == nil)
}
