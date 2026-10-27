// Apps/Apple/Sources/TodoAppleUI/WindowView.swift
import AppFeature
import FeatureModule
import SwiftUI

/// The view of one window: it makes the window from the window's path and its width class once, when the window first
/// appears, holds it for as long as the window lives, draws the root over its host, hands it the links the system
/// opens in it and the window's width class as it changes, writes its route back after every change, and opens the
/// windows the root asks for (`docs/specs/navigation.md`, sections 5 and 7; navigation state spec, section 4).
///
/// The window is kept in the view's state, which SwiftUI keeps for the life of the window, and is made when the view
/// drawn while that state is empty appears. A scene's content closure runs more than once for a window and hands
/// it a new value of this view each time, so a host made where the value is made, in the closure, in `init` or as
/// the initial value of a `@State`, which is evaluated on every creation of the struct, is made again on every run,
/// each another root over the store (`docs/specs/navigation.md`, "Risks"; ADR-0008). Probed on 2026-10-18 under
/// Swift 6.4.0: with the host made in the group's content closure, the first window of the Mac executable made two
/// hosts and Cmd-N two more; with the host made in `init`, or as a `@State`'s initial value, a window that appeared
/// and was redrawn by a change set had made two (`aWindowMakesOneHost`); kept in state and made on appearing, every
/// window made one, through a change set and a Cmd-N.
///
/// A window that cannot be made ends the process with the error, as a launch that throws does, until a recovery flow
/// exists (`docs/specs/feature-module-architecture.md`, section 5); the cost is that one window's failure ends the
/// windows that work.
///
/// A link the system opens reaches the drawn root's `onOpenURL`, which hands it to the window's way in, and a link
/// that launches the app is not lost while the window is not yet made: on 2026-10-20, on macOS 26.7.1 under Swift
/// 6.4.0, in a throwaway bundle that registered the `todo` scheme, SwiftUI made a window for a link that launched the
/// app, its placeholder made the window, and the link reached `onOpenURL` some 45 ms later, in each of six launches;
/// the placeholder, given an `onOpenURL` of its own, received nothing. SwiftUI then opened its first window as well,
/// on the default route, or the windows it restored.
///
/// The width class reaches the root the way a link does, through the window's way in, since it is an event of the
/// world, and the view decides nothing by it: the root's model carries the layout the root view draws (navigation
/// state spec, section 4; `docs/style.md`, "Views"). The window is made with the class the placeholder reads when it
/// appears, so the first frame already has its shape: on 2026-10-24, in the iOS 26.3 simulator, that class was the one
/// the window settled at in every window the probe made, on an iPhone 17 and in narrow iPad windows, at a fresh launch,
/// restored and opened with Open in New Window, and no video showed a frame of the split view first. The drawn root
/// reports the class on its first frame too, so that a class that moved between the window's making and that frame
/// still reaches the root, which takes the width it already has as nothing. The same day, rotating an iPhone 17 Pro
/// Max with a task open, with the tree chosen from a reported width, wrote no path and drew no frame of the old tree at
/// the new width.
struct WindowView: View {
    private let app: TodoApp

    /// The window's value in its group, the window's route in its text form beside an identity of the window's own
    /// (`Value`): nil for a window opened with none, the first of a launch, every Cmd-N and the window a link opens at
    /// a launch, which gets one at its first write. Its text is read once, when the window is made, and written after
    /// every change of the route. It is what a relaunch restores the window from, on the Mac
    /// (`docs/specs/navigation.md`, section 7) and on iOS: on 2026-10-20, in the iOS 26.3 simulator, the scene's saved
    /// state held this value, and a scene the system had ended in the background was made again from it.
    ///
    /// Writing it moves neither the window nor this view (spec, "Risks"): on 2026-10-20, on macOS 26.7.1, three
    /// writes of the text left the window its number, its one host and its view, and each read back as written. The Mac
    /// restores the values of a bundled app's windows: the same day the executable SwiftPM builds, which has no bundle,
    /// restored no window after Cmd-Q, and the throwaway bundle restored every window with its value.
    @Binding private var value: Value?

    /// The same text, kept by the scene (`docs/specs/navigation.md`, section 7), and written beside the value on every
    /// platform, since a view holds no platform condition for where a relaunch reads. It is read only when the window
    /// has no value of its own: always on the watch, whose group takes no value, and not at a relaunch on iOS, where a
    /// restored scene brought its value back too and each window was made from it, this text agreeing (2026-10-20, the
    /// iOS 26.3 simulator).
    @SceneStorage("route") private var storedPath: String?

    /// The window, nil only until the window first appears.
    @State private var window: TodoApp.Window?

    /// The window's horizontal size class, which only the view can know (`docs/style.md`, "Views"), read for the width
    /// class the window is made with and reports: compact on iPhone and in a narrow iPad window, regular in a wide
    /// one, and nil on the Mac.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// The window's width class as the root takes it: compact as narrow, and anything else as wide, the regular class
    /// and the Mac's, which has none. Nothing here is decided by it: it is handed to the root, and the layout comes
    /// back in the root's model.
    private var width: WindowWidth {
        horizontalSizeClass == .compact ? .narrow : .wide
    }

