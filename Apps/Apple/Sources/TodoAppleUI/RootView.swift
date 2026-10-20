// Apps/Apple/Sources/TodoAppleUI/RootView.swift
import AppFeature
import SwiftUI
import TodoCore

/// The root of the tree of views, and beside the window's view, which holds the window and its host, the one view that
/// names the host: it hands each child's view its part of the root's model and a closure that wraps the child's
/// actions in the root's, and draws the one tree every Apple platform has (`docs/specs/navigation.md`, section 6), with
/// the root's own sentence across the bottom of the window. A split view with the sidebar beside a stack whose root is
/// the list of the chosen view's tasks, the task screen pushed in that stack, and quick entry as a sheet over all of
/// it: on the Mac and the iPad the columns stay and the task pushes inside the detail column, and on iPhone SwiftUI
/// collapses the split view into one stack, sidebar, list, task. The containers are this epic's choice and the modules
/// know nothing of them; what any tree keeps is that every binding is read from the model and set only by sending an
/// action.
struct RootView: View {
    private let host: ModuleHost<AppModule>

    /// Whether the window is narrow, which only the view can know (`docs/style.md`, "Views"). A split view in a
    /// narrow window is one stack and the sidebar is not beside the pane, so the sidebar's sentence is drawn in the
    /// pane's column too, where it can be read.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Which of the split view's columns are shown, which only the view can know (`docs/style.md`, "Views"): handed
    /// to the split view, which writes it as it lays its columns out, and read for whether the sidebar is beside the
    /// pane.
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    init(host: ModuleHost<AppModule>) {
        self.host = host
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            TaskViewListView(model: host.model.taskViewList) { host.send(.taskViewList($0)) }
        } detail: {
            NavigationStack(path: stackPath) {
                Group {
                    if let list = host.model.taskViewList.taskList {
                        TaskListView(model: list) { host.send(.taskViewList(.taskList($0))) }
                    } else {
                        Text("Nothing to show")
                            .foregroundStyle(.secondary)
                    }
                }
                .toolbar { quickEntryButton }
            }
            // The sidebar's sentence is about the pane that stayed when another could not be opened, so it shows
            // beside the pane: under the sidebar's rows where the sidebar's column is beside the pane, and here where
            // it is not, in a narrow window, where the sidebar is a screen the pane is pushed over, and when the split
            // view reports the sidebar's column hidden. On 2026-10-18 "The list could not be opened." stood here alone
            // on iPhone and on the iPad in portrait, whose split view hid the sidebar and reported `detailOnly` (the
            // iOS 26.3 simulator), and on the Mac whose toolbar button had hidden the sidebar, which reported
            // `detailOnly` too; on the Mac with its sidebar shown it stood under the sidebar's rows alone, and it moved
            // between the two as the button hid and showed the sidebar.
            .safeAreaInset(edge: .bottom) {
                if isSidebarAway, let problem = host.model.taskViewList.problem {
                    // On a material across the pane, so that the rows scrolling under it do not show through: the
                    // regular one, since the bar's is unavailable on watchOS and a condition here would be about the
                    // look alone (typechecked for macOS 14, iOS 17 and watchOS 10 on 2026-10-18).
                    Text(problem)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                }
            }
        }
        // The root's sentence is about the window, a link that could not be opened in it, so it shows across the
        // window and not under one column, on the same material as the pane's sentence, for the same reason.
        .safeAreaInset(edge: .bottom) {
            if let problem = host.model.problem {
                Text(problem)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
            }
        }
        .sheet(isPresented: isQuickEntryUp) {
            if let quickEntry = host.model.quickEntry {
                QuickEntryView(model: quickEntry) { host.send(.quickEntry($0)) }
            }
        }
    }

    /// The stack's path: the head of the task open in the list, or nothing, the route's chain below the list mapped
    /// into the path the stack pushes the task screen for, read from the route the host publishes and moved only by
    /// an action (spec section 6, "Risks").
    ///
    /// A path and not `navigationDestination(item:)` bound to the head, which spec section 6 names, because the item
    /// lost the task a window opens with: on 2026-10-18, on macOS 26.7 under Swift 6.4.0, a window made from a path
    /// naming a task drew its list with nothing pushed, and the item binding's first write, as the window appeared,
    /// was nil, which went to the list as its back button and closed the task, with no runtime warning. The same
    /// window over this path showed the task pushed and wrote nothing. A route into another view's task while a
    /// task was open pushed the new task over the new list either way. This is the fallback the spec's "Risks" name,
    /// a map and not a decision: the state is the route's as before. In the iOS 26.3 simulator the same path at
    /// creation left three screens in the collapsed stack, the sidebar, the list and the task.
    ///
    /// A pop, by the back button or by the swipe back, is one write of the path without the task, which goes to the
    /// list as its back button. A write of a path that still holds a task sends nothing, since only the module opens
    /// one. The write SwiftUI makes after a pop the model drove, a task gone under its screen, reaches a list with
    /// no screen open, which moves nothing, the list's sentence included (`TaskList`).
    private var stackPath: Binding<[TaskID]> {
        Binding(get: { host.route.sidebar.list?.task.map { [$0.head] } ?? [] }, set: { path in
            guard path.isEmpty else { return }
            host.send(.taskViewList(.taskList(.backButtonTapped)))
        })
    }

    /// Whether quick entry is up, read from the model and moved only by an action (spec section 5). The swipe down
    /// and Esc are one write of false, which goes to quick entry as its Cancel button, and quick entry closes
    /// itself; the write of false after a close the model drove, a task created, reaches no quick entry and moves
    /// nothing (`AppModule`). Nothing writes true, since only the toolbar's button opens it.
    private var isQuickEntryUp: Binding<Bool> {
        Binding(get: { host.model.quickEntry != nil }, set: { isUp in
            guard !isUp else { return }
            host.send(.quickEntry(.cancelButtonTapped))
        })
    }

    /// The toolbar's quick entry button, on the root of the stack, the list or the placeholder drawn when no list is
    /// open, and not on the task pushed over it, which has none (the owner, 2026-10-20). Not on the split view: there
    /// it stood on the Mac's toolbar and on no screen of iPhone's collapsed stack, where each screen has a bar of its
    /// own (2026-10-18, the iOS 26.3 simulator).
    private var quickEntryButton: some View {
        Button("Quick Entry", systemImage: "plus") { host.send(.quickEntryButtonTapped) }
    }

    /// Whether the sidebar is not beside the pane: the split view is one stack in a narrow window (spec section 6),
    /// or it reports its sidebar's column hidden, `detailOnly`, as the iPad's did in portrait (2026-10-18).
    private var isSidebarAway: Bool { horizontalSizeClass == .compact || columnVisibility == .detailOnly }
}
