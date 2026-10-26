// Sources/DesignSystem/Icon.swift

extension DesignSystem {
    /// The icons a list can have, by the names the store keeps for them (`docs/specs/lists-screen.md`, section 9), so
    /// that `Icon(rawValue:)` reads the name a view holds and a name this app does not know reads as `nil`. The default
    /// glyph is a case of its own, so no icon of the look is optional, and a platform maps every case to a glyph of its
    /// own.
    public enum Icon: String, Sendable, CaseIterable {
        case tray, sun, calendar, week, logbook, trash, briefcase, house, hourglass, pen, bag, wrench, book, folder, list

        /// The default glyph, which the feature module that builds a tile picks for a list with no icon or with one
        /// this app does not know.
        case bullets
    }
}
