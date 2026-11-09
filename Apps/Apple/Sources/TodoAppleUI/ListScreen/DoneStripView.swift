// Apps/Apple/Sources/TodoAppleUI/ListScreen/DoneStripView.swift
import DesignSystemComponents
import SwiftUI

/// The Done strip's capsule as its model describes it (`DoneStripModel`; `Phone.dc.html`, the Done strip): its glyph,
/// its label and its chevron, turning on its motion, on the capsule, all of it the button that opens and closes the
/// strip, its words bumping as they change, the capsule tinted under the pointer where its style gives the tint
/// (`Hovering`). The tasks under it are the module's rows, which the screen draws
/// (`ListScreen`).
struct DoneStripView<Action: Equatable & Sendable>: View {
    private let model: DoneStripModel<Action>
    private let send: (Action) -> Void

    /// Whether a person asked for less motion: the chevron then turns without its animation, and the words do not bump.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ model: DoneStripModel<Action>, send: @escaping (Action) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        Button { send(model.action) } label: {
            HStack(spacing: model.style.spacing) {
                Icon(model.icon)
                Text(model.label)
                    .lineLimit(1)
                    .keyframeAnimator(initialValue: 1.0, trigger: model.label.text) { words, scale in
                        words.scaleEffect(scale)
                    } keyframes: { _ in
                        KeyframeTrack(\.self) {
                            let bump = model.style.bump
                            let duration = bump.animation.duration
                            if reduceMotion {
                                LinearKeyframe(1, duration: duration)
                            } else {
                                CubicKeyframe(bump.scale, duration: duration * bump.peakAt)
                                CubicKeyframe(1, duration: duration * (1 - bump.peakAt))
                            }
                        }
                    }
                Icon(model.chevron.icon)
                    .rotationEffect(.degrees(model.chevron.style.rotation))
                    .animation(
                        reduceMotion ? nil : Animation(model.chevron.style.animation),
                        value: model.chevron.style.rotation
                    )
            }
            .padding(.leading, model.style.leadingPadding)
            .padding(.trailing, model.style.trailingPadding)
            .frame(height: model.style.height)
            .hoverTint(
                model.style.hover, in: RoundedRectangle(cornerRadius: model.style.cornerRadius, style: .circular)
            )
            .background(
                Color(model.style.background), in: .rect(cornerRadius: model.style.cornerRadius, style: .circular)
            )
            .contentShape(.rect)
            // The words take no part in a leaving row's delayed motion, so that the new count stands at the write and
            // the bump plays on it, and the capsule fits them as they change (the controller's ruling on #177,
            // 2026-11-07).
            .transaction { $0.animation = nil }
        }
        .buttonStyle(.plain)
        .accessibilityHint(model.chevron.accessibilityLabel)
        .padding(.top, model.style.topMargin)
        .padding(.leading, model.style.leadingMargin)
        .padding(.trailing, model.style.trailingMargin)
        // One geometry, as a row that adds has (`AddRowView`).
        .geometryGroup()
    }
}
