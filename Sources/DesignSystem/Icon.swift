// Sources/DesignSystem/Icon.swift

extension DesignSystem {
    /// The icons a list can have, by the names the store keeps for them (`docs/specs/lists-screen.md`, section 9), so
    /// that `Icon(rawValue:)` reads the name a view holds and a name this app does not know reads as `nil`, as a view
    /// with no name does through the caller's `flatMap`. A platform draws `nil` as its default glyph, and maps the
    /// cases to glyphs of its own.
    public enum Icon: String, Sendable, CaseIterable {
        case tray, sun, calendar, week, logbook, trash, briefcase, house, hourglass, pen, bag, wrench, book, folder, list
    }
}
