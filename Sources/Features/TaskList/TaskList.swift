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

    /// The address of the list: the view it lists, and the task declared over it as the tail (spec section 2).
    ///
    /// In a window's path it is `view/<id>` followed by the task screen's part, and this route reads and writes
    /// its own part and hands the rest to the task screen's route, knowing that route's word and nothing more of
    /// its spelling.
    public struct Route: RouteValue {
        /// The view the list is on, which is what makes this list this one: a route to another view is
        /// another list, which the window's stack makes in place of this one (navigation state spec, section 2).
        public let head: ViewID

        /// The route of the task screen declared over the list, and nil when none is.
        public let task: TaskScreen.Route?

        public init(head: ViewID, task: TaskScreen.Route? = nil) {
            self.head = head
            self.task = task
        }

        /// The word before the view's id in a window's path.
        private static let word = "view"

        /// Reads the path it is handed whole: `view/<id>` from the front, the id whole and in either case through
        /// the core (`EntityID(uuidString:)`), then the task screen's part when what follows begins with its word.
        /// Whatever is left is refused, and so is a front that is not `view`: this route's word or the task
        /// screen's is out of place there, since each has one place, and any other segment is unknown, the empty
        /// one a doubled or trailing slash leaves included. Read from the left, so the first offence is the one
        /// named.
        package init(reading path: inout ArraySlice<String>) throws(RouteError) {
            let word = path.popFirst() ?? ""
            guard word == Route.word else { throw Route.refusal(of: word) }
            let head = try path.popID(readBy: ViewID.init(uuidString:))
            let task: TaskScreen.Route? = if path.first == TaskScreen.Route.word {
                try TaskScreen.Route(reading: &path)
            } else {
                nil
            }
            if let rest = path.first { throw Route.refusal(of: rest) }
            self.init(head: head, task: task)
        }

        /// This route's part of a window's path, its word and the view's id, its `rawValue`, and the task screen's
        /// part after it when a task is open.
        package var segments: [String] { [Route.word, head.rawValue] + (task?.segments ?? []) }

        /// A segment where this route cannot read it: a word this route or the task screen's knows is out of
        /// place, and anything else is unknown.
        private static func refusal(of segment: String) -> RouteError {
            segment == word || segment == TaskScreen.Route.word ? .segmentOutOfPlace(segment) : .unknownSegment(segment)
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

        /// What the task screen declared over this list answered, which the stack hands the list, its opener
        /// (ADR-0009, amendment of 2026-10-22, point 2).
        case destinationAnswered(TaskScreen.Output)

        /// The person went back to this list, and the task screen over it is gone already (navigation state spec,
        /// section 3).
        case uncovered

        /// The task the list declared could not be made: why, and the route of the task screen that still stands
        /// over the list, nil when none does, which the list takes back as its destination (navigation state spec,
        /// section 2).
        case notOpened(StoreError, stillOpen: TaskScreen.Route?)
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
    public var route: Route { Route(head: head, task: state.destination.pushed) }

    /// What the list declared over it, the task screen or nothing, which the window's stack reads after every event
    /// and follows (ADR-0009, amendment of 2026-10-22, point 2).
    public var destination: Destination<TaskScreen.Route> { state.destination }

    private let head: ViewID

    private let store: Store

    private var state: State

    /// Made from its route, the one way a list is made (spec section 3): the title and the rows of the view the head
    /// names, and the task the tail names declared over them, which the stack makes in the walk after the list is
    /// made. The view is read for its title and then once more by the query of its tasks, which reads it and hands
    /// back only the tasks, and each read of a view reads the table of views whole (`Store.view(_:)`): a list made
    /// reads that table twice, tens of rows in this epic.
    ///
    /// Throws when the view or its tasks cannot be read, a view that is gone among them, which is refused with
    /// `.notFound` and the view's id: a list that came up empty would look like a view with nothing in it,
    /// and the stack keeps what was open while the list's opener says so (navigation state spec, section 2). A task
    /// that cannot be made does not stop the list: a link to a task that is gone opens the view it names, and the
    /// stack tells the list, which says why with no task open, which is what still exists (spec section 3, the
    /// fourth flow).
    public init(store: Store, route: Route) throws(StoreError) {
        guard let view = try store.view(route.head) else { throw .notFound(route.head) }
        let rows = try TaskList.rows(of: store, in: route.head)
        self.head = route.head
        self.store = store
        self.state = State(title: view.title, rows: rows, destination: Destination(), problem: nil)
        setDestination(route.task)
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
            setDestination(TaskScreen.Route(head: id))
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
            setDestination(route.task)
            return nil
        case .destinationAnswered(.closeRequested), .uncovered:
            // The task screen asked to be closed, its task gone (spec section 3), or the person went back to the list
            // and the screen is gone already, and a list cannot keep a destination the person closed (navigation
            // state spec, section 3). Either way the list declares nothing over it, the stack drops the screen, and
            // the route names no task. Neither is a gesture on the list, so the sentence stays: one written while
            // the screen was up, by a link to a task that is gone or a reread that failed, is one the person first
            // sees now that the list is uncovered. The stack tells only a list with a screen over it, so the
            // platform's write after a pop the model drove reaches nobody. The arm names the screen's one answer, so
            // that an answer it learns to give stops this file compiling until the list has decided what it means
            // (spec section 4).
            setDestination(nil)
            return nil
        case .notOpened(let error, let stillOpen):
            // What still stands is taken back, so that the declaration is tried once and the screen that was open
            // stays (navigation state spec, section 2), and the list says why under its rows.
            setDestination(stillOpen)
            state.problem = TaskList.problem(error).sentence
            return nil
        case .changed(let changes):
            do {
                // Only a change naming this view can have deleted it or renamed it, and the view's read tells. A view
                // that is gone is answered at once: the opener closes this list, and the stack drops it with the task
                // screen over it (spec section 3), so rows read here would be work for nothing. A view that is there
                // gives the list its title, which stands even when the read of the tasks below fails, since the read
                // that answered it succeeded. A read that fails is a reread that failed, and the catch below says so.
                if changes.views.contains(head) {
                    guard let view = try store.view(head) else { return .closeRequested }
                    state.title = view.title
                }
                if TaskList.rereads(on: changes, of: head) { state.rows = try TaskList.rows(of: store, in: head) }
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
        }
    }

    /// Declares the task screen over the list, or nothing: a tap, a route, the way back and the stack's notices
    /// each arrive here, so what a tap opens and what a link opens cannot drift apart (spec section 3). Every call
    /// is a new write, which the window's stack follows at the walk after the event.
    private func setDestination(_ task: TaskScreen.Route?) {
        state.destination.declare(task.map { .pushed($0) })
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
    /// `today` is the UTC day of the machine's clock, read again at every read: a view such as Today selects by
    /// the day the query is made, and the list has no time zone to make a local day with, since a feature
    /// target may not import the Foundation that holds one (ADR-0001). It departs from spec section 10, which
    /// hands the list its day at creation the way the command-line demo passes it: a day handed once goes
    /// stale in a list left open past midnight, and the day changing is an event of the world, M4's, which
    /// will bring the platform's own day with it. Until then a list away from UTC is a day off for the hours
    /// in which its own date and UTC's differ, and a list left open across midnight UTC catches up at the next
    /// change that rereads it.
    private static func rows(of store: Store, in view: ViewID) throws(StoreError) -> [Model.Row] {
        let today = Day(millisSinceEpoch: Store.systemNow())
        return try store.tasks(in: view, today: today).map { Model.Row(id: $0.id, title: $0.title) }
    }

    /// The sentence a task that could not be made reads as. `.notFound` is the task being gone, which is what a link
    /// written before a delete, or a tap on a row a peer's delete has not yet reached, looks like from here. Anything
    /// else is the store failing to read a task that may well be there, and calling that "gone" would put on screen
    /// something that is not true.
    private static func problem(_ error: StoreError) -> Problem {
        switch error {
        case .notFound: .taskIsGone
        default: .couldNotReadTask
        }
    }

    /// Everything the list holds between two events: the view's title and the rows as the last reads produced them,
    /// what it declared over them, and the sentence a person was last told. One value, moved field by field, and the one place any of it
    /// is kept: the model is computed from it on every read (owner's reviews of #77 and #101).
    ///
    /// The destination is a field of the state, because what a screen declared over it is the navigation state, which
    /// the window's stack follows (ADR-0009, amendment of 2026-10-22, point 2).
    private struct State {
        var title: String
        var rows: [Model.Row]
        var destination: Destination<TaskScreen.Route>
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

        var sentence: String {
            switch self {
            case .taskIsGone: "The task is gone."
            case .couldNotReadTask: "The task could not be read."
            case .couldNotReadTasks: "The tasks could not be read, so this list may be out of date."
            }
        }
    }
}
