// Apps/Apple/Sources/TodoAppleUI/ListScreen/TaskLanding.swift
import DesignSystem
import DesignSystemComponents
import SwiftUI

/// A task's one motion on landing where it was dropped, as its style says (`TaskRowStyle`; `Phone.dc.html`,
/// `.row-fresh` and `.card-drop`, off one `st.fresh`): a list's row fades its `fresh` colour under itself, and a
/// column's card springs from its `landingScale` to its size, whichever is not nil, when it turns not nil or the row
/// appears with it. It plays once: a value that stays set plays no second time, and the motion runs out as it began
/// though the module clears the value at the next action, so it is this view's own. Where a person asked for less
/// motion it does not play.
///
/// `TaskLanding` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
struct TaskLanding: ViewModifier {
    private let style: TaskRowStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The motion playing, from what the style said when it began.
    @State private var landing: Landing?

    /// Whether the motion playing has been handed to its animation, its colour gone and its scale at 1.
    @State private var isAtRest = false

    /// Whether the value set now has played.
    @State private var hasLanded = false

    init(_ style: TaskRowStyle) {
        self.style = style
    }

    func body(content: Content) -> some View {
        content
            .background {
                if let color = landing?.color {
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .circular)
                        .fill(Color(color))
                        .opacity(isAtRest ? 0 : 1)
                }
            }
            .scaleEffect(isAtRest ? 1 : landing?.scale ?? 1)
            .background {
                // On appearing and not at the change that set it, as an entrance plays (`Entrance`), so that the first
                // frame stands at the motion's start, which this animation then leaves.
                if let landing {
                    Color.clear.onAppear { play(landing.animation) }
                }
            }
            .onAppear(perform: land)
            .onChange(of: isFresh) { land() }
    }

    private struct Landing {
        let color: DesignSystem.Color?
        let scale: Double?
        let animation: DesignSystem.Animation
    }

    private var isFresh: Bool { style.fresh != nil || style.landingScale != nil }

    private func land() {
        guard isFresh else {
            hasLanded = false
            return
        }
        guard !hasLanded else { return }
        hasLanded = true
        guard !reduceMotion, landing == nil else { return }
        landing = Landing(
            color: style.fresh, scale: style.landingScale,
            animation: style.fresh == nil ? style.landingAnimation : style.freshAnimation
        )
    }

    private func play(_ animation: DesignSystem.Animation) {
        withAnimation(Animation(animation), completionCriteria: .logicallyComplete) {
            isAtRest = true
        } completion: {
            landing = nil
            isAtRest = false
        }
    }
}
