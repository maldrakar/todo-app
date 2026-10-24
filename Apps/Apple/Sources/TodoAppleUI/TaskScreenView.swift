// Apps/Apple/Sources/TodoAppleUI/TaskScreenView.swift
import SwiftUI
import TaskScreenFeature

/// One task on a screen of its own, pushed over the list in the window's stack: its title, and nothing a person can
/// do with it yet, so the view takes no closure, since the screen's actions have no case to send (`TaskScreen`,
/// `docs/specs/navigation.md`, section 10). The way back is the stack's back button, whose shorter path the root view
/// hands the window whole, and the list it uncovers closes the task (navigation state spec, section 3).
struct TaskScreenView: View {
    private let model: TaskScreen.Model

    init(model: TaskScreen.Model) {
        self.model = model
    }

    var body: some View {
        Text(model.title)
            .font(.title)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
