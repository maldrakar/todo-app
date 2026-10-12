// Apps/Apple/Sources/TodoAppleUI/RootView.swift
import AppFeature
import SwiftUI

/// The root of the tree of views, and the one view that names the host: it hands the list its part of the
/// root's model and a closure that wraps the list's actions in the root's, and draws the pane beside it (spec
/// sections 3 and 4).
struct RootView: View {
    let host: ModuleHost<AppModule>

    var body: some View {
        NavigationSplitView {
            TaskViewListView(model: host.model.taskViewList) { host.send(.taskViewList($0)) }
        } detail: {
            if let detail = host.model.detail {
                Text(detail.title)
            } else {
                Text("No view selected")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
