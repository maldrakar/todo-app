// Apps/Apple/Sources/TodoAppleUI/TaskListView.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature

/// The blocks of one list, drawn as plain sections until the list screen draws the components' models (list screen
/// plan, Task 8): each row's check, its title and its Delete, the card in its place with its fields, its subtasks, Open
/// full screen and a plain close, "+ Add task", "+ Add list", the strip and the rows under it, and the floating "+"
/// under the list, every control sent as the action its model carries (`docs/style.md`). A drop stays out, Task 8's and
/// 9's. It is the root of the stack in a wide window's detail column, and a screen pushed over the views in a narrow
/// window's one stack, and what the list declared over itself, a task or another list, is pushed over it either way,
/// drawn by the root view's one destination for the window's stack, so the list draws nothing of it (navigation state
/// spec, section 6). What opens is the list's to decide, so a row and a block's title report the tap and nothing else.
/// The screen's title is the header's, which names the list in the back button's menu over what stands on it (#126).
struct TaskListView: View {
    private let model: TaskList.Model
    private let send: (TaskList.UserAction) -> Void

    init(model: TaskList.Model, send: @escaping (TaskList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        let shape = shape
        VStack(spacing: 0) {
            List {
                ForEach(shape.blocks) { block in
                    Section {
                        ForEach(block.rows) { row in
                            rowView(row)
                        }
                        if let addTask = block.addTask {
                            addRow(addTask)
                        }
                    } header: {
                        // A block's header in the list, or its column's in columns, which this view draws as the same
                        // sections until the board is drawn (Task 8); its title opens what the block is, and its field
                        // stands in its place while the list is being named.
                        if let header = block.header ?? block.column?.header {
                            if let field = header.field {
                                PlainField(
                                    field, focusesOnAppear: true, changed: { .listNameFieldChanged($0) }, send: send
                                )
                            } else {
                                Button(header.title.text) { send(header.titleTapped) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                if let addList = shape.addList {
                    addRow(addList)
                }
                if let done = model.done {
                    Section {
                        Button(done.label.text) { send(done.action) }
                            .buttonStyle(.plain)
                        ForEach(model.doneRows) { row in
                            rowView(row)
                        }
                    }
                }
            }
            if let addTask = model.addTask {
                Button(addTask.accessibilityLabel) { send(addTask.action) }
                    .padding()
            }
            // Under the rows, as the sidebar draws its own. A sentence written while a screen covered the list, a link
            // to a task that is gone among them, is first seen when the screen is popped (`TaskList`).
            if let problem = model.problem {
                Text(problem)
                    .padding()
            }
        }
        .navigationTitle(model.header.title.text)
    }

    /// The blocks the layout holds, the list's or the board's columns, drawn alike here, and the row after them that
    /// adds a list: the one switch over the layout's shapes (`docs/style.md`, "Views").
    private var shape: (blocks: [TaskList.Model.Block], addList: AddRowModel<TaskList.UserAction>?) {
        switch model.layout {
        case .list(let blocks): (blocks, model.addList)
        case .columns(let board): (board.columns, board.addList)
        }
    }

    /// A row of a block or of the strip, by its kind: the one switch over a row's kinds (`docs/style.md`, "Views"). The
    /// title is the button that opens the task, its title at the leading edge and the rest of the row a place to click
    /// too: as a bordered button on the Mac the row answered only on the bezel around its title.
    @ViewBuilder private func rowView(_ row: TaskList.Model.Row) -> some View {
        switch row {
        case .task(_, let task):
            HStack {
                checkButton(task.check)
                Button {
                    send(task.tap)
                } label: {
                    Text(task.title.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                ForEach(task.menu?.sections.flatMap(\.items) ?? [], id: \.title) { item in
                    Button(item.title, role: item.isDestructive ? .destructive : nil) { send(item.action) }
                        .buttonStyle(.plain)
                }
            }
        case .card(_, let card):
            VStack(alignment: .leading) {
                HStack {
                    checkButton(card.check)
                    PlainField(
                        card.title, focusesOnAppear: card.title.text.isEmpty, changed: { .titleFieldChanged($0) },
                        send: send
                    )
                    Button(card.expand.label.accessibilityLabel) { send(card.expand.action) }
                        .buttonStyle(.plain)
                }
                PlainField(card.notes, focusesOnAppear: false, changed: { .notesFieldChanged($0) }, send: send)
                ForEach(Array(card.subtasks.enumerated()), id: \.offset) { _, subtask in
                    HStack {
                        checkButton(subtask.check)
                        Text(subtask.title.text)
                    }
                }
                if let field = card.subtaskField {
                    PlainField(field, focusesOnAppear: true, changed: { .subtaskFieldChanged($0) }, send: send)
                } else {
                    addRow(card.addSubtask)
                }
                HStack {
                    ForEach(Array(card.pills.enumerated()), id: \.offset) { _, pill in
                        Text(pill.text.text)
                    }
                }
                Button("Close") { send(card.backgroundTapped) }
                    .buttonStyle(.plain)
            }
        }
    }

    /// A check, a row's, a card's or a subtask's: a plain circle, filled while it is checked, which reads aloud what a
    /// tap will do.
    private func checkButton(_ check: CheckModel<TaskList.UserAction>) -> some View {
        Button {
            send(check.action)
        } label: {
            Image(systemName: check.isChecked ? "checkmark.circle.fill" : "circle")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(check.accessibilityLabel)
    }

    /// A row that adds, its title the button.
    private func addRow(_ row: AddRowModel<TaskList.UserAction>) -> some View {
        Button(row.title.text) { send(row.action) }
            .buttonStyle(.plain)
    }
}

/// A text field the module's field model drives and no look, until the list screen draws the card (list screen plan,
/// Task 8): what is typed goes up through `changed`, while the field has the focus, since a field writes its text back
/// through its binding as it goes too, and that echo, which names no card, would land on the one opened since; Return,
/// Esc and a lost focus go as the model's actions. It is its own view and not `TitleField`, which asks the caret back
/// on every lost focus and cannot stand beside another field.
private struct PlainField: View {
    private let model: TextFieldModel<TaskList.UserAction>
    private let focusesOnAppear: Bool
    private let changed: (String) -> TaskList.UserAction
    private let send: (TaskList.UserAction) -> Void

    @FocusState private var isFocused: Bool

    init(
        _ model: TextFieldModel<TaskList.UserAction>, focusesOnAppear: Bool,
        changed: @escaping (String) -> TaskList.UserAction, send: @escaping (TaskList.UserAction) -> Void
    ) {
        self.model = model
        self.focusesOnAppear = focusesOnAppear
        self.changed = changed
        self.send = send
    }

    var body: some View {
        field
            .focused($isFocused)
            .onSubmit { send(model.submitted) }
            .onChange(of: isFocused) { _, isFocused in
                if !isFocused { send(model.focusLost) }
            }
            .onAppear {
                if focusesOnAppear { isFocused = true }
            }
    }

    /// The field, which reads Esc where a keyboard has one: `onKeyPress` has no watchOS.
    @ViewBuilder private var field: some View {
        let text = TextField(model.placeholder, text: Binding(get: { model.text }, set: { text in
            if isFocused { send(changed(text)) }
        }))
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
