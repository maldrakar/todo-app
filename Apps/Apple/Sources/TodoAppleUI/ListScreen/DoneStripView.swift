// Apps/Apple/Sources/TodoAppleUI/ListScreen/DoneStripView.swift
import DesignSystemComponents
import SwiftUI

/// The Done strip's capsule as its model describes it (`DoneStripModel`; `Phone.dc.html`, the Done strip): its glyph,
/// its label and its chevron, turning on its motion, on the capsule, all of it the button that opens and closes the
/// strip. The tasks under it are the module's rows, which the screen draws (`ListScreen`).
struct DoneStripView<Action: Equatable & Sendable>: View {
    private let model: DoneStripModel<Action>
    private let send: (Action) -> Void

    /// Whether a person asked for less motion: the chevron then turns without its animation.
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
            .background(
                Color(model.style.background), in: .rect(cornerRadius: model.style.cornerRadius, style: .circular)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(model.chevron.accessibilityLabel)
        .padding(.top, model.style.topMargin)
        .padding(.leading, model.style.leadingMargin)
        .padding(.trailing, model.style.trailingMargin)
    }
}
