// Apps/Apple/Sources/TodoAppleUI/RootView.swift
import AppFeature
import FeatureModule
import SwiftUI

/// The root of the tree of views, and beside the window's view, which holds the window and its host, the one view that
/// names the host: it hands the sidebar's view its model and a closure that wraps its actions in the root's, binds the
/// window's stack to the path of ids the model gives it, draws each element of it through one switch, and sends a pop
/// back whole (navigation state spec, sections 3 and 6), with the root's own sentence across the bottom of the window
/// and quick entry as a sheet over all of it. A wide window, the Mac's and the iPad's, is a split view with the
/// sidebar beside a stack whose root is the first screen over the sidebar, the list of the chosen view's tasks, and
/// the rest pushed in that stack. A narrow window, iPhone's and a narrow iPad's, is one stack with the views at its
/// root and every screen of the path pushed over them. The containers are the view's and the modules know nothing of
/// them; every binding is read from the model and set only by sending an action, and the stack's path only by
/// `.wentBack(to:)`. It reads neither the window's route nor which screen opens which.
struct RootView: View {
    private let host: ModuleHost<AppModule>

    /// Whether the window is narrow, which only the view can know (`docs/style.md`, "Views"), and which chooses the
    /// tree. A split view in a narrow window collapses into one stack whose screens SwiftUI pushes and pops from
    /// state of its own: in the iOS 26.3 simulator on 2026-10-21, on iPhone, a tap on the view still highlighted
    /// after Back pushed nothing (#107); a window opened on the views pushed no list for any tap or link (#116); and
    /// a list closed in the module when Back reached the views was slid back in over them, "Nothing to show" in it.
    /// A stack of its own has a path, and the path is the model's. Choosing the tree here, and cutting the path for
    /// the wide one, is the interim that #123 moves into the module, which will decide the layout from the width the
    /// view reports (navigation state spec, section 4).
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

    /// The wide window's tree: the sidebar beside the detail column, whose stack has the first screen over the
    /// sidebar at its root, or the placeholder when none stands, and the rest of the path pushed over it.
    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            NavigationStack(path: detailPath) {
                Group {
                    if let column = host.model.path.first {
                        screen(column)
                    } else {
                        Text("Nothing to show")
                            .foregroundStyle(.secondary)
                            .toolbar { quickEntryButton }
                    }
                }
                .navigationDestination(for: StackElementID.self, destination: screen)
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

    /// The narrow window's tree: the views at the root of one stack, and every screen of the model's path pushed
    /// over them, each drawn by the one destination.
    private var narrowStack: some View {
        NavigationStack(path: path) {
            sidebar
                .navigationDestination(for: StackElementID.self) { id in
                    screen(id)
                        // The sidebar's sentence on every screen pushed over the sidebar's rows, which draw it when
                        // they are on top, so it shows once on whichever screen is on top, a task's included (#110).
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

    /// One switch over the screens the window's stack can hold, the one place they are drawn: it picks a view per
    /// case, hands it its model and a closure that wraps its actions with its element's id, and decides nothing. Every
    /// case is drawn, with no `default`, so a kind of screen added to the stack and not drawn stops this view
    /// compiling (`docs/style.md`, "Views"; navigation state spec, section 6). An id the model no longer holds, one
    /// SwiftUI still draws while a pop the model drove plays out, draws nothing.
    ///
    /// The list carries the Quick Entry button on its toolbar, and the task pushed over it carries none (the owner,
    /// 2026-10-20).
    @ViewBuilder private func screen(_ id: StackElementID) -> some View {
        switch host.model.screens[id] {
        case .list(let model)?:
            TaskListView(model: model) { host.send(.screen(id, .list($0))) }
                .toolbar { quickEntryButton }
        case .task(let model)?:
            TaskScreenView(model: model)
        case nil:
            EmptyView()
        }
    }

    /// The narrow stack's path: every id of the model's path, read from the model and moved only by an action. A pop,
    /// by the back button, the swipe from the edge or the long-press menu that goes back several screens at once, is
    /// one write of a shorter path, which is sent whole as `.wentBack(to:)` and interpreted by the module (navigation
    /// state spec, section 3). The write SwiftUI makes after a pop the model drove, a task gone under its screen, is
    /// a path the module holds already, which moves nothing.
    private var path: Binding<[StackElementID]> {
        Binding(get: { host.model.path }, set: { host.send(.wentBack(to: $0)) })
    }

    /// The detail column's path in the wide window: the model's path after its first id, which stands at the column's
    /// root, so that a pop SwiftUI can reach leaves the list in place and the highlight cannot be removed. A write is
    /// sent whole with the column's id before it, as `.wentBack(to:)`. Cutting the path is the interim #123 moves
    /// into the module (navigation state spec, section 4).
    ///
    /// A path and not `navigationDestination(item:)` per screen, which lost the task a window opens with: on
    /// 2026-10-18, on macOS 26.7 under Swift 6.4.0, a window made from a path naming a task drew its list with nothing
    /// pushed, and the item binding's first write, as the window appeared, was nil, which closed the task, with no
    /// runtime warning. The same window over a path showed the task pushed and wrote nothing.
    private var detailPath: Binding<[StackElementID]> {
        Binding(get: { Array(host.model.path.dropFirst()) }, set: { written in
            host.send(.wentBack(to: Array(host.model.path.prefix(1)) + written))
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

    /// The toolbar's quick entry button, on the list or on the placeholder drawn when no list stands, and not on the
    /// task pushed over the list, which has none (the owner, 2026-10-20). Not on the split view: there it stood on the
    /// Mac's toolbar and on no screen of iPhone's collapsed stack, where each screen has a bar of its own (2026-10-18,
    /// the iOS 26.3 simulator).
    private var quickEntryButton: some View {
        Button("Quick Entry", systemImage: "plus") { host.send(.quickEntryButtonTapped) }
    }
}
