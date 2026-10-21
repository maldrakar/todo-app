// Apps/Apple/Sources/TodoAppleUI/RootView.swift
import AppFeature
import SwiftUI
import TodoCore

/// The root of the tree of views, and beside the window's view, which holds the window and its host, the one view that
/// names the host: it hands each child's view its part of the root's model and a closure that wraps the child's
/// actions in the root's, and draws the tree of the window's width (`docs/specs/navigation.md`, section 6, amended
/// 2026-10-21), with the root's own sentence across the bottom of the window and quick entry as a sheet over all of
/// it. A wide window, the Mac's and the iPad's, is a split view with the sidebar beside a stack whose root is the list
/// of the chosen view's tasks, the task screen pushed in that stack. A narrow window, iPhone's and a narrow iPad's, is
/// one stack with the views at its root and the list and the task pushed over them. The containers are this epic's
/// choice and the modules know nothing of them; what any tree keeps is that every binding is read from the model and
/// set only by sending an action.
struct RootView: View {
    private let host: ModuleHost<AppModule>

    /// Whether the window is narrow, which only the view can know (`docs/style.md`, "Views"), and which chooses the
    /// tree. A split view in a narrow window collapses into one stack whose screens SwiftUI pushes and pops from
    /// state of its own: in the iOS 26.3 simulator on 2026-10-21, on iPhone, a tap on the view still highlighted
    /// after Back pushed nothing (#107); a window opened on the views pushed no list for any tap or link (#116); and
    /// a list closed in the module when Back reached the views was slid back in over them, "Nothing to show" in it.
    /// A stack of its own has a path, and the path is read from the route, so the screens are the route.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Which of the split view's columns are shown, which only the view can know (`docs/style.md`, "Views"): handed
    /// to the split view, which writes it as it lays its columns out, and read for whether the sidebar is beside the
    /// pane.
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    init(host: ModuleHost<AppModule>) {
        self.host = host
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                narrowStack
            } else {
                splitView
            }
        }
        // The root's sentence is about the window, a link that could not be opened in it, so it shows across the
        // window and not under one column, drawn as the pane's sentence is. On 2026-10-20, on macOS 26.7.1, it stood
        // across the bottom of the window under the sidebar and the pane, and the sidebar's column ended above it.
        .safeAreaInset(edge: .bottom) {
            if let problem = host.model.problem {
                sentenceStrip(problem)
            }
        }
        .sheet(isPresented: isQuickEntryUp) {
            if let quickEntry = host.model.quickEntry {
                QuickEntryView(model: quickEntry) { host.send(.quickEntry($0)) }
            }
        }
    }

    /// The wide window's tree: the sidebar beside the pane, and the task pushed in the pane's own stack.
    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            NavigationStack(path: stackPath) {
                pane
            }
            // The sidebar's sentence is about the pane that stayed when another could not be opened, so it shows
            // beside the pane: under the sidebar's rows where the sidebar's column is beside the pane, and here when
            // the split view reports the sidebar's column hidden. On 2026-10-18 "The list could not be opened." stood
            // here alone on the iPad in portrait, whose split view hid the sidebar and reported `detailOnly` (the
            // iOS 26.3 simulator), and on the Mac whose toolbar button had hidden the sidebar, which reported
            // `detailOnly` too; on the Mac with its sidebar shown it stood under the sidebar's rows alone, and it moved
            // between the two as the button hid and showed the sidebar.
            .safeAreaInset(edge: .bottom) {
                if columnVisibility == .detailOnly, let problem = host.model.taskViewList.problem {
                    sentenceStrip(problem)
                }
            }
        }
    }

    /// The narrow window's tree: the views at the root of one stack, and the list and the task pushed over them as
    /// the route names them (`narrowPath`). The list's screen is the pane the wide window draws, and the task's
    /// screen is pushed by the list's own destination (`TaskListView`).
    private var narrowStack: some View {
        NavigationStack(path: narrowPath) {
            sidebar
                .navigationDestination(for: PushedList.self) { _ in
                    pane
                        // The sidebar's sentence on the screen pushed over the sidebar's rows, which draw it too
                        // when they are on top, so it shows beside the pane once, as in the wide window.
                        .safeAreaInset(edge: .bottom) {
                            if let problem = host.model.taskViewList.problem {
                                sentenceStrip(problem)
                            }
                        }
                }
        }
    }

    /// The list of views, the same in both trees.
    private var sidebar: some View {
        TaskViewListView(model: host.model.taskViewList) { host.send(.taskViewList($0)) }
    }

    /// The pane: the list of the chosen view's tasks, or a placeholder when none is open, with the Quick Entry
    /// button on its toolbar.
    private var pane: some View {
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

    /// The pane's stack's path in the wide window: the head of the task open in the list, or nothing, the route's
    /// chain below the list mapped into the path the stack pushes the task screen for, read from the route the host
    /// publishes and moved only by an action (spec section 6, "Risks").
    ///
    /// A path and not `navigationDestination(item:)` bound to the head, which spec section 6 names, because the item
    /// lost the task a window opens with: on 2026-10-18, on macOS 26.7 under Swift 6.4.0, a window made from a path
    /// naming a task drew its list with nothing pushed, and the item binding's first write, as the window appeared,
    /// was nil, which went to the list as its back button and closed the task, with no runtime warning. The same
    /// window over this path showed the task pushed and wrote nothing. A route into another view's task while a
    /// task was open pushed the new task over the new list either way. This is the fallback the spec's "Risks" name,
    /// a map and not a decision: the state is the route's as before.
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

    /// The narrow stack's path: the list open beside the views, then the task open in it, read from the route the
    /// host publishes and moved only by an action, as the wide window's path is. A `NavigationPath` and not an
    /// array, because the list's head and the task's are both an `EntityID`, and the task goes in as itself, so that
    /// the list's own destination pushes its screen.
    ///
    /// A pop writes a shorter path. One that keeps the list goes to the list as its back button, as in the wide
    /// window, and one without the list goes to the views as the list's back button, which closes the list and the
    /// highlight with it (`TaskViewList`); a pop from the task straight to the views, through the back button's
    /// menu, is that one write. A write that still holds the task sends nothing, since only the module opens one.
    /// The write SwiftUI makes after a pop the model drove reaches a module with nothing open at that depth, which
    /// moves nothing (`TaskList`, `TaskViewList`).
    private var narrowPath: Binding<NavigationPath> {
        Binding(get: {
            var path = NavigationPath()
            if let list = host.route.sidebar.list {
                path.append(PushedList(head: list.head))
                if let task = list.task { path.append(task.head) }
            }
            return path
        }, set: { path in
            switch path.count {
            case 0: host.send(.taskViewList(.listBackButtonTapped))
            case 1: host.send(.taskViewList(.taskList(.backButtonTapped)))
            default: break
            }
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

    /// A sentence across the width of what it is drawn under, the pane or the window, on a material so that the rows
    /// scrolling under it do not show through: the regular one, since the bar's is unavailable on watchOS and a
    /// condition here would be about the look alone (typechecked for macOS 14, iOS 17 and watchOS 10 on 2026-10-18).
    private func sentenceStrip(_ sentence: String) -> some View {
        Text(sentence)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
    }

    /// The toolbar's quick entry button, on the pane, the list or the placeholder drawn when no list is open, and not
    /// on the task pushed over it, which has none (the owner, 2026-10-20). Not on the split view: there it stood on
    /// the Mac's toolbar and on no screen of iPhone's collapsed stack, where each screen has a bar of its own
    /// (2026-10-18, the iOS 26.3 simulator).
    private var quickEntryButton: some View {
        Button("Quick Entry", systemImage: "plus") { host.send(.quickEntryButtonTapped) }
    }
}

/// The list as an element of the narrow stack's path, its view's head in a type of its own: a task's head is an
/// `EntityID` too, and the task's destination is registered for that type (`TaskListView`).
private struct PushedList: Hashable {
    let head: ViewID
}
