// Apps/Apple/Sources/TodoAppleUI/RootView.swift
import AppFeature
import FeatureModule
import SwiftUI

/// The root of the tree of views, and beside the window's view, which holds the window and its host, the one view that
/// names the host: it hands the sidebar's view its model and a closure that wraps its actions in the root's, draws the
/// layout the model gives it, binds each stack to the path of ids the layout carries, draws each element of the
/// window's stack through one switch, and sends a pop back whole (navigation state spec, sections 3, 4 and 6), with
/// the root's own sentence across the bottom of the window and quick entry as a sheet over all of it. A wide window,
/// the Mac's and a wide iPad window, is a split view with the sidebar beside a stack whose root is the layout's column,
/// the list of the chosen view's tasks, and the layout's path pushed in that stack. A narrow window, iPhone's and a
/// narrow iPad window, is one stack with the views at its root and every screen of the layout's path pushed over them.
/// The containers are the view's and the modules know nothing of them; which of the two a window has is the root
/// module's, decided from the width the window's view reports, and this view switches over the layout once and
/// chooses nothing by the width (`docs/style.md`, "Views"). Every binding is read from the model and set only by
/// sending an action, and a stack's path only by `.wentBack(to:)`. It reads neither the window's route nor which
/// screen opens which.
struct RootView: View {
    private let host: ModuleHost<AppModule>

    /// Which of the split view's columns are shown, which only the view can know (`docs/style.md`, "Views"): handed
    /// to the split view, which writes it as it lays its columns out, and read for whether the sidebar is beside the
    /// pane, in the body of `HiddenSidebarStrip` and never in this view's, whose stack it would leave drawing the list
    /// through a pushed task on the Mac (#133).
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    init(host: ModuleHost<AppModule>) {
        self.host = host
    }

