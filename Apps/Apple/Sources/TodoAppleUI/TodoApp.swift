// Apps/Apple/Sources/TodoAppleUI/TodoApp.swift
import AppFeature
import DeviceFile
import Foundation
import TodoCore

/// The composition root: one store per process, opened at launch under the device's identity, and a host per window,
/// each around a root of its own made from the window's path, with every change set the store reports handed to every
/// host still alive (`docs/specs/navigation.md`, section 5). The feature-module spec's "one host and one root per
/// process" is "one host per window, one store per process".
@MainActor
final class TodoApp {
    /// The composition root of this process, put together the first time anything reads it. A `static let` is
    /// initialised once, on first use, where a `@State` in the scene would not be: its initial value is
    /// evaluated on every creation of its struct, and each evaluation would open another store over the same
    /// file (spec, "Risks"; ADR-0005).
    ///
    /// A launch that throws ends the process with the error it threw; a recovery flow is a product decision
    /// (spec section 5).
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

    private init(store: Store) {
        self.store = store
    }

    /// The store at its path, the composition root around it, and the store's `onChange` wired to the fan-out.
    ///
    /// `TODO_DB` is the database's whole path and `TODO_DEVICE` the identity it is written under, each unset
    /// when exported empty, as the demo reads them: that is how one machine runs two copies of the app as two
    /// devices. Without `TODO_DEVICE` the identity is the one kept beside the database, and the first launch
    /// over a database mints one and keeps it there (ADR-0005).
    ///
    /// It throws whatever the store or the file system throws, and its caller acts on the throw: in the app a
    /// launch that failed is fatal and says why (spec section 5).
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
        let app = TodoApp(store: store)
        // Weakly, because the composition root holds the store: a strong one would close a cycle through the
        // store, and the database would stay open for the life of the process, beside whatever store is opened
        // over the same file next (`Store`, ADR-0005).
        store.onChange = { [weak app] changes in app?.fanOut(changes) }
        return app
    }

    /// A host for a window: the root made from the path, or from the default route when the path is nil or does not
    /// read.
    ///
    /// A path is the window's route in its one text form, kept by the window to be restored from
    /// (`docs/specs/navigation.md`, section 7). One that does not read, written by another version of the app or by
    /// hand, opens the default window and says nothing, which is restoration's rule; a link that does not read is
    /// #95's. A route whose views or tasks are gone is read, and opens what still exists, as the root's own children
    /// say (`docs/specs/navigation.md`, section 3).
    ///
    /// The host's world entrance is kept for the fan-out and the host itself is not: the window's view holds it, and
    /// when the view lets go the host is released and the next fan-out passes it by. It throws what the root throws
    /// when the store cannot read its sidebar, as a launch did when it made the one root.
    func makeHost(path: String?) throws -> ModuleHost<AppModule> {
        let route = path.flatMap { try? AppModule.Route(path: $0) } ?? .default
        let root = try AppModule(store: store, route: route)
        // Replaced before `init` returns, since `init` hands the host's entrance over as its last step, so the
        // placeholder is never what is kept.
        var deliver: @MainActor (AppModule.Event) -> Void = { _ in }
        let host = ModuleHost(root) { deliver = $0 }
        entrances.append(Entrance(host: host, deliver: deliver))
        return host
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
    /// for the app rather than for a bundle identifier, because the app has no bundle to take one from
    /// (ADR-0008).
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
