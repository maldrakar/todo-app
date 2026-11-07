// Apps/Apple/Sources/TodoAppleUI/DesignSystem/TitleField.swift
import DesignSystem
import DesignSystemComponents
import SwiftUI

/// The field a row draws while it is being renamed, a view of its own so that each field watches its own focus: the
/// action a lost focus sends names no row, and one flag shared by every row could not tell the field that lost focus
/// from the one a rename moved to. A list's row and an area's line draw it in its model's look (`fieldLook(_:)`), its
/// text and its placeholder its model's. It sends its model's actions for Return, Esc and a lost focus, and for the
/// text as it is typed what `changed` makes of it, which a model cannot hold (`TextFieldModel`; the owner, on #163's
/// thread r4431104202).
struct TitleField<Action: Equatable & Sendable>: View {
    private let model: TextFieldModel<Action>
    private let changed: (String) -> Action
    private let send: (Action) -> Void

    /// Whether the caret is in this field, which only the view can know (spec section 2).
    @FocusState private var isFocused: Bool

    init(_ model: TextFieldModel<Action>, changed: @escaping (String) -> Action, send: @escaping (Action) -> Void) {
        self.model = model
        self.changed = changed
        self.send = send
    }

    var body: some View {
        TextField(
            model.placeholder,
            text: Binding(get: { model.text }, set: { send(changed($0)) }),
            prompt: Text(model.placeholder).foregroundStyle(Color(model.style.placeholder))
        )
            // Plain, its look the model's (`fieldLook(_:)`): the Mac's default style draws a bezel of its own inside
            // it, where iOS's draws none.
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onSubmit { send(model.submitted) }
            #if os(macOS)
            // Esc. iOS and watchOS lack the modifier; what cancels a rename there is decided when they arrive.
            .onExitCommand { send(model.cancelled) }
            #endif
            // A field opens for a person to type in, whether a row's menu, the bar's "+" or the File menu opened it.
            .onAppear { isFocused = true }
            .onChange(of: isFocused) { _, focused in
                guard !focused else { return }
                send(model.focusLost)
                // What this view holds is from before `send`, so whether the field stays is not known here,
                // and the caret is asked back either way: a field still open after a lost focus is one whose
                // name the module refused.
                isFocused = true
            }
    }
}

extension View {
    /// A field in its model's look (`TextFieldModel`): its text in the model's font and colour, or the colour given, as
    /// a task's title has while its row leaves (`TaskLeavingStyle`), `padding` in from either end, at least `height`
    /// high, more for a field that grows down as it is typed in, on its background rounded by `cornerRadius`, with the
    /// ring along that edge. How wide it is is the row's or the line's that it stands in, by the model's minimum width.
    func fieldLook<Action>(_ field: TextFieldModel<Action>, color: DesignSystem.Color? = nil) -> some View {
        font(Font(field.style.font))
            .foregroundStyle(Color(color ?? field.style.color))
            .padding(.horizontal, field.style.padding)
            .frame(minHeight: field.style.height)
            .background(Color(field.style.background), in: .rect(cornerRadius: field.style.cornerRadius))
            .overlay { RoundedRectangle(cornerRadius: field.style.cornerRadius).stroke(field.style.ring) }
    }
}
