// Apps/Apple/Sources/TodoAppleUI/ListScreen/ListScreen.swift
import SwiftUI
import TaskListFeature

/// The list screen on a phone, a screen pushed over the Lists screen in a narrow window's stack, as the canvas draws it
/// (`Phone.dc.html`; list screen spec, sections 1 to 7): what the list screen draws wherever it stands (`ListSurface`),
/// its glass back always, since a list here always stands over the Lists screen, and what a narrow window's stack adds.
///
/// The bar is hidden, so the way back is the glass circle, which sends the list's action as every control does, and the
/// swipe from the screen's edge, which a hidden bar turns off, is kept on (`EdgeSwipeBack`) and is the stack's pop, as
/// the system's back button's; the long-press menu of that button goes with it.
///
/// The Mac draws the pane alone (`ListPane`), since its window has no size class and is always wide (`WindowView`);
/// what this screen calls that the Mac lacks is fenced and named all the same, the target being built for it.
struct ListScreen: View {
    private let model: TaskList.Model
    private let send: (TaskList.UserAction) -> Void

    init(model: TaskList.Model, send: @escaping (TaskList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        ListSurface(model: model, send: send, showsBack: true)
            #if !os(macOS)
            // The canvas has no bar over the content; the screens pushed over it keep theirs. The placement is
            // unavailable on macOS.
            .toolbar(.hidden, for: .navigationBar)
            #endif
            #if os(iOS)
            // iOS alone: the Mac and the watch have no `interactivePopGestureRecognizer`.
            .background { EdgeSwipeBack() }
            #endif
    }
}
