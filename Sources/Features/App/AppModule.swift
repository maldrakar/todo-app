// Sources/Features/App/AppModule.swift
import FeatureModule
import TaskViewListFeature
import TodoCore

/// The root of the tree of modules, and the one module a host holds: the list of views, and the pane beside
/// it that shows the view chosen in the list (spec section 3).
///
/// The pane is a placeholder in M2, the title of the chosen view, standing where M3's list module will. It is
/// made from what the list answers and a read of the root's own, never out of the list's model, so that the
/// module replacing it is created in the same place from the same two things: the id the list asked for, and
/// the store (spec section 4).
public final class AppModule: FeatureModule {
    /// What the root view draws: the list's model as the list assembled it, and the pane beside it.
    public struct Model: Equatable, Sendable {
        /// The pane beside the list: the chosen view's title, until M3's list module takes its place.
        public struct Detail: Equatable, Sendable {
            /// The view's title as the last read of it answered: at launch, when the view was chosen, and
            /// whenever a change names it.
            public let title: String
        }

        /// The list's own model, which the root carries to the list's view whole and decides nothing in.
        public let taskViewList: TaskViewList.Model

        /// The pane beside the list, and nil when there is nothing to show in it: the view it would show is
        /// gone.
        public let detail: Detail?
    }

    /// What the root view may send: what its children's views send, each wrapped in the case of the child it
    /// is for, so that the root view hands each child's view a closure over that child's actions alone (spec
    /// section 3).
    public enum UserAction: Equatable, Sendable {
        /// An action of the list of views, handed to the list as it came.
        case taskViewList(TaskViewList.UserAction)
    }

    /// Everything that reaches the root: an action a view sent, and a change the store committed, which the
    /// root hands on to every child that takes one (spec section 3).
    public enum Event: FeatureEvent {
        /// What a view sent, lifted by the host.
        case action(UserAction)
        /// What a commit touched, delivered by the host and never in the middle of another event (spec
        /// section 5).
        case changed(ChangeSet)
    }

    /// `Never`: there is no module above the root to ask anything of.
    public typealias Output = Never

    /// What the root view draws, assembled again after every event.
    public private(set) var model: Model

    private let store: Store

    private let taskViewList: TaskViewList

    private var state: State

    /// Throws what the list's `init` throws and what the first read of the pane throws. Later on, a failed
    /// read keeps the pane that is open, and at launch there is none to keep: a store that cannot be read
    /// then is the composition root's to refuse (spec section 5), as it is for the list.
    public init(store: Store) throws(StoreError) {
        let taskViewList = try TaskViewList(store: store)
        // The Inbox, because the list starts on it (its `init`), and a pane opened on anything else would sit
        // beside a highlight on another row. The root names it rather than asking the list which row it
        // starts on, because a choice reaches the root as the list's answer and the first one is never
        // answered: nobody made it. `theFirstDetailIsTheViewTheListHighlightsFirst` holds the two names
        // together.
        let state = State(detail: try AppModule.detail(of: BuiltInTaskViews.inbox, in: store))
        self.store = store
        self.taskViewList = taskViewList
        self.state = state
        self.model = state.model(with: taskViewList.model)
    }

    /// Hands the event to the list, reacts to what the list answers, and assembles the model again.
    ///
    /// It answers nothing, since `Output` is `Never`, and it is `@discardableResult` because every caller
    /// drops an answer that is always nil (`docs/style.md`, "One shape everywhere it fits").
    @discardableResult
    public func send(_ event: Event) -> Never? {
        // The list's shape, which the owner's review of #77 gave it: the cases below move the state and hand
        // the event on, and the model is assembled once when they are done, from the state and the list's
        // model as the list left it, so that one place decides what the root draws.
        defer { model = state.model(with: taskViewList.model) }
        switch event {
        case .action(.taskViewList(let action)):
            react(to: taskViewList.send(.action(action)))
        case .changed(let changes):
            // Every child that takes the event gets it, and each decides for itself whether the change is
            // one it reads: the list keeps a person typing in a task out of the views table on its own.
            react(to: taskViewList.send(.changed(changes)))
            // Only a change that names the pane's own view reads it again, where the list rereads on any
            // view at all. `store.view(_:)` reads the whole views table to answer for one row, and the list
            // has just read the same table for the same event. The narrower guard misses nothing: a view's
            // title and its deleted flag live on its own row, and a commit that changes either names that
            // view's id.
            if let detail = state.detail, changes.views.contains(detail.id) { readDetail(of: detail.id) }
        }
        return nil
    }

    /// What the list asked for, whichever event drew it out.
    ///
    /// One path for every answer: the root does not know which of the list's events answer, and does not
    /// encode it, so an answer a `.changed` might one day give is handled by the line that handles a click,
    /// and an event that answers nothing opens nothing. The switch has no default, so an answer the list
    /// learns to give stops this file compiling until the root has decided what it means.
    private func react(to output: TaskViewList.Output?) {
        switch output {
        case .selected(let id)?: readDetail(of: id)
        case nil: break
        }
    }

    /// Opens the pane on the view `id` names, or closes it when the store has no such view: that view is
    /// gone, and a pane on it would be a pane on nothing.
    ///
    /// A read that fails leaves the pane as it was, id and title together: the root has no `problem` of its
    /// own in M2 to say it in, and a screen that could not be made leaves the one that was open, which is
    /// how this seat will behave in M3 too, when the list module that takes it is created by an `init` that
    /// throws. `try?` is not used here because it folds a failed read and a view that is gone into the same
    /// nil, and those two mean opposite things: keep the pane, and close it.
    private func readDetail(of id: ViewID) {
        do {
            state.detail = try AppModule.detail(of: id, in: store)
        } catch {
            // Deliberately nothing, for the reason above.
        }
    }

    /// The pane for the view `id` names, or nil when the store holds no such view: the one read that the
    /// launch, an answer and a change all make.
    private static func detail(of id: ViewID, in store: Store) throws(StoreError) -> State.Detail? {
        try store.view(id).map { State.Detail(id: $0.id, title: $0.title) }
    }

    /// Everything the root holds between two events beside the list: the pane that is open. One value,
    /// moved by the cases of `send` and assembled into the model afterwards, which is how the list keeps
    /// its own.
    private struct State {
        var detail: Detail?

        /// The model the root view draws: the list's, as the list assembled it, and the pane.
        func model(with taskViewList: TaskViewList.Model) -> Model {
            Model(taskViewList: taskViewList, detail: detail.map { Model.Detail(title: $0.title) })
        }

        /// The pane that is open: the view it shows, which is what a change is matched against and what
        /// the pane is read again by, and the title the last read answered. The id stays here and out of
        /// `Model.Detail`, because nothing that draws the pane needs it (`docs/style.md`, "No API without a
        /// caller").
        struct Detail {
            let id: ViewID
            let title: String
        }
    }
}
