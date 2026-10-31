// Apps/Apple/Sources/TodoAppleUI/TaskViewListView.swift
import DesignSystemComponents
import SwiftUI
import TaskViewListFeature
import TodoCore

/// The list of views, drawn as the module assembled it, every gesture sent as the action its control's model holds
/// (spec section 2). A deselect is no gesture here: the List cannot remove the highlight (`selection`). It knows
/// nothing about renaming beyond what a row says: a row whose model has a field draws the field, and every other row
/// what its kind is, through the one switch over it in the tree (`docs/style.md`, "Views"): an area's line with its
/// label, and a list's title. It has no title of its own, so its row in the back button's menu over a screen pushed on
/// it is empty, where the screens over it are named by theirs (the owner, 2026-10-25, #126).
///
/// The Lists screen's look, the tiles, the counts, the chevrons and the bar, is the plan's ninth task's here: until
/// then this view draws the rows' words, their menus and the dialogs from the models of the screen's components, in
/// the layout it had (Lists screen plan, Tasks 5 and 8), and the edits as plainly: the confirmation as an alert, the
/// move picker as a sheet of a plain list, and edit mode from a button on the toolbar (Task 6). Each row has its
/// model's menu, so none in edit mode, and an area's line its own, Rename, New List and Delete Area (the controller's
/// ruling on #161).
struct TaskViewListView: View {
    private let model: TaskViewList.Model
    private let send: (TaskViewList.UserAction) -> Void

    /// Whether the list has the keyboard, which only the view can know (spec section 2).
    @FocusState private var isListFocused: Bool

    /// How many times the List has emptied its own highlight. Nothing uses the number: `selection` reads the
    /// property while `body` runs, so that a change runs `body` again.
    @State private var emptiedHighlights = 0

