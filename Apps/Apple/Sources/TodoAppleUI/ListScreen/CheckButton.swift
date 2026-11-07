// Apps/Apple/Sources/TodoAppleUI/ListScreen/CheckButton.swift
import DesignSystem
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
///
/// Its colours change, its tick draws itself and it pops as it is checked, each on its style's motion, or at once where
/// a person asked for less motion.
struct CheckCircle: View {
    private let style: CheckStyle
    private let isChecked: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ style: CheckStyle, isChecked: Bool) {
        self.style = style
        self.isChecked = isChecked
    }

    var body: some View {
        ZStack {
            Group {
                Circle()
                    .fill(Color(style.colors.fill).opacity(isChecked ? 1 : 0))
                Circle()
                    .strokeBorder(Color(isChecked ? style.colors.fill : style.colors.ring), lineWidth: style.ringWidth)
            }
            .animation(motion(style.fillAnimation), value: isChecked)
            Tick(mark: style.mark)
                .trim(from: 0, to: isChecked ? 1 : 0)
                .stroke(
                    Color(style.colors.mark),
                    style: StrokeStyle(lineWidth: style.markStrokeWidth, lineCap: .round, lineJoin: .round)
                )
                .frame(width: style.markSize, height: style.markSize)
                .animation(motion(style.markAnimation), value: isChecked)
        }
        .frame(width: style.diameter, height: style.diameter)
        .keyframeAnimator(initialValue: 1.0, trigger: isChecked) { circle, scale in
            circle.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                if isChecked && !reduceMotion {
                    let duration = style.animation.duration
                    CubicKeyframe(style.pop.dipScale, duration: duration * style.pop.dipAt)
                    CubicKeyframe(style.pop.peakScale, duration: duration * (style.pop.peakAt - style.pop.dipAt))
                    CubicKeyframe(1, duration: duration * (1 - style.pop.peakAt))
                } else {
                    // At rest for as long, not for no time: a timeline of no length left the circle at no size, so that
                    // a check going back to open vanished (the iOS 26.3 simulator, 2026-11-07).
                    LinearKeyframe(1, duration: style.animation.duration)
                }
            }
        }
    }

    private func motion(_ animation: DesignSystem.Animation) -> Animation? {
        reduceMotion ? nil : Animation(animation)
    }

    /// The style's tick scaled to the frame it is laid out in.
    private struct Tick: Shape {
        let mark: CheckStyle.Mark

        func path(in rect: CGRect) -> Path {
            let unit = rect.width / mark.box
            var path = Path()
            path.addLines(mark.points.map { CGPoint(x: $0.x * unit, y: $0.y * unit) })
            return path
        }
    }
}
