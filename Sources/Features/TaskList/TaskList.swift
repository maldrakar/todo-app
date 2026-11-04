// Sources/Features/TaskList/TaskList.swift
import FeatureModule
import TaskScreenFeature
import TodoCore

/// The tasks of one view, by title, and the task declared open over them.
///
/// It is declared by the sidebar, by a choice there, and stands in its window's stack over the sidebar, drawn in the
/// pane beside it on the Mac. A tap on a row declares the task screen over it in its destination, and the window's
/// stack makes, keeps and drops that screen (ADR-0009, amendment of 2026-10-22): the list holds no screen and draws
/// none, and hears what the screen asks for as `.destinationAnswered`. Neither the sidebar nor the root learns that a
/// list opens a task, and their code does not grow when the task screen learns to open something (navigation state
/// spec, section 2); the task screen's route reads and writes its own part of the window's path then, as this list's
/// route does. What it holds is what makes the navigation real and nothing more; sections, grouping, ordering and
/// completion are M4's (spec section 10).
///
/// It is a routable module (spec section 4): its head is the view it lists, and its tail is the route of the task it
/// declared, so that a link to a task declares the task over the list, and the route a window writes down names both.
public final class TaskList: Routable {
    public struct Model: Equatable, Sendable {
        /// One task of the view, as the last read of the view's tasks answered.
        public struct Row: Equatable, Sendable, Identifiable {
            public let id: TaskID
            public let title: String
        }

        /// The title of the view the list is on, as the last read of that view answered, drawn as the screen's
        /// title: the back button's menu names the list by it (#126).
        public let title: String

        /// The view's tasks, in the order the view's query gives them.
        public let rows: [Row]

        /// What went wrong, as the finished sentence the view shows, and nil when there is nothing to say:
        /// `send` cannot throw, so a failure inside it has nowhere else to go, and a view that had to spell one
        /// would be a view holding logic (spec section 2).
        public let problem: String?
    }

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

        /// What the list declared over itself, and nil when it declared nothing.
        public let over: Over?

        /// What the list declares over itself: the task screen, or another list, a list inside it or one of this
        /// list's own groups, each holding that screen's route whole, so that a chain of lists is a chain of these.
        public enum Over: RouteValue {
            case task(TaskScreen.Route)
            indirect case list(TaskList.Route)

            /// The head the stack compares a declaration with what stands by: a list's carries its group, so that a
            /// group's screen declared over its list is pushed and not kept (one shape with the root's route of a
            /// screen, `AppModule.Screen.Route.Head`).
            public enum Head: Equatable, Sendable {
                case task(TaskID)
                case list(TaskList.Route.Head)
            }

            public var head: Head {
                switch self {
                case .task(let route): .task(route.head)
                case .list(let route): .list(route.head)
                }
            }

            /// What the screen over the list answers, the task screen's or a list's, which the stack hands the list;
            /// both mean the screen asks to be closed.
            public enum Answer: Equatable, Sendable {
                case task(TaskScreen.Output)
                case list(TaskList.Output)
            }
        }

        public init(head: Head, over: Over? = nil) {
            self.head = head
            self.over = over
        }

        /// The word before a list's view's id in a window's path.
        private static let word = "view"

