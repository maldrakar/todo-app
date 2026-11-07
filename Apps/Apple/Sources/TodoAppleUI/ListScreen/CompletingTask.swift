// Apps/Apple/Sources/TodoAppleUI/ListScreen/CompletingTask.swift
import DesignSystemComponents
import SwiftUI

/// What a row and an open card share as a tap on their check completes the task (`Phone.dc.html`, `complete`, one for
/// both): the task is written done at once, and the module has no done task among its rows from then on, so its last
/// moments on screen are this view's own, the one animation of that write (list screen spec, section 3). It is drawn
/// done from the tap, its check filling and its title struck, it stays a moment, and it fades and sinks as what stands
/// under it closes up, all as its `TaskLeavingStyle` says. It leaves any other way at once, a card opening in a row's
/// place among them, since only this tap animates. Where a person asked for less motion it is drawn done and stays that
/// moment all the same, and goes with no fade or sink as what stands under it closes up at once: what they ask to lose
/// is the motion, not the sight of the check taking (the controller's ruling on #177, 2026-11-07). A done task's check
/// goes back to open at once, as the canvas's does.
///
/// A task still here when the motion ends, a write the store refused among them, goes back to what its model says: the
/// state ends on the motion's own end, and a motion with nothing to move, a refused write's, ends at once. A row that
/// comes in during that motion, the strip's for this task, comes in on it, so that it does not stand over the rows that
/// have not moved yet.
///
/// One geometry, so that the task moves whole as those above it close up: a row's glyphs and words, each placed on its
/// own, drifted apart on that motion (the iOS 26.3 simulator, 2026-11-07).
struct CompletingTask<Action: Equatable & Sendable, Content: View>: View {
    private let check: CheckModel<Action>
    private let leaving: TaskLeavingStyle
    private let send: (Action) -> Void
    private let content: (_ isCompleting: Bool, _ checkTapped: @escaping () -> Void) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Whether a tap on the check has just completed the task, which only this view can know.
    @State private var isCompleting = false

    init(
        _ check: CheckModel<Action>, leaving: TaskLeavingStyle, send: @escaping (Action) -> Void,
        @ViewBuilder content: @escaping (_ isCompleting: Bool, _ checkTapped: @escaping () -> Void) -> Content
    ) {
        self.check = check
        self.leaving = leaving
        self.send = send
        self.content = content
    }

    var body: some View {
        content(isCompleting, checkTapped)
            .geometryGroup()
            // One layer as it fades: a card's fields, each on its own surface, showed through it one by one.
            .compositingGroup()
            .transition(
                .asymmetric(insertion: .opacity, removal: .opacity.combined(with: .offset(y: leaving.offset)))
            )
    }

    private func checkTapped() {
        guard !check.isChecked else {
            send(check.action)
            return
        }
        isCompleting = true
        withAnimation(leavingMotion, completionCriteria: .logicallyComplete) {
            send(check.action)
        } completion: {
            isCompleting = false
        }
    }

    /// The style's motion, or where a person asked for less motion its motion with nothing to see.
    private var leavingMotion: Animation {
        Animation(reduceMotion ? leaving.reducedAnimation : leaving.animation)
    }
}
