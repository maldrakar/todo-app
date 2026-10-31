import Testing
import AppKit
import Foundation
import Observation
import SwiftUI
import AppFeature
import DeviceFile
import FeatureModule
import TaskViewListFeature
@testable import TodoAppleUI
import TodoCore

/// Which identity the store wrote under is out of reach through the host, which keeps the store to itself, so
/// each launch writes a list and a store opened after every launch has closed its own reads back the device
/// the journal recorded for each list.
@Test @MainActor func launchOpensTheDatabaseAtTheGivenPathAndKeepsTheDeviceBesideIt() throws {
    try withFreshDatabase { database in
        _ = try TodoApp.launch(environment: ["TODO_DB": database])
        #expect(FileManager.default.fileExists(atPath: database))
        let minted = try #require(DeviceFile.read(beside: database), "the first launch keeps the identity it minted")

        let second = try launchAndCreateAList(["TODO_DB": database])
        #expect(DeviceFile.read(beside: database) == minted, "a launch that minted again would have kept its own")

        let third = try launchAndCreateAList(["TODO_DB": database, "TODO_DEVICE": "given"])
        #expect(DeviceFile.read(beside: database) == minted, "an identity the environment names is not kept")

        let fourth = try launchAndCreateAList(["TODO_DB": database, "TODO_DEVICE": ""])

        let journal = try Store.open(path: database, device: Store.newDeviceID(), now: Store.systemNow).journal(after: 0)
        let writers = { (list: ViewID) in Set(journal.filter { $0.entityID == list.rawValue }.map(\.device)) }
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
            let window = try app.makeWindow(path: nil, width: .wide, capabilities: mac)
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
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        let host = try app.makeWindow(path: nil, width: .wide, capabilities: mac).host
        #expect(host.route.path == defaultWindow)
    }
}

/// A window restored or linked to opens on its path, the sidebar's part and the query alike.
@Test @MainActor func aWindowMadeFromAPathOpensIt() throws {
    try withFreshDatabase { database in
        let path = "/view/\(BuiltInTaskViews.today)?quick-entry"
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        let host = try app.makeWindow(path: path, width: .wide, capabilities: mac).host
        #expect(host.route.path == path)
    }
}

/// A path that does not read is the default window, silently, which is restoration's rule (`docs/specs/navigation.md`,
/// section 7): a path that would have opened Today but for a task with no id is refused whole, nothing of it is
/// opened, and the root says nothing, its sentence being a link's.
@Test @MainActor func aWindowMadeFromAnUnreadablePathIsTheDefaultWindow() throws {
    try withFreshDatabase { database in
        let path = "/view/\(BuiltInTaskViews.today)/task"
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        let host = try app.makeWindow(path: path, width: .wide, capabilities: mac).host
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
        #expect(try app.makeWindow(path: nil, width: .wide, capabilities: mac).host.route.path == path)
        let next = try app.makeWindow(path: nil, width: .wide, capabilities: mac)
        #expect(next.host.route.path == defaultWindow)
    }
}

