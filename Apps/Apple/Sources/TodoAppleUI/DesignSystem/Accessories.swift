// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Accessories.swift
import DesignSystemComponents
import SwiftUI

/// What stands at the right of a row or of a line as its models describe it (`AccessoryModel`), in the order given,
/// each as high as what it stands on, and the gap after the last: a count set against the right of a cell at least the
/// count's minimum width, or as wide as it reads where what it stands on gives none; a chevron, a grip or a check
/// centred in a cell as wide as the cell of what it stands on; and a space as wide as it says. Every size is the
/// model's of what the accessories stand on, a list's row (`ListRowView.End`), an area's line (`AreaLine`) or a
/// picker's top level, so the view picks none. The chevron sends the action its model holds; the rest send nothing.
///
/// `Accessories` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-10-31).
struct Accessories<Action: Equatable & Sendable>: View {
    private let models: [AccessoryModel<Action>]
    private let cellWidth: Double
    private let countMinimumWidth: Double?
    private let endGap: Double
    private let height: Double
    private let send: (Action) -> Void

    /// Whether a person asked for less motion, which only the view can read: the chevron then turns without its
    /// animation (`DesignSystem.Animation`).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The accessories in cells `cellWidth` wide and `height` high, a count's at least `countMinimumWidth` wide where
    /// it is given, with `endGap` after them, in points.
    init(
        _ models: [AccessoryModel<Action>], cellWidth: Double, countMinimumWidth: Double?, endGap: Double,
        height: Double, send: @escaping (Action) -> Void
    ) {
        self.models = models
        self.cellWidth = cellWidth
        self.countMinimumWidth = countMinimumWidth
        self.endGap = endGap
        self.height = height
        self.send = send
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(models.indices, id: \.self) { index in
                accessory(models[index])
            }
            Color.clear.frame(width: endGap, height: 1)
        }
    }

    /// One accessory in its cell, through the one switch over what stands at a row's right, every case drawn and none
    /// by `default` (`docs/style.md`, "Views").
    @ViewBuilder private func accessory(_ model: AccessoryModel<Action>) -> some View {
        switch model {
        case .count(let count):
            Text(count)
                .lineLimit(1)
                .frame(minWidth: countMinimumWidth.map { CGFloat($0) }, alignment: .trailing)
        case .chevron(let chevron):
            Button { send(chevron.action) } label: {
                Icon(chevron.icon)
                    .rotationEffect(.degrees(chevron.rotation))
                    .animation(reduceMotion ? nil : Animation(chevron.animation), value: chevron.rotation)
                    .frame(width: cellWidth, height: height)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(chevron.accessibilityLabel)
        case .grip(let grip):
            // The drag is the screen's, from anywhere on the row, so the grip says that the row drags and takes no
            // gesture of its own, and VoiceOver passes it by.
            Icon(grip)
                .accessibilityHidden(true)
                .frame(width: cellWidth, height: height)
        case .check(let check):
            // VoiceOver reads the choice as the selected trait of what the check stands on, and passes the mark by.
            Icon(check)
                .accessibilityHidden(true)
                .frame(width: cellWidth, height: height)
        case .space(let width):
            // Room and nothing drawn: a spacer, and not a clear colour, whose layers the glass of an alert over the
            // tree read, a few of its pixels 1 to 3/255 off (the iOS 26.3 simulator, 2026-10-31).
            Spacer(minLength: 0)
                .frame(width: width, height: height)
        }
    }
}
