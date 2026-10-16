// Sources/Features/App/AppModule.swift
import FeatureModule
import TaskViewListFeature
import TodoCore

/// The root of the tree of modules, and the one module a host holds: the list of views, and the pane beside
/// it that shows the view chosen in the list (spec section 3).
///
/// The pane is a placeholder in M2, the title of the chosen view, standing where M3's list module will. It is
/// made from two things, the id the list answers with and the store: the id is the list's answer, to `.created`
/// at launch and to what a person does after that, and the title is a read of the root's own rather than the
/// row's, so that the module replacing it is created in the same place from the same two things (spec
/// section 4).
public final class AppModule: FeatureModule {
    /// What the root view draws: the list's model as the list assembled it, and the pane beside it.
    public struct Model: Equatable, Sendable {
        /// The pane beside the list: the chosen view's title, until M3's list module takes its place.
        public struct Detail: Equatable, Sendable {
            /// The view's title as the last read of it answered: whenever the list answered with the view,
            /// at launch or after, and whenever a change names it.
            public let title: String
        }

        /// The list's own model, which the root carries to the list's view whole and decides nothing in.
        public let taskViewList: TaskViewList.Model

        /// The pane beside the list, and nil when there is nothing to show in it: the view it would show is
        /// gone, or it could not be read while no pane was open, as at launch, when there is none to keep.
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

    /// What the root view draws, computed from the state on every read and never kept beside it, so that what
    /// the root holds is in one place and the model cannot disagree with it (owner's review of #101).
    public var model: Model { state.model }

    private let store: Store

    private var state: State

    /// Throws what the list's `init` throws, and nothing else: a store the list cannot read at launch is the
    /// composition root's to refuse (spec section 5). A store the list has just read whole is trusted this
    /// far, and the pane's first read is the same read of the same table, so one that fails leaves the root
    /// with no pane rather than refusing the launch: there is no open pane to keep, which is the rule a failed
    /// read follows after a click too (owner's review of #78).
    public init(store: Store) throws(StoreError) {
        // The route of the default window, which names no view, so that the list starts on its own first choice,
        // as it did before it had a route; the root is made from a route of its own in #92.
        let taskViewList = try TaskViewList(store: store, route: .init(selection: nil))
        self.store = store
        self.state = State(taskViewList: taskViewList, detail: nil)
        // The list is told it has been created and answers with the view it starts on, which is the list's
        // to choose. The answer goes through `react(to:)`, the line a click's answer goes through, so the
        // first pane opens the way every later one does and this module names no view of its own. A list
        // that starts on no row, as it does when a person deleted the Inbox, answers nothing and opens no
        // pane.
        react(to: state.taskViewList.send(.created))
    }

    /// Hands the event to the list and reacts to what the list answers.
    ///
    /// It answers nothing, since `Output` is `Never`, and it is `@discardableResult` because every caller
    /// drops an answer that is always nil (`docs/style.md`, "One shape everywhere it fits").
    @discardableResult
    public func send(_ event: Event) -> Never? {
        switch event {
        case .action(.taskViewList(let action)):
            react(to: state.taskViewList.send(.action(action)))
        case .changed(let changes):
            // Every child that takes the event gets it, and each decides for itself whether the change is
            // one it reads: the list keeps a person typing in a task out of the views table on its own.
            react(to: state.taskViewList.send(.changed(changes)))
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
        case .openInWindow?:
            // Nothing yet. A new window is the platform's to open, so the root passes the request on under its
            // own name (spec section 4), and it has no output to pass it through until #92 gives it
            // `.openWindow`; no view sends the menu item before #94.
            break
        case nil: break
        }
    }

    /// Opens the pane on the view `id` names, or closes it when the store has no such view: that view is
    /// gone, and a pane on it would be a pane on nothing. It is the one read of the pane, which every
    /// answer, the first one included, and every change that names the pane's view make.
    ///
    /// A read that fails leaves the pane as it was, id and title together: the root has no `problem` of its
    /// own in M2 to say it in, and a screen that could not be made leaves the one that was open, which is
    /// how this seat will behave in M3 too, when the list module that takes it is created by an `init` that
    /// throws. `try?` is not used here because it folds a failed read and a view that is gone into the same
    /// nil, and those two mean opposite things: keep the pane, and close it.
    private func readDetail(of id: ViewID) {
        do {
            state.detail = try store.view(id).map { State.Detail(id: $0.id, title: $0.title) }
        } catch {
            // Deliberately nothing, for the reason above.
        }
    }

    /// Everything the root holds between two events: the list's module, and the pane that is open. One
    /// value, moved by the cases of `send`, from which the model is computed on every read, as the list's is
    /// (owner's reviews of #77 and #101).
    ///
    /// The list is a field of the state and not a property beside it, because the tree of live modules is
    /// the navigation state (spec section 4): a screen's module is part of what the root holds, and the
    /// module M3 puts in the pane's seat joins the list here (owner's review of #78). The field holds the
    /// list by reference, since a module is a class (`FeatureModule`), and it is a `let` because nothing
    /// replaces the list in M2: the cases of `send` move the pane, and the list moves itself, through its
    /// own `send`.
    private struct State {
        let taskViewList: TaskViewList
        var detail: Detail?

        /// The model the root view draws: the list's, as the list assembled it, and the pane.
        var model: Model {
            Model(taskViewList: taskViewList.model, detail: detail.map { Model.Detail(title: $0.title) })
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
