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
            /// everywhere else, and that is the whole of what it knows about renaming.
            ///
            /// The draft itself is state of the module, projected here rather than kept here. A reread
            /// rebuilds every row out of the store, so a draft that lived in a row would be emptied by a
            /// peer's edit arriving while a person was typing. The selection is deliberately the other way
            /// round — read back out of the rows — and the asymmetry is the point: a highlight that
            /// outlived its row must vanish, a draft a person is typing must not.
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

    /// The rename a person has open, and nil when no field is on screen.
    private var rename: Rename?

    /// Throws, because a store that cannot be read at launch is the composition root's to refuse: a list that
    /// came up empty would look like a database with nothing in it (spec section 5).
    public init(store: Store) throws(StoreError) {
        self.store = store
        self.model = Model(
            rows: try TaskViewList.rows(of: store, selecting: BuiltInTaskViews.inbox, renaming: nil), problem: nil
        )
    }

    public func send(_ event: Event) -> Output? {
        switch event {
        case .action(.rowSelected(let id)):
            // Answered every time, the same id twice included: choosing the row that is already chosen is
            // still a choice, and what the root does with it — open the view, close a column behind it — is
            // the root's. The problem goes with the event that produced it (spec, "The sidebar in M2").
            //
            // An open field stays open where it is. Losing focus is an action of its own, and the view is
            // what knows whether the field lost it: a module that read a selection change as a focus change
            // would settle or drop a person's half-typed name on a gesture they need not have made. The
            // owner settled this in chat on 2026-09-22, and `.titleFieldLostFocus` is the other half of it.
            model = Model(rows: TaskViewList.rows(model.rows, selecting: id, renaming: rename), problem: nil)
            return .selected(id)
        case .action(.renameMenuItemChosen(let id)):
            // The title comes off the row and not out of a read: the row is what the person chose the menu
            // item on, and a read here would open the field on a title nobody was looking at. A row that is
            // not there opens nothing, the way the field actions below do nothing without a field.
            guard let row = model.rows.first(where: { $0.id == id }) else { return nil }
            rename = Rename(id: id, draft: row.title)
            showRename()
            return nil
        case .action(.titleFieldChanged(let text)):
            // The four field actions are ignored when no field is open: what a gesture means is the
            // module's to know, and a view sending a keystroke cannot tell whether a rename exists. Ignored
            // to the letter, the model included — a field closing behind a refusal sends its cancellation
            // here, and clearing the problem on it would take away the sentence that explains the closing.
            guard let rename else { return nil }
            self.rename = Rename(id: rename.id, draft: text)
            showRename()
            return nil
        case .action(.titleFieldSubmitted), .action(.titleFieldLostFocus):
            // Two gestures, one line: Return says "this is the name" and clicking away says it too, the way
            // the Finder settles a name that was typed and left. A module that told them apart would be
            // guessing at a difference the person did not make, and one draft ended two ways would mean two
            // things — an empty title included, which is refused here whichever gesture ended it.
            guard let rename else { return nil }
            commit(rename)
            return nil
        case .action(.titleFieldCancelled):
            guard rename != nil else { return nil }
            // Esc leaves the title alone by leaving the store alone: the draft was never anywhere else.
            rename = nil
            showRename()
            return nil
        case .action(.createFolderButtonTapped):
            return createFolder()
        case .changed(let changes):
            // Every edit to a task is a commit that touched no view, and this list is the same afterwards,
            // so the guard is what keeps a person typing in a list out of the views table. A commit that did
            // touch a view rereads the whole tree rather than the branch it names, because views number in
            // the tens and the tree order needs every row anyway (spec, "The sidebar in M2").
            guard !changes.views.isEmpty else { return nil }
            // The sentence stands. It answered what a person did, and what another device did is no answer
            // to it: a problem cleared by a peer's edit would vanish between reading it and acting on it.
            reread(selecting: selection, problem: model.problem)
            return nil
        }
    }

    /// Rebuilds the rows, keeping the highlight where the person put it unless the view it names is gone: a
    /// selection that outlived its row is a highlight nobody can see and a detail pane nobody asked for.
    ///
    /// A read that fails keeps the rows on screen and says what happened, because `send` cannot throw
    /// (ADR-0006) and rows cleared by a failed read would take with them the only thing left to act on.
    /// The problem is the caller's to give: nil where the action answers for itself, the sentence a refused
    /// write produced, or the one already on screen after a `.changed`, which answered nobody.
    private func reread(selecting selection: ViewID?, problem: String?) {
        do {
            let rows = try TaskViewList.rows(of: store, selecting: selection, renaming: rename)
            // A rename whose row is gone ends here, the way the selection does: the field has nothing left
            // to be drawn on, and a draft kept behind the rows would write a name to a view a person can no
            // longer see. Ending it is the read's to do: nothing the person did here says it is over.
            if let rename, !rows.contains(where: { $0.id == rename.id }) { self.rename = nil }
            model = Model(rows: rows, problem: problem)
        } catch {
            model = Model(rows: model.rows, problem: Problem.couldNotRead.sentence)
        }
    }

    /// Writes the draft and closes the field, or refuses it and leaves the field where it is.
    ///
    /// The empty title is refused here and not by the store: what a person's word for a view has to be is
    /// this list's rule, and a core that had an opinion about it would hold the policy of its client
    /// (`docs/style.md`). The field stays open on the refusal, because the person is mid-word and the text
    /// they typed is the only place the name exists.
    private func commit(_ rename: Rename) {
        // "Empty after trimming", asked directly: `allSatisfy` is true of "" as well, and it answers the
        // question without building a trimmed string that would be measured and thrown away. The standard
        // library could trim — `trimmingPrefix(while:)` compiles at this package's deployment floor, probed
        // rather than remembered (`docs/style.md`) — so this is the shorter way and not the only one. The
        // rows are the ones already on screen, the draft on them included, which is what leaves the field
        // open.
        guard !rename.draft.allSatisfy(\.isWhitespace) else {
            model = Model(rows: model.rows, problem: Problem.emptyTitle.sentence)
            return
        }
        // The name the refusal below would use, read before the write: the row it names is gone from the
        // reread that follows, and by then there is nothing left to call the view.
        let title = model.rows.first { $0.id == rename.id }?.title
        var problem: String?
        do {
            // One change and no other: two changes to one field in one call keep only the last (#40), and a
            // rename has nothing else to say. The raw draft goes in, spaces at the ends included: they are
            // what the person typed, and a title is their word for the view.
            try store.update(view: rename.id, [.title(rename.draft)])
        } catch {
            problem = TaskViewList.problem(error, renaming: title).sentence
        }
        // The field closes either way. On the refusal the view it was open on is gone or unwritable, and a
        // field left open over it would invite the same person to type the same name again.
        self.rename = nil
        reread(selecting: selection, problem: problem)
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
            rename = Rename(id: id, draft: TaskViewList.newFolderTitle)
            reread(selecting: id, problem: nil)
            // The selection moved without anybody choosing a row. The root does not read this model
            // (ADR-0006), so it is told the same thing a click would have told it, or its detail pane keeps
            // the view from before the button.
            return .selected(id)
        } catch {
            // The rows stand: nothing was written, so there is nothing to reread and nothing has moved.
            model = Model(rows: model.rows, problem: Problem.couldNotSave.sentence)
            return nil
        }
    }

    /// The model rebuilt around the rename as it now stands, without a read: what a person typed changes
    /// where the field is and what is in it and nothing else in the list, so a keystroke that queried SQLite
    /// would be a keystroke waiting on a disk.
    private func showRename() {
        model = Model(rows: TaskViewList.rows(model.rows, selecting: selection, renaming: rename), problem: nil)
    }

    /// The chosen view, read back out of the rows. The model is the whole state of the selection: a copy
    /// beside it could name a view the rows no longer hold.
    private var selection: ViewID? { model.rows.first(where: \.isSelected)?.id }

    /// The tree as rows. `views()` answers parents before children with the effective parent already
    /// resolved, so a row's depth is its parent's plus one and the depths the walk has passed are all it
    /// carries: one pass, no stack, and a chain a thousand deep from sync reads like a flat list
    /// (`docs/style.md`, "No recursion over data-shaped depth"). A parent the walk has not passed reads as
    /// no parent, the way the core resolves a link it cannot use, rather than as a row left out of the list.
    private static func rows(
        of store: Store, selecting selection: ViewID?, renaming rename: Rename?
    ) throws(StoreError) -> [Model.Row] {
        var depths: [ViewID: Int] = [:]
        return try store.views().map { view in
            let depth = view.parent.flatMap { depths[$0] }.map { $0 + 1 } ?? 0
            depths[view.id] = depth
            return Model.Row(
                id: view.id, title: view.title, depth: depth, isSelected: view.id == selection,
                draft: rename?.text(on: view.id)
            )
        }
    }

    /// The same rows with the highlight on one of them and the field where the rename now is. Neither costs
    /// a read: choosing a row and typing in a field change nothing in the store, so a reread would answer
    /// with the tree the rows already are, once per keystroke.
    private static func rows(
        _ rows: [Model.Row], selecting selection: ViewID?, renaming rename: Rename?
    ) -> [Model.Row] {
        rows.map {
            Model.Row(
                id: $0.id, title: $0.title, depth: $0.depth, isSelected: $0.id == selection,
                draft: rename?.text(on: $0.id)
            )
        }
    }

    /// The name a new folder is born with. A constant because the row a person reads and the draft in the
    /// field are one word and two copies of it would drift apart. It is English here: a string a person
    /// reads is the formatting service's to localise, which arrives with M3, and the question is raised in
    /// chat rather than answered in this module.
    private static let newFolderTitle = "New folder"

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
