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

/// The lists' sixteen icons read the names the store keeps for them as they did before the chrome's glyphs joined them,
/// and each of the chrome's ten reads its own name, as every icon does (Lists screen plan, Task 8).
@Test func everyIconReadsItsOwnNameTheChromesTenAmongThem() {
    let lists: [String: DesignSystem.Icon] = [
        "tray": .tray, "sun": .sun, "calendar": .calendar, "week": .week, "logbook": .logbook, "trash": .trash,
        "briefcase": .briefcase, "house": .house, "hourglass": .hourglass, "pen": .pen, "bag": .bag, "wrench": .wrench,
        "book": .book, "folder": .folder, "list": .list, "bullets": .bullets,
    ]
    let chrome: [String: DesignSystem.Icon] = [
        "ellipsis": .ellipsis, "plus": .plus, "check": .check, "chevron": .chevron, "grip": .grip,
        "magnifier": .magnifier, "microphone": .microphone, "newWindow": .newWindow, "checkCircle": .checkCircle,
        "divider": .divider,
    ]
    for (name, icon) in lists.merging(chrome, uniquingKeysWith: { first, _ in first }) {
        #expect(DesignSystem.Icon(rawValue: name) == icon, "\(name)")
    }
    #expect(DesignSystem.Icon.allCases.count == lists.count + chrome.count)
}
