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

            /// The text of the rename in progress on this row, and nil on every other row and whenever no
            /// field is open at all: a view puts a text field where this is not nil, draws the title
            /// everywhere else, and that is the whole of what it knows about renaming. It is what the
            /// person typed, down to the spaces at its ends; what the store keeps is that text trimmed
            /// (`commit`), since a caret is no place for the module to be moving text about.
            ///
            /// The draft is the module's, put on the row when the model is assembled and never kept in one.
            /// A read replaces every row, so a draft that lived in a row would be emptied by a peer's edit
            /// arriving while a person was typing — where a highlight that outlived its row must vanish,
            /// which is why the two are dropped by different rules (`reread`).
            public let draft: String?
        }

        public let rows: [Row]

        /// What went wrong, as the finished sentence the view shows until the next event, and nil when
        /// there is nothing to say: `send` cannot throw, so a failure inside it has nowhere else to go,
        /// and a view that had to spell one would be a view holding logic (spec section 2).
        public let problem: String?
    }

    /// What a view may send. Each case is named for the control and the gesture and never for the operation
    /// it triggers, so that what a gesture means is decided here: a second way to start a rename is another
    /// case beside these, not a view that works out what to ask for (ADR-0006).
    public enum UserAction: Equatable, Sendable {
        /// A row of the list, clicked or moved onto with the arrow keys.
        case rowSelected(ViewID)
        /// The row's Rename menu item.
        case renameMenuItemChosen(ViewID)
        /// The text of the open field, on every keystroke.
        case titleFieldChanged(String)
        /// Return in the open field.
        case titleFieldSubmitted
        /// Esc in the open field.
        case titleFieldCancelled
        /// The field lost focus, because the person went somewhere else on screen.
        case titleFieldLostFocus
        /// The toolbar button.
        case createFolderButtonTapped
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

    private var state: State

    /// Throws, because a store that cannot be read at launch is the composition root's to refuse: a list that
    /// came up empty would look like a database with nothing in it (spec section 5).
    public init(store: Store) throws(StoreError) {
        let state = State(rows: try TaskViewList.rows(of: store), selection: BuiltInTaskViews.inbox)
        self.store = store
        self.state = state
        self.model = state.model
    }

    public func send(_ event: Event) -> Output? {
        // Every path ends here. The cases below move the state field by field and say nothing about what is
        // on screen; the model is assembled from the state once, when they are done, so there is one place
        // that decides what a row looks like (owner's review of #77). A path that moved nothing assembles
        // the same model again, which is the same value.
        defer { model = state.model }
        switch event {
        case .action(.rowSelected(let id)):
            // Answered every time, the same id twice included: choosing the row that is already chosen is
            // still a choice, and what the root does with it — open the view, close a column behind it — is
            // the root's. The sentence goes with the event that produced it (spec, "The sidebar in M2"),
            // which is the rule every action the module acts on follows.
            //
            // An open field stays open where it is. Losing focus is an action of its own, and the view is
            // what knows whether the field lost it: a module that read a selection change as a focus change
            // would settle or drop a person's half-typed name on a gesture they need not have made. The
            // owner settled this in chat on 2026-09-22, and `.titleFieldLostFocus` is the other half of it.
            state.selection = id
            state.problem = nil
            return .selected(id)
        case .action(.renameMenuItemChosen(let id)):
            // The title comes off the row and not out of a read: the row is what the person chose the menu
            // item on, and a read here would open the field on a title nobody was looking at. A row that is
            // not there opens nothing, the way the field actions below do nothing without a field.
            guard let row = state.rows.first(where: { $0.id == id }) else { return nil }
            // One field at a time: the rename that was open is replaced, draft and all, which is what makes
            // the menu item on a second row move the field rather than open another one.
            state.rename = Rename(id: id, draft: row.title)
            state.problem = nil
            return nil
        case .action(.titleFieldChanged(let text)):
            // The four field actions are ignored when no field is open: what a gesture means is the
            // module's to know, and a view sending a keystroke cannot tell whether a rename exists. Ignored
            // to the letter, the sentence included — a field closing behind a refusal sends its cancellation
            // here, and clearing the sentence on it would take away what explains the closing.
            guard let rename = state.rename else { return nil }
            state.rename = Rename(id: rename.id, draft: text)
            state.problem = nil
            return nil
        case .action(.titleFieldSubmitted), .action(.titleFieldLostFocus):
            // Two gestures, one line: Return says "this is the name" and clicking away says it too, the way
            // the Finder settles a name that was typed and left. A module that told them apart would be
            // guessing at a difference the person did not make, and one draft ended two ways would mean two
            // things — an empty title included, which is refused here whichever gesture ended it.
            guard let rename = state.rename else { return nil }
            commit(rename)
            return nil
        case .action(.titleFieldCancelled):
            guard state.rename != nil else { return nil }
            // Esc leaves the title alone by leaving the store alone: the draft was never anywhere else.
            state.rename = nil
            state.problem = nil
            return nil
        case .action(.createFolderButtonTapped):
            return createFolder()
        case .changed(let changes):
            // Every edit to a task is a commit that touched no view, and this list is the same afterwards,
            // so the guard is what keeps a person typing in a list out of the views table. A commit that did
            // touch a view rereads the whole tree rather than the branch it names, because views number in
            // the tens and the tree order needs every row anyway (spec, "The sidebar in M2").
            guard !changes.views.isEmpty else { return nil }
            // The sentence stands unless the reread replaces it. It answered what a person did, and what
            // another device did is no answer to it: a sentence cleared by a peer's edit would go between
            // the person being told and reading it.
            reread()
            return nil
        }
    }

    /// Reads the tree again and keeps of this person's session whatever the new rows still hold.
    ///
    /// The selection goes silently when its row does: a highlight that outlived its row is one nobody can
    /// see and a detail pane nobody asked for, and a person whose highlight moved was not interrupted. A
    /// rename goes with a sentence, because a person typing a name was, and the sentence is the one a
    /// refused write gives for the same fact, since a peer's delete is that fact arriving by another route
    /// (owner's review of #77). Both are dropped here rather than left to be discovered by the next write.
    ///
    /// A read that fails keeps the rows on screen and says what happened, because `send` cannot throw
    /// (ADR-0006) and rows cleared by a failed read would take with them the only thing left to act on.
    private func reread() {
        do {
            let rows = try TaskViewList.rows(of: store)
            if let selection = state.selection, !rows.contains(where: { $0.id == selection }) {
                state.selection = nil
            }
            if let rename = state.rename, !rows.contains(where: { $0.id == rename.id }) {
                // The name comes off the rows as they still are: the ones being read in no longer hold the
                // view, and after the assignment below there is nothing left to call it. A row already gone
                // from those too cannot be named at all, and an invented name is worse than silence.
                if let title = state.rows.first(where: { $0.id == rename.id })?.title {
                    state.problem = Problem.viewIsGone(title: title).sentence
                }
                state.rename = nil
            }
            state.rows = rows
        } catch {
            state.problem = Problem.couldNotRead.sentence
        }
    }

    /// Writes the draft and closes the field, or refuses it and leaves the field where it is.
    ///
    /// The empty title is refused here and not by the store: what a person's word for a view has to be is
    /// this list's rule, and a core that had an opinion about it would hold the policy of its client
    /// (`docs/style.md`). The field stays open on the refusal, because the person is mid-word and the text
    /// they typed is the only place the name exists.
    private func commit(_ rename: Rename) {
        // Trimmed once, and the one value both the refusal and the write work off: a draft that is nothing
        // but whitespace trims to nothing, which is what empty means here, and no second rule has to agree
        // with this one. Nothing else in the state moves, which is what leaves the field open on the raw
        // text a person is still looking at.
        let title = TaskViewList.trimmed(rename.draft)
        guard !title.isEmpty else {
            state.problem = Problem.emptyTitle.sentence
            return
        }
        // The name a refusal would use, read before the write: the reread below drops the row, and by then
        // there is nothing left to call the view.
        let viewName = state.rows.first { $0.id == rename.id }?.title
        var problem: String?
        do {
            // One change and no other: two changes to one field in one call keep only the last (#40), and a
            // rename has nothing else to say. The trimmed title goes in: what the person typed is what the
            // field shows them, and what a view is called is what the store keeps — padding is neither.
            try store.update(view: rename.id, [.title(title)])
        } catch {
            problem = TaskViewList.problem(error, renaming: viewName).sentence
        }
        // The field closes either way. On the refusal the view it was open on is gone or unwritable, and a
        // field left open over it would invite the same person to type the same name again.
        //
        // Closing it before the reread is also what keeps one fact to one sentence: the reread finds no
        // rename to drop, so the sentence it would have given for a deleted row cannot land on top of this
        // one.
        state.rename = nil
        state.problem = problem
        reread()
    }

    /// The draft as the store keeps it: the same text with the whitespace at either end gone, and the
    /// whitespace between words untouched, because that is part of the name.
    ///
    /// The standard library trims a prefix and has no suffix to match it — probed, not remembered
    /// (`docs/style.md`) — so the tail is trimmed as the prefix of the reverse. Both passes are `while`
    /// loops over the characters and neither recurses: a run of spaces in a title that arrived from sync is
    /// as data-shaped as a chain of parents.
    private static func trimmed(_ draft: String) -> String {
        let head = draft.trimmingPrefix(while: \.isWhitespace)
        return String(head.reversed().trimmingPrefix(while: \.isWhitespace).reversed())
    }

    /// The sentence a refused write reads as.
    ///
    /// `.notFound` is the one refusal this list can put in a person's words: the view the field was open on
    /// is gone, which is what a peer deleting it mid-rename looks like from here. Everything else is SQLite
    /// saying something about a file, and calling that "the view is gone" would put a sentence on screen
    /// that is not true. A `.notFound` with no title to give is the general sentence for the same reason:
    /// the specific one would have to invent the name it names.
    private static func problem(_ error: StoreError, renaming title: String?) -> Problem {
        switch (error, title) {
        case (.notFound, .some(let title)): .viewIsGone(title: title)
        default: .couldNotSave
        }
    }

    /// A folder at the end of the root level, chosen and with its field open, so that a person names it
    /// straight away instead of hunting for the row the button just made (spec, "The sidebar in M2").
    ///
    /// The write goes first and the rows come back out of the store: the id, the rank and the place in the
    /// tree are the store's to decide, and a row put together here would be this module's guess at them.
    private func createFolder() -> Output? {
        do {
            let id = try store.createView(NewTaskView(title: TaskViewList.newFolderTitle))
            state.selection = id
            state.rename = Rename(id: id, draft: TaskViewList.newFolderTitle)
            state.problem = nil
            reread()
            // The selection moved without anybody choosing a row. The root does not read this model
            // (ADR-0006), so it is told the same thing a click would have told it, or its detail pane keeps
            // the view from before the button.
            return .selected(id)
        } catch {
            // The rows stand: nothing was written, so there is nothing to reread and nothing has moved.
            state.problem = Problem.couldNotSave.sentence
            return nil
        }
    }

    /// The tree as one read produced it. `views()` answers parents before children with the effective parent
    /// already resolved, so a row's depth is its parent's plus one and the depths the walk has passed are all
    /// it carries: one pass, no stack, and a chain a thousand deep from sync reads like a flat list
    /// (`docs/style.md`, "No recursion over data-shaped depth"). A parent the walk has not passed reads as
    /// no parent, the way the core resolves a link it cannot use, rather than as a row left out of the list.
    private static func rows(of store: Store) throws(StoreError) -> [ReadRow] {
        var depths: [ViewID: Int] = [:]
        return try store.views().map { view in
            let depth = view.parent.flatMap { depths[$0] }.map { $0 + 1 } ?? 0
            depths[view.id] = depth
            return ReadRow(id: view.id, title: view.title, depth: depth)
        }
    }

    /// The name a new folder is born with. A constant because the row a person reads and the draft in the
    /// field are one word and two copies of it would drift apart. It is English here: a string a person
    /// reads is the formatting service's to localise, which arrives with M3, and the owner has settled that
    /// it stays English until then.
    private static let newFolderTitle = "New folder"

    /// Everything this module holds between two events: the rows as the last read produced them, the row a
    /// person chose, the rename they have open, and the sentence they were last told. One entity, moved
    /// field by field, with the model assembled from it afterwards, so that nothing on screen is state in
    /// its own right and there is no second copy to keep in step (owner's review of #77).
    ///
    /// A struct and not a class: a field of a struct held in a `var` property is mutated in place and the
    /// array inside it is copy-on-write, so a class buys nothing here and would put a second reference type
    /// into a module that is already one.
    private struct State {
        var rows: [ReadRow]
        var selection: ViewID?
        var rename: Rename? = nil
        var problem: String? = nil

        /// The model a view draws: the rows with this person's session projected onto them — the highlight
        /// on the row they chose, the draft on the row they are renaming — and the sentence, if any.
        var model: Model {
            Model(
                rows: rows.map {
                    Model.Row(
                        id: $0.id, title: $0.title, depth: $0.depth,
                        isSelected: $0.id == selection, draft: rename?.text(on: $0.id)
                    )
                },
                problem: problem
            )
        }
    }

    /// One row of the list as a read of the store produced it, before anything about this person's session
    /// is projected onto it. It is what the store answered and nothing else, which is what lets the same
    /// read serve a highlight that moves and a field that opens without being read again.
    private struct ReadRow {
        let id: ViewID
        let title: String
        let depth: Int
    }

    /// The rename a person has open: the row the field is on, and the text in it.
    private struct Rename {
        let id: ViewID
        let draft: String

        /// The draft as a row carries it, which is the projection `Model.Row.draft` is documented as.
        func text(on row: ViewID) -> String? { row == id ? draft : nil }
    }

    /// What can go wrong in this module, with the sentence each one reads as. The store's own error stays
    /// here: it names SQLite codes and journal rows, which is what a bug report is made of and not what a
    /// person can do anything about, and spelling it in the model would put that text on a screen.
    private enum Problem {
        case couldNotRead
        case emptyTitle
        case viewIsGone(title: String)
        case couldNotSave

        var sentence: String {
            switch self {
            case .couldNotRead: "The views could not be read, so this list may be out of date."
            case .emptyTitle: "A title cannot be empty."
            case .viewIsGone(let title): "“\(title)” is no longer there, so the new name was not saved."
            case .couldNotSave: "The change could not be saved, so nothing was written."
            }
        }
    }
}
