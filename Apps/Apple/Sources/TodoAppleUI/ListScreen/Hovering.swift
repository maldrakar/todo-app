// Apps/Apple/Sources/TodoAppleUI/ListScreen/Hovering.swift
import DesignSystem
import DesignSystemComponents
import SwiftUI

/// The pointer over a view, which only the view can know (`docs/style.md`, "Views"): the one place that holds it, and
/// hands it to what the view draws behind itself, which comes and goes on the motion given, or at once where a person
/// asked for less motion. Every control the canvas tints under the pointer draws its tint through it (`hoverTint(_:)`),
/// and a column's card its deeper shadow (`BlockRow`). The press's own tint is the system's (the controller's ruling
/// R166).
///
/// `Hovering` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and Observation
/// for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
struct Hovering<Look: View>: ViewModifier {
    private let animation: DesignSystem.Animation?
    private let look: (_ isHovered: Bool) -> Look

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    init(animation: DesignSystem.Animation?, @ViewBuilder look: @escaping (_ isHovered: Bool) -> Look) {
        self.animation = animation
        self.look = look
    }

    func body(content: Content) -> some View {
        content
            .background {
                look(isHovered)
                    .animation(reduceMotion ? nil : animation.map { Animation($0) }, value: isHovered)
            }
            #if !os(watchOS)
            // The watch has no pointer, nor the modifier.
            .onHover { isHovered = $0 }
            #endif
    }
}

extension View {
    /// The tint a style gives this view under the pointer, over its whole frame within the style's corners, behind what
    /// it holds and over what it stands on, as the canvas's inset shadow of `--hover` paints a box (`Mac.dc.html`,
    /// `.mc-tap:hover`); and nothing where the style gives none, the phone's.
    ///
    /// `hoverTint` was probed free: no member of that name on a view in a file importing SwiftUI, Foundation and
    /// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
    @ViewBuilder
    func hoverTint(_ hover: HoverStyle?) -> some View {
        if let hover {
            modifier(Hovering(animation: hover.animation) { isHovered in
                RoundedRectangle(cornerRadius: hover.cornerRadius, style: .circular)
                    .fill(Color(hover.color))
                    .opacity(isHovered ? 1 : 0)
            })
        } else {
            self
        }
    }
}
