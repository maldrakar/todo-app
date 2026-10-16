import Testing
import AppFeature
import FeatureModule
import QuickEntryFeature
import TaskListFeature
import TaskScreenFeature
import TaskViewListFeature
import TodoCore

private typealias Route = AppModule.Route

/// A view and a task as the command line prints their ids, the lowercase UUID string of `EntityID`. Fixed, so
/// that a refusal can name them and a failure reads the same on every run.
private let view = ViewID("6f1c2d3e-4a5b-4c6d-8e7f-0a1b2c3d4e5f")
private let task = TaskID("0d9e8f7a-6b5c-4d3e-9f2a-1b0c9d8e7f6a")

/// The sidebar's list on a view, the task open in it when there is one, and quick entry when it is up, which is
/// the shape every row of the text form's table reads as.
private func pane(_ view: ViewID, task: TaskID? = nil, quickEntry: Bool = false) -> Route {
    Route(
        sidebar: .init(list: .init(head: view, task: task.map { TaskScreen.Route(head: $0) })),
        quickEntry: quickEntry ? QuickEntry.Route() : nil
    )
}

/// The table of spec section 2, a row per line, with the two rows quick entry adds where the table has one: up
/// over a view with nothing open in it, and up over the default window.
private let table: [(route: Route, path: String)] = [
    (.default, "/"),
    (pane(view), "/view/\(view)"),
    (pane(view, task: task), "/view/\(view)/task/\(task)"),
    (pane(view, task: task, quickEntry: true), "/view/\(view)/task/\(task)?quick-entry"),
    (pane(view, quickEntry: true), "/view/\(view)?quick-entry"),
    (Route(sidebar: .init(list: nil), quickEntry: QuickEntry.Route()), "/?quick-entry"),
]

/// Each row written and read: the path a route writes is the row's, and the row's path reads as the route.
@Test func everyRowOfTheTableWritesAndReadsBack() throws {
    for row in table {
        #expect(row.route.path == row.path)
        #expect(try Route(path: row.path) == row.route, "reading \(row.path)")
    }
}

/// Starting from the value: a route written down and read again is the route, which is what restoring a window
/// from the path it kept depends on (spec section 7).
@Test func aRouteReadsBackToTheSameValue() throws {
    for row in table {
        #expect(try Route(path: row.route.path) == row.route, "after writing \(row.path)")
    }
}

/// An id reads in either case and is written as the command line prints it, lowercase, so that a link typed by
/// hand opens the same view as the one the app wrote, and writes back as the app writes it.
@Test func anUppercaseIDIsReadLowercased() throws {
    let shouted = "/view/\(view.rawValue.uppercased())/task/\(task.rawValue.uppercased())"
    let read = try Route(path: shouted)
    #expect(read == pane(view, task: task))
    #expect(read.path == "/view/\(view)/task/\(task)")
}

/// Each route reads its own part of the path and refuses what it cannot read, and the window refuses with what it
/// threw: here the list's route, which finds `task` before a view, `view` after the task and a word it does not
/// know, the task screen's route, which finds no id after `task`, and the core's reading of an id, which reads one
/// only whole.
@Test func whatARouteRefusesInThePathIsWhatTheWindowRefuses() {
    #expect(throws: RouteError.segmentOutOfPlace("task")) { try Route(path: "/task/\(task)") }
    #expect(throws: RouteError.segmentOutOfPlace("view")) { try Route(path: "/view/\(view)/task/\(task)/view/\(view)") }
    #expect(throws: RouteError.unknownSegment("edit")) { try Route(path: "/view/\(view)/task/\(task)/edit") }
    #expect(throws: RouteError.notAnID("42")) { try Route(path: "/view/\(view)/task/42") }
    #expect(throws: RouteError.notAnID("inbox")) { try Route(path: "/view/inbox") }
    #expect(throws: RouteError.notAnID("\(view)\u{0}junk")) { try Route(path: "/view/\(view)\u{0}junk") }
    #expect(throws: RouteError.notAnID("\(task)\u{0}")) { try Route(path: "/view/\(BuiltInTaskViews.inbox)/task/\(task)\u{0}") }
}

