// Sources/DesignSystem/Icon.swift

extension DesignSystem {
    /// The icons of the look: the ones a list can have, by the names the store keeps for them
    /// (`docs/specs/lists-screen.md`, section 9), so that `Icon(rawValue:)` reads the name a view holds and a name this
    /// app does not know reads as `nil`, and the chrome's glyphs, which a component's model names for the bar, the menus,
    /// a row and the picker (Lists screen plan, Task 8). The default glyph is a case of its own, so no icon of the look is
    /// optional, and a platform maps every case to a glyph of its own.
    ///
    /// A chrome glyph is an icon like any other, so its name read from the store reads as that glyph, as every icon's
    /// name reads as its own; nothing writes one.
    public enum Icon: String, Sendable, CaseIterable {
        case tray, sun, calendar, week, logbook, trash, briefcase, house, hourglass, pen, bag, wrench, book, folder, list

        /// The default glyph, which the feature module that builds a tile picks for a list with no icon or with one
        /// this app does not know.
        case bullets

        /// The chrome's glyphs, each named for what it draws: "…", "+", a check, the chevron that folds a branch, the
        /// grip of a row in edit mode, the search's magnifier and microphone, a window with a "+", a check in a circle,
        /// and a rectangle split by a line, which stands for an area and the top level.
        case ellipsis, plus, check, chevron, grip, magnifier, microphone, newWindow, checkCircle, divider
    }
}
