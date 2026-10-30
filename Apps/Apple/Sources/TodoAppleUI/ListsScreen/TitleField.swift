// Apps/Apple/Sources/TodoAppleUI/ListsScreen/TitleField.swift
import SwiftUI
import TaskViewListFeature

/// The field a row draws while it is being renamed, a view of its own so that each field watches its own
/// focus: `.titleFieldLostFocus` names no row, and one flag shared by every row could not tell the field that
/// lost focus from the one a rename moved to. The Lists screen draws it on a list's row and on an area's line, and the
/// sidebar on its rows until the plan's eighth task replaces it; each caller gives it its placeholder, and its font
/// through the environment, as a `TextField`'s.
struct TitleField: View {
    private let placeholder: LocalizedStringKey
    private let draft: String
    private let send: (TaskViewList.UserAction) -> Void

    /// Whether the caret is in this field, which only the view can know (spec section 2).
    @FocusState private var isFocused: Bool

    init(_ placeholder: LocalizedStringKey, draft: String, send: @escaping (TaskViewList.UserAction) -> Void) {
        self.placeholder = placeholder
        self.draft = draft
        self.send = send
    }

    var body: some View {
        TextField(placeholder, text: Binding(get: { draft }, set: { send(.titleFieldChanged($0)) }))
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