/// `quick-entry` is the one query item the window knows.
@Test func anUnknownQueryItemIsRefused() {
    #expect(throws: RouteError.unknownQuery("search")) { try Route(path: "/?search") }
    #expect(throws: RouteError.unknownQuery("sheet")) { try Route(path: "/view/\(view)?quick-entry&sheet") }
    #expect(throws: RouteError.unknownQuery("Quick-Entry")) { try Route(path: "/?Quick-Entry") }
}

/// A trailing slash leaves an empty segment after it, which is no segment the route has a place for.
@Test func aTrailingSlashIsRefused() {
    #expect(throws: RouteError.unknownSegment("")) { try Route(path: "/view/\(view)/") }
    #expect(throws: RouteError.unknownSegment("")) { try Route(path: "/view/\(view)/task/\(task)/") }
    #expect(throws: RouteError.unknownSegment("")) { try Route(path: "/view/") }
}

/// The empty string is not `/`: a caller that stripped a link down to nothing has no route to hand on, and the
/// codec does not guess the default window for it.
@Test func anEmptyStringIsRefused() {
    #expect(throws: RouteError.unknownSegment("")) { try Route(path: "") }
}

/// `quick-entry` is a bare flag: no screen in this epic opens with an argument, and the text form for one is
/// settled when the first screen needs one (spec section 2).
@Test func aQuickEntryWithAValueIsRefused() {
    #expect(throws: RouteError.unknownQuery("quick-entry=1")) { try Route(path: "/?quick-entry=1") }
    #expect(throws: RouteError.unknownQuery("quick-entry=")) { try Route(path: "/view/\(view)?quick-entry=") }
}

/// A string that does not begin with `/` is refused with what stands before its first slash, which names the
/// scheme a caller forgot to strip (spec section 2: the caller strips the scheme and the site).
@Test func aStringThatDoesNotBeginWithASlashIsRefused() {
    #expect(throws: RouteError.unknownSegment("view")) { try Route(path: "view/\(view)") }
    #expect(throws: RouteError.unknownSegment("todo:")) { try Route(path: "todo:///view/\(view)") }
    #expect(throws: RouteError.unknownSegment("")) { try Route(path: "?quick-entry") }
}

/// A doubled slash is an empty segment wherever it stands, the place of an id included: the window keeps the empty
/// segments of its path for the routes to refuse.
@Test func aDoubledSlashIsRefused() {
    #expect(throws: RouteError.unknownSegment("")) { try Route(path: "//") }
    #expect(throws: RouteError.unknownSegment("")) { try Route(path: "//view/\(view)") }
    #expect(throws: RouteError.unknownSegment("")) { try Route(path: "/view//\(view)") }
    #expect(throws: RouteError.unknownSegment("")) { try Route(path: "/view/\(view)//task/\(task)") }
}

/// A window has one quick entry, so its query item has one place too, and the same item again is out of it
/// rather than unknown.
@Test func quickEntryASecondTimeIsOutOfPlace() {
    #expect(throws: RouteError.segmentOutOfPlace("quick-entry")) { try Route(path: "/?quick-entry&quick-entry") }
}

/// A `?` opens a query, and a query of nothing, or an item of nothing after an `&`, is an empty item, which is
/// no item the window knows: the writer never puts a `?` without an item after it.
@Test func anEmptyQueryItemIsRefused() {
    #expect(throws: RouteError.unknownQuery("")) { try Route(path: "/?") }
    #expect(throws: RouteError.unknownQuery("")) { try Route(path: "/view/\(view)?") }
    #expect(throws: RouteError.unknownQuery("")) { try Route(path: "/?quick-entry&") }
    #expect(throws: RouteError.unknownQuery("")) { try Route(path: "/?&quick-entry") }
}

/// Every offence is found reading from the left, so a path that is wrong in two places is refused for the
/// first, and the query is read only after the path, its items from the left too.
@Test func theFirstOffenceFromTheLeftIsTheOneNamed() {
    #expect(throws: RouteError.notAnID("x")) { try Route(path: "/view/x/note") }
    #expect(throws: RouteError.unknownSegment("note")) { try Route(path: "/note?search") }
    #expect(throws: RouteError.unknownQuery("search")) { try Route(path: "/?search&quick-entry&quick-entry") }
}