    var body: some View {
        VStack(spacing: 0) {
            // The one switch over the layout, every shape drawn and none by `default` (`docs/style.md`, "Views"). A
            // window that narrows or widens gets the other shape from the root in the event its view reported, with the
            // same screens, and is drawn in the other tree.
            Group {
                switch host.model.layout {
                case .narrow(let path):
                    narrowStack(path: path)
                case .wide(let column, let path):
                    splitView(column: column, path: path)
                }
            }
            // The root's sentence is about the window, a link that could not be opened in it, so it shows across the
            // window and not under one column, drawn as the pane's sentence is. Under the containers and not inset over
            // them, so that they end above it and the sidebar's sentence, under the sidebar's rows or inset on a
            // screen, stands above it. Inset over them, it covered the sidebar's (#131): in the iOS 26.3 simulator on
            // 2026-10-24 the inset reached the root screen of a stack alone, and on a screen pushed over it both strips
            // stood in one frame at the bottom; on 2026-10-25, on macOS 26.7.1, with both sentences sent by a scratch
            // build, since no link reaches the executable while it runs, the sidebar's stood under the root's strip,
            // under the rows and at the bottom of the pane alike. Under them, the same day, both showed: on iPhone, and
            // on the iPad and the Mac with the sidebar hidden, the sidebar's right above the root's; with the sidebar
            // shown, the sidebar's under its rows and the root's across the window under both columns, which ended
            // above it. On iPhone the last row of a list scrolled to its end stands above the strip, where under the
            // inset it stood under it, and when the strip goes it rests 34 pt low, over the home indicator, until the
            // next scroll. While it shows, the Mac's toolbar draws an opaque bar over the pane where over the inset it
            // was clear, which the executable cannot show today, since nothing it receives writes the root's sentence.
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

    /// The wide window's tree: the sidebar beside the detail column, whose stack has the layout's column at its root,
    /// or the placeholder when no screen stands over the sidebar, and the layout's path pushed over it.
    ///
    /// The sidebar's sentence is about the pane that stayed when another could not be opened, so it shows beside the
    /// pane: under the sidebar's rows where the sidebar's column is beside the pane, and at the bottom of every screen
    /// of the stack when the split view reports the sidebar's column hidden. On 2026-10-18 the split view reported
    /// `detailOnly` on the iPad in portrait, where it hid the sidebar (the iOS 26.3 simulator), and on the Mac, whose
    /// toolbar button had hidden the sidebar; on the Mac with its sidebar shown the sentence stood under the sidebar's
    /// rows alone, and it moved between the rows and the pane as the button hid and showed the sidebar. On each screen
    /// and not on the stack, whose inset reached its root screen alone: on 2026-10-24 it stood mid-pane right under the
    /// placeholder on the iPad (the iOS 26.3 simulator) and on macOS 26.7.1, and a task pushed on the iPad had none
    /// (#110). Whether the column is hidden is read by a view of its own on each screen, `HiddenSidebarStrip`, so that
    /// a press of the sidebar's button redraws the strip and not this tree (#133).
    private func splitView(column: StackElementID?, path: [StackElementID]) -> some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            NavigationStack(path: stackPath(path)) {
                Group {
                    if let column {
                        screen(column)
                    } else {
                        Text("Nothing to show")
                            .foregroundStyle(.secondary)
                            // The whole pane, so that the sentence under the placeholder stands at its bottom.
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .toolbar { quickEntryButton }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    HiddenSidebarStrip(columnVisibility: $columnVisibility, strip: sidebarSentence)
                }
                .navigationDestination(for: StackElementID.self) { id in
                    screen(id)
                        .safeAreaInset(edge: .bottom) {
                            HiddenSidebarStrip(columnVisibility: $columnVisibility, strip: sidebarSentence)
                        }
                }
            }
        }
    }

    /// The narrow window's tree: the views at the root of one stack, and every screen of the layout's path pushed
    /// over them, each drawn by the one destination.
    ///
    /// One stack, and not a split view, which collapses in a narrow window into one stack whose screens SwiftUI
    /// pushes and pops from state of its own: in the iOS 26.3 simulator on 2026-10-21, on iPhone, a tap on the view
    /// still highlighted after Back pushed nothing (#107); a window opened on the views pushed no list for any tap or
    /// link (#116); and a list closed in the module when Back reached the views was slid back in over them, "Nothing
    /// to show" in it. A stack of its own has a path, and the path is the model's.
    private func narrowStack(path: [StackElementID]) -> some View {
        NavigationStack(path: stackPath(path)) {
            sidebar
                .navigationDestination(for: StackElementID.self) { id in
                    screen(id)
                        // The sidebar's sentence on every screen pushed over the sidebar's rows, which draw it when
                        // they are on top, so it shows once on whichever screen is on top, a task's included (#110).
                        .safeAreaInset(edge: .bottom) { sidebarSentence }
                }
        }
    }

    /// The strip with the sidebar's sentence for a screen of the window's stack, the one strip both trees inset at the
    /// bottom of their screens: the sidebar's rows put the sentence under them as text of their own, and a screen of
    /// the stack carries this strip where the rows are out of sight, hidden beside it or covered by it.
    @ViewBuilder private var sidebarSentence: some View {
        if let problem = host.model.taskViewList.problem {
            sentenceStrip(problem)
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
    /// SwiftUI still draws while a pop plays out, draws nothing and fills the screen, so the sidebar's sentence on
    /// that screen stays at its bottom: over an empty view it jumped to the middle of the screen sliding away, on
    /// iPhone and on the iPad (the iOS 26.3 simulator, 2026-10-24, #110). It has no title either, so a task popped
    /// by Back takes its title out of the bar as the pop starts, as it takes its text off the screen: with slow
    /// animations on an iPhone 17, the first frame of the pop showed the back button alone over a blank screen
    /// sliding away (the iOS 26.3 simulator, 2026-10-25, #126).
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
            Color.clear
        }
    }

    /// A stack's path, the one the layout carries, read from the model and moved only by an action, in both trees. A
    /// pop, by the back button, the swipe from the edge or the long-press menu that goes back several screens at once,
    /// is one write of a shorter path, which is sent whole as `.wentBack(to:)`, as SwiftUI wrote it, and the module
    /// reads it against the layout it has when the write arrives (navigation state spec, sections 3 and 4), the one
    /// this tree was drawn from unless the width moved in between, which no write crossed in the probes of 2026-10-24:
    /// in the wide tree the column is not in the path, so no write can pop it and the highlight cannot be removed. The
    /// write SwiftUI makes after a pop the model drove, a task gone under its screen, is a path the module holds
    /// already, which moves nothing.
    ///
    /// The getter answers the path the switch over the layout bound, and reads the layout no second time, which would
    /// be a second condition over it (`docs/style.md`, "Views"): when the model moves, the body runs again and the
    /// stack is handed a binding over the new path.
    ///
    /// A path and not `navigationDestination(item:)` per screen, which lost the task a window opens with: on
    /// 2026-10-18, on macOS 26.7 under Swift 6.4.0, a window made from a path naming a task drew its list with nothing
    /// pushed, and the item binding's first write, as the window appeared, was nil, which closed the task, with no
    /// runtime warning. The same window over a path showed the task pushed and wrote nothing.
    private func stackPath(_ path: [StackElementID]) -> Binding<[StackElementID]> {
        Binding(get: { path }, set: { host.send(.wentBack(to: $0)) })
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
    /// scrolling under the pane's strip do not show through, and the window's, which no row reaches, looks the same:
    /// the regular one, since the bar's is unavailable on watchOS and a condition here would be about the look alone
    /// (typechecked for macOS 14, iOS 17 and watchOS 10 on 2026-10-18).
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

/// The sidebar's strip on a screen of the wide window's stack, drawn while the split view reports the sidebar's column
/// hidden, a view of its own so that the column's visibility is read in its body and not in the root's (#133). A root
/// whose body read it was drawn again in the update that hid or showed the sidebar, and handed the stack a new path
/// binding there, and from then on the task pushed over the list lost its background and its bar and the list showed
/// through it: on macOS 26.7.1 on 2026-10-25, in both directions, on each commit tried since the first split view,
/// and in a throwaway app only with both, the read and a binding made anew on each pass, while either alone, or the
/// read with a binding the stack kept, drew the task clean. The iPad, in the iOS 26.3 simulator, drew it clean either
/// way.
private struct HiddenSidebarStrip<Strip: View>: View {
    /// The split view's columns, handed as the binding and not as its value, since reading the value where this view is
    /// made would be the root's read.
    let columnVisibility: Binding<NavigationSplitViewVisibility>
    let strip: Strip

    var body: some View {
        if columnVisibility.wrappedValue == .detailOnly {
            strip
        }
    }
}
