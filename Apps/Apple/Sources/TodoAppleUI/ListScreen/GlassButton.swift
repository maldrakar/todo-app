// Apps/Apple/Sources/TodoAppleUI/ListScreen/GlassButton.swift
import DesignSystemComponents
import SwiftUI

/// A button on glass over the list screen's content as its model describes it (`GlassButtonModel`; `Phone.dc.html`,
/// `.glass`; `Mac.dc.html`, the nav row), sending its model's action: a circle on glass of its own, or an item of the
/// pane's capsule, which stands on the capsule's glass. "…" is the same face as a `Menu`'s label (`GlassButtonFace`).
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

/// A glass button that puts a menu up as its model describes it (`GlassMenuButtonModel`), "…" with Show as (list
/// screen spec, section 5): its glass face as the label of the system's menu, the menu's items in the model's order
/// with their checks and their headings (`MenuItems`). Left out on the watch, where `Menu` is unavailable, and whose
/// build is a compile check in this epic.
///
/// `GlassMenu` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
struct GlassMenu<Action: Equatable & Sendable>: View {
    private let model: GlassMenuButtonModel<Action>
    private let send: (Action) -> Void

    init(_ model: GlassMenuButtonModel<Action>, send: @escaping (Action) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        #if os(watchOS)
        EmptyView()
        #else
        Menu { MenuItems(model.menu, send: send) } label: { GlassButtonFace(model.label) }
            #if os(macOS)
            // Its label alone, as a plain button draws it: the Mac's default style puts it in a pull-down's bezel.
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            #endif
            .menuOrder(.fixed)
            .accessibilityLabel(model.label.accessibilityLabel)
        #endif
    }
}

/// The face of a glass button, its glyph moved off centre where its look says so, in a capsule as wide and as high as
/// its look says, which is a circle where the two are the same (`GlassButtonLabelModel`; `Mac.dc.html`, `.mc-gi`'s
/// rounding): a `GlassButton`'s, and "…"'s as the label of its menu. It stands on the glass its look gives it, and on
/// none where its look has none, inside the pane's capsule, which has its own.
///
/// `GlassButtonFace` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-08).
struct GlassButtonFace: View {
    private let model: GlassButtonLabelModel

    init(_ model: GlassButtonLabelModel) {
        self.model = model
    }

    var body: some View {
        // Circular corners, which in a square draw the circle the face drew before it had a height of its own: a
        // capsule's default corners are continuous.
        let shape = Capsule(style: .circular)
        Icon(model.icon)
            .offset(x: model.style.iconOffset)
            .frame(width: model.style.diameter, height: model.style.height)
            .hoverTint(model.style.hover)
            .contentShape(shape)
            .glassSurface(model.style.glass, in: shape)
    }
}

extension View {
    /// The look's glass under a control or under the pane's capsule, in its shape, and none at all where `glass` is
    /// nil, whatever the OS: iOS 26's glass, which casts a shadow of its own and answers a press, and the Mac's and the
    /// watch's of the same year; before them the canvas's, its surface over the material the bar's controls stand on,
    /// which stands in for its backdrop blur, edged with its hairline and casting its shadow
    /// (`GlassControlStyle.Glass`).
    ///
    /// `glassSurface` was probed free: no member of that name on a view in a file importing SwiftUI, Foundation and
    /// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
    @ViewBuilder
    func glassSurface(_ glass: GlassControlStyle.Glass?, in shape: some Shape) -> some View {
        if let glass {
            if #available(iOS 26, macOS 26, watchOS 26, *) {
                glassEffect(.regular.interactive(), in: shape)
            } else {
                background(Color(glass.surface), in: shape)
                    .glass(in: shape, edge: Color(glass.line.color), edgeWidth: glass.line.width, shadow: glass.shadow)
            }
        } else {
            self
        }
    }
}
