// Sources/Features/App/AppModule.swift
import FeatureModule
import QuickEntryFeature
import TaskListFeature
import TaskViewListFeature
import TodoCore

/// The root of the tree of modules, and the one module a host holds: the sidebar, the list of the chosen view's
/// tasks in the pane beside it, and quick entry when it is up (spec section 1).
///
/// It knows its three children and what each asks for: the task open in the list is the list's child, so this
/// module never learns that a list opens a task, and its code does not grow when the task screen learns to open
/// something (spec section 1). The window's text form does grow: it spells the whole window, so it names the task,
/// and a screen opened inside the task screen would be a segment of it too (`Route`). The task list and quick entry
/// sit in seats (spec section 4), and the sidebar is a field of the root's state outside one (owner's decision of
/// 2026-10-16; `State` says why).
///
/// It is a routable module (spec section 4), and its route is the route of the window: what a link carries, what
/// a window is restored from and what the web's address bar shows, each through the route's one text form (spec
/// section 2).
public final class AppModule: Routable {
    /// What the root view draws: each child's model as the child computes it, carried whole, and the root's own
    /// sentence beside them.
    public struct Model: Equatable, Sendable {
        /// The sidebar's own model.
        public let taskViewList: TaskViewList.Model

        /// The pane's own model, and nil when no pane is open: when the window was made without one, and after
        /// the view the pane was on is gone.
        public let taskList: TaskList.Model?

        /// Quick entry's own model while it is up, and nil when it is not; it is drawn as a sheet on every Apple
        /// platform (spec section 5).
        public let quickEntry: QuickEntry.Model?

        /// What went wrong, as the finished sentence the view shows until the next action that has something to
        /// act on it, and nil when there is nothing to say: a pane that could not be opened, where the one that was
        /// open stays (spec section 3).
        public let problem: String?
    }

    /// What the root view may send: what its children's views send, each wrapped in the case of the child it is
    /// for, so that the root view hands each child's view a closure over that child's actions alone, and the
    /// root's own toolbar button. Named for the control and the gesture, never for what the root does about it
    /// (`docs/style.md`).
    public enum UserAction: Equatable, Sendable {
        /// An action of the sidebar, handed to it as it came.
        case taskViewList(TaskViewList.UserAction)
        /// An action of the pane's list, handed to it as it came; with no pane open it moves nothing, the root's
        /// sentence included.
        case taskList(TaskList.UserAction)
        /// An action of quick entry, handed to it as it came; with no quick entry up it moves nothing, the root's
        /// sentence included.
        case quickEntry(QuickEntry.UserAction)
        /// The toolbar's quick entry button.
        case quickEntryButtonTapped
    }

    /// Everything that reaches the root: an action a view sent, a change the store committed, which the root
    /// hands to every child, and the two events of a routable module, `.created` and `.route` (spec section 3).
    public enum Event: RoutedEvent {
        /// What a view sent, lifted by the host.
        case action(UserAction)
        /// What a commit touched, delivered by the host and never in the middle of another event (spec section 5).
        case changed(ChangeSet)
        /// The module has just been made: the event `RoutedEvent` asks every routable module to spell, which a
        /// parent sends the child it made. The root has no parent and nothing sends it this today; `init` has told
        /// every child already, so it answers nothing and moves nothing.
        case created
        /// A route applied to the live window, a link into it or the browser's back and forward buttons (spec
        /// sections 7 and 8), and never by a view, whose closure spells user actions alone.
        case route(Route)
    }

    /// What the root asks of the platform, since there is no module above it.
    public enum Output: Equatable, Sendable {
        /// A window to open on the route, which only the platform can open: the sidebar's request for a view in
        /// a window of its own, passed on under the root's own name (spec section 4, the rule of bubbling).
        case openWindow(Route)
    }

    /// What the root view draws, computed from the state on every read and never kept beside it, so that what the
    /// root holds is in one place and the model cannot disagree with it (owner's review of #101).
    public var model: Model { state.model }

    /// The route of the window, assembled from the children's routes on every read and never kept beside them
    /// (spec section 4): a route the root kept would have to be moved by every event that moves a child.
    public var route: Route {
        Route(sidebar: state.taskViewList.route, detail: state.taskList.route, quickEntry: state.quickEntry.route)
    }

    private var state: State

