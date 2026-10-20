import Testing
import AppKit
import Foundation
import Observation
import SwiftUI
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
            let window = try app.makeWindow(path: nil)
            released = window.host
            releasedRoot = app
        }
        #expect(released == nil)
        #expect(releasedRoot == nil, "the composition root went too, and the store with it")
    }
}

/// A window made from no path is the default window.
@Test @MainActor func aWindowMadeFromNoPathIsTheDefaultWindow() throws {
    try withFreshDatabase { database in
        let host = try TodoApp.launch(environment: ["TODO_DB": database]).makeWindow(path: nil).host
        #expect(host.route.path == defaultWindow)
    }
}

/// A window restored or linked to opens on its path, the sidebar's part and the query alike.
@Test @MainActor func aWindowMadeFromAPathOpensIt() throws {
    try withFreshDatabase { database in
        let path = "/view/\(BuiltInTaskViews.today)?quick-entry"
        let host = try TodoApp.launch(environment: ["TODO_DB": database]).makeWindow(path: path).host
        #expect(host.route.path == path)
    }
}

/// A path that does not read is the default window, silently, which is restoration's rule (`docs/specs/navigation.md`,
/// section 7): a path that would have opened Today but for a task with no id is refused whole, nothing of it is
/// opened, and the root says nothing, its sentence being a link's.
@Test @MainActor func aWindowMadeFromAnUnreadablePathIsTheDefaultWindow() throws {
    try withFreshDatabase { database in
        let path = "/view/\(BuiltInTaskViews.today)/task"
        let host = try TodoApp.launch(environment: ["TODO_DB": database]).makeWindow(path: path).host
        #expect(host.route.path == defaultWindow)
        #expect(host.model.problem == nil)
    }
}

/// The Mac executable has no URL scheme, so a link is handed to it at launch, in `TODO_ROUTE`, and read with the
/// route's codec as a link is (`docs/specs/navigation.md`, section 7).
@Test @MainActor func aLaunchRouteIsReadFromTheEnvironment() throws {
    try withFreshDatabase { database in
        let path = "/view/\(BuiltInTaskViews.today)/task/\(TaskID())?quick-entry"
        let app = try TodoApp.launch(environment: ["TODO_DB": database, "TODO_ROUTE": path])
        #expect(app.launchRoute == (try AppModule.Route(path: path)))
    }
}

/// A `TODO_ROUTE` exported empty names no route, and neither does one that does not read, nor none at all.
@Test @MainActor func anEmptyLaunchRouteIsNil() throws {
    try withFreshDatabase { database in
        for route in ["", "/view", nil] as [String?] {
            let environment = ["TODO_DB": database, "TODO_ROUTE": route].compactMapValues { $0 }
            let app = try TodoApp.launch(environment: environment)
            #expect(app.launchRoute == nil, "\(String(describing: route))")
        }
    }
}

/// `TODO_ROUTE` goes to the first window made with no path of its own and is spent there: every later window made with
/// none, Cmd-N's, opens the default window (the owner, 2026-10-20).
@Test @MainActor func theFirstWindowMadeWithNoPathOpensTheLaunchRoute() throws {
    try withFreshDatabase { database in
        let path = "/view/\(BuiltInTaskViews.today)?quick-entry"
        let app = try TodoApp.launch(environment: ["TODO_DB": database, "TODO_ROUTE": path])
        #expect(try app.makeWindow(path: nil).host.route.path == path)
        #expect(try app.makeWindow(path: nil).host.route.path == defaultWindow)
    }
}

/// A first window with a path of its own, one the system restored, opens that path and spends the launch route all the
/// same, so a window made after it with none opens the default window.
@Test @MainActor func aFirstWindowWithAPathOfItsOwnSpendsTheLaunchRoute() throws {
    try withFreshDatabase { database in
        let restored = "/view/\(BuiltInTaskViews.today)"
        let app = try TodoApp.launch(environment: ["TODO_DB": database, "TODO_ROUTE": "/?quick-entry"])
        #expect(try app.makeWindow(path: restored).host.route.path == restored)
        #expect(try app.makeWindow(path: nil).host.route.path == defaultWindow)
    }
}

/// A link is the scheme and the window's route in its text form, `todo:///view/<id>/task/<id>`: the scheme is stripped
/// and the rest read with the route's codec (`docs/specs/navigation.md`, section 7).
@Test @MainActor func aURLWithTheSchemeReadsAsARoute() throws {
    let path = "/view/\(BuiltInTaskViews.today)/task/\(TaskID())"
    #expect(TodoApp.route(from: try #require(URL(string: "todo://" + path))) == (try AppModule.Route(path: path)))
}

