// Apps/Apple/Sources/TodoAppleUI/TodoApp.swift
import AppFeature
import DeviceFile
import FeatureModule
import Foundation
import TodoCore

/// The composition root: one store per process, opened at launch under the device's identity, and a host per window,
/// each around a root of its own made from the window's path, with every change set the store reports handed to every
/// host still alive (`docs/specs/navigation.md`, section 5), where the feature-module spec's "one host and one root
/// per process" becomes "one host per window, one store per process". A link the system opens in a window reaches that
/// window's host through the same entrance as the change sets, by a way in handed to the window when it is made
/// (section 7), and so does the width class the window's view reports (navigation state spec, section 4).
@MainActor
final class TodoApp {
    /// The composition root of this process, put together the first time anything reads it. A `static let` is
    /// initialised once, on first use, where a `@State` in the scene would not be: its initial value is
    /// evaluated on every creation of its struct, and each evaluation would open another store over the same
    /// file (`docs/specs/feature-module-architecture.md`, "Risks"; ADR-0005).
    ///
    /// A launch that throws ends the process with the error it threw; a recovery flow is a product decision
    /// (`docs/specs/feature-module-architecture.md`, section 5).
    static let shared: TodoApp = {
        do {
            return try launch(environment: ProcessInfo.processInfo.environment)
        } catch {
            fatalError("The app could not launch: \(error)")
        }
    }()

    private let store: Store

    /// The world's entrance of every host made here, in the order the hosts were made, each beside its host
    /// held weakly, which is what says whether the entrance still leads anywhere.
    private var entrances: [Entrance] = []

    /// How many windows `makeWindow` has made, each with a host of its own, one for every call that returned one: read
    /// by the test that holds a window to one host (`docs/specs/navigation.md`, "Risks"), and by `makeWindow`, for
    /// whether the launch route is spent. It counts the hosts made and not the entrances still alive: a host made and
    /// dropped by a redraw leaves an entrance that the next fan-out prunes, and the change set that forces the redraw
    /// is a fan-out, so a count of live entrances would hide the second host.
    private(set) var hostsMade = 0

    /// The route `TODO_ROUTE` named at launch, and nil when it is unset or does not read, an empty one among them,
    /// since a route's text begins with `/`. The executable SwiftPM builds for the Mac has no bundle, so no URL scheme
    /// reaches it, and a link is handed to it here, the way `TODO_DB` names the database (`docs/specs/navigation.md`,
    /// section 7).
    ///
    /// It is the first window's, and only when that window has no path of its own; every later window made with none,
    /// Cmd-N's, opens the default window (the owner, 2026-10-20). One that does not read opens the default window and
    /// says nothing, as a path a window was restored from does: it is the developer's stand-in for a link on the
    /// executable that has no bundle, and the owner kept an unreadable one silent, as the plan's rule has it
    /// (2026-10-20).
    let launchRoute: AppModule.Route?

    private init(store: Store, launchRoute: AppModule.Route?) {
        self.store = store
        self.launchRoute = launchRoute
    }

    /// The store at its path, the composition root around it, and the store's `onChange` wired to the fan-out.
    ///
    /// `TODO_DB` is the database's whole path and `TODO_DEVICE` the identity it is written under, each unset
    /// when exported empty, as the demo reads them: that is how one machine runs two copies of the app as two
    /// devices. Without `TODO_DEVICE` the identity is the one kept beside the database, and the first launch
    /// over a database mints one and keeps it there (ADR-0005). `TODO_ROUTE` is the first window's route
    /// (`launchRoute`).
    ///
    /// It throws whatever the store or the file system throws, and its caller acts on the throw: in the app a
    /// launch that failed is fatal and says why (`docs/specs/feature-module-architecture.md`, section 5).
    static func launch(environment: [String: String]) throws -> TodoApp {
        let database = try set(environment["TODO_DB"]) ?? defaultDatabase()
        let held = set(environment["TODO_DEVICE"]) ?? DeviceFile.read(beside: database)
        let device = held ?? Store.newDeviceID()
        let store = try Store.open(path: database, device: device, now: Store.systemNow)
        // Kept after the database opened, the order the demo keeps: a path that cannot be opened is the store's
        // to refuse, so a launch over one fails with the store's error and leaves no identity beside a database
        // that is not there. The open has already recorded the new id in `own_devices`, so a launch that then
        // cannot keep it leaves that row behind and the next launch mints another.
        if held == nil { try DeviceFile.keep(device, beside: database) }
        let launchRoute = environment["TODO_ROUTE"].flatMap { try? AppModule.Route(path: $0) }
        let app = TodoApp(store: store, launchRoute: launchRoute)
        // Weakly, because the composition root holds the store: a strong one would close a cycle through the
        // store, and the database would stay open for the life of the process, beside whatever store is opened
        // over the same file next (`Store`, ADR-0005).
        store.onChange = { [weak app] changes in app?.fanOut(changes) }
        return app
    }

