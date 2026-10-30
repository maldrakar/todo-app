// Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsDialogs.swift
import SwiftUI
import TaskViewListFeature

/// The two dialogs of the list of views, drawn from the two optionals of its model (Lists screen spec, section 6;
/// ADR-0009, amendment of 2026-10-25): the confirmation of a delete as an alert, its title and message with Delete and
/// Cancel, and the picker of Move to… as a sheet, whose content each view draws in its own look, so that the phone's
/// screen, the sidebar and the plan's eighth task's sidebar put them up the one way.
struct ListsDialogs<PickerContent: View>: ViewModifier {
    private let model: TaskViewList.Model
    private let send: (TaskViewList.UserAction) -> Void
    private let picker: (TaskViewList.Model.MovePicker) -> PickerContent

    /// The dialogs of the model, which send their actions, the picker drawn by `picker` while it is up.
    init(
        model: TaskViewList.Model, send: @escaping (TaskViewList.UserAction) -> Void,
        @ViewBuilder picker: @escaping (TaskViewList.Model.MovePicker) -> PickerContent
    ) {
        self.model = model
        self.send = send
        self.picker = picker
    }

    func body(content: Content) -> some View {
        content
            .alert(
                model.confirmation?.title ?? "", isPresented: isConfirmationUp, presenting: model.confirmation
            ) { _ in
                Button("Delete", role: .destructive) { send(.deleteConfirmed) }
                Button("Cancel", role: .cancel) { send(.deleteCancelled) }
            } message: { confirmation in
                Text(confirmation.message)
            }
            .sheet(isPresented: isMovePickerUp) {
                if let movePicker = model.movePicker {
                    picker(movePicker)
                }
            }
    }

    /// Whether the confirmation is up, read from the model and moved only by an action, which a write of false is not.
    /// Every dismissal of an alert is one of its own buttons: iOS has no tap outside one, and Esc on the Mac and an
    /// iPad's keyboard press its Cancel. Each button sends its own action, Delete `deleteConfirmed` and Cancel
    /// `deleteCancelled`, so the alert's dismissal is still its Cancel action, through the button, whichever SwiftUI
    /// does first, the button's action or its write into this binding. A write sent as Cancel would take the
    /// confirmation down before a Delete that ran after it. On the Mac on 2026-10-29, by hand, Delete deleted with a
    /// binding that sent the write as Cancel, so there the action ran first. The sheet's binding below is the other
    /// kind: a swipe down and Esc are writes of false with no button behind them.
    private var isConfirmationUp: Binding<Bool> {
        Binding(get: { model.confirmation != nil }, set: { _ in })
    }

    /// Whether the move picker is up, read from the model and moved only by an action. The swipe down, and Esc on the
    /// Mac, are one write of false, which goes to the module as the picker's Cancel; the write that follows a close the
    /// module drove, a row tapped or Cancel, reaches no picker and moves nothing.
    private var isMovePickerUp: Binding<Bool> {
        Binding(get: { model.movePicker != nil }, set: { isUp in
            guard !isUp else { return }
            send(.movePickerCancelled)
        })
    }
}
