// Sources/DesignSystem/IconSet.swift

extension DesignSystem {
    /// The icons a list can have, by the names the store keeps in `TaskView.icon` (`docs/specs/lists-screen.md`,
    /// section 9), so that `IconSet(rawValue:)` reads a view's icon, and a name this app does not know, or none, reads
    /// as `nil`, which a platform draws as its default glyph. Each platform maps the cases to glyphs of its own.
    public enum IconSet: String, Sendable, CaseIterable {
        case tray, sun, calendar, week, logbook, trash, briefcase, house, hourglass, pen, bag, wrench, book, folder, list
    }
}
