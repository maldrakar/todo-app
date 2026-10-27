// Sources/Features/App/AppModule.swift
import FeatureModule
import QuickEntryFeature
import TaskListFeature
import TaskScreenFeature
import TaskViewListFeature
import TodoCore

/// The root of the tree of modules, and the one module a host holds (spec section 1): the window's stack, with the
/// sidebar as its base and the screens it and they declared standing over it, quick entry when it is up, and the
/// root's own sentence when a link into the window could not be read.
///
/// It owns the window's flow (ADR-0009, amendment of 2026-10-22, point 3): it holds every screen of the window's
/// stack, through the stack, and names the kinds that can stand there in `Screen`, and it decides none of their
/// transitions. The sidebar declares the list of the view chosen in it, and the list declares the task tapped in it,
/// each in its own destination, and the stack follows the declarations after every event, so this module never
/// learns that a choice opens a list or that a list opens a task, and its code does not grow when a screen learns to
/// open one of the kinds it holds (navigation state spec, section 2). Quick entry sits in a seat (spec section 4),
/// the window's own modal, which the root alone holds.
///
/// It decides the layout of the window's navigation (navigation state spec, section 4). The window's view reports
/// the window's width class, narrow or wide, as an event of the world, and decides nothing by it; the model carries
/// the shape for that class ready to draw, every screen over the sidebar in one path when the window is narrow, and
/// when it is wide the first of them as the detail column's root and the rest as its path. The screens stand in the
/// stack whichever the shape, so a window that narrows or widens keeps them, with their state.
///
/// It is a routable module (spec section 4), and its route is the route of the window: what a link carries, what
/// a window is restored from and what the web's address bar shows, each through the route's one text form, `path`
/// (spec section 2).
public final class AppModule: Routable {
    /// What the root view draws: each module's model as the module computes it, carried whole, the layout of the
    /// screens standing over the sidebar, and the root's own sentence.
    public struct Model: Equatable, Sendable {
        /// The sidebar's own model, with its highlight and the sentence it says.
        public let taskViewList: TaskViewList.Model

        /// The shape of the window's navigation for its width, with the ids of the screens standing over the sidebar
        /// in it, which the root view switches over once and whose path it binds and hands back whole as
        /// `.wentBack(to:)` (navigation state spec, sections 3, 4 and 6).
        public let layout: Layout

        /// The model of each screen standing over the sidebar, by the id of its element, so that the root view finds
        /// an element's model without a search. It holds a model for every id of `layout`, the column's included, and
        /// none beside.
        public let screens: [StackElementID: ScreenModel]

        /// Quick entry's own model while it is up, and nil when it is not; it is drawn as a sheet on every Apple
        /// platform (spec section 5).
        public let quickEntry: QuickEntry.Model?

        /// What went wrong in the window and is no other module's to say, as the finished sentence the view shows,
        /// and nil when there is nothing to say: a link that could not be read, which no module was handed (the
        /// owner, 2026-10-16, answering the spec's open question). What a module says about itself is in its own
        /// model.
        public let problem: String?
    }

    /// The shape of the window's navigation for its width class, which the root decides and the root view draws:
    /// the view switches over it once, binds the path it carries and chooses no tree of its own (navigation state
    /// spec, sections 4 and 6; `docs/style.md`, "Views"). Both shapes hold the ids of the same screens, bottom up, so
    /// a window that narrows or widens has the same screens in the other shape.
    public enum Layout: Equatable, Sendable {
        /// One stack, with the sidebar at its root and every screen over the sidebar in its path: iPhone's window and
        /// a narrow iPad window.
        case narrow(path: [StackElementID])
        /// The sidebar in a column of its own, beside a stack whose root is the first screen over the sidebar, nil
        /// when none stands, which the view draws as its placeholder, and whose path is the rest: the Mac's window
        /// and a wide iPad window. The column is not in the path, so no write of the path can pop it, and "in a wide
        /// window the highlight cannot be removed" holds by construction.
        case wide(column: StackElementID?, path: [StackElementID])
    }

