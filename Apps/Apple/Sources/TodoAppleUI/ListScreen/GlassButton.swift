// Apps/Apple/Sources/TodoAppleUI/ListScreen/GlassButton.swift
import DesignSystemComponents
import SwiftUI

/// A round button on glass over the list screen's content as its model describes it (`GlassButtonModel`;
/// `Phone.dc.html`, `.glass`), which sends nothing of its own: what a tap on it does is its screen's, the way back
/// being the window's stack's (`RootView`). "…" is the same circle as a `Menu`'s label (`Face`).
struct GlassButton: View {
    private let model: GlassButtonModel
    private let action: () -> Void

    init(_ model: GlassButtonModel, action: @escaping () -> Void) {
        self.model = model
        self.action = action
    }

    var body: some View {
        Button(action: action) { Face(model) }
            .buttonStyle(.plain)
            .accessibilityLabel(model.accessibilityLabel)
    }

    /// The circle and its glyph, moved off centre where the model says so.
    struct Face: View {
        private let model: GlassButtonModel

        init(_ model: GlassButtonModel) {
            self.model = model
        }

        var body: some View {
            let glyph = Icon(model.icon)
                .offset(x: model.style.iconOffset)
                .frame(width: model.style.diameter, height: model.style.diameter)
                .contentShape(Circle())
            // iOS 26's glass, which casts a shadow of its own and answers a press, and the Mac's and the watch's of the
            // same year; before them the canvas's: its surface over a material, which stands in for its backdrop blur,
            // edged with its hairline and casting its shadow (`GlassControlStyle`).
            if #available(iOS 26, macOS 26, watchOS 26, *) {
                glyph.glassEffect(.regular.interactive(), in: Circle())
            } else {
                glyph
                    .background(Color(model.style.surface), in: Circle())
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(model.style.shadow)
                    }
                    .overlay { Circle().stroke(model.style.line) }
            }
        }
    }
}
