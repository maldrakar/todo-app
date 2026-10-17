import Testing
import Foundation
import Observation
import AppFeature
import DeviceFile
import TaskViewListFeature
@testable import TodoAppleUI
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

/// The store holds the composition root's fan-out as its `onChange`, the composition root holds the store, and
/// a host holds the module that holds the store. A fan-out that held the composition root would close a cycle,
/// store to composition root to store, that kept both alive once the last holder let go, and every launch would
/// keep its database open for the life of the process.
@Test @MainActor func theStoreDoesNotKeepTheHostAlive() throws {
    try withFreshDatabase { database in
        weak var released: ModuleHost<AppModule>?
        weak var releasedRoot: TodoApp?
        do {
            let app = try TodoApp.launch(environment: ["TODO_DB": database])
            let host = try app.makeHost(path: nil)
            released = host
            releasedRoot = app
        }
        #expect(released == nil)
        #expect(releasedRoot == nil, "the composition root went too, and the store with it")
    }
}

/// A window made from no path is the default window.
@Test @MainActor func aHostMadeFromNoPathIsTheDefaultWindow() throws {
    try withFreshDatabase { database in
        let host = try TodoApp.launch(environment: ["TODO_DB": database]).makeHost(path: nil)
        #expect(host.route.path == defaultWindow)
    }
}

/// A window restored or linked to opens on its path, the sidebar's part and the query alike.
@Test @MainActor func aHostMadeFromAPathOpensIt() throws {
    try withFreshDatabase { database in
        let path = "/view/\(BuiltInTaskViews.today)?quick-entry"
        let host = try TodoApp.launch(environment: ["TODO_DB": database]).makeHost(path: path)
        #expect(host.route.path == path)
    }
}

/// A path that does not read is the default window, silently, which is restoration's rule (`docs/specs/navigation.md`,
/// section 7): a path that would have opened Today but for a task with no id is refused whole, and nothing of it is
/// opened.
@Test @MainActor func aHostMadeFromAnUnreadablePathIsTheDefaultWindow() throws {
    try withFreshDatabase { database in
        let path = "/view/\(BuiltInTaskViews.today)/task"
        let host = try TodoApp.launch(environment: ["TODO_DB": database]).makeHost(path: path)
        #expect(host.route.path == defaultWindow)
    }
}

/// One store per process and a host per window: a write through one window's action reaches every window, the
/// windows made before the writer and after it and the writer itself, and each then draws what a window opened
/// after the write draws. The write is quick entry's, through the window made second, so that the writer's list
/// too learns of the task from the change set alone, and a fan-out that reached the first host only, the last
/// only, or skipped the writer would leave a window behind.
@Test @MainActor func everyLiveHostOverOneStoreReceivesAChange() throws {
    try withFreshDatabase { database in
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        let first = try app.makeHost(path: nil)
        let writer = try app.makeHost(path: "/?quick-entry")
        let third = try app.makeHost(path: nil)
        let before = first.model
        writer.send(.quickEntry(.titleFieldChanged("Milk")))
        writer.send(.quickEntry(.addButtonTapped))
        let opened = try app.makeHost(path: nil)
        #expect(opened.model != before, "the write moved what a window draws")
        #expect(first.model == opened.model, "the window made before the writer")
        #expect(writer.model == opened.model, "the writer, its quick entry closed")
        #expect(third.model == opened.model, "the window made after the writer")
    }
}

/// The fan-out's form, which `docs/specs/navigation.md` chooses in section 5: the window that wrote has its event in
/// flight, and the other window, idle, takes the change set at once, inside the first one's event, before its `send`
/// returns. Sound because the store reports a commit after it is done and no module writes in answer to `.changed`.
@Test @MainActor func anIdleHostTakesAChangeInsideAnotherHostsEvent() throws {
    try withFreshDatabase { database in
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        let first = try app.makeHost(path: nil)
        let second = try app.makeHost(path: nil)
        let order = Order()
        withObservationTracking { _ = second.model } onChange: {
            MainActor.assumeIsolated { order.steps.append(.secondModelMoved) }
        }
        first.send(.taskViewList(.createFolderButtonTapped))
        order.steps.append(.firstSendReturned)
        #expect(order.steps == [.secondModelMoved, .firstSendReturned])
    }
}