    /// What the root view may send: what the views of the window's modules send, each wrapped in the case of the
    /// module it is for, so that the root view hands each module's view a closure over that module's actions alone,
    /// the way back its stack's path reports, and the root's own toolbar button. Named for the control and the
    /// gesture, never for what the root does about it (`docs/style.md`).
    public enum UserAction: Equatable, Sendable {
        /// An action of the sidebar, handed to it as it came.
        case taskViewList(TaskViewList.UserAction)
        /// An action of a screen standing over the sidebar, with the id of the element its view draws, handed to it
        /// as it came. An id the stack no longer holds, a screen dropped since its view read the model, moves
        /// nothing.
        case screen(StackElementID, ScreenAction)
        /// The way back, by the back button, the swipe from the edge or the long-press menu that goes back several
        /// screens at once, which SwiftUI reports only as the shorter path it wrote into the path of the layout and the
        /// root view hands on whole (navigation state spec, section 3). The root reads it against the layout it has
        /// when the write arrives, which is the one the view bound unless the width moved in between: narrow, as the
        /// whole of what stands over the sidebar, and wide, as what stands over the column, so the column is never
        /// popped (section 4). A write the view bound in the other layout, one that lands after the width moved, is
        /// read in the layout the root has: on 2026-10-24, in the iOS 26.3 simulator, no write crossed a change of
        /// tree. Named for the gesture: what it closes is the stack's to work out, and a path that is not a shorter
        /// prefix of the one it holds, the write SwiftUI makes after a pop the model drove among them, moves nothing.
        case wentBack(to: [StackElementID])
        /// An action of quick entry, handed to it as it came; with no quick entry up it moves nothing.
        case quickEntry(QuickEntry.UserAction)
        /// The toolbar's quick entry button.
        case quickEntryButtonTapped
    }

    /// Everything that reaches the root: an action a view sent, a change the store committed, which the root
    /// hands to every module of the window, the two events of a routable module, `.created` and `.route` (spec
    /// section 3), a link that could not be read, and the window's width class.
    public enum Event: RoutedEvent {
        /// What a view sent, lifted by the host.
        case action(UserAction)
        /// What a commit touched, delivered by the host and never in the middle of another event (spec section 5).
        case changed(ChangeSet)
        /// The module has just been made: the event `RoutedEvent` asks every routable module to spell, which a
        /// parent sends the child it made. The root has no parent and nothing sends it this today; `init` has told
        /// the sidebar already, and the stack every screen it made, so it answers nothing and moves nothing.
        case created
        /// A route applied to the live window, a link into it or the browser's back and forward buttons (spec
        /// sections 7 and 8), and never by a view, whose closure spells user actions alone.
        case route(Route)
        /// A link into the live window that does not read as a route, delivered by the composition root through the
        /// entrance a link that reads takes as `.route` (spec section 7). It is an event of the world and not a
        /// `UserAction`, because a link is no control a person pressed: a view's closure spells user actions alone, and
        /// the link reaches the host through the composition root's way in. It carries no text, since the sentence is
        /// all the window shows of it.
        ///
        /// It moves nothing but the root's sentence: the window stays as it was, and the root says the link could
        /// not be opened, since what failed is no screen's (the owner, 2026-10-16). A window restored from a text that
        /// does not read is made on the default route and says nothing, which is restoration's rule, so this comes
        /// from a link alone.
        case unreadableLink
        /// The window's width class as its view reports it, delivered by the composition root through the entrance a
        /// link takes (navigation state spec, section 4). It is an event of the world and not a `UserAction`: nobody
        /// pressed anything, and a view's closure spells user actions alone (the owner, 2026-10-20, on the window's
        /// way in).
        ///
        /// It moves the layout, and the sidebar's tiles and title fonts, which the sidebar builds for the width it is
        /// handed (Lists screen spec, sections 8 and 9), and nothing else: no screen is made or dropped, no sentence
        /// moves and the route stays, so the width the window already has moves nothing.
        case widthChanged(WindowWidth)
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

    /// The route of the window, assembled on every read and never kept beside what it is read from (spec section 4):
    /// the stack's, written from the top down from what stands, so that a declaration that has aged never reaches
    /// the text (navigation state spec, section 3), and quick entry's.
    public var route: Route { Route(sidebar: state.stack.route, quickEntry: state.quickEntry.route) }

    private var state: State

