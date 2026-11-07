// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Shape+DesignSystemComponents.swift
import DesignSystemComponents
import SwiftUI

extension Shape {
    /// The shape's outline drawn as a line of the look (`LineStyle`): in its colour, as wide as its width, and dashed
    /// as its dash says, solid where the dash is empty.
    func stroke(_ line: LineStyle) -> some View {
        stroke(Color(line.color), style: StrokeStyle(lineWidth: line.width, dash: line.dash.map { CGFloat($0) }))
    }
}

/// A rule of the look along an axis (`LineStyle`): a bar as thick as the style's width and as long as the frame it is
/// laid out in, in its colour: an area's line, the divider of the bar's group and a row's guides.
///
/// A rule is drawn solid, as every rule of the look is; the first dashed rule adds its dash here. It is a filled bar,
/// as the Lists screen drew its rules before their model (Task 7): a line stroked along the middle of the bar, the same
/// geometry, drew a guide's edges, which stand between pixels, up to 7/255 off the filled bar's on an iPhone 17 (the
/// iOS 26.3 simulator, 2026-10-30).
///
/// `Rule` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and Observation for
/// macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-10-30).
struct Rule: View {
    private let style: LineStyle
    private let axis: Axis

    init(_ style: LineStyle, along axis: Axis) {
        self.style = style
        self.axis = axis
    }

    var body: some View {
        Rectangle()
            .fill(Color(style.color))
            .frame(width: axis == .vertical ? style.width : nil, height: axis == .horizontal ? style.width : nil)
    }
}
