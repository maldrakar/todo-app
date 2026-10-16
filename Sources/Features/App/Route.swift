// Sources/Features/App/Route.swift
import FeatureModule
import QuickEntryFeature
import TaskViewListFeature

extension AppModule {
    /// The route of the root, which is the route of the window: the sidebar's, with the list open in it and the
    /// task open in that, and whether quick entry is up (spec section 2). It is what a link carries, what a
    /// window is restored from and what the web's address bar shows, each through its one text form, `path`.
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

        /// Reads the text form, a path with a query (spec section 2), which is why the name covers the query
        /// too: `/`, `/view/<id>`, `/view/<id>/task/<id>`, with `?quick-entry` when quick entry is up.
        ///
        /// Each route reads its own part, so this one reads only what is the window's: the leading `/`, the
        /// path split from the query at the first `?`, the path handed to the sidebar's route and the query's
        /// items to quick entry's. The path is split at every `/`, its empty segments kept for the routes to
        /// refuse. A route is data from outside, so anything a route cannot read refuses the whole route with the
        /// segment named, read from the left so that the first offence is the one named, the path before the
        /// query, and nothing traps (spec section 2, `docs/style.md`). The string is the path and the query alone:
        /// a scheme or a site is the platform's wrapping, which its caller strips, so a string that does not begin
        /// with `/` is refused rather than unwrapped.
        ///
        /// It undoes `path`, so a path that reads writes back as itself but for the case of its ids, and a route
        /// reads back from its `path` as itself.
        public init(path: String) throws(RouteError) {
            let query = path.firstIndex(of: "?")
            let text = path[..<(query ?? path.endIndex)]
            guard text.first == "/" else { throw .unknownSegment(String(text.prefix { $0 != "/" })) }
            var segments = text == "/" ? [] : Route.split(text.dropFirst(), at: "/")
            let sidebar = try TaskViewList.Route(reading: &segments)
            var items = query.map { Route.split(path[path.index(after: $0)...], at: "&") } ?? []
            let quickEntry: QuickEntry.Route? = if items.first == QuickEntry.Route.item {
                try QuickEntry.Route(reading: &items)
            } else {
                nil
            }
            // What no route read: quick entry's item again is out of place, since a window has one quick entry,
            // and any other item is unknown, the empty one a `?` or an `&` with nothing after it leaves included,
            // which the writer never writes.
            if let item = items.first {
                throw item == QuickEntry.Route.item ? .segmentOutOfPlace(item) : .unknownQuery(item)
            }
            self.init(sidebar: sidebar, quickEntry: quickEntry)
        }

        /// The text form of the route: the sidebar's part as the path, the chain of screens, and quick entry's
        /// as the query, a modal being beside the chain (spec section 2). A sidebar with no list is written as
        /// `/`, which leaves the choice to the sidebar.
        public var path: String {
            let items = quickEntry?.items ?? []
            let query = items.isEmpty ? "" : "?" + items.joined(separator: "&")
            return "/" + sidebar.segments.joined(separator: "/") + query
        }

        /// The parts of the path or of the query between their separators, the empty ones kept, so that a doubled,
        /// leading or trailing separator leaves an empty part for a route to refuse.
        private static func split(_ text: Substring, at separator: Character) -> ArraySlice<String> {
            text.split(separator: separator, omittingEmptySubsequences: false).map(String.init)[...]
        }
    }
}