    /// Made from the window's route, the one way a window is made: at launch and for a new window, and from the
    /// text a window was restored from (spec sections 5 and 7). It says nothing of its own: the root's sentence
    /// answers a link into a live window.
    ///
    /// The sidebar is made from its part of the route, and declares the list in its own `init`: the route's list
    /// when it names one, with the task in it, and the view the sidebar starts on otherwise, the Inbox for the
    /// default window, so the root names no view of its own (ADR-0006, amendment of 2026-10-03). The stack is built
    /// on it, and the sidebar is told it was created through the stack, whose first walk makes what it declared and
    /// what that declared in turn (navigation state spec, section 3). Quick entry comes last.
    ///
    /// The route defaults to the default window, so that a caller with no route to hand on spells none (owner's
    /// review of #103, as quick entry's `init` has it since #102).
    ///
    /// The width is the class the window opens with, so that its first frame already has the shape of its layout and
    /// the sidebar its tiles (navigation state spec, section 4), and the sidebar is made with it. It has no default: a window made wide and told otherwise on its first
    /// frame is the spec's fallback for a host that does not know the class when the window is made, and a default
    /// here would make that fallback a rule of the core (`docs/style.md`, "A lower layer holds no policy of its
    /// client").
    ///
    /// Throws what the sidebar's `init` throws and nothing else, as M2's root did: a window is not made around a
    /// sidebar the store cannot read, and refusing the launch is the composition root's. A screen of the stack that
    /// cannot be made is its opener's to say, and quick entry cannot fail to be made.
    public init(store: Store, route: Route = .default, width: WindowWidth) throws(StoreError) {
        let taskViewList = try TaskViewList(store: store, route: route.sidebar, width: width)
        // The stack and the seat are built once, here, each with the way to make what it holds: a closure over the
        // `init` of the kind the route names that captures the store and never this root. The root holds both in its
        // state, so a closure holding the root would close a cycle, root to state to stack or seat to closure to
        // root, and none of them would ever be released (`ScreenStack.init`, `Seat.init`). The stack's closure names
        // its error, the screens' `Failure`; the seat's throws nothing, so it is applied without `try`.
        let stack = ScreenStack<Screen>(base: taskViewList) { route throws(StoreError) in
            switch route {
            case .list(let list): return .list(try TaskList(store: store, route: list))
            case .task(let task): return .task(try TaskScreen(store: store, route: task))
            }
        }
        let quickEntry = Seat<QuickEntry, Never> { route in QuickEntry(store: store, route: route) }
        self.state = State(stack: stack, quickEntry: quickEntry, width: width)
        // The sidebar answers being created with nothing, and the one output it could give, a window to open,
        // needs a person to ask for it, so nothing is dropped here.
        _ = react(to: state.stack.send(.created))
        react(to: state.quickEntry.apply(route.quickEntry))
    }

