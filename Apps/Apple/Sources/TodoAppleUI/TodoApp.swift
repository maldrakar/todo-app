// Apps/Apple/Sources/TodoAppleUI/TodoApp.swift
import AppFeature
import DeviceFile
import Foundation
import TodoCore

/// The composition root: the store, the root module and the host, put together once per launch (spec
/// section 5).
@MainActor
public enum TodoApp {
    /// The store at its path, the root module, the host, and the store's onChange wired to the host.
    ///
    /// `TODO_DB` is the database's whole path and `TODO_DEVICE` the identity it is written under, each unset
    /// when exported empty, as the demo reads them: that is how one machine runs two copies of the app as two
    /// devices. Without `TODO_DEVICE` the identity is the one kept beside the database, and the first launch
    /// over a database mints one and keeps it there (ADR-0005).
    ///
    /// It throws whatever the store or the file system throws: what a launch that failed means is the
    /// scene's to decide (spec section 5).
    public static func launch(environment: [String: String]) throws -> ModuleHost<AppModule> {
        let database = try set(environment["TODO_DB"]) ?? defaultDatabase()
        let held = set(environment["TODO_DEVICE"]) ?? DeviceFile.read(beside: database)
        let device = held ?? Store.newDeviceID()
        let store = try Store.open(path: database, device: device, now: Store.systemNow)
        // Kept after the database opened, the order the demo keeps: a path that cannot be opened is the store's
        // to refuse, so a launch over one fails with the store's error and leaves no identity beside a database
        // that is not there. The open has already recorded the new id in `own_devices`, so a launch that then
        // cannot keep it leaves that row behind and the next launch mints another.
        if held == nil { try DeviceFile.keep(device, beside: database) }
        let root = try AppModule(store: store)
        return ModuleHost(root) { deliver in store.onChange = { deliver(.changed($0)) } }
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
}
