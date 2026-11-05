// Sources/Features/TaskList/TaskList+Routing.swift
import FeatureModule
import TaskScreenFeature
import TodoCore

/// The list's address, its head and its tail, and how a window's path spells it: read by loops and written by one, a
/// chain of lists bounded where a person never goes, and a group's word and key (spec sections 2 and 9; ADR-0009,
/// amendments of 2026-11-01 and 2026-11-02).
extension TaskList {
    /// The address of the list: the view it lists, with one of its own groups on a group's screen, and what it
    /// declared over itself as the tail (spec sections 2 and 9; ADR-0009, amendments of 2026-11-01 and 2026-11-02).
    ///
    /// In a window's path it is `view/<id>`, then `task/<id>` for the task screen, `view/…` for a list opened over it,
    /// or a group's word and key for one of its own groups opened over it, and this route reads and writes its own part
    /// and hands the task screen's to that screen's route, knowing that route's word and nothing more of its spelling.
    public struct Route: RouteValue {
        /// What makes this list this one: the view, and on a group's screen the group of it shown. A route to another
        /// view, or to a group of this one, is another list, which the window's stack makes in place of this one or
        /// over it (navigation state spec, section 2), so a group's screen and its list's never share a head.
        public struct Head: Hashable, Sendable {
            public let view: ViewID
            public let group: Group?

            public init(view: ViewID, group: Group? = nil) {
                self.view = view
                self.group = group
            }
        }

        /// One of the list's own groups as its address, a grouping and its key; a day is a distance from today and
        /// never a date, so that a link keeps meaning "tomorrow" as Today's keeps meaning today (ADR-0009, amendment
        /// of 2026-11-02). Nil is the group with no key: no day, no tag, no parent.
        public enum Group: Hashable, Sendable {
            /// `day/+1`, `day/0`, `day/-2`, `day/none`: by the day of When.
            case day(Int32?)
            /// `deadline/…`, with the same keys: by the day of the deadline.
            case deadline(Int32?)
            /// `tag/<id>`, `tag/none`.
            case tag(TagID?)
            /// `parent/<id>`, `parent/none`.
            case parent(TaskID?)
            /// `status/open`, `status/done`, `status/canceled`.
            case status(TaskStatus)
        }

        public let head: Head

        /// The rest of the route after its head, what the list declared over itself, and nil when it declared nothing.
        public let tail: Tail?

        /// What the list can declare over itself, the route's tail: the task screen, or another list, a list inside it
        /// or one of this list's own groups, each holding that screen's route whole, so that a chain of lists is a
        /// chain of these. It has no head of its own: the stack compares the heads of the routes it holds once the
        /// window's enum of screens has mapped this one into it (`AppModule.Screen.Route`; owner's review of #188).
        public enum Tail: Equatable, Sendable {
            case task(TaskScreen.Route)
            indirect case list(TaskList.Route)

            /// What the screen over the list answers, the task screen's or a list's, which the stack hands the list;
            /// both mean the screen asks to be closed.
            public enum Answer: Equatable, Sendable {
                case task(TaskScreen.Output)
                case list(TaskList.Output)
            }
        }

        public init(head: Head, tail: Tail? = nil) {
            self.head = head
            self.tail = tail
        }

        /// The word before a list's view's id in a window's path.
        private static let word = "view"

        /// The most lists a chain holds, the first included, a group's screen over its list counting as one. A path is
        /// data from outside, and the stack makes a screen for every list of the chain, each reading its page, while
        /// comparing two chains (the synthesized `==`) and releasing one walk the chain by recursion, so the chain is
        /// bounded where a person never goes, as a filter is bounded for the walks over it (`maximumDepth`, which the
        /// store refuses a deeper filter by): past the bound the word that would make one more list has no place
        /// (the controller's ruling on #175, 2026-11-04).
        private static let longestChain = 32

        /// Reads the path it is handed whole: `view/<id>` from the front, then, as long as the chain holds fewer lists
        /// than `longestChain`, `view/<id>` for a list over the one before or a group's word and key for one of that
        /// list's own groups over it, then the task screen's part when what follows begins with its word. An id reads
        /// whole and in either case through the core (`EntityID(uuidString:)`). After a group only the task screen's
        /// part may follow, since a group holds no lists, so `view` or a second group's word there is out of place, as
        /// is the word that would make a chain longer than `longestChain`; whatever is left after the task screen's
        /// part is refused too, a word this route or the task screen's knows as out of place and anything else as
        /// unknown, the empty segment a doubled or trailing slash leaves included. Read from the left, so the first
        /// offence is the one named.
        ///
        /// A path is data from outside, so the chain is read by a loop that collects each list's head into an array,
        /// which is then folded from the end into the chain of routes: no recursion over the path's length
        /// (`docs/style.md`). Nothing reads the store: a group that reads but names nothing is refused when its screen
        /// is made (ADR-0009, amendment of 2026-11-02).
        package init(reading path: inout ArraySlice<String>) throws(RouteError) {
            let word = path.popFirst() ?? ""
            guard word == Route.word else { throw Route.refusal(of: word) }
            var last = Head(view: try path.popID(readBy: ViewID.init(uuidString:)))
            var heads = [last]
            var task: TaskScreen.Route?
            while let next = path.first, task == nil {
                if next == TaskScreen.Route.word {
                    task = try TaskScreen.Route(reading: &path)
                    continue
                }
                let groupWord = Group.Word(rawValue: next)
                guard next == Route.word || groupWord != nil else { throw Route.refusal(of: next) }
                guard last.group == nil, heads.count < Route.longestChain else { throw .segmentOutOfPlace(next) }
                path.removeFirst()
                last = if let groupWord {
                    Head(view: last.view, group: try Group(groupWord, reading: &path))
                } else {
                    Head(view: try path.popID(readBy: ViewID.init(uuidString:)))
                }
                heads.append(last)
            }
            if let rest = path.first { throw Route.refusal(of: rest) }
            var tail = task.map(Tail.task)
            for head in heads.dropFirst().reversed() {
                tail = .list(Route(head: head, tail: tail))
            }
            self.init(head: heads[0], tail: tail)
        }