    public func send(_ event: Event) -> Output? {
        switch event {
        case .action(.taskViewList(let action)):
            return react(to: state.stack.send(.action(action)))
        case .action(.screen(let id, let action)):
            // Handed to the element as it came, and what it answers goes to its opener; an id the stack no longer
            // holds moves nothing. The root's sentence stays, since a gesture on a screen is that screen's.
            return react(to: state.stack.send(.action(action), to: id))
        case .action(.wentBack(let path)):
            // Read against the layout the root has as the write arrives, the one the view bound unless the width moved
            // in between, which no write crossed in the probes of 2026-10-24, so that in a wide window the column goes
            // before it and no write can pop the column (navigation state spec, section 4). The stack drops what was
            // over the screen now on top and tells that screen, which empties its destination (section 3). A path it
            // does not hold as a shorter prefix moves nothing, which is where SwiftUI's write after a pop the model
            // drove lands, in either layout. The root's sentence stays, since the way back is a gesture on the screens.
            return react(to: state.stack.wentBack(to: state.stackPath(wentBackTo: path)))
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
            // Every module of the window gets the change and decides for itself whether it reads it: the sidebar
            // first, then each screen standing over it, bottom up, as the path stood when the change arrived, which
            // is read before the sidebar takes it (navigation state spec, section 8, the third flow). A screen whose
            // subject is gone asks to be closed, its opener empties its destination, and the walk drops it with what
            // stands over it, whose id the loop then finds gone and hands nothing. The root reads the store for
            // nothing of its own (spec section 3, ADR-0006, amendment of 2026-10-14), and its sentence stays: a
            // change answers nothing a person was told. Of what the sidebar answers the root returns the first drawn,
            // as the stack does within one call.
            let path = state.stack.path
            var output = react(to: state.stack.send(.changed(changes)))
            for id in path {
                let answer = react(to: state.stack.send(.changed(changes), to: id))
                output = output ?? answer
            }
            react(to: state.quickEntry.send(.changed(changes)))
            return output
        case .created:
            // The sentence included: being created answers nothing a person was told.
            return nil
        case .route(let route):
            // A link into the live window, or the browser's back button: the sidebar takes its part, which declares
            // the list in it whole, the stack makes or keeps the list and hands it its part, which declares the task,
            // and quick entry is reconciled with the route's quick entry (navigation state spec, section 3). A route
            // with no quick entry drops a live one and its draft, a link from outside included, since a draft is
            // session state, which no route carries (spec section 2). The root's sentence goes at the start, as the
            // list's goes at the start of a route, and the sidebar's unless a field is open (the owner, 2026-10-16):
            // the link read, and what the route cannot open is its opener's to say, as the sidebar says a list it
            // could not open.
            state.problem = nil
            let output = react(to: state.stack.send(.route(route.sidebar)))
            react(to: state.quickEntry.apply(route.quickEntry))
            return output
        case .unreadableLink:
            // A second link that does not read says it again, over a sentence still on screen or one taken away.
            state.problem = Problem.unreadableLink.sentence
            return nil
        case .widthChanged(let width):
            // The layout is computed from the width and the stack on every read, so the root's own part is the width
            // alone. The sidebar is handed it too, since its rows take the tiles of the width they are drawn at, and
            // it answers nothing; it is reached through the stack, whose walk after the event finds no destination
            // written and moves nothing. The same width again moves nothing in either.
            state.width = width
            return react(to: state.stack.send(.widthChanged(width)))
        }
    }

    /// What the sidebar asked for, whichever event drew it out, which the stack hands the root as the flow's owner.
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

    /// Everything the root holds between two events: the window's stack, the seat of quick entry, the root's
    /// sentence and the window's width class. One value, moved by the cases of `send`, from which the model, its
    /// layout included, and the route are computed on every read (owner's reviews of #77 and #101).
    ///
    /// The sidebar is the stack's base and not an element or a seat. A window always has it and nothing replaces it,
    /// so the root makes it and hands it to the stack, which keeps it to itself: the root reads its model through
    /// `baseModel` and reaches it only through the stack's `send(_:)`, so that no event reaches the sidebar without
    /// the walk after it (`ScreenStack`). The stack and the seat are `var`s: each is a struct holding classes, and a
    /// call that changes what it holds is a mutation of this state.
    private struct State {
        var stack: ScreenStack<Screen>
        var quickEntry: Seat<QuickEntry, Never>
        var problem: String?
        /// The class the window's view reported last, or the one the window was made with, which the layout is cut
        /// by and nothing else reads: the sidebar is handed the same class and keeps its own.
        var width: WindowWidth

        /// The model the root view draws: the sidebar's and each screen's, as each computes it, the layout of the
        /// screens over the sidebar, quick entry's, and the root's sentence.
        var model: Model {
            Model(
                taskViewList: stack.baseModel, layout: layout, screens: stack.models,
                quickEntry: quickEntry.model, problem: problem
            )
        }

        /// The stack's path in the shape of the window's width (navigation state spec, section 4): narrow, the whole
        /// of it as the one path; wide, its first id as the column, or none when nothing stands, and the rest as
        /// the path.
        var layout: Layout {
            switch width {
            case .narrow: .narrow(path: stack.path)
            case .wide: .wide(column: stack.path.first, path: Array(stack.path.dropFirst()))
            }
        }

        /// The stack's path that a way back to `written` stands for, read against the layout as it is now, which is
        /// the one the view bound `written` from unless the width moved in between: narrow, the whole of the stack's
        /// path; wide, the path over the column, so the column's id goes before it and the column is never popped
        /// (navigation state spec, section 4). With nothing in the column nothing stands, and whatever was written
        /// moves nothing.
        func stackPath(wentBackTo written: [StackElementID]) -> [StackElementID] {
            switch layout {
            case .wide(let column?, _): [column] + written
            case .narrow, .wide(nil, _): written
            }
        }
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
