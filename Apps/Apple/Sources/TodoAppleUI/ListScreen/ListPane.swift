// Apps/Apple/Sources/TodoAppleUI/ListScreen/ListPane.swift
import SwiftUI
import TaskListFeature

/// The list screen as the detail pane beside the sidebar of a wide window, the Mac's and a wide iPad window's, as the
/// Mac's canvas draws it (`Mac.dc.html`; list screen spec, section 10): what the list screen draws wherever it stands
/// (`ListSurface`), at the pane's numbers, which the module gives a list in a wide window, with the capsule of "+" and
/// "…" where the phone has "…" alone and a floating "+"; and its glass back only where `showsBack` says, which is the
/// root's to know: the list at the column's base has none, the sidebar being the base, and a list opened over it, a
/// block's or a list inside, has it.
///
/// The stack's bar stays, as the Mac's toolbar does, since the split view's button that shows the sidebar stands on it:
/// on the iPad in portrait it was the bar's one button, "Show Sidebar", and it showed the sidebar beside the pane (the
/// iOS 26.3 simulator, an iPad Pro 11-inch (M5), 2026-11-09). The row of glass buttons stands under the bar, inside the
/// safe area, and never under the toolbar's glass. The bar's own back is hidden, the glass back being the pane's way
/// back, as the canvas has no other; with it goes the swipe from the edge that pops, so that a swipe there shows the
/// sidebar, as it did over a list over a list, the back staying (the same). So the pane needs no `EdgeSwipeBack`, which
/// would take that edge.
///
/// The row's gestures are the phone's, wired the same way (`ListSurface`), and the platform decides which are there:
/// on the iPad the system's drag and menu and the swipe (spike #174, y1); on the Mac a click on a row opens its card,
/// which is the row's tap, the right click opens the row's menu, and the pointer's drag is another part's. Esc closes
/// an open card wherever a keyboard has one.
///
/// `ListPane` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and Observation
/// for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
struct ListPane: View {
    private let model: TaskList.Model
    private let send: (TaskList.UserAction) -> Void
    private let showsBack: Bool

    init(model: TaskList.Model, send: @escaping (TaskList.UserAction) -> Void, showsBack: Bool) {
        self.model = model
        self.send = send
        self.showsBack = showsBack
    }

    var body: some View {
        ListSurface(model: model, send: send, showsBack: showsBack)
            .navigationBarBackButtonHidden()
            #if os(iOS)
            // The title in the bar's middle, as the Mac's toolbar has it, and not the large one a stack's first screen
            // takes on iOS above the header's own. The mode is unavailable on macOS.
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if !os(watchOS)
            .background { escape }
            #endif
    }

    #if !os(watchOS)
    /// Esc, which closes an open card, as a keyboard shortcut of the window's: a field that has the focus takes its own
    /// Esc first (`PlainField`), and with no field focused, as after a click opened a card, this takes it, where
    /// `onExitCommand` hears nothing until a view of the pane holds the focus (a probe of 2026-11-09 on macOS 26 with
    /// Xcode 27.1, an Esc key event handed to an `NSHostingView`'s window: the command with nothing focused heard none,
    /// a hidden shortcut heard it, a focused field's own Esc and its exit command each came before the shortcut, and of
    /// a stack's screens only the one on top heard it). Hidden, it draws nothing and reads nothing aloud. Left out on
    /// the watch, which has no keyboard shortcut.
    private var escape: some View {
        Button("Close") { send(.escapeKeyPressed) }
            .keyboardShortcut(.cancelAction)
            .hidden()
    }
    #endif
}
