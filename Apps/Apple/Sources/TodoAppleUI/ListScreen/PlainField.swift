// Apps/Apple/Sources/TodoAppleUI/ListScreen/PlainField.swift
import DesignSystemComponents
import SwiftUI

/// A field with no ring of its own that stands in what it belongs to, a card's title, notes and subtask's and a list's
/// name's (`TaskList.plainField`), a view of its own so that each field watches its own focus. It draws what its model
/// holds in its model's look (`fieldLook(_:)`), sends its model's actions for Return, Esc and a lost focus, and for the
/// text what `changed` makes of it, which a model cannot hold (`TextFieldModel`).
///
/// What is typed goes up only while the field has the focus: a field writes its text back through its binding as it
/// goes too, and that echo, after a card has closed, names no card and would land on the one opened since. It is not
/// `TitleField`, which asks the caret back on every lost focus and cannot stand beside another field. Whether it takes
/// the focus when it appears, and takes it back after Return, is its caller's, which is the view's own focus: a new
/// task's title does and a stored one does not, and on the Mac a `TextField` ends editing on a Return, so that the next
/// empty subtask's field the module opens would close at once on the lost focus (Task 7's hand check).
///
/// `PlainField` was probed free against SwiftUI, Foundation and Observation for macOS 14, iOS 17 and watchOS 10 with
/// Xcode 27.1 (2026-11-07), as `CheckButton`, `WrappingRow`, `BlockRow`, `AddRowView` and `BlockHeaderView` were.
struct PlainField<Action: Equatable & Sendable>: View {
    private let model: TextFieldModel<Action>
    private let axis: Axis
    private let focusesOnAppear: Bool
    private let keepsFocusOnSubmit: Bool
    private let changed: (String) -> Action
    private let send: (Action) -> Void

    @FocusState private var isFocused: Bool

    /// The field, on one line unless `axis` says it grows down, as a card's notes do.
    init(
        _ model: TextFieldModel<Action>, axis: Axis = .horizontal, focusesOnAppear: Bool,
        keepsFocusOnSubmit: Bool = false, changed: @escaping (String) -> Action,
        send: @escaping (Action) -> Void
    ) {
        self.model = model
        self.axis = axis
        self.focusesOnAppear = focusesOnAppear
        self.keepsFocusOnSubmit = keepsFocusOnSubmit
        self.changed = changed
        self.send = send
    }

    var body: some View {
        field
            // Plain, its look the model's: the Mac's default style draws a bezel of its own inside it, where iOS's
            // draws none.
            .textFieldStyle(.plain)
            .fieldLook(model)
            .focused($isFocused)
            .onSubmit {
                send(model.submitted)
                if keepsFocusOnSubmit { isFocused = true }
            }
            .onChange(of: isFocused) { _, isFocused in
                if !isFocused { send(model.focusLost) }
            }
            .onAppear {
                if focusesOnAppear { isFocused = true }
            }
    }

    /// The field, which reads Esc where a keyboard has one: `onKeyPress` has no watchOS.
    @ViewBuilder private var field: some View {
        let text = TextField(
            model.placeholder,
            text: Binding(get: { model.text }, set: { text in
                if isFocused { send(changed(text)) }
            }),
            prompt: Text(model.placeholder).foregroundStyle(Color(model.style.placeholder)),
            axis: axis
        )
        #if os(watchOS)
        text
        #else
        text.onKeyPress(.escape) {
            send(model.cancelled)
            return .handled
        }
        #endif
    }
}