/// The query is the link's too: `todo:///view/<id>?quick-entry` opens the view with quick entry up.
@Test @MainActor func aURLWithTheQueryReadsAsARoute() throws {
    let path = "/view/\(BuiltInTaskViews.today)?quick-entry"
    let url = try #require(URL(string: "todo://" + path))
    let route = try #require(TodoApp.route(from: url))
    #expect(route == (try AppModule.Route(path: path)))
    #expect(route.quickEntry != nil)
}

/// A link whose path or query does not read gives no route, which its window answers with the root's sentence: a task
/// with no id, a segment no route owns, an empty item in the query, and no path at all.
@Test @MainActor func anUnreadableURLGivesNil() throws {
    let today = BuiltInTaskViews.today
    for text in ["todo:///view/\(today)/task", "todo:///settings", "todo:///view/\(today)?", "todo:"] {
        #expect(TodoApp.route(from: try #require(URL(string: text))) == nil, "\(text)")
    }
}

/// The route is the URL's path and query alone, so a URL that says more, a host, a user or a fragment, gives none
/// rather than a route that drops what it said: `todo://view/<id>`, one slash short, reads `view` as the host, and the
/// other forms have a path that would read without them.
@Test @MainActor func aURLWithAHostOrAFragmentGivesNil() throws {
    let today = BuiltInTaskViews.today
    for text in ["todo://view/\(today)", "todo://localhost/view/\(today)", "todo://user@/view/\(today)",
                 "todo:///view/\(today)#notes", "todo:///view/\(today)#"] {
        #expect(TodoApp.route(from: try #require(URL(string: text))) == nil, "\(text)")
    }
}

