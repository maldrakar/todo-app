// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Accessories.swift
import DesignSystemComponents
import SwiftUI

/// What stands at the right of a row or of a line as its models describe it (`AccessoryModel`), in the order given,
/// each as high as what it stands on, and the gap after the last: a text set against the right of a cell at least the
/// text's minimum width, or as wide as it reads where what it stands on gives none; a chevron, a grip or a check
/// centred in a cell at least the cell's minimum width and as wide as the glyph on this platform; a space as wide as it
/// says; and an accessory hidden, its room kept and drawn empty. Every size is the model's of what the accessories
/// stand on, a list's row (`ListRowView.End`), an area's line (`AreaLine`) or a picker's top level, so the view picks
/// none but the glyph's own width, which is the platform's. The chevron sends the action its model holds; the rest
/// send nothing.
///
/// `Accessories` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-10-31).
struct Accessories<Action: Equatable & Sendable>: View {
    private let models: [AccessoryModel<Action>]
    private let cellMinimumWidth: Double
    private let textMinimumWidth: Double?
    private let endGap: Double
    private let height: Double
    private let send: (Action) -> Void

    /// Whether a person asked for less motion, which only the view can read: the chevron then turns without its
    /// animation (`DesignSystem.Animation`).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The accessories in cells at least `cellMinimumWidth` wide and `height` high, a text's at least
    /// `textMinimumWidth` wide where it is given, with `endGap` after them, in points.
    init(
        _ models: [AccessoryModel<Action>], cellMinimumWidth: Double, textMinimumWidth: Double?, endGap: Double,
        height: Double, send: @escaping (Action) -> Void
    ) {
        self.models = models
        self.cellMinimumWidth = cellMinimumWidth
        self.textMinimumWidth = textMinimumWidth
        self.endGap = endGap
        self.height = height
        self.send = send
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(models.indices, id: \.self) { index in
                accessory(models[index], reduceMotion: reduceMotion)
            }
            Color.clear.frame(width: endGap, height: 1)
        }
    }

    /// One accessory in its cell, through the one switch over what stands at a row's right, every case drawn and none
    /// by `default` (`docs/style.md`, "Views"); the chevron turns without its animation where a person asked for less
    /// motion.
    @ViewBuilder private func accessory(_ model: AccessoryModel<Action>, reduceMotion: Bool) -> some View {
        switch model {
        case .text(let text):
            Text(text)
                .lineLimit(1)
                .frame(minWidth: textMinimumWidth.map { CGFloat($0) }, alignment: .trailing)
        case .chevron(let chevron):
            Button { send(chevron.action) } label: {
                Icon(chevron.icon)
                    .rotationEffect(.degrees(chevron.rotation))
                    .animation(reduceMotion ? nil : Animation(chevron.animation), value: chevron.rotation)
                    .frame(minWidth: cellMinimumWidth, minHeight: height, maxHeight: height)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(chevron.accessibilityLabel)
        case .grip(let grip):
            // The drag is the screen's, from anywhere on the row, so the grip says that the row drags and takes no
            // gesture of its own, and VoiceOver passes it by.
            Icon(grip)
                .accessibilityHidden(true)
                .frame(minWidth: cellMinimumWidth, minHeight: height, maxHeight: height)
        case .check(let check):
            // VoiceOver reads the choice as the selected trait of what the check stands on, and passes the mark by.
            Icon(check)
                .accessibilityHidden(true)
                .frame(minWidth: cellMinimumWidth, minHeight: height, maxHeight: height)
        case .space(let width):
            // Room and nothing drawn: a spacer, which lays out and draws no layer.
            Spacer(minLength: 0)
                .frame(width: width, height: height)
        case .hidden(let accessory):
            Hidden(accessory: accessory, accessories: self, reduceMotion: reduceMotion)
        }
    }

    /// An accessory hidden: its cell, as wide as its glyph on this platform, drawn at no opacity, as the move picker
    /// drew the room for its check before its model (Task 7), and taking no touch or VoiceOver. A view of its own,
    /// since a function cannot return a view made of itself.
    private struct Hidden: View {
        let accessory: AccessoryModel<Action>
        let accessories: Accessories
        let reduceMotion: Bool

        var body: some View {
            accessories.accessory(accessory, reduceMotion: reduceMotion)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