/// The window that wrote gets its own change set too, and its event is in flight when the store reports the
/// commit, so the change set waits for the event to return, as it did with one window: the host publishes the
/// model the action left, quick entry closed and its task not yet in the list, and then the model the change
/// set left, the task in the list, which nothing but the change set tells the list of.
@Test @MainActor func aHostInFlightQueuesTheChange() throws {
    try withFreshDatabase { database in
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        let host = try app.makeHost(path: "/?quick-entry")
        host.send(.quickEntry(.titleFieldChanged("Milk")))
        let publications = Publications(by: host)
        host.send(.quickEntry(.addButtonTapped))
        let models = publications.models.dropFirst() + [host.model]
        #expect(models.map(\.quickEntry) == [nil, nil])
        #expect(models.map { $0.taskViewList.taskList?.rows.map(\.title) } == [[], ["Milk"]])
    }
}

/// A window's view holds its host and the composition root holds it weakly, so a closed window's host goes
/// with its view, and the next fan-out passes over it and reaches the window made after it.
@Test @MainActor func aClosedWindowsHostIsReleasedAndReceivesNothing() throws {
    try withFreshDatabase { database in
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        let writer = try app.makeHost(path: nil)
        weak var closed: ModuleHost<AppModule>?
        do {
            let host = try app.makeHost(path: nil)
            closed = host
        }
        let later = try app.makeHost(path: nil)
        #expect(closed == nil)
        writer.send(.taskViewList(.createFolderButtonTapped))
        let opened = try app.makeHost(path: nil)
        #expect(later.model == opened.model, "the fan-out after the closed window reached the window after it")
    }
}

/// The default window's path: the Inbox's list, which the sidebar chooses itself, nothing open in it and no quick
/// entry.
private let defaultWindow = "/view/\(BuiltInTaskViews.inbox)"

/// The order in which two things happened, on the main actor, where the host assigns its model and an observer
/// is told inside the assignment.
@MainActor private final class Order {
    enum Step: Equatable {
        case secondModelMoved
        case firstSendReturned
    }

    var steps: [Step] = []
}

/// Every model a host held when it published the next one, in order, from the one it held when this began.
/// An observer is told as an assignment begins, before the value changes, so what it reads is the model being
/// replaced, and it observes again for the next one; the last published is the host's `model` itself.
///
/// The observer holds the host weakly. The last one it registers is never told, so the host's registrar keeps it,
/// and one that held the host would keep the host, its root and the store with its connection open for the rest
/// of the test process, over a directory `withFreshDatabase` has deleted.
@MainActor private final class Publications {
    private(set) var models: [AppModule.Model] = []

    init(by host: ModuleHost<AppModule>) {
        observe(host)
    }

    private func observe(_ host: ModuleHost<AppModule>) {
        withObservationTracking { _ = host.model } onChange: { [weak self, weak host] in
            MainActor.assumeIsolated {
                guard let self, let host else { return }
                self.models.append(host.model)
                self.observe(host)
            }
        }
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

/// Launches, creates a folder the way a person does in the one window, and answers the folder's id. The
/// composition root and the host are released when this returns, and the store with them, so the next launch
/// over the same file is the only one open.
@MainActor private func launchAndCreateAFolder(_ environment: [String: String]) throws -> ViewID {
    let app = try TodoApp.launch(environment: environment)
    let host = try app.makeHost(path: nil)
    let before = Set(host.model.taskViewList.rows.map(\.id))
    host.send(.taskViewList(.createFolderButtonTapped))
    return try #require(Set(host.model.taskViewList.rows.map(\.id)).subtracting(before).first)
}
