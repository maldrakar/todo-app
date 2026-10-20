// Sources/Features/App/AppModule.swift
import FeatureModule
import QuickEntryFeature
import TaskViewListFeature
import TodoCore

/// The root of the tree of modules, and the one module a host holds (spec section 1): the sidebar, with the list of
/// the chosen view's tasks it opened, quick entry when it is up, and the root's own sentence when a link into the
/// window could not be read.
///
/// It knows its two children and what each asks for, and nothing below them. The task open in the list is the
/// list's, so this module never learns that a list opens a task, and its code does not grow when the task screen
/// learns to open something (spec section 1). The list is the sidebar's, since a choice in the sidebar opens it,
/// by the rule that every screen is a child of the screen that opened it, applied in the owner's review of #103
/// (ADR-0009), so this module never learns that a choice opens a list either. Quick entry sits in a seat (spec
/// section 4), and the sidebar is a field of the root's state outside one (owner's decision of 2026-10-16; `State`
/// says why).
///
/// It is a routable module (spec section 4), and its route is the route of the window: what a link carries, what
/// a window is restored from and what the web's address bar shows, each through the route's one text form, `path`
/// (spec section 2).
public final class AppModule: Routable {
    /// What the root view draws: each child's model as the child computes it, carried whole, and the root's own
    /// sentence.
    public struct Model: Equatable, Sendable {
        /// The sidebar's own model, which carries the list open in it and the sentence it says.
        public let taskViewList: TaskViewList.Model

        /// Quick entry's own model while it is up, and nil when it is not; it is drawn as a sheet on every Apple
        /// platform (spec section 5).
        public let quickEntry: QuickEntry.Model?

        /// What went wrong in the window and is no child's to say, as the finished sentence the view shows, and nil
        /// when there is nothing to say: a link that could not be read, which no child was handed (the owner,
        /// 2026-10-16, answering the spec's open question). What a child says about itself is in its own model.
        public let problem: String?
    }

    /// What the root view may send: what its children's views send, each wrapped in the case of the child it is
    /// for, so that the root view hands each child's view a closure over that child's actions alone, and the
    /// root's own toolbar button. Named for the control and the gesture, never for what the root does about it
    /// (`docs/style.md`).
    public enum UserAction: Equatable, Sendable {
        /// An action of the sidebar, handed to it as it came, the actions of the list open in it among them.
        case taskViewList(TaskViewList.UserAction)
        /// An action of quick entry, handed to it as it came; with no quick entry up it moves nothing.
        case quickEntry(QuickEntry.UserAction)
        /// The toolbar's quick entry button.
        case quickEntryButtonTapped
    }

    /// Everything that reaches the root: an action a view sent, a change the store committed, which the root
    /// hands to every child, the two events of a routable module, `.created` and `.route` (spec section 3), and a
    /// link that could not be read.
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
        /// A link into the live window that does not read as a route, delivered by the composition root through the
        /// entrance a link that reads takes as `.route` (spec section 7). It is an event of the world and not a
        /// `UserAction`, because a link is no control a person pressed and a view has no way to send it. It carries
        /// no text, since the sentence is all the window shows of it.
        ///
        /// It moves nothing but the root's sentence: the window stays as it was, and the root says the link could
        /// not be opened, since what failed is no child's (the owner, 2026-10-16). A window restored from a text that
        /// does not read is made on the default route and says nothing, which is restoration's rule, so this comes
        /// from a link alone.
        case unreadableLink
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
    public var route: Route { Route(sidebar: state.taskViewList.route, quickEntry: state.quickEntry.route) }

    private var state: State

    /// Made from the window's route, the one way a window is made: at launch and for a new window, and from the
    /// text a window was restored from (spec sections 5 and 7). It says nothing of its own: the root's sentence
    /// answers a link into a live window.
    ///
    /// The sidebar is made from its part of the route, and opens the list in its own `init`: on the route's list
    /// when it names one, and on the view the sidebar starts on otherwise, the Inbox for the default window, so
    /// the root names no view of its own (ADR-0006, amendment of 2026-10-03). Then it is told it was created, as
    /// every child is, and quick entry comes last.
    ///
    /// The route defaults to the default window, so that a caller with no route to hand on spells none (owner's
    /// review of #103, as quick entry's `init` has it since #102).
    ///
    /// Throws what the sidebar's `init` throws and nothing else, as M2's root did: a window is not made around a
    /// sidebar the store cannot read, and refusing the launch is the composition root's. A list that cannot be
    /// made is the sidebar's to say, and quick entry cannot fail to be made.
    public init(store: Store, route: Route = .default) throws(StoreError) {
        let taskViewList = try TaskViewList(store: store, route: route.sidebar)
        // The seat is built once, here, with the way to make quick entry: a closure over its own `init` that
        // captures the store and never this root. The root holds the seat in its state, so a closure holding the
        // root would close a cycle, root to state to seat to closure to root, and none of them would ever be
        // released (`Seat.init`). The closure throws nothing, so the seat is applied without `try`.
        let quickEntry = Seat<QuickEntry, Never> { route in QuickEntry(store: store, route: route) }
        self.state = State(taskViewList: taskViewList, quickEntry: quickEntry)
        // The sidebar answers being created with nothing, and the one output it could give, a window to open,
        // needs a person to ask for it, so nothing is dropped here.
        _ = react(to: state.taskViewList.send(.created))
        react(to: state.quickEntry.apply(route.quickEntry))
    }

