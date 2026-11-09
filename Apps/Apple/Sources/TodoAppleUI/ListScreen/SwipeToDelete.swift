// Apps/Apple/Sources/TodoAppleUI/ListScreen/SwipeToDelete.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature

/// The screen's one swipe, held so that a move of the finger draws one row and not all of them: every row that can be
/// swiped reads which row is taken, `row`, which changes only when another is taken, and only that row reads how far it
/// stands, `x`, and how it moves. An observed class and not the screen's state, so that the screen is not drawn again
/// either.
///
/// `ScreenSwipe` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
@MainActor @Observable
final class ScreenSwipe {
    private(set) var row: BlockRowID?
    private(set) var x: CGFloat = 0
    private(set) var isFollowingFinger = false

    /// The swipe as its steps left it, which the gestures read and nothing draws from.
    @ObservationIgnored private(set) var current: RowSwipe?

    /// Whether a row stands taken, which a tap on a row only closes.
    var isOpen: Bool { current != nil }

    func step(_ phase: RowSwipe.Phase) {
        set(RowSwipe.after(phase, from: current))
    }

    func close() {
        set(nil)
    }

    /// A row has left the screen, by a peer's change among the ways: it stands open no longer, and so the next tap on a
    /// row is that row's.
    func rowLeft(_ row: BlockRowID) {
        if current?.row == row { close() }
    }

    private func set(_ swipe: RowSwipe?) {
        current = swipe
        if row != swipe?.row { row = swipe?.row }
        let x = swipe?.x ?? 0
        if self.x != x { self.x = x }
        let isFollowingFinger = swipe?.isFollowingFinger ?? false
        if self.isFollowingFinger != isFollowingFinger { self.isFollowingFinger = isFollowingFinger }
    }
}

/// A row's swipe to its Delete as its model describes it (`SwipeModel`; `Phone.dc.html`, the row's swipe): the row
/// moved aside by as far as the screen's swipe says, on the swipe's motion where no finger moves it, and behind it the
/// button at the style's numbers. The button reads aloud what it deletes, and VoiceOver has the same as an action of
/// the row, since no swipe reaches it. A row with no swipe has none of this.
struct SwipeToDelete: ViewModifier {
    private let model: SwipeModel<TaskList.UserAction>?
    private let row: BlockRowID
    private let swipe: ScreenSwipe
    private let delete: (TaskList.UserAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        _ model: SwipeModel<TaskList.UserAction>?, of row: BlockRowID, in swipe: ScreenSwipe,
        delete: @escaping (TaskList.UserAction) -> Void
    ) {
        self.model = model
        self.row = row
        self.swipe = swipe
        self.delete = delete
    }

    func body(content: Content) -> some View {
        if let model {
            let isTaken = swipe.row == row
            let x = isTaken ? swipe.x : 0
            let isAtOnce = reduceMotion || isTaken && swipe.isFollowingFinger
            content
                .animation(isAtOnce ? nil : Animation(model.style.animation)) { $0.offset(x: x) }
                .background(alignment: .trailing) {
                    if x < 0 {
                        button(model)
                    }
                }
                .accessibilityAction(named: Text(model.accessibilityLabel)) { delete(model.action) }
                .onDisappear { swipe.rowLeft(row) }
        } else {
            content
        }
    }

    private func button(_ model: SwipeModel<TaskList.UserAction>) -> some View {
        Button { delete(model.action) } label: {
            Text(model.button)
                .frame(width: model.style.buttonWidth)
                .frame(maxHeight: .infinity)
                .background(
                    Color(model.style.background),
                    in: .rect(cornerRadius: model.style.buttonCornerRadius, style: .circular)
                )
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.accessibilityLabel)
        .padding(.vertical, model.style.buttonVerticalInset)
        .padding(.trailing, model.style.buttonTrailingInset)
    }
}
