// Apps/Apple/Sources/TodoAppleUI/RootView.swift
import AppFeature
import SwiftUI

/// The root of the tree of views, and the one view that names the host: it hands the list its part of the
/// root's model and a closure that wraps the list's actions in the root's, and draws the pane beside it (spec
/// sections 3 and 4).
struct RootView: View {
    private let host: ModuleHost<AppModule>

    init(host: ModuleHost<AppModule>) {
        self.host = host
    }

    var body: some View {
        NavigationSplitView {
            TaskViewListView(model: host.model.taskViewList) { host.send(.taskViewList($0)) }
        } detail: {
            if let list = host.model.taskList {
                List(list.rows) { Text($0.title) }
            } else {
                Text("Nothing to show")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
