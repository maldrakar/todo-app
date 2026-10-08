import Testing
import Foundation
import AppFeature
import DeviceFile
import TaskViewListFeature
import TodoAppleUI
import TodoCore

/// Which identity the store wrote under is out of reach through the host, which keeps the store to itself, so
/// each launch writes a folder and a store opened after every launch has closed its own reads back the device
/// the journal recorded for each folder.
@Test @MainActor func launchOpensTheDatabaseAtTheGivenPathAndKeepsTheDeviceBesideIt() throws {
    try withFreshDatabase { database in
        _ = try TodoApp.launch(environment: ["TODO_DB": database])
        #expect(FileManager.default.fileExists(atPath: database))
        let minted = try #require(DeviceFile.read(beside: database), "the first launch keeps the identity it minted")

        let second = try launchAndCreateAFolder(["TODO_DB": database])
        #expect(DeviceFile.read(beside: database) == minted, "a launch that minted again would have kept its own")

        let third = try launchAndCreateAFolder(["TODO_DB": database, "TODO_DEVICE": "given"])
        #expect(DeviceFile.read(beside: database) == minted, "an identity the environment names is not kept")

        let fourth = try launchAndCreateAFolder(["TODO_DB": database, "TODO_DEVICE": ""])

        let journal = try Store.open(path: database, device: Store.newDeviceID(), now: Store.systemNow).journal(after: 0)
        let writers = { (folder: ViewID) in Set(journal.filter { $0.entityID == folder.rawValue }.map(\.device)) }
        #expect(writers(second) == [minted])
        #expect(writers(third) == ["given"], "TODO_DEVICE outranks the file")
        #expect(writers(fourth) == [minted], "an empty TODO_DEVICE is unset, as the demo reads it")
    }
}

/// A directory where the database should be is a path SQLite cannot open. The identity is kept only once the
/// database has opened, so a launch the store refused leaves nothing beside the path.
@Test @MainActor func launchRefusesAPathThatCannotBeOpened() throws {
    try withFreshDatabase { database in
        try FileManager.default.createDirectory(atPath: database, withIntermediateDirectories: false)
        #expect(throws: StoreError.self) { try TodoApp.launch(environment: ["TODO_DB": database]) }
        #expect(DeviceFile.read(beside: database) == nil)
    }
}

/// The store holds the world's entrance as its `onChange`, and the host holds the module that holds the
/// store. An entrance that held the host would keep all four alive once the last holder let go, and every
/// launch would keep its database open for the life of the process.
@Test @MainActor func theStoreDoesNotKeepTheHostAlive() throws {
    try withFreshDatabase { database in
        weak var released: ModuleHost<AppModule>?
        do {
            let host = try TodoApp.launch(environment: ["TODO_DB": database])
            released = host
        }
        #expect(released == nil)
    }
}

/// Hands `body` a database path no other test uses, in a directory of its own under the system's temporary
/// one, and removes the directory afterwards: a launch writes beside its database as well as into it.
@MainActor private func withFreshDatabase(_ body: (String) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "todo-apple-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory.appending(path: "todo.sqlite").path(percentEncoded: false))
}

/// Launches, creates a folder the way a person does, and answers the folder's id. The host is released when
/// this returns, and the store with it, so the next launch over the same file is the only one open.
@MainActor private func launchAndCreateAFolder(_ environment: [String: String]) throws -> ViewID {
    let host = try TodoApp.launch(environment: environment)
    let before = Set(host.model.taskViewList.rows.map(\.id))
    host.send(.taskViewList(.createFolderButtonTapped))
    return try #require(Set(host.model.taskViewList.rows.map(\.id)).subtracting(before).first)
}