/// A link the system opened in a window goes to that window's host alone, through its world entrance, as a route
/// applied (`docs/specs/navigation.md`, section 7): the other window stays where it was.
@Test @MainActor func aLinkOpensItsRouteInItsOwnWindow() throws {
    try withFreshDatabase { database in
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        let linked = try app.makeWindow(path: nil)
        let other = try app.makeWindow(path: nil)
        let path = "/view/\(BuiltInTaskViews.today)?quick-entry"
        linked.open(try #require(URL(string: "todo://" + path)))
        #expect(linked.host.route.path == path)
        #expect(linked.host.model.problem == nil)
        #expect(other.host.route.path == defaultWindow)
    }
}

/// A link that does not read leaves its window where it was, and the root says so in that window alone.
@Test @MainActor func anUnreadableLinkSaysSoInItsOwnWindow() throws {
    try withFreshDatabase { database in
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        let path = "/view/\(BuiltInTaskViews.today)"
        let linked = try app.makeWindow(path: path)
        let other = try app.makeWindow(path: nil)
        linked.open(try #require(URL(string: "todo://view/\(BuiltInTaskViews.today)")))
        #expect(linked.host.model.problem == "The link could not be opened.")
        #expect(linked.host.route.path == path)
        #expect(other.host.model.problem == nil)
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
        let first = try app.makeWindow(path: nil).host
        let writer = try app.makeWindow(path: "/?quick-entry").host
        let third = try app.makeWindow(path: nil).host
        let before = first.model
        writer.send(.quickEntry(.titleFieldChanged("Milk")))
        writer.send(.quickEntry(.addButtonTapped))
        let opened = try app.makeWindow(path: nil).host
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
        let first = try app.makeWindow(path: nil).host
        let second = try app.makeWindow(path: nil).host
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
        let host = try app.makeWindow(path: "/?quick-entry").host
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
        let writer = try app.makeWindow(path: nil).host
        weak var closed: ModuleHost<AppModule>?
        do {
            let window = try app.makeWindow(path: nil)
            closed = window.host
        }
        let later = try app.makeWindow(path: nil).host
        #expect(closed == nil)
        writer.send(.taskViewList(.createFolderButtonTapped))
        let opened = try app.makeWindow(path: nil).host
        #expect(later.model == opened.model, "the fan-out after the closed window reached the window after it")
    }
}

/// One host per window, the composition risk a host per window brings back (`docs/specs/navigation.md`, "Risks";
/// ADR-0008): each window's view, hosted in a window of its own, makes a host of its own when the window appears and
/// never again. Two windows make two hosts, which one host shared by every window, the `static let` the scene held
/// in #93, would not. The count is of the windows `makeWindow` made, and not of the entrances still alive, because the
/// change set that forces the redraw also prunes the entrances of released hosts, which would hide a second host
/// made and dropped by the redraw.
///
/// The window's view sits where the scene puts it, in a content closure that runs more than once for a window, twice
/// for the first window of the Mac executable on 2026-10-18, and hands the window a new value of the view on every run.
/// Here that closure runs again on every model the writer publishes, so the change set that redraws the windows hands
/// each a new value too, and a host made where the value is made, rather than kept in the view's state, is made again.
@Test @MainActor func aWindowMakesOneHost() throws {
    try withFreshDatabase { database in
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        let writer = try app.makeWindow(path: nil).host
        let redraws = [Redraws(), Redraws()]
        let windows = redraws.map { redraws in
            hostInAWindow(ContentClosure(writer: writer, redraws: redraws) {
                WindowView(app: app, path: .constant(nil))
            })
        }
        defer {
            for window in windows {
                window.contentViewController = nil
                window.close()
            }
        }
        turnTheRunLoop(until: { app.hostsMade == 3 })
        #expect(app.hostsMade == 3, "the writer's host, and one for each window, made when it appeared")

        let before = redraws.map(\.count)
        let redrawn = { zip(redraws, before).allSatisfy { $0.count > $1 } }
        writer.send(.taskViewList(.createFolderButtonTapped))
        turnTheRunLoop(until: redrawn)
        settleTheRunLoop()
        #expect(redrawn(), "the change set redrew both windows and handed each a new value of its view")
        #expect(app.hostsMade == 3, "and the redraw made no host")
    }
}

/// A window writes its route into its value in the group as soon as it is made, which is what the Mac restores it from
/// (`docs/specs/navigation.md`, section 7): a window opened with no value, here the first of a launch with
/// `TODO_ROUTE`, carries the route it opened on from then on, and not nil.
@Test @MainActor func aWindowWritesItsRouteIntoItsValueWhenItIsMade() throws {
    try withFreshDatabase { database in
        let path = "/view/\(BuiltInTaskViews.today)?quick-entry"
        let app = try TodoApp.launch(environment: ["TODO_DB": database, "TODO_ROUTE": path])
        let value = Value()
        let window = hostInAWindow(WindowView(app: app, path: Binding(get: { value.path }, set: { value.path = $0 })))
        defer {
            window.contentViewController = nil
            window.close()
        }
        turnTheRunLoop(until: { value.path != nil })
        #expect(value.path == path)
    }
}

/// A window's value in its group, kept outside the view as the group keeps it.
@MainActor private final class Value {
    var path: String?
}

/// The default window's path: the Inbox's list, which the sidebar chooses itself, nothing open in it and no quick
/// entry.
private let defaultWindow = "/view/\(BuiltInTaskViews.inbox)"

/// A scene's content closure in miniature: its body hands the window a new value of its content on every run, and
/// it runs again on every model the writer publishes.
private struct ContentClosure<Content: View>: View {
    let writer: ModuleHost<AppModule>
    let redraws: Redraws
    @ViewBuilder let content: () -> Content

    var body: some View {
        let _ = redraws.record(writer.model)
        content()
    }
}

/// How many times a content closure ran, kept outside the view so that counting does not redraw it.
@MainActor private final class Redraws {
    private(set) var count = 0

    /// Counts a run. It takes the model a run reads so that the read is the call, which is what makes the next
    /// model the writer publishes run the closure again.
    func record(_ model: AppModule.Model) {
        count += 1
    }
}

/// A window of its own around `rootView`, on screen, as the scene puts a window's content in one.
@MainActor private func hostInAWindow(_ rootView: some View) -> NSWindow {
    let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
    // An `NSWindow` made in code is released by its own `close()` unless told otherwise, which under ARC releases it
    // a second time.
    window.isReleasedWhenClosed = false
    window.orderFront(nil)
    return window
}

/// Turns the main run loop, where AppKit and SwiftUI do their work, until `condition` holds or five seconds have
/// passed, whichever comes first; the caller's expectation says which.
@MainActor private func turnTheRunLoop(until condition: () -> Bool) {
    let deadline = Date.now.addingTimeInterval(5)
    while !condition(), Date.now < deadline {
        RunLoop.main.run(until: Date.now.addingTimeInterval(0.05))
    }
}

/// Turns the main run loop ten more passes of a fiftieth of a second each, so that work one pass behind what a wait
/// saw has run before the expectations are read: a bounded wait, not a timing assertion (`docs/style.md`).
@MainActor private func settleTheRunLoop() {
    for _ in 0..<10 {
        RunLoop.main.run(until: Date.now.addingTimeInterval(0.02))
    }
}

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
    let host = try app.makeWindow(path: nil).host
    let before = Set(host.model.taskViewList.rows.map(\.id))
    host.send(.taskViewList(.createFolderButtonTapped))
    return try #require(Set(host.model.taskViewList.rows.map(\.id)).subtracting(before).first)
}
