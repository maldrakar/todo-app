// Apps/Apple/Sources/TodoAppleUI/ListsScreen/TitleField.swift
import DesignSystemComponents
import SwiftUI
import TaskViewListFeature

/// The field a row draws while it is being renamed, a view of its own so that each field watches its own
/// focus: `.titleFieldLostFocus` names no row, and one flag shared by every row could not tell the field that
/// lost focus from the one a rename moved to. The Lists screen draws it on a list's row and on an area's line, in its
/// model's look (`fieldLook(_:)`), and the sidebar plainly on its rows until the plan's ninth task replaces it; its
/// text and its placeholder are its model's either way. What it sends is its own to send, as a model holds no closure
/// that makes the action carrying the typed text (`FieldModel`).
struct TitleField: View {
    private let model: FieldModel
    private let send: (TaskViewList.UserAction) -> Void

    /// Whether the caret is in this field, which only the view can know (spec section 2).
    @FocusState private var isFocused: Bool

    init(_ model: FieldModel, send: @escaping (TaskViewList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        TextField(model.placeholder, text: Binding(get: { model.text }, set: { send(.titleFieldChanged($0)) }))
            .focused($isFocused)
            .onSubmit { send(.titleFieldSubmitted) }
            #if os(macOS)
            // Esc. iOS and watchOS lack the modifier; what cancels a rename there is decided when they arrive.
            .onExitCommand { send(.titleFieldCancelled) }
            #endif
            // A field opens for a person to type in, whether the menu or the toolbar opened it.
            .onAppear { isFocused = true }
            .onChange(of: isFocused) { _, focused in
                guard !focused else { return }
                send(.titleFieldLostFocus)
                // What this view holds is from before `send`, so whether the field stays is not known here,
                // and the caret is asked back either way: a field still open after a lost focus is one whose
                // name the module refused.
                isFocused = true
            }
    }
}

extension View {
    /// A field in its model's look (`FieldModel`): its text in the model's font and colour, `padding` in from either
    /// end, `height` high, on its background rounded by `cornerRadius`, with the ring along that edge. How wide it is
    /// is the row's or the line's that it stands in, by the model's minimum width.
    func fieldLook(_ field: FieldModel) -> some View {
        font(Font(field.font))
            .foregroundStyle(Color(field.color))
            .padding(.horizontal, field.padding)
            .frame(height: field.height)
            .background(Color(field.background), in: .rect(cornerRadius: field.cornerRadius))
            .overlay { RoundedRectangle(cornerRadius: field.cornerRadius).stroke(field.ring) }
    }
}
