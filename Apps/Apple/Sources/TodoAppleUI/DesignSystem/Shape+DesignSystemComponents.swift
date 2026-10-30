// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Shape+DesignSystemComponents.swift
import DesignSystemComponents
import SwiftUI

extension Shape {
    /// The shape's outline drawn as a line of the look (`StrokeModel`): in its colour, as wide as its width, and dashed
    /// as its dash says, solid where the dash is empty.
    func stroke(_ model: StrokeModel) -> some View {
        stroke(Color(model.color), style: StrokeStyle(lineWidth: model.width, dash: model.dash.map { CGFloat($0) }))
    }
}

/// A rule of the look along an axis (`StrokeModel`): a bar as thick as the model's width and as long as the frame it is
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
    private let model: StrokeModel
    private let axis: Axis

    init(_ model: StrokeModel, along axis: Axis) {
        self.model = model
        self.axis = axis
    }

    var body: some View {
        Rectangle()
            .fill(Color(model.color))
            .frame(width: axis == .vertical ? model.width : nil, height: axis == .horizontal ? model.width : nil)
    }
}
