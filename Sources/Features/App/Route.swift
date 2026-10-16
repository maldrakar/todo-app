// Sources/Features/App/Route.swift
import FeatureModule
import QuickEntryFeature
import TaskListFeature
import TaskScreenFeature
import TaskViewListFeature
import TodoCore

extension AppModule {
    /// The route of the root, which is the route of the window: the sidebar's, with the list open in it and the
    /// task open in that, and whether quick entry is up (spec section 2). It is what a link carries, what a
    /// window is restored from and what the web's address bar shows, each through its one text form, `text`.
    public struct Route: RouteValue {
        /// The same for every window, which has one root: the root is made from a route once and every later
        /// route reaches it as `.route`, of which it reads the tail.
        public var head: NoHead { NoHead() }

        /// The sidebar's route, which carries the list open in it, and none, which leaves the list to follow the
        /// sidebar's choice.
        public let sidebar: TaskViewList.Route

        /// Quick entry when it is up, and nil when it is not, which closes a live one, its draft with it: a draft
        /// is session state, which no route carries (spec section 2).
        public let quickEntry: QuickEntry.Route?

        public init(sidebar: TaskViewList.Route, quickEntry: QuickEntry.Route?) {
            self.sidebar = sidebar
            self.quickEntry = quickEntry
        }

        /// The default window: it names no list, so the sidebar chooses Inbox itself and opens its list; no quick
        /// entry.
        public static let `default` = Route(sidebar: .init(list: nil), quickEntry: nil)

        /// The text form: `/`, `/view/<id>`, `/view/<id>/task/<id>`, with `?quick-entry` when it is up.
        ///
        /// It undoes `text`: `/view/<id>` opens the sidebar's list on the view, `/task/<id>` after it opens the task
        /// in that list, and `?quick-entry` adds quick entry. So a text that reads writes back as itself but for the
        /// case of its ids, and a route reads back from its `text` as itself. A route is data from outside, so
        /// anything else refuses the whole route with the segment named, read from the left so that the first
        /// offence is the one named, the path before the query, and nothing traps (spec section 2,
        /// `docs/style.md`). An id is a segment `UUID(uuidString:)` reads whole, in either case, and is kept lowercase,
        /// the form the command line prints. The string is the path and the query alone: a scheme or a site is the
        /// platform's wrapping, which its caller strips, so a string that does not begin with `/` is refused
        /// rather than unwrapped.
        public init(text: String) throws(RouteError) {
            let query = text.firstIndex(of: "?")
            let list = try Route.list(reading: text[..<(query ?? text.endIndex)])
            let quickEntry = try Route.quickEntry(reading: query.map { text[text.index(after: $0)...] })
            self.init(sidebar: .init(list: list), quickEntry: quickEntry)
        }

        /// The text form of the route: the view of the sidebar's list and the task open in it as the path, and
        /// quick entry as a query item, the chain of screens being the path and a modal being beside it (spec
        /// section 2). A sidebar with no list is written as `/`, which leaves the choice to the sidebar. Ids are
        /// written as `EntityID.description` prints them.
        public var text: String {
            var segments: [String] = []
            if let list = sidebar.list {
                segments += [Segment.view.rawValue, list.head.description]
                if let task = list.task { segments += [Segment.task.rawValue, task.head.description] }
            }
            let query = quickEntry == nil ? "" : "?" + Route.quickEntryItem
            return "/" + segments.joined(separator: "/") + query
        }

        /// The list a path names, and nil for `/`, which names none.
        ///
        /// Each word has one place: `view` first, and `task` after the view's id, each followed by its id. A
        /// word the path knows anywhere else, a second `view` or `task` included, is out of place, and any
        /// other segment, the empty one between two slashes or after a trailing one included, is unknown.
        private static func list(reading path: Substring) throws(RouteError) -> TaskList.Route? {
            guard path.first == "/" else { throw .unknownSegment(String(path.prefix { $0 != "/" })) }
            guard path != "/" else { return nil }
            var segments = path.dropFirst().split(separator: "/", omittingEmptySubsequences: false).map(String.init)[...]
            var view: ViewID?
            var task: TaskID?
            while let segment = segments.popFirst() {
                switch (Segment(rawValue: segment), view, task) {
                case (.view?, nil, _): view = try segments.popID(readBy: ViewID.init(uuidString:))
                case (.task?, _?, nil): task = try segments.popID(readBy: TaskID.init(uuidString:))
                case (_?, _, _): throw .segmentOutOfPlace(segment)
                case (nil, _, _): throw .unknownSegment(segment)
                }
            }
            // A path past `/` that did not throw began with `view`, so the view is there; `map` says so without a
            // force unwrap.
            return view.map { TaskList.Route(head: $0, task: task.map { TaskScreen.Route(head: $0) }) }
        }

        /// Quick entry, when the query says it is up. The one item is a bare flag, with no value, since no
        /// screen in this epic opens with an argument (spec section 2), and it has one place, so a second one
        /// is out of it. Any other item is unknown, the empty one a `?` or an `&` with nothing after it leaves
        /// included, which the writer never writes.
        private static func quickEntry(reading query: Substring?) throws(RouteError) -> QuickEntry.Route? {
            guard let query else { return nil }
            var quickEntry: QuickEntry.Route?
            for item in query.split(separator: "&", omittingEmptySubsequences: false).map(String.init) {
                guard item == quickEntryItem else { throw .unknownQuery(item) }
                guard quickEntry == nil else { throw .segmentOutOfPlace(item) }
                quickEntry = QuickEntry.Route()
            }
            return quickEntry
        }

        /// The words of the path, each spelled once, so that the writer and the reader cannot spell one two ways.
        private enum Segment: String {
            case view
            case task
        }

        /// The query item that says quick entry is up, spelled once for the writer and the reader alike.
        private static let quickEntryItem = "quick-entry"
    }
}
