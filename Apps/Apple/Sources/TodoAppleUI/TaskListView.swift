// Apps/Apple/Sources/TodoAppleUI/TaskListView.swift
import SwiftUI
import TaskListFeature

/// The tasks of one view, drawn as the list assembled them, a row's tap sent as the one action its control is named
/// for (`docs/style.md`). It is the root of the stack in a wide window's detail column, and a screen pushed over the
/// views in a narrow window's one stack, and the task the list declared is pushed over it either way, drawn by the
/// root view's one destination for the window's stack, so the list draws nothing of it (navigation state spec,
/// section 6). What opens is the list's to decide, so a row reports the tap and nothing else. The screen's title is the
/// view's, which names the list in the back button's menu over the task (#126).
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
        .navigationTitle(model.title)
    }
}
