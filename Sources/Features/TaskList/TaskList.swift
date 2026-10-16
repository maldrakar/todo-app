// Sources/Features/TaskList/TaskList.swift
import FeatureModule
import TaskScreenFeature
import TodoCore

/// The tasks of one view, by title, and the task opened from among them.
///
/// It is the sidebar's child, opened by a choice there and held in a seat of the sidebar's (ADR-0009), and it is
/// drawn in the pane beside the sidebar on the Mac. The task screen opened from a row is its child, held in a seat
/// of its own, so neither the sidebar nor the root learns that a list opens a task, and their code does not grow
/// when the task screen learns to open something (spec section 1); the task screen's route reads and writes its
/// own part of the window's path then, as this list's route does. What it holds is what makes the navigation real
/// and nothing more; sections, grouping, ordering and completion are M4's (spec section 10).
///
/// It is a routable module (spec section 4): its head is the view it lists, and its tail is the route of the
/// task open in it, so that a link to a task opens the list with the task screen in it, and the route a window
/// writes down names both.
public final class TaskList: Routable {
    public struct Model: Equatable, Sendable {
        /// One task of the view, as the last read of the view's tasks answered.
        public struct Row: Equatable, Sendable, Identifiable {
            public let id: TaskID
            public let title: String
        }

        /// The view's tasks, in the order the view's query gives them.
        public let rows: [Row]

        /// The open task screen's model, which the list carries to the screen's view whole and decides nothing
        /// in, and nil when no task is open.
        public let task: TaskScreen.Model?

        /// What went wrong, as the finished sentence the view shows, and nil when there is nothing to say:
        /// `send` cannot throw, so a failure inside it has nowhere else to go, and a view that had to spell one
        /// would be a view holding logic (spec section 2).
        public let problem: String?
    }

    /// The address of the list: the view it lists, and the task open in it as the tail (spec section 2).
    ///
    /// In a window's path it is `view/<id>` followed by the task screen's part, and this route reads and writes
    /// its own part and hands the rest to the task screen's route, knowing that route's word and nothing more of
    /// its spelling.
    public struct Route: RouteValue {
        /// The view the list is on, which is what makes this list this one: a route to another view is
        /// another list, which the seat holding this one makes in its place (spec section 3).
        public let head: ViewID

        /// The route of the task screen open in the list, and nil when none is.
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

        /// This route's part of a window's path, its word and the view's id as `EntityID.description` prints it,
        /// and the task screen's part after it when a task is open.
        package var segments: [String] { [Route.word, head.description] + (task?.segments ?? []) }

        /// A segment where this route cannot read it: a word this route or the task screen's knows is out of
        /// place, and anything else is unknown.
        private static func refusal(of segment: String) -> RouteError {
            segment == word || segment == TaskScreen.Route.word ? .segmentOutOfPlace(segment) : .unknownSegment(segment)
        }
    }

    /// What a view may send, each case named for the gesture and never for the operation it triggers (ADR-0006).
    public enum UserAction: Equatable, Sendable {
        /// A row of the list, tapped or clicked.
        case rowTapped(TaskID)
        /// The back button of the task screen, tapped, or the swipe back that does the same: SwiftUI reports
        /// both as one write of nil through the binding that pushed the screen. It names the control and the
        /// gesture, and closing the screen is what the list decides it means (owner's review of #101), where
        /// the spec has `taskClosed` (`docs/plans/navigation.md`, Deviations).
        case backButtonTapped
    }

    public enum Event: RoutedEvent {
        case action(UserAction)
        case changed(ChangeSet)

        /// The parent has just made this list: sent once, by the seat that holds it, right after `init`. The
        /// list was made from a route its parent chose and already knows, the task in it included, so it has
        /// nothing to report and answers nothing.
        case created

        /// A route applied to the live list, by a link or by its parent reconciling the window: an event of the
        /// world that no view can send (ADR-0006, amendment of 2026-10-14). The head of a live list never
        /// changes, so it is the tail alone that the list reads.
        case route(Route)
    }