    /// A window: a host around a root made from the path, or from the default route when there is none or it does not
    /// read, with the width class the window opens with and whether another can open beside it, and the window's ways
    /// in for a link and for its width.
    ///
    /// A path is the window's route in its one text form, kept by the window to be restored from
    /// (`docs/specs/navigation.md`, section 7). One that does not read, written by another version of the app or by
    /// hand, opens the default window and says nothing, which is restoration's rule; a link that does not read is
    /// said in its window (`Window.open`). A route whose views or tasks are gone is read, and opens what still exists,
    /// as the root's own children say (`docs/specs/navigation.md`, section 3). The first window made with no path
    /// opens `launchRoute` instead of the default route, when there is one, and the first window made at all spends
    /// it, with a path or without: the window's view hands over the text of the value its window was opened with and
    /// never knows of a launch route, so whether a window is the first is decided here (the owner, 2026-10-20).
    ///
    /// The width is the class the window's view reads when the window first appears, so the window's first frame
    /// already has the shape of its layout (navigation state spec, section 4). It has no default, as the root's has
    /// none: the one caller in the product, the window's view, always has one, and a test spells the width it means.
    /// Whether a window can open beside this one is the platform's answer, which the window's view reads when the
    /// window first appears and the root hands to the sidebar, whose lists' menus offer Open in New Window only where
    /// one can (`docs/specs/navigation.md`, section 5); it has no default, for the width's reason.
    ///
    /// The host's world entrance is kept for the fan-out and handed to the window inside `open` and `widthChanged`, and
    /// the host itself is not kept: its caller, the window's view, holds the window for as long as the window lives
    /// (`WindowView`), and once the caller lets go the host is released and the next fan-out passes it by. It throws
    /// what the root's `init` throws, the store's error when the sidebar cannot be read, and its caller acts on the
    /// throw.
    func makeWindow(path: String?, width: WindowWidth, supportsMultipleWindows: Bool) throws -> Window {
        let unspentLaunchRoute = hostsMade == 0 ? launchRoute : nil
        let route = path.map { (try? AppModule.Route(path: $0)) ?? .default } ?? unspentLaunchRoute ?? .default
        let root = try AppModule(
            store: store, route: route, width: width, supportsMultipleWindows: supportsMultipleWindows
        )
        // Replaced before `init` returns, since `init` hands the host's entrance over as its last step, so the
        // placeholder is never what is kept.
        var entrance: @MainActor (AppModule.Event) -> Void = { _ in }
        let host = ModuleHost(root) { entrance = $0 }
        let deliver = entrance
        entrances.append(Entrance(host: host, deliver: deliver))
        hostsMade += 1
        // Both over the entrance alone, which holds the host weakly, and never over the host or the composition root.
        return Window(
            host: host,
            open: { url in deliver(TodoApp.route(from: url).map(AppModule.Event.route) ?? .unreadableLink) },
            widthChanged: { width in deliver(.widthChanged(width)) }
        )
    }

