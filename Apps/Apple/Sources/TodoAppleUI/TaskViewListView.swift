// Apps/Apple/Sources/TodoAppleUI/TaskViewListView.swift
import SwiftUI
import TaskViewListFeature
import TodoCore

/// The list of views, drawn as the module assembled it, every gesture sent as the one action its control is
/// named for (spec section 2). It knows nothing about renaming beyond what a row says: a row with a `draft`
/// draws a field, and every other row its title.
struct TaskViewListView: View {
    let model: TaskViewList.Model
    let send: (TaskViewList.UserAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            List(model.rows, selection: selection) { row in
                Group {
                    if let draft = row.draft {
                        TitleField(draft: draft, send: send)
                    } else {
                        Text(row.title)
                    }
                }
                // The tree as the flat rows carry it: a number to indent by, so that drawing it decides nothing
                // (`TaskViewList`).
                .padding(.leading, CGFloat(row.depth) * 16)
                .contextMenu {
                    Button("Rename") { send(.renameMenuItemChosen(row.id)) }
                }
            }
            if let problem = model.problem {
                Text(problem)
                    .padding()
            }
        }
        .toolbar {
            Button("New Folder", systemImage: "folder.badge.plus") { send(.createFolderButtonTapped) }
        }
    }

    /// The highlight, read from the model and moved only by an action, the shape a text field's binding has
    /// (spec section 4). A nil written back, the list cleared, sends nothing: no action takes it, so the model
    /// keeps its highlight.
    private var selection: Binding<ViewID?> {
        Binding(get: { model.selection }, set: { id in
            if let id { send(.rowSelected(id)) }
        })
    }
}

/// The field a row draws while it is being renamed, a view of its own so that each field watches its own
/// focus: `.titleFieldLostFocus` names no row, and one flag shared by every row could not tell the field that
/// lost focus from the one a rename moved to.
private struct TitleField: View {
    let draft: String
    let send: (TaskViewList.UserAction) -> Void

    /// Whether the caret is in this field, which only the view can know (spec section 2).
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Title", text: Binding(get: { draft }, set: { send(.titleFieldChanged($0)) }))
            .focused($isFocused)
            .onSubmit { send(.titleFieldSubmitted) }
            .onExitCommand { send(.titleFieldCancelled) }
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