        /// This route's part of a window's path and the chain's over it: each list's `view/<id>`, its id's `rawValue`,
        /// or a group's word and key alone, since a group's view is its list's, and the task screen's part at the top
        /// when a task is open. Written by a loop up the chain, never a recursion over it.
        package var segments: [String] {
            var segments: [String] = []
            var route: Route? = self
            while let current = route {
                segments += current.head.group?.segments ?? [Route.word, current.head.view.rawValue]
                switch current.tail {
                case .list(let next)?:
                    route = next
                case .task(let task)?:
                    segments += task.segments
                    route = nil
                case nil:
                    route = nil
                }
            }
            return segments
        }

        /// A segment where this route cannot read it: a word this route, a group or the task screen's route knows is
        /// out of place, and anything else is unknown.
        private static func refusal(of segment: String) -> RouteError {
            segment == word || segment == TaskScreen.Route.word || Group.Word(rawValue: segment) != nil
                ? .segmentOutOfPlace(segment) : .unknownSegment(segment)
        }
    }
}

extension TaskList.Route.Group {
    /// The word a group's address begins with in a window's path, one per grouping (ADR-0009, amendment of
    /// 2026-11-02).
    enum Word: String {
        case day, deadline, tag, parent, status
    }

    /// The group's word, which names its grouping.
    var word: Word {
        switch self {
        case .day: .day
        case .deadline: .deadline
        case .tag: .tag
        case .parent: .parent
        case .status: .status
        }
    }

    /// The group's part of a window's path, its word and its key: a distance signed, `0` today, an id as its
    /// `rawValue`, a status by its name, or `none` for the group with no key.
    fileprivate var segments: [String] {
        let key = switch self {
        case .day(let distance), .deadline(let distance): distance.map(Self.key(of:)) ?? Self.none
        case .tag(let id): id?.rawValue ?? Self.none
        case .parent(let id): id?.rawValue ?? Self.none
        case .status(let status): status.name
        }
        return [word.rawValue, key]
    }

    /// Reads the key after the group's word, taken from the front of what is left of the path: a distance only as
    /// `+n`, `0` or `-n`, so that a link has one spelling, and one a day offset of `Int32` holds; an id whole through
    /// the core, as every id is read; a status by its name; `none` for the group with no key, which a status has not.
    /// A key that does not read is refused as written, an id as every id is.
    fileprivate init(_ word: Word, reading path: inout ArraySlice<String>) throws(RouteError) {
        switch word {
        case .day: self = .day(try Self.distance(reading: &path))
        case .deadline: self = .deadline(try Self.distance(reading: &path))
        case .tag: self = .tag(try Self.id(reading: &path))
        case .parent: self = .parent(try Self.id(reading: &path))
        case .status:
            let key = path.popFirst() ?? ""
            guard let status = TaskStatus.allCases.first(where: { $0.name == key }) else { throw .unknownSegment(key) }
            self = .status(status)
        }
    }

    /// The key of the group with no key: no day, no tag, no parent, in a window's path and in a fold's key.
    static let none = "none"

    /// A distance as a key: `0`, or its sign and its digits.
    private static func key(of distance: Int32) -> String {
        distance > 0 ? "+\(distance)" : String(distance)
    }

    /// Reads a distance's key, or `none`: `0`, or a sign and digits with no leading zero, which `Int32` holds.
    private static func distance(reading path: inout ArraySlice<String>) throws(RouteError) -> Int32? {
        let key = path.popFirst() ?? ""
        if key == none { return nil }
        if key == "0" { return 0 }
        let digits = key.dropFirst()
        guard let sign = key.first, sign == "+" || sign == "-", let first = digits.first, first != "0",
              digits.count <= 10, digits.allSatisfy({ ("0"..."9").contains($0) }),
              let magnitude = Int64(digits), let distance = Int32(exactly: sign == "-" ? -magnitude : magnitude)
        else { throw .unknownSegment(key) }
        return distance
    }

    /// Reads an id's key, or `none`, the id read as every id of a route is (`popID(readBy:)`).
    private static func id(reading path: inout ArraySlice<String>) throws(RouteError) -> EntityID? {
        guard path.first != none else {
            path.removeFirst()
            return nil
        }
        return try path.popID(readBy: EntityID.init(uuidString:))
    }
}

extension TaskStatus {
    /// The status's name, as a group's key spells it in a window's path and a block's key in the device's folds.
    var name: String {
        switch self {
        case .open: "open"
        case .done: "done"
        case .canceled: "canceled"
        }
    }
}