/// A first window with a path of its own, one the system restored, opens that path and spends the launch route all the
/// same, so a window made after it with none opens the default window.
@Test @MainActor func aFirstWindowWithAPathOfItsOwnSpendsTheLaunchRoute() throws {
    try withFreshDatabase { database in
        let restored = "/view/\(BuiltInTaskViews.today)"
        let app = try TodoApp.launch(environment: ["TODO_DB": database, "TODO_ROUTE": "/?quick-entry"])
        let first = try app.makeWindow(path: restored, width: .wide, capabilities: mac)
        #expect(first.host.route.path == restored)
        let next = try app.makeWindow(path: nil, width: .wide, capabilities: mac)
        #expect(next.host.route.path == defaultWindow)
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

/// The route is the URL's path and query alone, so a URL that says more, a host, a user, a password, a port or a
/// fragment, gives none rather than a route that drops what it said: `todo://view/<id>`, one slash short, reads `view`
/// as the host, and the other forms have a path that would read without them.
@Test @MainActor func aURLWithAHostOrAFragmentGivesNil() throws {
    let today = BuiltInTaskViews.today
    for text in ["todo://view/\(today)", "todo://localhost/view/\(today)", "todo://user@/view/\(today)",
                 "todo://:secret@/view/\(today)", "todo://:80/view/\(today)",
                 "todo:///view/\(today)#notes", "todo:///view/\(today)#"] {
        #expect(TodoApp.route(from: try #require(URL(string: text))) == nil, "\(text)")
    }
}

/// A link the system opened in a window goes to that window's host alone, through its world entrance, as a route
/// applied (`docs/specs/navigation.md`, section 7): the other window stays where it was.
@Test @MainActor func aLinkOpensItsRouteInItsOwnWindow() throws {
    try withFreshDatabase { database in
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        let linked = try app.makeWindow(path: nil, width: .wide, capabilities: mac)
        let other = try app.makeWindow(path: nil, width: .wide, capabilities: mac)
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
        let linked = try app.makeWindow(path: path, width: .wide, capabilities: mac)
        let other = try app.makeWindow(path: nil, width: .wide, capabilities: mac)
        linked.open(try #require(URL(string: "todo://view/\(BuiltInTaskViews.today)")))
        #expect(linked.host.model.problem == "The link could not be opened.")
        #expect(linked.host.route.path == path)
        #expect(other.host.model.problem == nil)
    }
}

/// A window is made with the width class it opens with, so that its first frame already has the shape of its layout
/// (navigation state spec, section 4): one made narrow, as iPhone's is, has the Inbox's list in the one path over the
/// sidebar, where a wide one has it in the column.
@Test @MainActor func aWindowMadeNarrowIsLaidOutNarrow() throws {
    try withFreshDatabase { database in
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        let model = try app.makeWindow(path: nil, width: .narrow, capabilities: iPhone).host.model
        guard case .narrow(let path) = model.layout else {
            Issue.record("a window made narrow is laid out narrow, and is \(model.layout)")
            return
        }
        #expect(path.count == 1)
        #expect(listTitles(model) == [], "the Inbox's list, empty in a new database")
    }
}

/// A window is made with what its platform offers, which its view reads once and the root hands to the sidebar
/// (`WindowCapabilities`), each of the two facts passed through on its own, at one width: whether another window can
/// open beside it, where every list's menu offers Open in New Window and otherwise none does
/// (`docs/specs/navigation.md`, section 5), and whether the platform has edit mode, where Edit, sent as the bar's "…"
/// sends it, puts the sidebar in edit mode and otherwise moves nothing (Lists screen spec, sections 7 and 8).
@Test @MainActor func aWindowIsMadeWithWhatItsPlatformOffers() throws {
    try withFreshDatabase { database in
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        for opensWindowsBeside in [true, false] {
            for hasEditMode in [true, false] {
                let capabilities = WindowCapabilities(opensWindowsBeside: opensWindowsBeside, hasEditMode: hasEditMode)
                let host = try app.makeWindow(path: nil, width: .wide, capabilities: capabilities).host
                let rows = host.model.taskViewList.rows
                #expect(!rows.isEmpty, "the built-in lists")
                #expect(rows.allSatisfy { offersANewWindow($0) } == opensWindowsBeside, "\(capabilities)")
                #expect(rows.contains { offersANewWindow($0) } == opensWindowsBeside, "\(capabilities)")
                host.send(.taskViewList(.editMenuItemChosen))
                #expect(host.model.taskViewList.isEditing == hasEditMode, "\(capabilities)")
            }
        }
    }
}

/// The width class a window's view reports goes to that window's host alone, through its world entrance, as a link
/// does (navigation state spec, section 4): the window made narrow is laid out wide once told so, its screens and its
/// route as they were, and the other window stays narrow.
@Test @MainActor func theWindowsWidthReachesItsHost() throws {
    try withFreshDatabase { database in
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        let widened = try app.makeWindow(path: nil, width: .narrow, capabilities: iPhone)
        let other = try app.makeWindow(path: nil, width: .narrow, capabilities: iPhone).host
        let before = widened.host.model
        let otherBefore = other.model
        guard case .narrow(let path) = before.layout, let list = path.first else {
            Issue.record("the Inbox's list in a narrow window is the setup, and the layout is \(before.layout)")
            return
        }
        widened.widthChanged(.wide)
        #expect(widened.host.model.layout == .wide(column: list, path: []))
        #expect(widened.host.model.screens == before.screens)
        #expect(widened.host.route.path == defaultWindow)
        #expect(other.model == otherBefore)
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
        let first = try app.makeWindow(path: nil, width: .wide, capabilities: mac).host
        let writer = try app.makeWindow(path: "/?quick-entry", width: .wide, capabilities: mac).host
        let third = try app.makeWindow(path: nil, width: .wide, capabilities: mac).host
        let before = first.model
        writer.send(.quickEntry(.titleFieldChanged("Milk")))
        writer.send(.quickEntry(.addButtonTapped))
        let opened = try app.makeWindow(path: nil, width: .wide, capabilities: mac).host
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
        let first = try app.makeWindow(path: nil, width: .wide, capabilities: mac).host
        let second = try app.makeWindow(path: nil, width: .wide, capabilities: mac).host
        let order = Order()
        withObservationTracking { _ = second.model } onChange: {
            MainActor.assumeIsolated { order.steps.append(.secondModelMoved) }
        }
        first.send(.taskViewList(.newListMenuItemChosen(in: nil)))
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
        let host = try app.makeWindow(path: "/?quick-entry", width: .wide, capabilities: mac).host
        host.send(.quickEntry(.titleFieldChanged("Milk")))
        let publications = Publications(by: host)
        host.send(.quickEntry(.addButtonTapped))
        let models = publications.models.dropFirst() + [host.model]
        #expect(models.map(\.quickEntry) == [nil, nil])
        #expect(models.map(listTitles) == [[], ["Milk"]])
    }
}

/// A window's view holds its host and the composition root holds it weakly, so a closed window's host goes
/// with its view, and the next fan-out passes over it and reaches the window made after it.
@Test @MainActor func aClosedWindowsHostIsReleasedAndReceivesNothing() throws {
    try withFreshDatabase { database in
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        let writer = try app.makeWindow(path: nil, width: .wide, capabilities: mac).host
        weak var closed: ModuleHost<AppModule>?
        do {
            let window = try app.makeWindow(path: nil, width: .wide, capabilities: mac)
            closed = window.host
        }
        let later = try app.makeWindow(path: nil, width: .wide, capabilities: mac).host
        #expect(closed == nil)
        writer.send(.taskViewList(.newListMenuItemChosen(in: nil)))
        let opened = try app.makeWindow(path: nil, width: .wide, capabilities: mac).host
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
        let writer = try app.makeWindow(path: nil, width: .wide, capabilities: mac).host
        let redraws = [Redraws(), Redraws()]
        let windows = redraws.map { redraws in
            hostInAWindow(ContentClosure(writer: writer, redraws: redraws) {
                WindowView(app: app, value: .constant(nil))
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
        writer.send(.taskViewList(.newListMenuItemChosen(in: nil)))
        turnTheRunLoop(until: redrawn)
        settleTheRunLoop()
        #expect(redrawn(), "the change set redrew both windows and handed each a new value of its view")
        #expect(app.hostsMade == 3, "and the redraw made no host")
    }
}

/// Open in New Window opens a window of its own every time, on the view a window shows too, because a value an open
/// window already has brings that window forward instead of opening one (probed 2026-10-20, macOS 26.7.1): two
/// requests for one route are two values, each with an identity of its own.
@Test func twoRequestsForOneRouteAreTwoValues() {
    let path = "/view/\(BuiltInTaskViews.inbox)"
    #expect(WindowView.Value(path: path) != WindowView.Value(path: path))
}

/// A window writes its route into its value in the group as soon as it is made, which is what the Mac restores it from
/// (`docs/specs/navigation.md`, section 7): a window opened with no value, here the first of a launch with
/// `TODO_ROUTE`, carries one from then on whose text is the route it opened on. The route names Today and not quick
/// entry, so that the test puts up no sheet in the window it holds on screen.
@Test @MainActor func aWindowWritesItsRouteIntoItsValueWhenItIsMade() throws {
    try withFreshDatabase { database in
        let path = "/view/\(BuiltInTaskViews.today)"
        let app = try TodoApp.launch(environment: ["TODO_DB": database, "TODO_ROUTE": path])
        let kept = Kept()
        let window = hostInAWindow(WindowView(app: app, value: kept.binding))
        defer {
            window.contentViewController = nil
            window.close()
        }
        turnTheRunLoop(until: { kept.value != nil })
        #expect(kept.value?.path == path)
    }
}

/// A window keeps its identity through every write and moves its route's text alone, so its value stays its own and
/// no request for another window can equal it: a window made with a value whose text the root writes back otherwise,
/// `/`, which opens the Inbox, carries the Inbox's path under the identity it was made with.
@Test @MainActor func aWindowKeepsItsIdentityThroughItsWrite() throws {
    try withFreshDatabase { database in
        let app = try TodoApp.launch(environment: ["TODO_DB": database])
        let made = WindowView.Value(path: "/")
        let kept = Kept(made)
        let window = hostInAWindow(WindowView(app: app, value: kept.binding))
        defer {
            window.contentViewController = nil
            window.close()
        }
        turnTheRunLoop(until: { kept.value?.path != "/" })
        #expect(kept.value == WindowView.Value(id: made.id, path: defaultWindow))
    }
}

/// A window's value in its group, kept outside the view as the group keeps it.
@MainActor private final class Kept {
    var value: WindowView.Value?

    init(_ value: WindowView.Value? = nil) {
        self.value = value
    }

    /// The binding the window's view is handed, as the group hands it the window's value.
    var binding: Binding<WindowView.Value?> {
        Binding(get: { self.value }, set: { self.value = $0 })
    }
}

/// Whether a row of the sidebar is a list whose menu opens it in a new window.
private func offersANewWindow(_ row: TaskViewList.Model.Row) -> Bool {
    guard case .list(let list) = row.kind, let menu = list.menu else { return false }
    return menu.sections.contains { section in
        section.items.contains { $0.action == .openInNewWindowMenuItemChosen(row.id) }
    }
}

/// The titles of the list standing first over the sidebar in a window's model, read as the root view reads it, the
/// first id of the layout, the narrow path's first or the wide column, and its screen's model, and nil when no list
/// stands there.
private func listTitles(_ model: AppModule.Model) -> [String]? {
    let first = switch model.layout {
    case .narrow(let path): path.first
    case .wide(let column, _): column
    }
    guard let first, case .list(let list)? = model.screens[first] else { return nil }
    return list.rows.map(\.title)
}

/// The default window's path: the Inbox's list, which the sidebar chooses itself, nothing open in it and no quick
/// entry.
private let defaultWindow = "/view/\(BuiltInTaskViews.inbox)"

/// What the Mac offers a window, which most tests make theirs with, another window beside it and no edit mode; and what
/// iPhone offers, no window beside it and edit mode.
private let mac = WindowCapabilities(opensWindowsBeside: true, hasEditMode: false)
private let iPhone = WindowCapabilities(opensWindowsBeside: false, hasEditMode: true)

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

/// Launches, creates a list the way a person does in the one window, and answers the list's id. The
/// composition root and the host are released when this returns, and the store with them, so the next launch
/// over the same file is the only one open.
@MainActor private func launchAndCreateAList(_ environment: [String: String]) throws -> ViewID {
    let app = try TodoApp.launch(environment: environment)
    let host = try app.makeWindow(path: nil, width: .wide, capabilities: mac).host
    let before = Set(host.model.taskViewList.rows.map(\.id))
    host.send(.taskViewList(.newListMenuItemChosen(in: nil)))
    return try #require(Set(host.model.taskViewList.rows.map(\.id)).subtracting(before).first)
}