    /// The route a link carries, the URL's path and query read with the route's codec as they are written, still
    /// percent-encoded, and nil when they do not read or the URL says more than a route has room for.
    ///
    /// A link is the window's route in its text form behind the app's scheme, `todo:///view/<id>/task/<id>`, so the
    /// scheme is stripped and the rest is what the route reads (`docs/specs/navigation.md`, section 7). The scheme is
    /// not checked, so a URL of another scheme reads by the same rule: a `file://` URL reads as a route only when its
    /// path is a route's, `/view/<id>`, and as a link that does not read otherwise.
    ///
    /// Between the scheme and the path a link has an empty authority, and anything in it, a host, a user, a password
    /// or a port, gives nil, as a fragment does, rather than a route that drops what it said; `todo://view/<id>`, one
    /// slash short, has `view` for its host. The empty authority is a host that is absent or empty, whichever `URL`
    /// answers, and the user, the password and the port are refused by name, so the guard leans on neither answer: on
    /// 2026-10-20, under Swift 6.4.0 on macOS 26.7.1, `URL` answered no host for `todo:///view/<id>` and an empty one
    /// beside the user of `todo://user@/view`, the empty user and the password of `todo://:secret@/view` and the port
    /// of `todo://:80/view`.
    ///
    /// Static, because it reads nothing of the composition root, so the window's way in that calls it holds none.
    static func route(from url: URL) -> AppModule.Route? {
        guard (url.host(percentEncoded: true) ?? "").isEmpty, url.user(percentEncoded: true) == nil,
              url.password(percentEncoded: true) == nil, url.port == nil, url.fragment(percentEncoded: true) == nil
        else { return nil }
        let query = url.query(percentEncoded: true).map { "?" + $0 } ?? ""
        return try? AppModule.Route(path: url.path(percentEncoded: true) + query)
    }

    /// What a window's view is handed once, when its window first appears: the window's host, and the window's ways
    /// in for a link (the owner, 2026-10-20) and for its width class (navigation state spec, section 4). The view
    /// holds it for as long as the window lives, and nothing else does.
    struct Window {
        /// The window's host, which the window's view draws and sends its actions to.
        let host: ModuleHost<AppModule>

        /// Takes a link the system opened in this window to this window's host, through its world entrance, the one
        /// `.changed` comes through: `.route` when the link reads (`TodoApp.route(from:)`), and the root's
        /// `.unreadableLink` when it does not, which leaves the window as it was and says so
        /// (`docs/specs/navigation.md`, section 7). Both are events of the world, and through this the window's view
        /// delivers only what the codec reads from a URL, a `.route`, any a URL can spell, or `.unreadableLink`, and
        /// never `.changed` or `.created`; it never holds the entrance itself, which stays the composition root's
        /// (section 5; the owner, 2026-10-20). It holds the host weakly, as the entrance does, so a window's view that
        /// lets go of its window lets go of the host.
        let open: @MainActor (URL) -> Void

        /// Takes the width class the window's view reads, narrow or wide, to this window's host, through the same
        /// entrance, as the root's `.widthChanged`, which moves the window's layout and nothing else (navigation state
        /// spec, section 4). It is an event of the world, since nobody pressed anything, so it reaches the host by the
        /// composition root's way in, as a link does, and never by the view's closure over user actions; the view
        /// reports the width through this and decides nothing by it (`docs/style.md`, "Views"; the owner, 2026-10-20,
        /// on the window's way in). It holds the host weakly, as `open` does.
        let widthChanged: @MainActor (WindowWidth) -> Void
    }

    /// Hands what a commit touched to every host still alive, in the order they were made, and forgets the
    /// entrances of those that are not.
    ///
    /// It is called inside the event of the window that wrote, whose host queues the change set; every other
    /// host, idle, takes it at once, inside that event. That is sound because the store calls `onChange` after
    /// the transaction commits, so a host reads a store in which the write is done, and because no module
    /// writes in answer to `.changed`, so no fan-out starts inside another (`docs/specs/navigation.md`, section 5).
    private func fanOut(_ changes: ChangeSet) {
        entrances.removeAll { $0.host == nil }
        for entrance in entrances { entrance.deliver(.changed(changes)) }
    }

    /// The database a launch opens when `TODO_DB` names none. Its directory under Application Support is named
    /// for the app rather than for a bundle identifier, because the Mac executable has no bundle to take one from
    /// (ADR-0008); on iPhone and iPad Application Support is the app's own container's already.
    private static func defaultDatabase() throws -> String {
        let directory = URL.applicationSupportDirectory.appending(path: "todo", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "todo.sqlite").path(percentEncoded: false)
    }

    /// A variable a shell exported without a value names no database and no device, as the demo reads one.
    private static func set(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// A host's world entrance, and the host beside it, held weakly so that the composition root keeps no
    /// window alive: once the host is gone the entrance leads nowhere and is dropped at the next fan-out.
    private struct Entrance {
        weak var host: ModuleHost<AppModule>?
        let deliver: @MainActor (AppModule.Event) -> Void
    }
}
