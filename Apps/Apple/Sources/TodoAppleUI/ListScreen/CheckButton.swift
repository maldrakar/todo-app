// Apps/Apple/Sources/TodoAppleUI/ListScreen/CheckButton.swift
import DesignSystemComponents
import SwiftUI

/// A check as its model describes it (`CheckModel`; `Phone.dc.html`, `.cb` in its `.cbh`), a row's, a card's or a
/// subtask's: the circle centred in its tap area, sending what `action` does, which reads aloud what a tap will do.
/// Whether it is drawn checked is its caller's, since a row's check fills on the tap and its model's answer may not
/// come while the row is on screen (`TaskRowView`).
struct CheckButton<Action: Equatable & Sendable>: View {
    private let model: CheckModel<Action>
    private let isChecked: Bool
    private let action: () -> Void

    init(_ model: CheckModel<Action>, isChecked: Bool, action: @escaping () -> Void) {
        self.model = model
        self.isChecked = isChecked
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            CheckCircle(model.style, isChecked: isChecked)
                .frame(width: model.style.hitWidth, height: model.style.hitHeight)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.accessibilityLabel)
    }
}

/// The circle of a check in its style's colours and numbers: its ring and clear inside while it is open; while it is
/// checked its fill for the ring and inside it, with the tick on the fill. The tick is the canvas's drawn stroke and no
/// glyph, so that it can draw itself in. A subtask's draft has this circle with no button (`TaskCardView`).
struct CheckCircle: View {
    private let style: CheckStyle
    private let isChecked: Bool

    init(_ style: CheckStyle, isChecked: Bool) {
        self.style = style
        self.isChecked = isChecked
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(style.colors.fill).opacity(isChecked ? 1 : 0))
            Circle()
                .strokeBorder(Color(isChecked ? style.colors.fill : style.colors.ring), lineWidth: style.ringWidth)
            Tick()
                .trim(from: 0, to: isChecked ? 1 : 0)
                .stroke(
                    Color(style.colors.mark),
                    style: StrokeStyle(lineWidth: style.markStrokeWidth, lineCap: .round, lineJoin: .round)
                )
                .frame(width: style.markSize, height: style.markSize)
        }
        .frame(width: style.diameter, height: style.diameter)
    }

    /// The canvas's tick, `M6.5 12.5l3.5 3.5 7.5-8` in its 24-unit box, scaled to the frame it is laid out in.
    private struct Tick: Shape {
        func path(in rect: CGRect) -> Path {
            let unit = rect.width / 24
            var path = Path()
            path.move(to: CGPoint(x: 6.5 * unit, y: 12.5 * unit))
            path.addLine(to: CGPoint(x: 10 * unit, y: 16 * unit))
            path.addLine(to: CGPoint(x: 17.5 * unit, y: 8 * unit))
            return path
        }
    }
}