    public func send(_ event: Event) -> Output? {
        switch event {
        case .action(.taskViewList(let action)):
            return react(to: state.taskViewList.send(.action(action)))
        case .action(.quickEntry(let action)):
            // Cancel included, which closes quick entry by its own answer. With no quick entry up the empty seat
            // answers nothing, which is where the sheet's binding lands when it writes false after a close the model
            // drove, and nothing moves.
            react(to: state.quickEntry.send(.action(action)))
            return nil
        case .action(.quickEntryButtonTapped):
            // The root's own gesture, so the root's sentence goes with it, as each module's sentence goes with its own
            // gestures; a gesture in a child is the child's, and leaves it (the owner, 2026-10-20). A quick entry
            // already up has the head of every quick entry, so its seat keeps it, draft and all.
            state.problem = nil
            react(to: state.quickEntry.apply(QuickEntry.Route()))
            return nil
        case .changed(let changes):
            // Every child gets the change, one line each, and decides for itself whether it reads it; the sidebar
            // hands it on to the list, and a child whose subject is gone asks to be closed through its answer. The
            // root reads the store for nothing of its own (spec section 3, ADR-0006, amendment of 2026-10-14), and
            // its sentence stays: a change answers nothing a person was told.
            let output = react(to: state.taskViewList.send(.changed(changes)))
            react(to: state.quickEntry.send(.changed(changes)))
            return output
        case .created:
            // The sentence included: being created answers nothing a person was told.
            return nil
        case .route(let route):
            // A link into the live window, or the browser's back button: the sidebar takes its part, which moves the
            // highlight and the list, and quick entry is reconciled with the route's quick entry (spec section 3, the
            // third flow). A route with no quick entry drops a live one and its draft, a link from outside included,
            // since a draft is session state, which no route carries (spec section 2). The root's sentence goes at the
            // start, as the list's goes at the start of a route, and the sidebar's unless a field is open (the owner,
            // 2026-10-16): the link read, and what the route cannot open is the child's to say, as the sidebar says a
            // list it could not open.
            state.problem = nil
            let output = react(to: state.taskViewList.send(.route(route.sidebar)))
            react(to: state.quickEntry.apply(route.quickEntry))
            return output
        case .unreadableLink:
            // A second link that does not read says it again, over a sentence still on screen or one taken away.
            state.problem = Problem.unreadableLink.sentence
            return nil
        }
    }

    /// What the sidebar asked for, whichever event drew it out.
    ///
    /// One path for every answer: the root does not encode which of the sidebar's events answer. The switch has no
    /// default, so an answer the sidebar learns to give stops this file compiling until the root has decided what
    /// it means (spec section 4).
    private func react(to output: TaskViewList.Output?) -> Output? {
        switch output {
        case .openInWindow(let sidebar)?:
            // A window is the platform's to open, so the request leaves the root under its own name, with the
            // sidebar's own route for the new window and no quick entry (spec section 4, the rule of bubbling).
            return .openWindow(Route(sidebar: sidebar, quickEntry: nil))
        case nil:
            return nil
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

    /// Everything the root holds between two events: the sidebar, the seat of quick entry and the root's sentence. One
    /// value, moved by the cases of `send`, from which the model and the route are computed on every read (owner's
    /// reviews of #77 and #101).
    ///
    /// The sidebar is a field and not a seat. A seat makes, keeps, replaces and drops a child, and the sidebar,
    /// whose head is `NoHead` and which a window always has, needs none of the four; a seat's optional route and
    /// model would not fill the root's fields, which are not optional (owner's decision of 2026-10-16). It is a
    /// `let`, since nothing replaces it, and a module is a class, so it moves itself through its own `send`. The
    /// seat is a `var`: a seat is a struct holding a class, and a call that changes what it holds is a mutation
    /// of this state.
    private struct State {
        let taskViewList: TaskViewList
        var quickEntry: Seat<QuickEntry, Never>
        var problem: String?

        /// The model the root view draws: each child's, as the child computes it, and the root's sentence.
        var model: Model { Model(taskViewList: taskViewList.model, quickEntry: quickEntry.model, problem: problem) }
    }

    /// What can go wrong in this module, with the sentence each one reads as.
    private enum Problem {
        case unreadableLink

        var sentence: String {
            switch self {
            case .unreadableLink: "The link could not be opened."
            }
        }
    }
}