    public enum Output: Equatable, Sendable {
        /// The view is gone, so the list asks its parent to drop it (spec section 3); the task screen open in it
        /// goes with it.
        case closeRequested
    }

    /// What a view draws, computed from the state on every read and never kept beside it, so that what the
    /// list holds is in one place and the model cannot disagree with it (owner's review of #101).
    public var model: Model { state.model }

    /// The route the list is on, assembled and never kept beside its state (spec section 4): its own head, and
    /// as the tail the route of the task screen in its seat, which names a task only while a screen is open on
    /// it.
    public var route: Route { Route(head: head, task: state.task.route) }

    private let head: ViewID

    private let store: Store

    private var state: State

    /// Made from its route, the one way a list is made (spec section 3): the rows of the view the head names,
    /// and the task screen the tail names, opened in the list's seat.
    ///
    /// Throws when the view's tasks cannot be read, a view that is gone among them, which the query refuses
    /// with `.notFound` and the view's id: a list that came up empty would look like a view with nothing in it,
    /// and its parent keeps what was open and says so (spec section 3). A task screen that cannot be made does
    /// not stop the list: a link to a task that is gone opens the view it names, with no task open and a
    /// sentence saying why, which is what still exists (spec section 3, the fourth flow).
    public init(store: Store, route: Route) throws(StoreError) {
        let rows = try TaskList.rows(of: store, in: route.head)
        // The seat is built once, here, with the way to make the screen: a closure over the screen's own
        // `init` that captures the store and never this list. The list holds the seat in its state, so a
        // closure holding the list would close a cycle, list to state to seat to closure to list, and none of
        // them would ever be released (`Seat.init`). Its error is named, so that the seat's type below is
        // checked against it rather than widened to `any Error`.
        let task = Seat<TaskScreen, StoreError> { route throws(StoreError) in
            try TaskScreen(store: store, route: route)
        }
        self.head = route.head
        self.store = store
        self.state = State(rows: rows, task: task, problem: nil)
        apply(route)
    }

    public func send(_ event: Event) -> Output? {
        switch event {
        case .action(.rowTapped(let id)):
            // A row the list does not hold opens nothing and moves nothing, the sentence included, the way the
            // sidebar's menu items do nothing on a row it does not hold: the tap is on something no longer on
            // screen, and what it would open is a task this view does not show.
            guard state.rows.contains(where: { $0.id == id }) else { return nil }
            // The sentence goes with a tap on a row, the one gesture made on the list itself, and it goes before
            // the route is applied, so that a task that cannot be made writes a fresh one: it answers this tap,
            // and the one it replaces answered something earlier.
            state.problem = nil
            apply(Route(head: head, task: TaskScreen.Route(head: id)))
            return nil
        case .action(.backButtonTapped):
            // The way back is the route without the task, applied (spec section 3, the second flow). It is a
            // gesture on the screen that covered the list, so it leaves the list's sentence: one written while
            // the screen was up, by a link to a task that is gone or a reread that failed, is one the person
            // first sees now that the list is uncovered. With no screen open it moves nothing at all, since an
            // empty seat has nothing to drop: the view sends this action when the platform writes nil through
            // its binding, and the platform writes one after a pop the model drove as well, as after
            // `.closeRequested`, when nobody tapped anything, which is why the sidebar ignores a field action
            // with no field open (#81).
            apply(Route(head: head))
            return nil
        case .created:
            // The sentence stays: the parent sends this right after `init`, and a sentence written there, a link
            // to a task that is gone, would be erased before anyone read it. Being created answers no gesture.
            return nil
        case .route(let route):
            // The route's own head is not read: a seat hands a live list only a route with its head, and the
            // head of a live module never changes (spec section 3). The sentence goes at the start, as it does
            // for a tap: a route is what a link or a click in the sidebar asks of this list, and the sentence on
            // screen answered something earlier (owner, 2026-10-16). A route whose task cannot be made writes a
            // fresh one, inside `apply`.
            state.problem = nil
            apply(route)
            return nil
        case .changed(let changes):
            do {
                // Only a change naming this view can have deleted it, and the view's read tells. A view that is
                // gone is answered at once: the parent drops this list and the seat with it (spec section 3), so
                // rows read here and a change handed to the screen would be work for nothing. A read that fails
                // is a reread that failed, and the catch below says so.
                if changes.views.contains(head) {
                    guard try store.view(head) != nil else { return .closeRequested }
                }
                if TaskList.rereads(on: changes, of: head) { state.rows = try TaskList.rows(of: store, in: head) }
            } catch {
                // The rows on screen are kept, since they are assigned only after a read that succeeded, and a
                // list emptied by a failed read would take with it the only thing left to act on. The sentence
                // is written only when none is on screen, as in the sidebar: a change answers for nobody, so it
                // neither clears a sentence nor replaces one, and "may be out of date" would take the place of
                // what the person was told about something they did or a link asked for.
                if state.problem == nil { state.problem = Problem.couldNotReadTasks.sentence }
            }
            // The open screen gets the change whatever the rows did, since what it shows is its own task's and
            // only it reads that.
            react(to: state.task.send(.changed(changes)))
            return nil
        }
    }

