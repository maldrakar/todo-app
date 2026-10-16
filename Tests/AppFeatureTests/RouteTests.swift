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
private let table: [(route: Route, text: String)] = [
    (.default, "/"),
    (pane(view), "/view/\(view)"),
    (pane(view, task: task), "/view/\(view)/task/\(task)"),
    (pane(view, task: task, quickEntry: true), "/view/\(view)/task/\(task)?quick-entry"),
    (pane(view, quickEntry: true), "/view/\(view)?quick-entry"),
    (Route(sidebar: .init(list: nil), quickEntry: QuickEntry.Route()), "/?quick-entry"),
]

/// Each row written and read: the text a route writes is the row's, and the row's text reads as the route.
@Test func everyRowOfTheTableWritesAndReadsBack() throws {
    for row in table {
        #expect(row.route.text == row.text)
        #expect(try Route(text: row.text) == row.route, "reading \(row.text)")
    }
}

/// Starting from the value: a route written down and read again is the route, which is what restoring a window
/// from the text it kept depends on (spec section 7).
@Test func aRouteReadsBackToTheSameValue() throws {
    for row in table {
        #expect(try Route(text: row.route.text) == row.route, "after writing \(row.text)")
    }
}

/// A task is opened inside a view's list, so it has no place before one (spec section 2).
@Test func taskWithoutViewIsOutOfPlace() {
    #expect(throws: RouteError.segmentOutOfPlace("task")) { try Route(text: "/task/\(task)") }
    #expect(throws: RouteError.segmentOutOfPlace("task")) { try Route(text: "/task/\(task)/view/\(view)") }
}

/// A segment the window's route has no place for refuses the whole route and is named, wherever it stands.
@Test func anUnknownSegmentIsRefused() {
    #expect(throws: RouteError.unknownSegment("list")) { try Route(text: "/list/\(view)") }
    #expect(throws: RouteError.unknownSegment("tag")) { try Route(text: "/view/\(view)/tag/\(task)") }
    #expect(throws: RouteError.unknownSegment("edit")) { try Route(text: "/view/\(view)/task/\(task)/edit") }
    #expect(throws: RouteError.unknownSegment("View")) { try Route(text: "/View/\(view)") }
}

/// An id is a segment `UUID(uuidString:)` reads whole, in either case, and it is kept as the command line prints it,
/// lowercase, so that a link typed by hand opens the same view as the one the app wrote.
@Test func anUppercaseIDIsReadLowercased() throws {
    let shouted = "/view/\(view.rawValue.uppercased())/task/\(task.rawValue.uppercased())"
    let read = try Route(text: shouted)
    #expect(read == pane(view, task: task))
    #expect(read.text == "/view/\(view)/task/\(task)")
}

/// What stands where an id must and does not read as one is refused as written, and `view` or `task` with
/// nothing after it has an empty one.
@Test func aStringThatIsNotAnIDIsRefused() {
    #expect(throws: RouteError.notAnID("inbox")) { try Route(text: "/view/inbox") }
    #expect(throws: RouteError.notAnID("42")) { try Route(text: "/view/\(view)/task/42") }
    #expect(throws: RouteError.notAnID("\(view)x")) { try Route(text: "/view/\(view)x") }
    #expect(throws: RouteError.notAnID("")) { try Route(text: "/view") }
    #expect(throws: RouteError.notAnID("")) { try Route(text: "/view/\(view)/task") }
}

/// `UUID(uuidString:)` stops reading at a NUL, so an id with a NUL and anything after it would read as the id before
/// it. The whole segment has to be the id, or it is refused as written.
@Test func anIDWithAnythingAfterANULIsRefused() {
    let view = "\(view)\u{0}junk"
    #expect(throws: RouteError.notAnID(view)) { try Route(text: "/view/\(view)") }
    let task = "\(task)\u{0}"
    #expect(throws: RouteError.notAnID(task)) { try Route(text: "/view/\(BuiltInTaskViews.inbox)/task/\(task)") }
}

/// `quick-entry` is the one query item the window knows.
@Test func anUnknownQueryItemIsRefused() {
    #expect(throws: RouteError.unknownQuery("search")) { try Route(text: "/?search") }
    #expect(throws: RouteError.unknownQuery("sheet")) { try Route(text: "/view/\(view)?quick-entry&sheet") }
    #expect(throws: RouteError.unknownQuery("Quick-Entry")) { try Route(text: "/?Quick-Entry") }
}

