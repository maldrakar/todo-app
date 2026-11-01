// Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsSidebar.swift
import SwiftUI
import TaskViewListFeature

/// The list of views in the sidebar of a wide window, the Mac's and the iPad's alike, as the canvas's Mac board draws
/// it (`Mac.dc.html`; Lists screen spec, section 8): the tree (`ListsTree`) on the sidebar colour, which the phone's
/// Lists screen draws too, with the bar at the bottom of the column (`Bar`), the sentence above the bar, and the
/// confirmation of a delete as an alert and Move to… as a sheet (`ListsDialogs`, `MovePickerSheet`). The module builds
/// every model it draws for the wide window, with the sidebar's numbers, so it decides nothing the phone's screen does
/// not: where the platform has edit mode, the iPad's, its rows carry the phone's gestures and its bar is the phone's,
/// "…", the search capsule and "+", and edit mode's; where it has none, the Mac's, the bar is the board's, the search
/// field and "+" with its menu's keys, and the pointer drags a row at any time. A secondary click on the Mac and a long
/// press on the iPad open a row's menu, as `contextMenu` does on each.
///
/// The column is the container's, the view's: the board's sidebar colour behind the tree and the bar, the tree 2 pt
/// below the column's top and its last row 14 above the bar at the end of a scroll (`Mac.dc.html`, the tree's content
/// padding), and its width, which the split view's column takes (`RootView`). The board's top strip with its traffic
/// lights and button, its trailing border and its drawn sideways scroll bar are the platform's: the window's title bar
/// and the split view's own button, divider and scroll bars.
///
/// `ListsSidebar` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-10-31).
struct ListsSidebar: View {
    private let model: TaskViewList.Model
    private let send: (TaskViewList.UserAction) -> Void

    init(model: TaskViewList.Model, send: @escaping (TaskViewList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        ListsTree(model: model, send: send)
            .background(Color(.sidebar))
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: 2)
                    .allowsHitTesting(false)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottom }
            .modifier(ListsDialogs(model: model, send: send) { MovePickerSheet(model: $0, send: send) })
    }

    /// The bar at the bottom of the column, on the sidebar colour so that the rows scroll under it unseen, and the
    /// sentence under the rows above it, where it stays as the phone's does, with the root's strip under the window
    /// below both (`RootView`); the sentence's strip is the one every module's sentence shares, whose look no
    /// component's model holds yet (Lists screen plan, Task 8). The 14 pt above them are clear, so that a row scrolled
    /// under them shows, and take no touch, so that it is still tapped there.
    private var bottom: some View {
        VStack(spacing: 0) {
            if let problem = model.problem {
                Text(problem).listsSentence(on: .sidebar)
            }
            Bar(model.bar, send: send)
                .frame(maxWidth: .infinity)
                .background(Color(.sidebar))
        }
        .padding(.top, 14)
    }
}
