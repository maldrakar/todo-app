// Apps/Apple/Sources/TodoAppleUI/WindowView.swift
import AppFeature
import SwiftUI

/// The view of one window: it makes the window's host from the window's path once, when the window first appears,
/// holds it for as long as the window lives, and draws the root over it (`docs/specs/navigation.md`, section 5).
///
/// The host is kept in the view's state, which SwiftUI keeps for the life of the window, and is made when the view
/// drawn while that state is empty appears. A scene's content closure runs more than once for a window and hands
/// it a new value of this view each time, so a host made where the value is made, in the closure, in `init` or as
/// the initial value of a `@State`, which is evaluated on every creation of the struct, is made again on every run,
/// each another root over the store (`docs/specs/navigation.md`, "Risks"; ADR-0008). Probed on 2026-10-18 under
/// Swift 6.4.0: with the host made in the group's content closure, the first window of the Mac executable made two
/// hosts and Cmd-N two more; with the host made in `init`, or as a `@State`'s initial value, a window that appeared
/// and was redrawn by a change set had made two (`aWindowMakesOneHost`); kept in state and made on appearing, every
/// window made one, through a change set and a Cmd-N.
///
/// A window whose host cannot be made ends the process with the error, as a launch that throws does, until a
/// recovery flow exists (`docs/specs/feature-module-architecture.md`, section 5); the cost is that one window's
/// failure ends the windows that work.
struct WindowView: View {
    private let app: TodoApp

    /// The window's route in its text form, read once, when the host is made from it.
    private let path: String?

    /// The window's host, nil only until the window first appears.
    @State private var host: ModuleHost<AppModule>?

    init(app: TodoApp, path: String?) {
        self.app = app
        self.path = path
    }

    var body: some View {
        if let host {
            RootView(host: host)
        } else {
            // A view that fills the window, because a view with nothing in it never appears: on 2026-10-18 an
            // `onAppear` on a `Group` holding nothing never ran in a window of the group, and the window stayed
            // empty. Once the host is made this view goes, so it appears once.
            Color.clear
                .onAppear(perform: makeHost)
        }
    }

    private func makeHost() {
        do {
            host = try app.makeHost(path: path)
        } catch {
            fatalError("The window could not be made: \(error)")
        }
    }
}