        /// Reads the path it is handed whole: `view/<id>` from the front, then, as often as they come, `view/<id>` for a
        /// list over the one before or a group's word and key for one of that list's own groups over it, then the task
        /// screen's part when what follows begins with its word. An id reads whole and in either case through the core
        /// (`EntityID(uuidString:)`). After a group only the task screen's part may follow, since a group holds no
        /// lists, so `view` or a second group's word there is out of place; whatever is left after the task screen's
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
                guard last.group == nil else { throw .segmentOutOfPlace(next) }
                path.removeFirst()
                last = if let groupWord {
                    Head(view: last.view, group: try Group(groupWord, reading: &path))
                } else {
                    Head(view: try path.popID(readBy: ViewID.init(uuidString:)))
                }
                heads.append(last)
            }
            if let rest = path.first { throw Route.refusal(of: rest) }
            var over = task.map(Over.task)
            for head in heads.dropFirst().reversed() {
                over = .list(Route(head: head, over: over))
            }
            self.init(head: heads[0], over: over)
        }

        /// This route's part of a window's path and the chain's over it: each list's `view/<id>`, its id's `rawValue`,
        /// or a group's word and key alone, since a group's view is its list's, and the task screen's part at the top
        /// when a task is open. Written by a loop up the chain, never a recursion over it.
        package var segments: [String] {
            var segments: [String] = []
            var route: Route? = self
            while let current = route {
                segments += current.head.group?.segments ?? [Route.word, current.head.view.rawValue]
                switch current.over {
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

    /// What a view may send, each case named for the gesture and never for the operation it triggers (ADR-0006).
    /// The way back from the task is not one: SwiftUI reports it only as the shorter path it wrote, which the root
    /// view sends the window whole, and the stack tells the list `.uncovered` (navigation state spec, section 3).
    public enum UserAction: Equatable, Sendable {
        /// A row of the list, tapped or clicked.
        case rowTapped(TaskID)
    }

    public enum Event: RoutedEvent {
        case action(UserAction)
        case changed(ChangeSet)

        /// The window's stack has just made this list: sent once, right after `init`. The list was made from a route
        /// its opener declared and already knows, the task in it included, so it has nothing to report and answers
        /// nothing.
        case created

        /// A route handed to the live list, which its opener declared again with this list's head, by a link or by a
        /// click on the list's view: an event of the world that no view can send (ADR-0006, amendment of
        /// 2026-10-14), which the stack hands the list once, as `.declared` (navigation state spec, section 2). The
        /// head of a live list never changes, so it is the tail alone that the list reads.
        case route(Route)

        /// What the screen declared over this list answered, the task screen or a list, which the stack hands the list,
        /// its opener (ADR-0009, amendment of 2026-10-22, point 2).
        case destinationAnswered(Route.Over.Answer)

        /// The person went back to this list, and the screen over it is gone already (navigation state spec, section 3).
        case uncovered

        /// What the list declared could not be made, the task screen or a list: why, and the route of what still stands
        /// over the list, nil when nothing does, which the list takes back as its destination (navigation state spec,
        /// section 2).
        case notOpened(StoreError, stillOpen: Route.Over?)

        /// The device's day, which the root hands every screen of its window when the window's view reports a new one,
        /// at midnight, in a new time zone or on waking on another day: an event of the world that no view can send
        /// (spec section 8; ADR-0006, amendment of 2026-11-01). Which tasks a view selects can depend on the day, so a
        /// new one rereads them; the day the list already has reads nothing. Neither is a gesture on the list, so the
        /// sentence on screen and the destination stay.
        case dayChanged(DeviceDay)
    }

    public enum Output: Equatable, Sendable {
        /// The view is gone, so the list asks its opener to close it (spec section 3); the stack drops the task
        /// screen over it with it.
        case closeRequested
    }

    /// What a view draws, computed from the state on every read and never kept beside it, so that what the
    /// list holds is in one place and the model cannot disagree with it (owner's review of #101).
    public var model: Model { state.model }

    /// The route the list is on, assembled and never kept beside its state (spec section 4): its own head, and as
    /// the tail the task it declared. The window's stack writes the window down from what stands instead, so a
    /// declaration that has aged never reaches the text (navigation state spec, section 3).
    public var route: Route { Route(head: head, over: state.destination.pushed) }

    /// What the list declared over it, the task screen, a list or nothing, which the window's stack reads after every
    /// event and follows (ADR-0009, amendment of 2026-10-22, point 2).
    public var destination: Destination<Route.Over> { state.destination }

    private let head: Route.Head

    private let store: Store

    private var state: State

    /// Made from its route, the one way a list is made (spec section 3): the title and the rows of the view the head
    /// names, and the task the tail names declared over them, which the stack makes in the walk after the list is
    /// made. The view is read for its title and then once more by the query of its tasks, which reads it and hands
    /// back only the tasks, and each read of a view reads the table of views whole (`Store.view(_:)`): a list made
    /// reads that table twice, tens of rows in this epic.
    ///
    /// The day is the device's, which the window's stack hands the list when it makes it, the day its root has then, so
    /// that a list made after midnight starts on the new day (spec section 8). It has no default, as the root's has
    /// none: the day is the platform's to say (`docs/style.md`, "A lower layer holds no policy of its client").
    ///
    /// Throws when the view or its tasks cannot be read, a view that is gone among them, which is refused with
    /// `.notFound` and the view's id: a list that came up empty would look like a view with nothing in it,
    /// and the stack keeps what was open while the list's opener says so (navigation state spec, section 2). A task
    /// that cannot be made does not stop the list: a link to a task that is gone opens the view it names, and the
    /// stack tells the list, which says why with no task open, which is what still exists (spec section 3, the
    /// fourth flow).
    public init(store: Store, route: Route, day: DeviceDay) throws(StoreError) {
        guard let view = try store.view(route.head.view) else { throw .notFound(route.head.view) }
        let rows = try TaskList.rows(of: store, in: route.head.view, today: day.day)
        self.head = route.head
        self.store = store
        self.state = State(title: view.title, rows: rows, day: day, destination: Destination(), problem: nil)
        setDestination(route.over)
    }

    public func send(_ event: Event) -> Output? {
        switch event {
        case .action(.rowTapped(let id)):
            // A row the list does not hold opens nothing and moves nothing, the sentence included, the way the
            // sidebar's menu items do nothing on a row it does not hold: the tap is on something no longer on
            // screen, and what it would open is a task this view does not show.
            guard state.rows.contains(where: { $0.id == id }) else { return nil }
            // The sentence goes with a tap on a row, the one gesture made on the list itself, and it goes before the
            // task is declared, so that a task that cannot be made writes a fresh one when the stack says so: it
            // answers this tap, and the one it replaces answered something earlier.
            state.problem = nil
            setDestination(.task(TaskScreen.Route(head: id)))
            return nil
        case .created:
            // Being created answers no gesture, so it moves nothing, the sentence included.
            return nil
        case .route(let route):
            // The route's own head is not read: the stack hands a live list only a route with its head, and the head
            // of a live module never changes (spec section 3). The sentence goes at the start, as it does for a tap:
            // a route is what a link or a click in the sidebar asks of this list, and the sentence on screen
            // answered something earlier (owner, 2026-10-16). A task the route names that cannot be made writes a
            // fresh one, on `.notOpened`.
            state.problem = nil
            setDestination(route.over)
            return nil
        case .destinationAnswered(.task(.closeRequested)), .destinationAnswered(.list(.closeRequested)), .uncovered:
            // The screen over the list asked to be closed, its task or its view gone (spec section 3), or the person
            // went back to the list and the screen is gone already, and a list cannot keep a destination the person
            // closed (navigation state spec, section 3). Either way the list declares nothing over it, the stack drops
            // the screen with whatever stands over it, and the route names nothing over the list. None is a gesture on
            // the list, so the sentence stays: one written while the screen was up, by a link to a task that is gone
            // or a reread that failed, is one the person first sees now that the list is uncovered. The stack tells
            // only a list with a screen over it, so the platform's write after a pop the model drove reaches nobody.
            // The arms name each screen's one answer, so that an answer either learns to give stops this file
            // compiling until the list has decided what it means (spec section 4).
            setDestination(nil)
            return nil
        case .notOpened(let error, let stillOpen):
            // What still stands is taken back, so that the declaration is tried once and the screen that was open
            // stays (navigation state spec, section 2), and the list says why under its rows, naming what it declared,
            // which is read before what stays takes its place.
            let problem = TaskList.problem(error, declared: state.destination.pushed)
            setDestination(stillOpen)
            state.problem = problem.sentence
            return nil
        case .changed(let changes):
            do {
                // Only a change naming this view can have deleted it or renamed it, and the view's read tells. A view
                // that is gone is answered at once: the opener closes this list, and the stack drops it with the task
                // screen over it (spec section 3), so rows read here would be work for nothing. A view that is there
                // gives the list its title, which stands even when the read of the tasks below fails, since the read
                // that answered it succeeded. A read that fails is a reread that failed, and the catch below says so.
                if changes.views.contains(head.view) {
                    guard let view = try store.view(head.view) else { return .closeRequested }
                    state.title = view.title
                }
                if TaskList.rereads(on: changes, of: head.view) {
                    state.rows = try TaskList.rows(of: store, in: head.view, today: state.day.day)
                }
            } catch {
                // Neither the rows on screen nor the title is cleared, since each is assigned only after its own read
                // succeeded, and a list emptied by a failed read would take with it the only thing left to act on.
                // The sentence is written only when none is on screen, as in the sidebar: a change answers for
                // nobody, so it neither clears a sentence nor replaces one, and "may be out of date" would take the
                // place of what the person was told about something they did or a link asked for.
                if state.problem == nil { state.problem = Problem.couldNotReadTasks.sentence }
            }
            // The destination stays: the task screen over the list reads the change itself, handed it by the window,
            // and asks to be closed when its task is gone.
            return nil
        case .dayChanged(let day):
            // The day is kept whether or not the read below holds, since it is what the world says and every later
            // read of the rows is by it. A read that fails leaves the rows and says so only when nothing is on screen,
            // as a change's reread does: the day answers for nobody.
            guard day != state.day else { return nil }
            state.day = day
            do {
                state.rows = try TaskList.rows(of: store, in: head.view, today: day.day)
            } catch {
                if state.problem == nil { state.problem = Problem.couldNotReadTasks.sentence }
            }
            return nil
        }
    }

    /// Declares the task screen or a list over the list, or nothing: a tap, a route, the way back and the stack's
    /// notices each arrive here, so what a tap opens and what a link opens cannot drift apart (spec section 3). Every
    /// call is a new write, which the window's stack follows at the walk after the event.
    private func setDestination(_ over: Route.Over?) {
        state.destination.declare(over.map { .pushed($0) })
    }

    /// Whether a change can have moved this view's tasks. Which tasks a view holds is its query's to say, and
    /// that query reads tasks, the tags they carry and the view's own filter, so a change naming any task, any
    /// tag or this view rereads the whole list. A change names the entity it touched and not what moved
    /// because of it: a task trashed moves its children out of a view and names itself alone, and a tag
    /// deleted empties a view filtered by it and names only the tag (`ChangeSet`). A view holds tens of tasks
    /// in this epic, and the query is the one place that knows which. A change naming only other views is no
    /// change to this one's tasks and costs not even a read, which is every edit made in the sidebar to a view
    /// other than this one.
    private static func rereads(on changes: ChangeSet, of view: ViewID) -> Bool {
        !changes.tasks.isEmpty || !changes.tags.isEmpty || changes.views.contains(view)
    }

    /// The view's tasks as one read of the store answers them, in the query's order.
    ///
    /// `today` is the device's day, handed in: a view such as Today selects by the day the query is made, and the list
    /// has no time zone to tell the day by, since a feature target may not import the Foundation that holds one
    /// (ADR-0001). The platform, which has one, reads the day and hands it in when the list is made and again when it
    /// changes (`.dayChanged`), so the list draws the device's own day and catches up at midnight with no change to
    /// the store (spec section 8; ADR-0006, amendment of 2026-11-01).
    private static func rows(of store: Store, in view: ViewID, today: Day) throws(StoreError) -> [Model.Row] {
        try store.tasks(in: view, today: today).map { Model.Row(id: $0.id, title: $0.title) }
    }

    /// The sentence what the list declared over itself reads as when it could not be made, by what it declared.
    /// `.notFound` is what was declared being gone, which is what a link written before a delete, or a tap on a row a
    /// peer's delete has not yet reached, looks like from here: the task, the list inside, or a group's tag or parent.
    /// A group refused as `.invalid` names a grouping its list does not have, a link that outlived the grouping it
    /// names (ADR-0009, amendment of 2026-11-02). Anything else is the store failing to read what may well be there,
    /// and calling that "gone" would put on screen something that is not true.
    private static func problem(_ error: StoreError, declared: Route.Over?) -> Problem {
        switch (declared, error) {
        case (.list(let route)?, .notFound): route.head.group == nil ? .listIsGone : .groupIsGone
        case (.list(let route)?, .invalid): route.head.group == nil ? .couldNotOpenList : .notGroupedThatWay
        case (.list(let route)?, _): route.head.group == nil ? .couldNotOpenList : .couldNotOpenGroup
        case (.task?, .notFound), (nil, .notFound): .taskIsGone
        case (.task?, _), (nil, _): .couldNotReadTask
        }
    }

    /// Everything the list holds between two events: the view's title and the rows as the last reads produced them, the
    /// device's day they were read by, what it declared over them, and the sentence a person was last told. One value,
    /// moved field by field, and the one place any of it is kept: the model is computed from it on every read (owner's
    /// reviews of #77 and #101).
    ///
    /// The destination is a field of the state, because what a screen declared over it is the navigation state, which
    /// the window's stack follows (ADR-0009, amendment of 2026-10-22, point 2).
    private struct State {
        var title: String
        var rows: [Model.Row]
        var day: DeviceDay
        var destination: Destination<Route.Over>
        var problem: String?

        /// The model a view draws: the title, the rows and the sentence, if any.
        var model: Model { Model(title: title, rows: rows, problem: problem) }
    }

    /// What can go wrong in this module, with the sentence each one reads as. The store's own error stays here:
    /// it names SQLite codes and journal rows, which is what a bug report is made of and not what a person can
    /// do anything about.
    private enum Problem {
        case taskIsGone
        case couldNotReadTask
        case couldNotReadTasks
        case listIsGone
        case couldNotOpenList
        case notGroupedThatWay
        case groupIsGone
        case couldNotOpenGroup

        var sentence: String {
            switch self {
            case .taskIsGone: "The task is gone."
            case .couldNotReadTask: "The task could not be read."
            case .couldNotReadTasks: "The tasks could not be read, so this list may be out of date."
            case .listIsGone: "The list is gone."
            case .couldNotOpenList: "The list could not be opened."
            case .notGroupedThatWay: "This list is not grouped that way, so the group could not be opened."
            case .groupIsGone: "The group is gone."
            case .couldNotOpenGroup: "The group could not be opened."
            }
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
    var segments: [String] {
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
    init(_ word: Word, reading path: inout ArraySlice<String>) throws(RouteError) {
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

    /// The key of the group with no key: no day, no tag, no parent.
    private static let none = "none"

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