    init(model: TaskViewList.Model, send: @escaping (TaskViewList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        VStack(spacing: 0) {
            List(model.rows, selection: selection) { row in
                // The one switch over a row's kind in the tree, every case drawn and no `default`.
                switch row.kind {
                case .area(let line):
                    treeRow(depth: row.depth, field: line.field, menu: line.menu) { lineLabel(line) }
                case .list(let list):
                    // A tap on the title is the row's choice, the highlighted row's too, which the List does not
                    // report: on the Mac a click on the highlighted row moves no highlight and writes no selection,
                    // so the task open in its list stayed open, where a click on the highlighted view closes it
                    // (`TaskViewList`). It replaces the List's own selection on the title, which fills the row; the
                    // row's insets and a nested row's indent stay the List's, and the arrow keys still go through
                    // `selection`. On 2026-10-18, on the Mac: a click on a view's title or on the rest of its row chose
                    // it, one action each, and on the highlighted view closed its task; the same day, a tap on the
                    // title's text alone, sent only for the highlighted row, left a click on another view's title
                    // choosing nothing. On 2026-10-20, in the iOS 26.3 simulator, a tap on another view's row pushed
                    // its list on iPhone, and on the iPad a tap on the highlighted view closed its task.
                    treeRow(depth: row.depth, field: list.field, menu: list.menu) { titleLabel(list, send: send) }
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
        #if !os(watchOS)
        // The sidebar's "+", a menu with an item for each thing it makes, each sending the action its item is named for:
        // where a list or an area goes, and that New Task is quick entry, is the module's to decide (Lists screen spec,
        // section 8). The look is the plan's Task 9, which draws the bar's model here; until then the toolbar keeps its
        // own layout and words, since the bar's model holds the phone's controls, Edit inside "…" and, in edit mode,
        // + List and + Area in place of "+". Not on the watch, where `Menu` is unavailable (a file typechecked against
        // the watchOS 10 SDK with Xcode 27.1 on 2026-10-27), and whose build is a compile check in this epic, as it is
        // for the row's menu above.
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
        // The confirmation as an alert and the picker as a sheet of a plain list (`ListsDialogs`).
        .modifier(ListsDialogs(model: model, send: send) { MovePickerList(model: $0, send: send) })
    }

    /// A row of the tree: the field while the row is being renamed, and its label otherwise, indented by its depth,
    /// with its menu where its model has one.
    private func treeRow(
        depth: Int, field: TextFieldModel<TaskViewList.UserAction>?, menu: MenuModel<TaskViewList.UserAction>?,
        @ViewBuilder label: () -> some View
    ) -> some View {
        Group {
            if let field {
                TitleField(field, changed: TaskViewList.UserAction.titleFieldChanged, send: send)
            } else {
                label()
            }
        }
        // The tree as the flat rows carry it: a number to indent by, so that drawing it decides nothing
        // (`TaskViewList`).
        .padding(.leading, CGFloat(depth) * 16)
        #if !os(watchOS)
        // Not on the watch, where the modifier is deprecated since watchOS 7, so the watch's build, a compile check in
        // this epic (`docs/specs/navigation.md`, section 8), leaves the whole menu out, Rename with it. A row with no
        // menu, every row in edit mode, has an empty one, which opens as none. Open in New Window, where a list's menu
        // has it, asks for the window, and the root passes the request on as its output, which the window's view
        // answers by opening the window (`WindowView`).
        .contextMenu {
            if let menu {
                MenuItems(menu, send: send)
            }
        }
        #endif
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

/// The move picker, drawn from its model with no look of its own until the plan's ninth task: "Top level" and the rows
/// in a plain list, each sending its tap, each row indented by its model's leading, the present parent checked and
/// the rows that cannot take the list disabled, and Cancel in the bar, every word the model's.
private struct MovePickerList: View {
    let model: PickerModel<TaskViewList.Model.Kind, TaskViewList.UserAction>
    let send: (TaskViewList.UserAction) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button { send(model.topLevel.action) } label: {
                    HStack {
                        Text(model.topLevel.title.text)
                        check(model.topLevel.accessories)
                    }
                    .padding(.leading, model.topLevel.leading)
                }
                ForEach(model.options.indices, id: \.self) { index in
                    let option = model.options[index]
                    // The one switch over a row's kind in the picker, every case drawn and no `default`.
                    switch option.row {
                    case .area(let line):
                        choice(option, tap: line.tap, leading: line.leading, accessories: line.accessories) {
                            lineLabel(line)
                        }
                    case .list(let list):
                        // The row's tap, which its button sends, and which a list's title sends too, since the
                        // title's own gesture is the one a tap on it reaches. A greyed-out row's, should that gesture
                        // still take one, moves nothing in the module.
                        choice(option, tap: list.tap, leading: list.leading, accessories: list.accessories) {
                            titleLabel(list, send: send)
                        }
                    }
                }
            }
            .navigationTitle(model.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.cancel.title, role: model.cancel.isDestructive ? .destructive : nil) {
                        send(model.cancel.action)
                    }
                }
            }
        }
        // A sheet on the Mac is as large as what it holds, and a list asks for no height of its own.
        .frame(minWidth: 320, minHeight: 400)
    }

    /// An option as a button that sends the row's tap, with the check where it is the present choice, disabled where it
    /// cannot be chosen.
    private func choice(
        _ option: PickerModel<TaskViewList.Model.Kind, TaskViewList.UserAction>.Option, tap: TaskViewList.UserAction,
        leading: Double, accessories: [AccessoryModel<TaskViewList.UserAction>], @ViewBuilder label: () -> some View
    ) -> some View {
        Button { send(tap) } label: {
            HStack {
                label()
                check(accessories)
            }
            .padding(.leading, leading)
        }
        .disabled(option.isDisabled)
    }

    /// The check where the model puts one at a row's right, its symbol alone, as this picker drew it before the
    /// components' models (Task 6). The rest of what stands there, the room for the check on every other row, is the
    /// phone's look, which this plain list leaves out until the plan's ninth task.
    private func check(_ accessories: [AccessoryModel<TaskViewList.UserAction>]) -> some View {
        ForEach(accessories.indices, id: \.self) { index in
            // The one switch over what stands at a row's right in this picker, every case drawn and no `default`.
            switch accessories[index] {
            case .check(let check):
                Image(check.icon)
            case .count, .chevron, .grip, .space:
                EmptyView()
            }
        }
    }
}

/// An area's line as the tree and the move picker label it, with its name beside it when it has one.
///
/// The line takes no highlight, so that a click on it puts none there: an area never opens, and the module moves
/// nothing for `.rowSelected` on it, so a highlight the List put there would stay beside the list of the view chosen
/// before. The picker's List keeps no selection, so it is nothing there. A function and not a view of its own, so that
/// the line's selection trait reaches the List's row as it did when the switch stood in the row itself.
private func lineLabel(_ line: AreaLineModel<TaskViewList.UserAction>) -> some View {
    HStack {
        if let label = line.label { Text(label.text) }
        VStack { Divider() }
    }
    .selectionDisabled()
}

/// A list's title as the tree and the move picker label it, which fills the row to its trailing edge so that a tap on
/// it covers the row past the title's text and sends the row's tap.
private func titleLabel(
    _ list: ListRowModel<TaskViewList.UserAction>, send: @escaping (TaskViewList.UserAction) -> Void
) -> some View {
    Text(list.title.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture { send(list.tap) }
}
