// Apps/Apple/Sources/TodoAppleUI/ListScreen/SwipeToDelete.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature

/// The screen's one swipe, which every row that can be swiped reads, so that a move of the finger draws those rows' few
/// lines again and not the screen: an observed class and not the screen's state.
///
/// `ScreenSwipe` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
@MainActor @Observable
final class ScreenSwipe {
    var current: RowSwipe?
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
            let current = swipe.current?.row == row ? swipe.current : nil
            let x = current?.x ?? 0
            let isAtOnce = current?.isFollowingFinger == true || reduceMotion
            content
                .animation(isAtOnce ? nil : Animation(model.style.animation)) { $0.offset(x: x) }
                .background(alignment: .trailing) {
                    if x < 0 {
                        button(model)
                    }
                }
                .accessibilityAction(named: Text(model.accessibilityLabel)) { delete(model.action) }
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
