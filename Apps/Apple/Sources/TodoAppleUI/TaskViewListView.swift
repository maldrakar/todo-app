// Apps/Apple/Sources/TodoAppleUI/TaskViewListView.swift
import SwiftUI
import TaskViewListFeature
import TodoCore

/// The list of views, drawn as the module assembled it, every gesture sent as the one action its control is
/// named for (spec section 2), except a deselect, which no action takes (`selection`). It knows nothing about
/// renaming beyond what a row says: a row with a `draft` draws a field, and every other row its title.
struct TaskViewListView: View {
    private let model: TaskViewList.Model
    private let send: (TaskViewList.UserAction) -> Void

    /// Whether the list has the keyboard, which only the view can know (spec section 2).
    @FocusState private var isListFocused: Bool

    init(model: TaskViewList.Model, send: @escaping (TaskViewList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

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
            .focused($isListFocused)
            // The list takes the keyboard when it appears, so that the arrow keys move the highlight from the
            // start: without this the list came up unfocused, and Down did nothing until a click (2026-10-12).
            .onAppear { isListFocused = true }
            if let problem = model.problem {
                Text(problem)
                    .padding()
            }
        }
        // Wide enough for the toolbar's button beside the sidebar's own: at 140 and 180 pt the button went into the
        // toolbar's overflow menu, and at 220 it stood on the toolbar (2026-10-12). A minimum and not only an
        // ideal, because the column opens at the width AppKit saved for it (`NSSplitView Subview Frames` in the
        // app's defaults): with a saved width, an ideal of 220 opened at 180, the minimum it had then.
        .navigationSplitViewColumnWidth(min: 220, ideal: 220)
        .toolbar {
            Button("New Folder", systemImage: "folder.badge.plus") { send(.createFolderButtonTapped) }
        }
    }

    /// The highlight, read from the model and moved only by an action, the shape a text field's binding has
    /// (spec section 4). A nil written back is not sent, because no action takes it. In the app, a Cmd-click on
    /// the highlighted row drops the List's own highlight while the model and the pane keep the view, so the
    /// screen and the model disagree until the next model change (2026-10-12).
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
