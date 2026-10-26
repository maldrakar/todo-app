// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Image+DesignSystem.swift
import DesignSystem
import SwiftUI

extension Image {
    /// A list's icon as an SF Symbol; no icon, which is also what a name this app does not know reads as, draws the
    /// bulleted list.
    init(_ icon: DesignSystem.Icon?) {
        self.init(systemName: Self.systemName(for: icon))
    }

    /// The symbol an icon draws. A symbol that does not exist draws nothing and says nothing, so all sixteen names were
    /// looked up in the system's `name_availability.plist` (`/System/Library/CoreServices/CoreGlyphs.bundle`,
    /// 2026-10-26): each exists from iOS 15, macOS 12 and watchOS 8 at the latest, so on iOS 17, macOS 14 and
    /// watchOS 10 too, and a test asks the Mac for each. The `switch` names every case with no `default`, so an icon
    /// added to the look stops this compiling until it has a symbol.
    static func systemName(for icon: DesignSystem.Icon?) -> String {
        switch icon {
        case .tray: "tray"
        case .sun: "sun.max"
        case .calendar: "calendar"
        case .week: "calendar.badge.clock"
        case .logbook: "text.book.closed"
        case .trash: "trash"
        case .briefcase: "briefcase"
        case .house: "house"
        case .hourglass: "hourglass"
        case .pen: "pencil"
        case .bag: "bag"
        case .wrench: "wrench"
        case .book: "book"
        case .folder: "folder"
        case .list: "checklist"
        case nil: "list.bullet"
        }
    }
}