    /// Applies a route to the list, which is the one entrance to navigation inside it: a tap, a link, a relaunch
    /// and the way back each arrive here as a route, so what a tap opens and what a link opens cannot drift
    /// apart (spec section 3).
    ///
    /// The head is this list's own and the tail is all that moves: the seat keeps the screen on the same task,
    /// replaces it on another and drops it on none. A screen that cannot be made leaves the one that was open,
    /// since the seat makes the new one before it lets the old one go, and the list says why in its own model
    /// (spec section 3). What the seat hands back goes through `react(to:)`, the line every answer of the
    /// screen goes through.
    private func apply(_ route: Route) {
        do {
            react(to: try state.task.apply(route.task))
        } catch {
            state.problem = TaskList.problem(error).sentence
        }
    }

    /// What the task screen asked for, whichever event drew it out: its answer to `.created`, which is nothing
    /// today, and its answer to a change. One path for every answer, with no `default`, so that an answer the
    /// screen learns to give stops this file compiling until the list has decided what it means (spec section 4).
    private func react(to output: TaskScreen.Output?) {
        switch output {
        case .closeRequested?:
            // The task is gone, and so is the screen on it (spec section 3): the stack it was pushed onto pops
            // back to the list on every platform (spec section 6), and the route names no task.
            state.task.drop()
        case nil:
            break
        }
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

    /// The sentence a screen that could not be made reads as. `.notFound` is the task being gone, which is what
    /// a link written before a delete, or a tap on a row a peer's delete has not yet reached, looks like from
    /// here. Anything else is the store failing to read a task that may well be there, and calling that "gone"
    /// would put on screen something that is not true.
    private static func problem(_ error: StoreError) -> Problem {
        switch error {
        case .notFound: .taskIsGone
        default: .couldNotReadTask
        }
    }

    /// Everything the list holds between two events: the rows as the last read produced them, the seat with the
    /// task screen in it, and the sentence a person was last told. One value, moved field by field, and the
    /// one place any of it is kept: the model is computed from it on every read (owner's reviews of #77 and
    /// #101).
    ///
    /// The seat is a field of the state and not a property beside it, because the tree of live modules is the
    /// navigation state (`docs/specs/feature-module-architecture.md`, section 4): the screen open in the list is
    /// part of what the list holds.
    private struct State {
        var rows: [Model.Row]
        var task: Seat<TaskScreen, StoreError>
        var problem: String?

        /// The model a view draws: the rows, the open screen's model as the screen computes it, and the
        /// sentence, if any.
        var model: Model { Model(rows: rows, task: task.model, problem: problem) }
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