    /// Made from the window's route, the one way a window is made: at launch and for a new window, and from the
    /// text a window was restored from (spec sections 5 and 7).
    ///
    /// The sidebar is made first and told it was created, and its answer, the view it starts on, opens the pane
    /// on the line a click's answer takes, so that launch and a click are one path and the root names no view of
    /// its own (ADR-0006, amendment of 2026-10-03): the default window's sidebar answers with the Inbox, and the
    /// pane opens on it. Then the route's pane is applied when it names one, and a pane on the view the sidebar
    /// chose finds that list already in its seat and opens the task in it (spec section 4). In the other order
    /// the sidebar's answer would reach the list with its task open and close it. Quick entry comes last.
    ///
    /// Throws what the sidebar's `init` throws and nothing else, as M2's root did: a window is not made around a
    /// sidebar the store cannot read, and refusing the launch is the composition root's. A pane that cannot be
    /// made leaves its seat as it was and a sentence in `problem`, and quick entry cannot fail to be made.
    public init(store: Store, route: Route) throws(StoreError) {
        let taskViewList = try TaskViewList(store: store, route: route.sidebar)
        // Each seat is built once, here, with the way to make its child: a closure over the child's own `init`
        // that captures the store and never this root. The root holds the seats in its state, so a closure
        // holding the root would close a cycle, root to state to seat to closure to root, and none of them
        // would ever be released (`Seat.init`). The pane's error is named so that the seat's type is checked
        // against it rather than widened to `any Error`; quick entry's closure throws nothing, so its seat is
        // applied without `try`.
        let taskList = Seat<TaskList, StoreError> { route throws(StoreError) in try TaskList(store: store, route: route) }
        let quickEntry = Seat<QuickEntry, Never> { route in QuickEntry(store: store, route: route) }
        self.state = State(taskViewList: taskViewList, taskList: taskList, quickEntry: quickEntry, problem: nil)
        // The answer to `.created` is the sidebar's first choice, and the one output it could give besides, a
        // window to open, needs a person to ask for it, so nothing is dropped here.
        _ = react(to: state.taskViewList.send(.created))
        if let detail = route.detail { apply(pane: detail) }
        react(to: state.quickEntry.apply(route.quickEntry))
    }

    public func send(_ event: Event) -> Output? {
        // An action takes the sentence away, since the person has done something since reading it, and it goes
        // before the action is handed on, so that a pane the action cannot open writes a fresh one. A route, a
        // change and being created are nobody's doing and leave it, since a sentence cleared by them would go before
        // the person had read it. So does an action for a pane or a quick entry that is not there, which moves
        // nothing at all: a view sends one when the platform writes back through a binding after a close the model
        // drove, as the sheet does after a route closed quick entry, and nobody did anything.
        switch event {
        case .action(.taskViewList(let action)):
            state.problem = nil
            return react(to: state.taskViewList.send(.action(action)))
        case .action(.taskList(let action)):
            // The back button the platform sends after a pop the model drove reaches a list that is there, and takes
            // the sentence too. That sentence was on screen before the pop: the event that popped wrote none, since
            // a pop and a pane that could not be opened never come from one event.
            guard state.taskList.route != nil else { return nil }
            state.problem = nil
            react(to: state.taskList.send(.action(action)))
            return nil
        case .action(.quickEntry(let action)):
            // Cancel included, which closes quick entry by its own answer; with no quick entry up, it is where the
            // sheet's binding lands when it writes false after a close the model drove.
            guard state.quickEntry.route != nil else { return nil }
            state.problem = nil
            react(to: state.quickEntry.send(.action(action)))
            return nil
        case .action(.quickEntryButtonTapped):
            // A quick entry already up has the head of every quick entry, so its seat keeps it, draft and all.
            state.problem = nil
            react(to: state.quickEntry.apply(QuickEntry.Route()))
            return nil
        case .changed(let changes):
            // Every child gets the change, one line each, and decides for itself whether it reads it; a child whose
            // subject is gone asks to be closed through its answer. The root reads the store for nothing of its
            // own (spec section 3, ADR-0006, amendment of 2026-10-14).
            let output = react(to: state.taskViewList.send(.changed(changes)))
            react(to: state.taskList.send(.changed(changes)))
            react(to: state.quickEntry.send(.changed(changes)))
            return output
        case .created:
            return nil
        case .route(let route):
            // A link into the live window, or the browser's back button: the sidebar moves its highlight, the pane is
            // reconciled with the route's pane, and quick entry with the route's quick entry (spec section 3, the
            // third flow). The sidebar answers a route with nothing, since the route's choice is one the root
            // already holds, so the pane is applied once. A route that says nothing of the pane leaves it to follow
            // the sidebar, so `/` keeps the highlight, the list and its task where they are (owner's decision of
            // 2026-10-16). A route with no quick entry drops a live one and its draft, a link from outside included,
            // since a draft is session state, which no route carries (spec section 2).
            let output = react(to: state.taskViewList.send(.route(route.sidebar)))
            if let detail = route.detail { apply(pane: detail) }
            react(to: state.quickEntry.apply(route.quickEntry))
            return output
        }
    }

