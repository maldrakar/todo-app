// Apps/Apple/Sources/TodoAppleUI/TaskListView.swift
import SwiftUI
import TaskListFeature
import TodoCore

/// The tasks of one view, drawn as the list assembled them, a row's tap sent as the one action its control is named
/// for (`docs/style.md`). It is the root of the stack in the window's detail column, and the task open in the list is
/// pushed over it: the list draws the task's screen out of its own model, as a parent draws its child, and the root
/// view binds the stack's path to the open task's head (`docs/specs/navigation.md`, section 6). What opens is the
/// list's to decide, so a row reports the tap and nothing else.
struct TaskListView: View {
    private let model: TaskList.Model
    private let send: (TaskList.UserAction) -> Void

    init(model: TaskList.Model, send: @escaping (TaskList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        VStack(spacing: 0) {
            List(model.rows) { row in
                // The whole row is the button, its title at the leading edge and the rest of the row a place to
                // click too: as a bordered button on the Mac the row answered only on the bezel around its title.
                Button {
                    send(.rowTapped(row.id))
                } label: {
                    Text(row.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            // Under the rows, as the sidebar draws its own. A sentence written while a task covered the list, a
            // link to a task that is gone among them, is first seen when the task is popped (`TaskList`).
            if let problem = model.problem {
                Text(problem)
                    .padding()
            }
        }
        // The path holds the open task's head and never its model (spec section 6), and the destination draws the
        // screen out of the list's model, which carries it. It is registered for `EntityID`, which `ViewID` is too,
        // and draws the open task whatever value it is handed, so a second kind of screen pushed into this stack needs
        // a type of its own for its destination. On 2026-10-20, on the Mac and in the iOS 26.3 simulator, a window
        // made from a path naming a task showed the task pushed, and a route into another view's task pushed it over
        // the new list.
        .navigationDestination(for: TaskID.self) { _ in
            if let task = model.task {
                TaskScreenView(model: task)
            }
        }
    }
}
