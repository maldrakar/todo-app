// Apps/Apple/Sources/TodoAppleUI/TaskListView.swift
import SwiftUI
import TaskListFeature

/// The tasks of one view, drawn as the list assembled them, a row's tap sent as the one action its control is named
/// for (`docs/style.md`). It is the root of the stack in the window's detail column, and the task opened from a row is
/// pushed over it by the root view, which binds the stack to the open task's head (`docs/specs/navigation.md`,
/// section 6): what opens is the list's to decide, so a row reports the tap and nothing else.
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
                Button(row.title) { send(.rowTapped(row.id)) }
            }
            // Under the rows, as the sidebar draws its own. A sentence written while a task covered the list, a
            // link to a task that is gone among them, is first seen when the task is popped (`TaskList`).
            if let problem = model.problem {
                Text(problem)
                    .padding()
            }
        }
    }
}