    /// Applies a route to the pane's seat, which keeps the list on the same view and hands it the route, and
    /// replaces it on another (spec section 3). A list that cannot be made, its view gone or the store unread,
    /// leaves the one that was open, since the seat makes the new one before it lets the old one go, and the root
    /// says so (spec section 3).
    private func apply(pane route: TaskList.Route) {
        do {
            react(to: try state.taskList.apply(route))
        } catch {
            state.problem = Problem.couldNotOpenList.sentence
        }
    }

    /// What the sidebar asked for, whichever event drew it out.
    ///
    /// One path for every answer: the root does not encode which of the sidebar's events answer, so its first
    /// choice at launch, a click and any answer a later event gives take the same line. The switch has no
    /// default, so an answer the sidebar learns to give stops this file compiling until the root has decided
    /// what it means (spec section 4).
    private func react(to output: TaskViewList.Output?) -> Output? {
        switch output {
        case .selected(let id)?:
            // Applied every time, the highlighted view's own row included: on the view the pane is on, the seat
            // keeps the list and the route's empty tail closes the task open in it, so a click on the highlighted
            // view returns to its list, as System Settings does on the Mac and a second tap on a tab does on iOS
            // (owner's decision of 2026-10-16).
            apply(pane: TaskList.Route(head: id))
            return nil
        case .openInWindow(let id)?:
            // A window is the platform's to open, so the request leaves the root under its own name, with the
            // route of a window on the view (spec section 4, the rule of bubbling).
            return .openWindow(Route(sidebar: .init(selection: id), detail: .init(head: id), quickEntry: nil))
        case nil:
            return nil
        }
    }

    /// What the pane's list asked for: to be closed, because its view is gone, and the root drops it with the
    /// task open in it (spec section 3).
    private func react(to output: TaskList.Output?) {
        switch output {
        case .closeRequested?: state.taskList.drop()
        case nil: break
        }
    }

    /// What quick entry asked for: to be closed, and the root drops it. With its task created, that is the modal's
    /// own half of the way back (spec section 5); after its Cancel, which the swipe down and Esc send too, it is
    /// quick entry's own answer to its own action, since closing is what quick entry decides the gesture means
    /// (the owner's ruling on #101).
    private func react(to output: QuickEntry.Output?) {
        switch output {
        case .closeRequested?: state.quickEntry.drop()
        case nil: break
        }
    }

    /// Everything the root holds between two events: the sidebar, the seats of the pane and of quick entry, and
    /// the sentence a person was last told. One value, moved by the cases of `send`, from which the model and the
    /// route are computed on every read (owner's reviews of #77 and #101).
    ///
    /// The sidebar is a field and not a seat. A seat makes, keeps, replaces and drops a child, and the sidebar,
    /// whose head is `NoHead` and which a window always has, needs none of the four; a seat's optional route and
    /// model would not fill the root's fields, which are not optional (owner's decision of 2026-10-16). It is a
    /// `let`, since nothing replaces it, and a module is a class, so it moves itself through its own `send`. The
    /// seats are `var`s: a seat is a struct holding a class, and a call that changes what it holds is a mutation
    /// of this state.
    private struct State {
        let taskViewList: TaskViewList
        var taskList: Seat<TaskList, StoreError>
        var quickEntry: Seat<QuickEntry, Never>
        var problem: String?

        /// The model the root view draws: each child's, as the child computes it, and the sentence, if any.
        var model: Model {
            Model(taskViewList: taskViewList.model, taskList: taskList.model, quickEntry: quickEntry.model, problem: problem)
        }
    }

    /// What can go wrong in the root, with the sentence each one reads as. The store's own error stays here: it
    /// names SQLite codes and journal rows, which is what a bug report is made of and not what a person can do
    /// anything about.
    private enum Problem {
        case couldNotOpenList

        var sentence: String {
            switch self {
            case .couldNotOpenList: "The list could not be opened."
            }
        }
    }
}
