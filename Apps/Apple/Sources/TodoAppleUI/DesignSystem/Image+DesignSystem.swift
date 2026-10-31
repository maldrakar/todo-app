// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Image+DesignSystem.swift
import DesignSystem
import SwiftUI

extension Image {
    /// An icon of the look as an SF Symbol, a list's, the default glyph's and the chrome's alike.
    init(_ icon: DesignSystem.Icon) {
        self.init(systemName: Self.systemName(for: icon))
    }

    /// The symbol an icon draws. A symbol that does not exist draws nothing and says nothing, so every name was looked
    /// up in the system's `name_availability.plist` (`/System/Library/CoreServices/CoreGlyphs.bundle`): the lists'
    /// sixteen on 2026-10-26, each from iOS 15, macOS 12 and watchOS 8 at the latest, and the chrome's ten on
    /// 2026-10-30, each from the 2019, 2020 or 2021 releases, so all of them on iOS 17, macOS 14 and watchOS 10, and a
    /// test asks the Mac for each. The chrome's are the symbols the Lists screen drew before its models named them
    /// (Task 7). The `switch` names every case with no `default`, so an icon added to the look stops this compiling
    /// until it has a symbol.
    static func systemName(for icon: DesignSystem.Icon) -> String {
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
        case .bullets: "list.bullet"
        case .ellipsis: "ellipsis"
        case .plus: "plus"
        case .check: "checkmark"
        case .chevron: "chevron.down"
        case .grip: "line.3.horizontal"
        case .magnifier: "magnifyingglass"
        case .microphone: "mic"
        case .newWindow: "macwindow.badge.plus"
        case .checkCircle: "checkmark.circle"
        case .divider: "rectangle.split.1x2"
        }
    }
}
