// Apps/Apple/Sources/TodoAppleUI/ListScreen/GlassButton.swift
import DesignSystemComponents
import SwiftUI

/// A round button on glass over the list screen's content as its model describes it (`GlassButtonModel`;
/// `Phone.dc.html`, `.glass`), sending its model's action. "…" is the same circle as a `Menu`'s label (`GlassButtonFace`).
struct GlassButton<Action: Equatable & Sendable>: View {
    private let model: GlassButtonModel<Action>
    private let send: (Action) -> Void

    init(_ model: GlassButtonModel<Action>, send: @escaping (Action) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        Button { send(model.action) } label: { GlassButtonFace(model.label) }
            .buttonStyle(.plain)
            .accessibilityLabel(model.label.accessibilityLabel)
    }
}

/// The circle of a glass button and its glyph, moved off centre where its look says so (`GlassButtonLabelModel`): a
/// `GlassButton`'s, and "…"'s as the label of its menu.
///
/// `GlassButtonFace` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-08).
struct GlassButtonFace: View {
    private let model: GlassButtonLabelModel

    init(_ model: GlassButtonLabelModel) {
        self.model = model
    }

    var body: some View {
        let glyph = Icon(model.icon)
            .offset(x: model.style.iconOffset)
            .frame(width: model.style.diameter, height: model.style.diameter)
            .contentShape(Circle())
        // iOS 26's glass, which casts a shadow of its own and answers a press, and the Mac's and the watch's of the
        // same year; before them the canvas's: its surface over the material the bar's controls stand on, which
        // stands in for its backdrop blur, edged with its hairline and casting its shadow (`GlassControlStyle.Glass`).
        if #available(iOS 26, macOS 26, watchOS 26, *) {
            glyph.glassEffect(.regular.interactive(), in: Circle())
        } else {
            if let glass = model.style.glass {
                glyph
                    .background(Color(glass.surface), in: Circle())
                    .glass(
                        in: Circle(), edge: Color(glass.line.color), edgeWidth: glass.line.width, shadow: glass.shadow
                    )
            } else {
                glyph
            }
        }
    }
}
