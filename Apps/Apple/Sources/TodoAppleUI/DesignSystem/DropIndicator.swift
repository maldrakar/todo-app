// Apps/Apple/Sources/TodoAppleUI/DesignSystem/DropIndicator.swift
import DesignSystemComponents
import SwiftUI

/// The Finder's mark of the place where a lifted row would land, as its style describes it (`DropIndicatorStyle`): a gap
/// between the rows with the line, a rule rounded at its ends, and the circle over its start, ringed inside its diameter
/// as the canvas's border is, each placed from the edge its caller gives: the tile of the drop's depth in the Lists
/// tree, the rows' leading edge in a list of tasks. It is a view's own feedback and sends nothing.
///
/// `DropIndicator` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
struct DropIndicator: View {
    private let style: DropIndicatorStyle
    private let edge: CGFloat
    private let visibleRight: CGFloat

    /// The mark placed from the edge, its line ending short of the right edge of the rows on screen.
    init(_ style: DropIndicatorStyle, from edge: CGFloat, visibleRight: CGFloat) {
        self.style = style
        self.edge = edge
        self.visibleRight = visibleRight
    }

    var body: some View {
        let lineStart = edge + style.lineOffset
        ZStack(alignment: .leading) {
            Rule(style.line, along: .horizontal)
                .frame(width: max(0, visibleRight - style.trailingGap - lineStart))
                .clipShape(.rect(cornerRadius: style.lineCornerRadius))
                .padding(.leading, lineStart)
            Circle()
                .fill(Color(style.circleFill))
                .overlay { Circle().inset(by: style.circleRing.width / 2).stroke(style.circleRing) }
                .frame(width: style.circleDiameter, height: style.circleDiameter)
                .padding(.leading, edge + style.circleOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .frame(height: style.height)
    }
}