    init(app: TodoApp, value: Binding<Value?>) {
        self.app = app
        self._value = value
    }

    var body: some View {
        if let window {
            takingLinks(RootView(host: window.host))
                .onOpenURL(perform: window.open)
                .onChange(of: window.host.route.path) { _, routeText in keep(routeText) }
                // On the first frame as well, `initial`, for a class that moved after the window was made; a width the
                // window has already moves nothing in the root.
                .onChange(of: width, initial: true) { _, width in window.widthChanged(width) }
        } else {
            // A view that fills the window, because a view with nothing in it never appears: on 2026-10-18 an
            // `onAppear` on a `Group` holding nothing never ran in a window of the group, and the window stayed
            // empty. Once the window is made this view goes, so it appears once.
            Color.clear
                .onAppear(perform: makeWindow)
        }
    }

    private func makeWindow() {
        do {
            let window = try app.makeWindow(path: value?.path ?? storedPath, width: width)
            answerTheRoot(of: window.host)
            self.window = window
            keep(window.host.route.path)
        } catch {
            fatalError("The window could not be made: \(error)")
        }
    }

    /// Writes the window's route down where a relaunch reads it, the group's value and the scene's storage, as it is
    /// when the window is made and after every change. The value keeps the window's identity and moves its text alone,
    /// and a window that has none yet gets one here.
    private func keep(_ routeText: String) {
        value = value.map { Value(id: $0.id, path: routeText) } ?? Value(path: routeText)
        storedPath = routeText
    }

    #if !os(watchOS)
    /// The group's way to open a window with a value, read for the handler of the root's output.
    @Environment(\.openWindow) private var openWindow

    /// Installs the handler of the root's output on the window's host, right after the window is made, so that it is
    /// there before any gesture can draw an output out: a window opened on the route the root asks for, its value the
    /// route's text beside an identity minted for it (`docs/specs/navigation.md`, section 5). The identity is what
    /// makes every request a new window, on the view a window already shows too (the owner, 2026-10-20): a value an
    /// open window already has brings that window forward and opens none (2026-10-20, macOS 26.7.1).
    ///
    /// The handler captures the action alone. The host holds its handler, so a handler that held the host would
    /// close a cycle, host to handler to host, and a closed window's host would never be released and would go on
    /// taking every change set (`ModuleHost.onOutput`); and this view is a struct, so a handler that read any of its
    /// properties, `openWindow` among them, would capture the view and with it the state that holds the window, its
    /// host included (probed 2026-10-17 under Swift 6.4.0 with a `@MainActor` struct standing in for the view). On
    /// 2026-10-20, on macOS 26.7.1, with this handler installed, the host of a closed window was released, at
    /// SwiftUI's next update after the close, as it was with no handler: until that update the closed window's view
    /// stays, and it took one more change set.
    private func answerTheRoot(of host: ModuleHost<AppModule>) {
        host.onOutput = { [openWindow] output in
            switch output {
            case .openWindow(let route): openWindow(value: Value(path: route.path))
            }
        }
    }

    /// The window's content claiming every link, so that the key window takes a link and a new window opens only when
    /// none is open, where SwiftUI's default for a window group is a new window for every link
    /// (`docs/specs/navigation.md`, section 7). On 2026-10-20, on macOS 26.7.1, in the throwaway bundle: without the
    /// modifier every link opened a new window, a second link another; with it a link went to the key window, a second
    /// link to the same window, a link after another window was made key to that one, and with no window open a new
    /// window opened and took the link. The scene's `handlesExternalEvents(matching: [])` beside it lost every link
    /// that arrived with no window open, at a launch too.
    private func takingLinks(_ root: some View) -> some View {
        root.handlesExternalEvents(preferring: ["*"], allowing: ["*"])
    }
    #else
    // The watch has one window and opens no other: nothing on it draws out the root's request for a window, since the
    // sidebar's menu is not drawn there (`TaskViewListView`), so the root's output goes unanswered, and a link has one
    // window to go to. `openWindow` and `handlesExternalEvents` are unavailable on watchOS (a file typechecked against
    // the watchOS 10 SDK on 2026-10-14). This is the view's one platform condition.
    private func answerTheRoot(of host: ModuleHost<AppModule>) {}

    private func takingLinks(_ root: some View) -> some View { root }
    #endif
}

extension WindowView {
    /// A window's value in its group: the window's route in its text form, beside an identity of the window's own that
    /// every write keeps (`docs/specs/navigation.md`, section 5; the owner, 2026-10-20). The text alone would make two
    /// windows on one route one value, and `openWindow(value:)` with a value an open window has brings that window
    /// forward instead of opening one (probed 2026-10-20 on macOS 26.7.1), so Open in New Window on the view a window
    /// shows opened nothing. A type of this package and not a conformance of the route, which keeps its one codec for
    /// its text; `Codable` and `Hashable` are what the group asks of its value, and both are synthesized.
    struct Value: Codable, Hashable {
        let id: UUID
        let path: String

        /// A value under the given identity, or under a new one, which is how a window the root asks for, and a window
        /// opened with no value at its first write, gets its own.
        init(id: UUID = UUID(), path: String) {
            self.id = id
            self.path = path
        }
    }
}
