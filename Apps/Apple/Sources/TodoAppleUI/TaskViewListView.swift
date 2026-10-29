// Apps/Apple/Sources/TodoAppleUI/TaskViewListView.swift
import SwiftUI
import TaskViewListFeature
import TodoCore

/// The list of views, drawn as the module assembled it, every gesture sent as the one action its control is
/// named for (spec section 2). A deselect is no gesture here: the List cannot remove the highlight (`selection`). It
/// knows nothing about renaming beyond what a row says: a row with a `draft` draws a field, and every other row
/// what its kind is, through the one switch over it (`docs/style.md`, "Views"): an area's line with its label, and a
/// list's title. It has no title of its own, so its row in the back button's menu over a screen pushed on it is empty,
/// where the screens over it are named by theirs (the owner, 2026-10-25, #126).
///
/// The Lists screen's look, the tiles, the counts, the chevrons and the bar, is the plan's seventh and eighth tasks':
/// until then this view draws the model's new rows with the look it had (Lists screen plan, Task 5), and the edits as
/// plainly: the confirmation as an alert, the move picker as a sheet of a plain list, and edit mode from a button on
/// the toolbar (Task 6).
struct TaskViewListView: View {
    private let model: TaskViewList.Model
    private let send: (TaskViewList.UserAction) -> Void

    /// Whether the list has the keyboard, which only the view can know (spec section 2).
    @FocusState private var isListFocused: Bool

    /// How many times the List has emptied its own highlight. Nothing uses the number: `selection` reads the
    /// property while `body` runs, so that a change runs `body` again.
    @State private var emptiedHighlights = 0

