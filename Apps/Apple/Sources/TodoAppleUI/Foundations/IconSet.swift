// Apps/Apple/Sources/TodoAppleUI/Foundations/IconSet.swift

/// The canvas's icon names as SF Symbols (`docs/specs/lists-screen.md`, section 9). A symbol that does not exist draws
/// nothing and says nothing, so all sixteen names here were looked up in the system's `name_availability.plist`
/// (`/System/Library/CoreServices/CoreGlyphs.bundle`, 2026-10-26): each exists from iOS 15, macOS 12 and watchOS 8 at
/// the latest, so on iOS 17, macOS 14 and watchOS 10 too.
enum IconSet {
    private static let fallback = "list.bullet"

    private static let symbols: [String: String] = [
        "tray": "tray",
        "sun": "sun.max",
        "calendar": "calendar",
        "week": "calendar.badge.clock",
        "logbook": "text.book.closed",
        "trash": "trash",
        "briefcase": "briefcase",
        "house": "house",
        "hourglass": "hourglass",
        "pen": "pencil",
        "bag": "bag",
        "wrench": "wrench",
        "book": "book",
        "folder": "folder",
        "list": "checklist",
    ]

    /// The symbol for a canvas icon name; no name and a name the set does not hold draw the default.
    static func symbol(_ name: String?) -> String {
        name.flatMap { symbols[$0] } ?? fallback
    }
}
