// Apps/Apple/Sources/TodoAppleUI/ListScreen/ListPane.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature

/// The list screen as the detail pane beside the sidebar of a wide window, the Mac's and a wide iPad window's, as the
/// Mac's canvas draws it (`Mac.dc.html`; list screen spec, section 10): what the list screen draws wherever it stands
/// (`ListSurface`), at the pane's numbers, which the module gives a list in a wide window, with its glass buttons in
/// the window's bar (`ListPaneBar`): back only where `showsBack` says, which is the root's to know, the list at the
/// column's base having none, the sidebar being the base, and a list opened over it, a block's or a list inside,
/// having it; and the capsule of "+" and "…" where the phone has "…" alone and a floating "+".
///
/// The canvas has one row over the pane, at the height of the window's own controls (`Mac.dc.html`, :165 and :481), so
/// the bar is that row: the split view's button that shows the sidebar on it, in the Mac's toolbar and on the iPad's
/// bar, beside the back and the capsule, and no title over the header that names the list. The title stays set: it
/// names the list in the back menu of a task pushed over it (#126) and the Mac's window.
///
/// The ways back are the glass back alone. The bar's own back is hidden, the canvas having no other, and with it go its
/// long-press menu, the only way back several screens at once, and on iOS the swipe from the screen's edge, which shows
/// the sidebar there instead (the iOS 26.3 simulator, an iPad Pro 11-inch (M5), 2026-11-09), so the pane needs no
/// `EdgeSwipeBack`, which would take that edge. The sidebar opens any list at the column, under nothing.
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
        ListSurface(model: model, send: send) { sendFromContent in
            ListPaneBar(model: model, send: send, sendFromContent: sendFromContent, showsBack: showsBack)
        }
        .navigationBarBackButtonHidden()
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

/// The pane's glass buttons as the items of the window's bar, which the bar places: back at its leading edge, after the
/// sidebar's button, where the pane draws it, and the capsule at its trailing edge, each standing on the style's glass
/// alone (`GlassToolbarItem`); and the bar's title taken off it. Left out on the watch, which has neither the
/// placements nor the title's removal, and draws no pane.
///
/// `ListPaneBar` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
private struct ListPaneBar: ViewModifier {
    let model: TaskList.Model
    let send: (TaskList.UserAction) -> Void
    let sendFromContent: (TaskList.UserAction) -> Void
    let showsBack: Bool

    func body(content: Content) -> some View {
        #if os(watchOS)
        content
        #else
        let barred = content
            .toolbar {
                if showsBack {
                    GlassToolbarItem(placement: .navigation) { GlassButton(model.back, send: send) }
                }
                GlassToolbarItem(placement: .primaryAction) { trailing }
            }
            #if os(iOS)
            // The bar inline, where a stack's first screen would otherwise keep a large title's room under it. The
            // mode is unavailable on macOS.
            .navigationBarTitleDisplayMode(.inline)
            #endif
        // The bar's title off it, from iOS 18 and macOS 15, which can say so; before them an empty item in the title's
        // place, which takes the title off iOS's bar and leaves the Mac's window title in its toolbar.
        if #available(iOS 18, macOS 15, *) {
            barred.toolbar(removing: .title)
        } else {
            barred.toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
        }
        #endif
    }

    /// The capsule where the style has one, and "…" alone where it has none.
    @ViewBuilder private var trailing: some View {
        if let capsule = model.style.capsule {
            self.capsule(capsule)
        } else {
            GlassMenu(model.showAs, send: send)
        }
    }

    /// The glass capsule of the pane (`Mac.dc.html`, the nav row's `.glass`): the "+" where the list takes a task,
    /// which closes a row a swipe left open as the floating "+" does, the divider after it, and "…", standing on the
    /// capsule's glass and on none of their own (`GlassButtonFace`).
    private func capsule(_ style: GlassCapsuleStyle) -> some View {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .circular)
        return HStack(spacing: 0) {
            if let addTask = model.glassAddTask {
                GlassButton(addTask, send: sendFromContent)
                Rule(style.divider, along: .vertical)
                    .frame(height: style.dividerHeight)
            }
            GlassMenu(model.showAs, send: send)
        }
        .padding(.horizontal, style.horizontalPadding)
        .frame(height: style.height)
        .glassSurface(style.glass, in: shape)
    }
}

#if !os(watchOS)
/// An item of the window's bar standing on the glass its content draws and on none of the bar's: iOS 26 and macOS 26
/// put their own glass behind a bar's item, which would stand under the style's a second time; before them the bar
/// draws none. Left out on the watch, whose bar has neither the placements nor the glass.
///
/// `GlassToolbarItem` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
private struct GlassToolbarItem<Content: View>: ToolbarContent {
    let placement: ToolbarItemPlacement
    @ViewBuilder let content: () -> Content

    var body: some ToolbarContent {
        if #available(iOS 26, macOS 26, *) {
            ToolbarItem(placement: placement) { content() }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: placement) { content() }
        }
    }
}
#endif