    /// Whether the app can open a window beside this one, which the platform reports (`docs/specs/navigation.md`,
    /// sections 5 and 10). Read on 2026-10-18: true on the Mac; false on iPhone, its Info.plist declaring multiple
    /// scenes or not; on the iPad true only with that declaration, which Task 9's Info.plist makes, and false without
    /// it (the iOS 26.3 simulator).
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

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
                        switch row.kind {
                        case .area(let label):
                            // A line across the row, with the area's name beside it when it has one. Not selectable, so
                            // that a click on the line puts no highlight on it: an area never opens, and the module
                            // moves nothing for `.rowSelected` on it, so a highlight the List put there would stay
                            // beside the list of the view chosen before.
                            HStack {
                                if let label { Text(label) }
                                VStack { Divider() }
                            }
                            .selectionDisabled()
                        case .list(let list):
                            // A tap on the title is the row's choice, the highlighted row's too, which the List does
                            // not report: on the Mac a click on the highlighted row moves no highlight and writes no
                            // selection, so the task open in its list stayed open, where a click on the highlighted
                            // view closes it (`TaskViewList`). The title fills the row to its trailing edge so that the
                            // tap covers the row past the title's text, and it replaces the List's own selection there;
                            // the row's insets and a nested row's indent stay the List's, and the arrow keys still go
                            // through `selection`. On 2026-10-18, on the Mac: a click on a view's title or on the rest
                            // of its row chose it, one action each, and on the highlighted view closed its task; the
                            // same day, a tap on the title's text alone, sent only for the highlighted row, left a
                            // click on another view's title choosing nothing. On 2026-10-20, in the iOS 26.3 simulator,
                            // a tap on another view's row pushed its list on iPhone, and on the iPad a tap on the
                            // highlighted view closed its task.
                            Text(list.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(.rect)
                                .onTapGesture { send(.rowSelected(row.id)) }
                        }
                    }
                }
                // The tree as the flat rows carry it: a number to indent by, so that drawing it decides nothing
                // (`TaskViewList`).
                .padding(.leading, CGFloat(row.depth) * 16)
                #if !os(watchOS)
                // Not on the watch, where the modifier is deprecated since watchOS 7, so the watch's build, a compile
                // check in this epic (`docs/specs/navigation.md`, section 8), leaves the whole menu out, Rename with
                // it.
                .contextMenu {
                    Button("Rename") { send(.renameMenuItemChosen(row.id)) }
                    Button("New List") { send(.newListMenuItemChosen(in: row.id)) }
                    // Only where a window can open beside this one, which iPhone cannot (`docs/specs/navigation.md`,
                    // section 5). It asks for the window, and the root passes the request on as its output, which
                    // the window's view answers by opening the window (`WindowView`).
                    if supportsMultipleWindows {
                        Button("Open in New Window") { send(.openInNewWindowMenuItemChosen(row.id)) }
                    }
                    // On an area's line too, where the module moves nothing for Move to…, since an area moves along
                    // the root alone; the menus of each kind are the plan's seventh and eighth tasks'.
                    Button("Move to…") { send(.moveToMenuItemChosen(row.id)) }
                    Button("Delete", role: .destructive) { send(.deleteMenuItemChosen(row.id)) }
                }
                #endif
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
        #if !os(watchOS)
        // The sidebar's "+", a menu with an item for each thing it makes, each sending the action its item is named for:
        // where a list or an area goes, and that New Task is quick entry, is the module's to decide (Lists screen spec,
        // section 8). The look is the plan's Tasks 7 and 8. Not on the watch, where `Menu` is unavailable (a file
        // typechecked against the watchOS 10 SDK with Xcode 27.1 on 2026-10-27), and whose build is a compile check in
        // this epic, as it is for the row's menu above.
        .toolbar {
            Menu("Add", systemImage: "plus") {
                Button("New Task") { send(.newTaskMenuItemChosen) }
                Button("New List") { send(.newListMenuItemChosen(in: nil)) }
                Button("New Area") { send(.newAreaMenuItemChosen) }
            }
            // Edit, which "…" holds on the phone and the iPad, and Done, the check that ends edit mode, as one button
            // that says which the model is in (Lists screen spec, section 7).
            if model.isEditing {
                Button("Done") { send(.doneButtonTapped) }
            } else {
                Button("Edit") { send(.editMenuItemChosen) }
            }
        }
        #endif
        .alert(model.confirmation?.title ?? "", isPresented: isConfirmationUp, presenting: model.confirmation) { _ in
            Button("Delete", role: .destructive) { send(.deleteConfirmed) }
            Button("Cancel", role: .cancel) { send(.deleteCancelled) }
        } message: { confirmation in
            Text(confirmation.message)
        }
        .sheet(isPresented: isMovePickerUp) {
            if let movePicker = model.movePicker {
                MovePickerList(picker: movePicker, send: send)
            }
        }
    }

    /// Whether the confirmation is up, read from the model and moved only by an action, as quick entry's sheet is
    /// (`RootView`). The alert's buttons send their own actions, and SwiftUI dismisses the alert after a button's
    /// action has run, writing false into this binding, which goes to the module as Cancel: after Delete or Cancel the
    /// module has taken the confirmation down already, and it moves nothing (`TaskViewList`, the trap of the plan's
    /// Task 6).
    private var isConfirmationUp: Binding<Bool> {
        Binding(get: { model.confirmation != nil }, set: { isUp in
            guard !isUp else { return }
            send(.deleteCancelled)
        })
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

    /// The highlight, read from the model and moved only by an action, the shape a text field's binding has
    /// (spec section 4).
    ///
    /// The highlight cannot be removed, which the owner chose on 2026-10-12. A Cmd-click on the highlighted row
    /// makes the List drop its own highlight and write nil, while the model and the pane keep the view. The nil
    /// is not sent, since no action takes it, and the model does not change, so nothing the module does would
    /// draw the List again. The view does it: the count moves, `body` runs again, and the List is handed
    /// `model.selection` once more. On 2026-10-12, with the highlight emptied through the accessibility API,
    /// the row was highlighted again within half a second; without the count it stayed empty. On a narrow window
    /// the highlight goes when the list's back button closes the list, which is the module's to do and is sent from
    /// the stack's path, not from here (`RootView`; the owner, 2026-10-21).
    private var selection: Binding<ViewID?> {
        _ = emptiedHighlights
        return Binding(get: { model.selection }, set: { id in
            if let id { send(.rowSelected(id)) } else { emptiedHighlights += 1 }
        })
    }
}

/// The move picker, drawn from its model with no look of its own until the plan's seventh task: "Top level" and the
/// rows in a plain list, each sending its tap, the present parent checked and the rows that cannot take the list
/// disabled, and Cancel in the bar.
private struct MovePickerList: View {
    let picker: TaskViewList.Model.MovePicker
    let send: (TaskViewList.UserAction) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button { send(.movePickerRowTapped(nil)) } label: {
                    HStack {
                        Text("Top level")
                        if picker.isTopLevelCurrent { Image(systemName: "checkmark") }
                    }
                }
                ForEach(picker.rows) { pickerRow in
                    Button { send(.movePickerRowTapped(pickerRow.id)) } label: {
                        HStack {
                            // The one switch over a row's kind in the picker, every case drawn (`docs/style.md`,
                            // "Views"): an area's line with its label, and a list's title.
                            switch pickerRow.row.kind {
                            case .area(let label):
                                if let label { Text(label) }
                                VStack { Divider() }
                            case .list(let list):
                                Text(list.title)
                            }
                            if pickerRow.isCurrent { Image(systemName: "checkmark") }
                        }
                        .padding(.leading, CGFloat(pickerRow.row.depth) * 16)
                    }
                    .disabled(pickerRow.isDisabled)
                }
            }
            .navigationTitle(picker.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { send(.movePickerCancelled) }
                }
            }
        }
        // A sheet on the Mac is as large as what it holds, and a list asks for no height of its own.
        .frame(minWidth: 320, minHeight: 400)
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