/// A trailing slash leaves an empty segment after it, which is no segment the route has a place for.
@Test func aTrailingSlashIsRefused() {
    #expect(throws: RouteError.unknownSegment("")) { try Route(text: "/view/\(view)/") }
    #expect(throws: RouteError.unknownSegment("")) { try Route(text: "/view/\(view)/task/\(task)/") }
    #expect(throws: RouteError.unknownSegment("")) { try Route(text: "/view/") }
}

/// The empty string is not `/`: a caller that stripped a link down to nothing has no route to hand on, and the
/// codec does not guess the default window for it.
@Test func anEmptyStringIsRefused() {
    #expect(throws: RouteError.unknownSegment("")) { try Route(text: "") }
}

/// `quick-entry` is a bare flag: no screen in this epic opens with an argument, and the text form for one is
/// settled when the first screen needs one (spec section 2).
@Test func aQuickEntryWithAValueIsRefused() {
    #expect(throws: RouteError.unknownQuery("quick-entry=1")) { try Route(text: "/?quick-entry=1") }
    #expect(throws: RouteError.unknownQuery("quick-entry=")) { try Route(text: "/view/\(view)?quick-entry=") }
}

/// A string that does not begin with `/` is refused with what stands before its first slash, which names the
/// scheme a caller forgot to strip (spec section 2: the caller strips the scheme and the site).
@Test func aStringThatDoesNotBeginWithASlashIsRefused() {
    #expect(throws: RouteError.unknownSegment("view")) { try Route(text: "view/\(view)") }
    #expect(throws: RouteError.unknownSegment("todo:")) { try Route(text: "todo:///view/\(view)") }
    #expect(throws: RouteError.unknownSegment("")) { try Route(text: "?quick-entry") }
}

/// A doubled slash is an empty segment wherever it stands, the place of an id included.
@Test func aDoubledSlashIsRefused() {
    #expect(throws: RouteError.unknownSegment("")) { try Route(text: "//") }
    #expect(throws: RouteError.unknownSegment("")) { try Route(text: "//view/\(view)") }
    #expect(throws: RouteError.unknownSegment("")) { try Route(text: "/view//\(view)") }
    #expect(throws: RouteError.unknownSegment("")) { try Route(text: "/view/\(view)//task/\(task)") }
}

/// A window has one pane and the pane one task, so `view` and `task` each have one place, and a second one is
/// out of it, as `view` is after `task`.
@Test func aSegmentASecondTimeIsOutOfPlace() {
    #expect(throws: RouteError.segmentOutOfPlace("view")) { try Route(text: "/view/\(view)/view/\(view)") }
    #expect(throws: RouteError.segmentOutOfPlace("task")) { try Route(text: "/view/\(view)/task/\(task)/task/\(task)") }
    #expect(throws: RouteError.segmentOutOfPlace("view")) { try Route(text: "/view/\(view)/task/\(task)/view/\(view)") }
}

/// A window has one quick entry, so its query item has one place too, and the same item again is out of it
/// rather than unknown.
@Test func quickEntryASecondTimeIsOutOfPlace() {
    #expect(throws: RouteError.segmentOutOfPlace("quick-entry")) { try Route(text: "/?quick-entry&quick-entry") }
}

/// A `?` opens a query, and a query of nothing, or an item of nothing after an `&`, is an empty item, which is
/// no item the window knows: the writer never puts a `?` without an item after it.
@Test func anEmptyQueryItemIsRefused() {
    #expect(throws: RouteError.unknownQuery("")) { try Route(text: "/?") }
    #expect(throws: RouteError.unknownQuery("")) { try Route(text: "/view/\(view)?") }
    #expect(throws: RouteError.unknownQuery("")) { try Route(text: "/?quick-entry&") }
    #expect(throws: RouteError.unknownQuery("")) { try Route(text: "/?&quick-entry") }
}

/// Every offence is found reading from the left, so a path that is wrong in two places is refused for the
/// first, and the query is read only after the path.
@Test func theFirstOffenceFromTheLeftIsTheOneNamed() {
    #expect(throws: RouteError.notAnID("x")) { try Route(text: "/view/x/note") }
    #expect(throws: RouteError.unknownSegment("note")) { try Route(text: "/note?search") }
}
