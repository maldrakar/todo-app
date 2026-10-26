// Apps/Apple/Sources/TodoAppleUI/Foundations/Typography.swift
import SwiftUI

/// The canvas's type (`Main.dc.html`). The large and section titles are the rounded face; the rest is the system face.
enum Typography {
    static let largeTitle = Font.system(size: 32, weight: .heavy, design: .rounded)
    static let sectionTitle = Font.system(size: 17, weight: .heavy, design: .rounded)
    static let meta = Font.system(size: 12.5, weight: .medium)
    static let count = Font.system(size: 15, weight: .regular)

    /// A row's title: 17 at the root and 16 nested, semibold when the row has children and regular otherwise.
    static func rowTitle(depth: Int, hasChildren: Bool) -> Font {
        .system(size: depth == 0 ? 17 : 16, weight: hasChildren ? .semibold : .regular)
    }
}
