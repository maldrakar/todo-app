// Sources/Features/TaskViewList/TaskViewList.swift
import FeatureModule
import TodoCore

/// The views a person keeps, flattened out of the store's tree into the list they are chosen from.
///
/// Named for what it holds and not for where it is put: the same list is a sidebar beside a Mac window and a
/// screen of its own on a phone, and a module that knew which one it was would be two modules.
///
/// The rows are flat and carry a depth instead of holding their children: a view drawing them indents by a
/// number and decides nothing, and the walk that builds them never recurses over a chain that arrived from
/// sync (`docs/style.md`).
public final class TaskViewList: FeatureModule {
    public struct Model: Equatable, Sendable {
        public struct Row: Equatable, Sendable {
            public let id: ViewID
            public let title: String
            public let depth: Int
            public let isSelected: Bool
        }

        public let rows: [Row]

        /// What went wrong, as the finished sentence the view shows until the next event, and nil when
        /// there is nothing to say: `send` cannot throw, so a failure inside it has nowhere else to go,
        /// and a view that had to spell one would be a view holding logic (spec section 2).
        public let problem: String?
    }

    public enum UserAction: Equatable, Sendable {
        case rowSelected(ViewID)
    }

    public enum Event: FeatureEvent {
        case action(UserAction)
        case changed(ChangeSet)
    }

    public enum Output: Equatable, Sendable {
        case selected(ViewID)
    }

    public private(set) var model: Model

    private let store: Store

    /// Throws, because a store that cannot be read at launch is the composition root's to refuse: a list that
    /// came up empty would look like a database with nothing in it (spec section 5).
    public init(store: Store) throws(StoreError) {
        self.store = store
        self.model = Model(rows: try TaskViewList.rows(of: store, selecting: BuiltInTaskViews.inbox), problem: nil)
    }

    public func send(_ event: Event) -> Output? {
        switch event {
        case .action(.rowSelected(let id)):
            // Answered every time, the same id twice included: choosing the row that is already chosen is
            // still a choice, and what the root does with it — open the view, close a column behind it — is
            // the root's. The problem goes with the event that produced it (spec, "The sidebar in M2").
            model = Model(rows: TaskViewList.rows(model.rows, selecting: id), problem: nil)
            return .selected(id)
        case .changed(let changes):
            // Every edit to a task is a commit that touched no view, and this list is the same afterwards,
            // so the guard is what keeps a person typing in a list out of the views table. A commit that did
            // touch a view rereads the whole tree rather than the branch it names, because views number in
            // the tens and the tree order needs every row anyway (spec, "The sidebar in M2").
            guard !changes.views.isEmpty else { return nil }
            reread()
            return nil
        }
    }

    /// Rebuilds the rows, keeping the highlight where the person put it unless the view it names is gone: a
    /// selection that outlived its row is a highlight nobody can see and a detail pane nobody asked for.
    ///
    /// A read that fails keeps the rows on screen and says what happened, because `send` cannot throw
    /// (ADR-0006) and rows cleared by a failed read would take with them the only thing left to act on.
    private func reread() {
        do {
            model = Model(rows: try TaskViewList.rows(of: store, selecting: selection), problem: nil)
        } catch {
            model = Model(rows: model.rows, problem: Problem.couldNotRead.sentence)
        }
    }

    /// The chosen view, read back out of the rows. The model is the whole state of the selection: a copy
    /// beside it could name a view the rows no longer hold.
    private var selection: ViewID? { model.rows.first(where: \.isSelected)?.id }

    /// The tree as rows. `views()` answers parents before children with the effective parent already
    /// resolved, so a row's depth is its parent's plus one and the depths the walk has passed are all it
    /// carries: one pass, no stack, and a chain a thousand deep from sync reads like a flat list
    /// (`docs/style.md`, "No recursion over data-shaped depth"). A parent the walk has not passed reads as
    /// no parent, the way the core resolves a link it cannot use, rather than as a row left out of the list.
    private static func rows(of store: Store, selecting selection: ViewID?) throws(StoreError) -> [Model.Row] {
        var depths: [ViewID: Int] = [:]
        return try store.views().map { view in
            let depth = view.parent.flatMap { depths[$0] }.map { $0 + 1 } ?? 0
            depths[view.id] = depth
            return Model.Row(id: view.id, title: view.title, depth: depth, isSelected: view.id == selection)
        }
    }

    /// The same rows with the highlight on another one. Choosing a row changes nothing in the store, so it
    /// costs no read: a reread would answer with the tree the rows already are.
    private static func rows(_ rows: [Model.Row], selecting selection: ViewID) -> [Model.Row] {
        rows.map { Model.Row(id: $0.id, title: $0.title, depth: $0.depth, isSelected: $0.id == selection) }
    }

    /// What can go wrong in this module, with the sentence each one reads as. The store's own error stays
    /// here: it names SQLite codes and journal rows, which is what a bug report is made of and not what a
    /// person can do anything about, and spelling it in the model would put that text on a screen.
    private enum Problem {
        case couldNotRead

        var sentence: String {
            switch self {
            case .couldNotRead: "The views could not be read, so this list is the last one that could be."
            }
        }
    }
}
