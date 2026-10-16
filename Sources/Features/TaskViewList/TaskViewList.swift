// Sources/Features/TaskViewList/TaskViewList.swift
import FeatureModule
import TaskListFeature
import TodoCore

/// The views a person keeps, flattened out of the store's tree into the list they are chosen from, and the list
/// of the chosen view's tasks, which that choice opens.
///
/// Named for what it holds and not for where it is put: the same list is a sidebar beside a Mac window and a
/// screen of its own on a phone, and a module that knew which one it was would be two modules.
///
/// The rows are flat and carry a depth instead of holding their children: a view drawing them indents by a
/// number and decides nothing, and the walk that builds them never recurses over a chain that arrived from
/// sync (`docs/style.md`).
///
/// It is the task list's parent. A choice here opens the list of that view's tasks, so the list is this module's
/// child, held in a seat of its own, by the rule that every screen is a child of the screen that opened it
/// (ADR-0009), drawn on a phone as the screen pushed after this one and on the Mac as the pane beside it. The root
/// never learns that a choice opens a list.
///
/// It is a routable module, one that can be opened (spec section 4): its route has no head, because a window
/// has one list of views, and its tail is the route of the list open in it, so that a link to a view opens its
/// list here, highlighted, and the route a window writes down names the view and the task open in its list.
public final class TaskViewList: Routable {
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
            /// arriving while a person was typing. What ends it is its row going, which `reread` decides
            /// for the draft and for the highlight alike.
            public let draft: String?
        }

        public let rows: [Row]

        /// The id of the highlighted row, and nil when no row is highlighted: what a list that keeps its
        /// selection as one value is bound to, as the Mac's `List(selection:)` is, so that the binding reads a
        /// field the way a text field's reads `draft`, instead of searching the rows for one (spec section 4).
        ///
        /// It is the highlight `Row.isSelected` carries, held a second way because it is read a second way: a
        /// list bound to one value reads this, and a client that draws row by row reads the row. Both come
        /// off the same drawn rows when the model is assembled, so they name the same row or none.
        public let selection: ViewID?

        /// The open list's own model, which this module carries to the list's view whole and decides nothing
        /// in, and nil when no list is open: when the module was made on a view that is gone, and after the view
        /// the list was on is gone.
        public let taskList: TaskList.Model?

        /// What went wrong, as the finished sentence the view shows, and nil when there is nothing to say:
        /// `send` cannot throw, so a failure inside it has nowhere else to go, and a view that had to spell one
        /// would be a view holding logic (spec section 2). A list that could not be opened is said here, where
        /// the list that stays open is drawn beside it; what the list says about itself is in its own model.
        public let problem: String?
    }

    /// The address of the module in its window: no head, and the route of the list open in it as the tail (spec
    /// section 4).
    public struct Route: RouteValue {
        /// The same for every one, which is what keeps the one a window holds alive on every route it is
        /// handed: it is never made again by a link, so a name half typed in it survives one.
        public var head: NoHead { NoHead() }

        /// The list open beside the views, whose head is the view it lists, so that the highlight and the list
        /// cannot name two views in a route. Nil says nothing of the list, which then follows the highlight: at
        /// creation it opens on the Inbox, and on a live module the list stays as it is (owner, 2026-10-16).
        public let list: TaskList.Route?

        public init(list: TaskList.Route?) {
            self.list = list
        }

        /// Reads the list from a window's path, owning no segment of its own: it hands the path whole to the
        /// list's route, which reads it to the end or refuses it, and an empty path names no list.
        package init(reading path: inout ArraySlice<String>) throws(RouteError) {
            let list: TaskList.Route? = if path.isEmpty { nil } else { try TaskList.Route(reading: &path) }
            self.init(list: list)
        }

        /// This route's part of a window's path, which is its list's, and nothing when it names no list.
        package var segments: [String] { list?.segments ?? [] }
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
        /// The row's Open in New Window menu item, on the Mac and the iPad.
        case openInNewWindowMenuItemChosen(ViewID)
        /// An action of the open list, handed to it as it came. With no list open it moves nothing, and it never
        /// touches this module's sentence: a sentence goes with this module's own gestures and a route, and a
        /// gesture in the list is the list's, as a gesture on the task screen leaves the list's own sentence.
        case taskList(TaskList.UserAction)
    }

    public enum Event: RoutedEvent {
        case action(UserAction)
        case changed(ChangeSet)

        /// The parent has just created this module: sent once, by the module that holds it, right after
        /// `init`. It is not the creation of a folder, which is `createFolderButtonTapped` and a write; it is
        /// this module's own creation, and it writes nothing. It is an event of the world and not a
        /// `UserAction`, because nobody did anything and a view has no way to send it (spec section 2).
        ///
        /// It is answered with nothing and moves nothing, the sentence included: the module was made from a
        /// route its parent chose and already knows, and it opened the list of the view it starts on in its
        /// `init`, as the task list opens its task screen in its own.
        case created

        /// A route applied to the live module, by a link or by the root reconciling its window: an event of the
        /// world, like `.changed`, that no view can send (ADR-0006, amendment of 2026-10-14). The head never
        /// differs, so it is the tail alone that the module reads.
        case route(Route)
    }

    public enum Output: Equatable, Sendable {
        /// A view a person asked to see in a window of its own, which only the platform can open: the module
        /// asks with its own route on that view, and its parent passes the request on under its own name (spec
        /// section 4, the rule of bubbling), so the root never spells the route of the list below it.
        case openInWindow(Route)
    }

    /// What a view draws, computed from the state on every read and never kept beside it, so that what the
    /// list holds is in one place and the model cannot disagree with it (owner's review of #101).
    public var model: Model { state.model }

    /// The route of the module, assembled from its seat and never kept beside it (spec section 4): the route of
    /// the list open in it, which names the view that list is on and the task open in it, so that what a window
    /// writes down is what is open, and a highlight with no list behind it is written as nothing.
    public var route: Route { Route(list: state.taskList.route) }

    private let store: Store

    private var state: State

    /// Made from its route, the one way it is made (spec section 3): it starts on the view the route's list
    /// names, or on the Inbox when the route names none, and opens the list in its seat, here, the way the task
    /// list opens its task screen in its own `init`: on the route's list when the route names one, with the task
    /// in it, and otherwise on the view it starts on.
    ///
    /// That start is highlighted only when a row holds it, whichever its source, because a highlight kept anyway
    /// would light up the moment a peer's change brought the row in — a link to a view not yet synced here —
    /// beside a list that was never opened on it. It is the invariant `createFolder` holds for the same reason:
    /// what this module puts on a row of its own accord goes onto a row the list holds. A list the route names is
    /// opened whether or not a row holds its view, and one that cannot be made, its view gone or not yet synced,
    /// is said in `problem`; the Inbox this module falls back on is opened only when a row holds it, so a person
    /// who deleted it is told nothing, having asked for nothing.
    ///
    /// Throws, because a store that cannot be read at launch is the composition root's to refuse: a list that
    /// came up empty would look like a database with nothing in it (spec section 5). Only this module's own read
    /// throws: a list that cannot be made leaves the seat empty and says so in `problem`.
    public init(store: Store, route: Route) throws(StoreError) {
        let rows = try TaskViewList.rows(of: store)
        let start = route.list?.head ?? BuiltInTaskViews.inbox
        // The seat is built once, here, with the way to make the list: a closure over the list's own `init` that
        // captures the store and never this module. The module holds the seat in its state, so a closure
        // holding the module would close a cycle, module to state to seat to closure to module, and none of them
        // would ever be released (`Seat.init`). Its error is named, so that the seat's type below is checked
        // against it rather than widened to `any Error`.
        let taskList = Seat<TaskList, StoreError> { route throws(StoreError) in
            try TaskList(store: store, route: route)
        }
        self.store = store
        let selection = rows.contains(where: { $0.id == start }) ? start : nil
        self.state = State(rows: rows, selection: selection, taskList: taskList)
        if let list = route.list ?? state.selection.map({ TaskList.Route(head: $0) }) { apply(list: list) }
    }

    public func send(_ event: Event) -> Output? {
        // The cases below move the state field by field and say nothing about what is on screen: the model is
        // computed from the state, so there is one place that decides what a row looks like (owner's reviews
        // of #77 and #101).
        switch event {
        case .action(.rowSelected(let id)):
            // The list's route on the view, applied every time, the highlighted row's own included: choosing the
            // row that is already chosen is still a choice. On the view the list is on, the seat keeps the list
            // and the route's empty tail closes the task open in it, so a click on the highlighted view returns
            // to its list, as System Settings does on the Mac and a second tap on a tab does on iOS (owner,
            // 2026-10-16); on another view the seat makes a new list.
            //
            // The sentence goes with the event that produced it (spec, "The sidebar in M2"), except while a
            // field is open: then the sentence on screen is what explains the field, and this gesture leaves
            // the field where it is. A click on another row while the field holds an empty name loses the
            // field's focus first, so the refusal that sets the sentence arrives before this; cleared here, it
            // would leave an empty field with the caret in it and nothing saying why. The owner chose this in
            // chat on 2026-10-12.
            //
            // An open field stays open where it is. Losing focus is an action of its own, and the view is
            // what knows whether the field lost it: a module that read a selection change as a focus change
            // would settle or drop a person's half-typed name on a gesture they need not have made. The
            // owner settled this in chat on 2026-09-22, and `.titleFieldLostFocus` is the other half of it.
            //
            // The sentence goes before the list is applied, so that a list the click cannot open writes a fresh
            // one: it answers this click, and the one it replaces answered something earlier.
            state.selection = id
            if state.rename == nil { state.problem = nil }
            apply(list: TaskList.Route(head: id))
            return nil
        case .action(.renameMenuItemChosen(let id)):
            // The title comes off the row and not out of a read: the row is what the person chose the menu
            // item on, and a read here would open the field on a title nobody was looking at. A row that is
            // not there opens nothing, the way the field actions below do nothing without a field.
            guard let row = state.rows.first(where: { $0.id == id }) else { return nil }
            // One field at a time: the rename that was open is replaced, draft and all, which is what makes
            // the menu item on a second row move the field rather than open another one.
            state.rename = State.Rename(id: id, draft: row.title)
            state.problem = nil
            return nil
        case .action(.titleFieldChanged(let text)):
            // The four field actions are ignored when no field is open: what a gesture means is the
            // module's to know, and a view sending a keystroke cannot tell whether a rename exists. Ignored
            // to the letter, the sentence included: a field's echo of its text and its lost focus can arrive
            // after the module has closed the field, and a sentence cleared by them would go before the person
            // had read it.
            //
            // A text that is already the draft is ignored the same way, sentence included, because it is no
            // keystroke: on 2026-10-12, by hand, a `TextField` wrote the text it holds back through its binding
            // twice for every keystroke, and again after Return and after a lost focus. Taken for typing, the
            // report after a refused Return would clear the sentence the refusal had just set, and "A title
            // cannot be empty." would never stay on screen.
            guard let rename = state.rename, text != rename.draft else { return nil }
            state.rename = State.Rename(id: rename.id, draft: text)
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
            createFolder()
            return nil
        case .action(.openInNewWindowMenuItemChosen(let id)):
            // Asked of the parent, because a window is the platform's to open and what it opens is the root's
            // to decide (spec section 4, the rule of bubbling). It asks with this module's own route on the view,
            // the list on it, so that the root passes it on without spelling the list's route. Nothing here
            // moves, the highlight, an open field and its sentence included: the person did nothing to this
            // module, and the window that opens beside it answers nothing they were told. A row that is not
            // there asks for nothing, the way the Rename menu item on one opens no field.
            guard state.rows.contains(where: { $0.id == id }) else { return nil }
            return .openInWindow(Route(list: TaskList.Route(head: id)))
        case .action(.taskList(let action)):
            // Handed on as it came, and with no list open the empty seat answers nothing, which is where the
            // platform's write through a binding lands after a close the model drove, and nothing moves. The
            // sentence stays: a gesture in the list is the list's, and this module's sentence goes with its own
            // gestures and a route.
            react(to: state.taskList.send(.action(action)))
            return nil
        case .created:
            // Nothing moves, the sentence included, because being created answers nothing a person was told,
            // and nothing is answered: `init` opened the list already.
            return nil
        case .route(let route):
            // The route's choice and not a person's, and its parent already knows it, so it is answered with
            // nothing (spec section 3, the third flow). The sentence goes at its start, so that a list the route
            // cannot open writes a fresh one, except while a field is open, whose sentence explains it and which
            // the route leaves where it is, as a click does (owner, 2026-10-16). A route carries no session state
            // and keeps what did not change (spec sections 2 and 3): it moves the highlight onto its list's view
            // when a row holds it, a link to a view that is gone leaving the highlight where it is, and applies
            // its list to the seat, which keeps the list on the same view and replaces it on another. A route that
            // names no list leaves the highlight and the list alone, because the default window chooses the Inbox
            // itself, at creation and never again (owner, 2026-10-16).
            if state.rename == nil { state.problem = nil }
            guard let list = route.list else { return nil }
            if state.rows.contains(where: { $0.id == list.head }) { state.selection = list.head }
            apply(list: list)
            return nil
        case .changed(let changes):
            // Every edit to a task is a commit that touched no view, and the rows are the same afterwards, so
            // the condition is what keeps a person typing in a list out of the views table. A commit that did
            // touch a view rereads the whole tree rather than the branch it names, because views number in
            // the tens and the tree order needs every row anyway (spec, "The sidebar in M2").
            if !changes.views.isEmpty {
                // The sentence stands unless the reread replaces it. It answered what a person did, and what
                // another device did is no answer to it: a sentence cleared by a peer's edit would go between
                // the person being told and reading it.
                do {
                    try reread()
                } catch {
                    // Only when there is nothing on screen already. A `.changed` neither clears a sentence nor
                    // replaces one, because it answers for nobody: the field can be open with a refusal on it
                    // when a peer's edit arrives, and "the list may be out of date" would take the place of
                    // what the person was actually told.
                    if state.problem == nil { state.problem = Problem.couldNotRead.sentence }
                }
            }
            // The open list gets the change whatever the rows did, since what it shows is its view's tasks and
            // only it reads them, and a list whose view is gone asks to be closed. Nothing is written in answer
            // (spec section 5).
            react(to: state.taskList.send(.changed(changes)))
            return nil
        }
    }

    /// Applies a route to the list's seat, the one road to it: the seat keeps the list on the same view and
    /// hands it the route, which opens, keeps or closes the task in it, and makes a new list on another view
    /// (spec section 3). A list that cannot be made, its view gone or its tasks unread, leaves the one that was
    /// open, since the seat makes the new one before it lets the old one go, and this module says so (spec
    /// section 3). What the seat hands back goes through `react(to:)`, the line every answer of the list takes.
    private func apply(list route: TaskList.Route) {
        do {
            react(to: try state.taskList.apply(route))
        } catch {
            state.problem = Problem.couldNotOpenList.sentence
        }
    }

    /// What the open list asked for, whichever event drew it out: to be closed, because its view is gone, and this
    /// module drops it with the task open in it (spec section 3). One path for every answer, with no `default`, so
    /// that an answer the list learns to give stops this file compiling until this module has decided what it
    /// means (spec section 4).
    private func react(to output: TaskList.Output?) {
        switch output {
        case .closeRequested?: state.taskList.drop()
        case nil: break
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
    /// The rows on screen are never cleared by a read that failed, because they are assigned last and a
    /// throw leaves them where they were: `send` cannot throw (ADR-0006), and a list emptied by a failed
    /// read would take with it the only thing left to act on.
    ///
    /// What a failed read means is the caller's to say, which is why this throws instead of writing a
    /// sentence of its own. It means three different things: after a `.changed` nothing else is in flight,
    /// after a refused write there is already something more specific to say, and after a folder was
    /// written it means the folder cannot be shown yet — and a reread that swallowed the error had to pick
    /// one of the three for all of them, which is what left the corner this closes (owner's review of #77,
    /// 2026-09-24).
    private func reread() throws(StoreError) {
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
    }

    /// Writes the draft and closes the field, or refuses it and leaves the field where it is.
    ///
    /// The empty title is refused here and not by the store: what a person's word for a view has to be is
    /// this list's rule, and a core that had an opinion about it would hold the policy of its client
    /// (`docs/style.md`). The field stays open on the refusal, because the person is mid-word and the text
    /// they typed is the only place the name exists.
    private func commit(_ rename: State.Rename) {
        // Trimmed once, and the one value both the refusal and the write work off: a draft that is nothing
        // but whitespace trims to nothing, which is what empty means here, and no second rule has to agree
        // with this one. Nothing else in the state moves, which is what leaves the field open on the raw
        // text a person is still looking at.
        let title = rename.draft.trimmed()
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
        do {
            try reread()
        } catch {
            // Only when there is nothing better to say. A refusal answered what the person asked for, and
            // named the view where it could; a read that failed afterwards says the list may be stale,
            // which is the smaller of the two facts and must not take the place of the larger.
            if state.problem == nil { state.problem = Problem.couldNotRead.sentence }
        }
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
    private func createFolder() {
        let id: ViewID
        do {
            id = try store.createView(NewTaskView(title: TaskViewList.newFolderTitle))
        } catch {
            // The rows stand: nothing was written, so there is nothing to reread and nothing has moved.
            state.problem = Problem.couldNotSave.sentence
            return
        }
        state.problem = nil
        do {
            try reread()
        } catch {
            // The folder is written and cannot be shown yet, so neither the highlight nor the field moves
            // onto it: the rows here are the ones from before the button, and a rename left on a row this
            // list does not hold would be waiting there when the next unrelated `.changed` brought the row
            // in, opening a text field on a folder made minutes ago.
            state.problem = Problem.couldNotRead.sentence
            return
        }
        // The invariant that holds this shut, and it is exactly this wide: what this module puts on a row
        // of its own accord goes onto a row the list holds, here after a write of its own, and in `init` and
        // on `.route` without one. Here the read that just ran is the only thing that can say whether the
        // list holds the row. It does not cover `.rowSelected`, which stores the id a view names without
        // asking the rows (left as it shipped, see #77).
        //
        // A peer can have deleted the folder between the write and this read, and a highlight on a row
        // that came back deleted is a highlight on nothing.
        guard state.rows.contains(where: { $0.id == id }) else { return }
        state.selection = id
        state.rename = State.Rename(id: id, draft: TaskViewList.newFolderTitle)
        // The highlight moved without anybody choosing a row, and the folder's list opens as a click would have
        // opened it. Only where the highlight actually moved: a list on a folder the module is not highlighting
        // is the divergence this prevents.
        apply(list: TaskList.Route(head: id))
    }

    /// The tree as one read produced it. `views()` answers parents before children with the effective parent
    /// already resolved, so a row's depth is its parent's plus one and the depths the walk has passed are all
    /// it carries: one pass, no stack, and a chain a thousand deep from sync reads like a flat list
    /// (`docs/style.md`, "No recursion over data-shaped depth"). A parent the walk has not passed reads as
    /// no parent, the way the core resolves a link it cannot use, rather than as a row left out of the list.
    private static func rows(of store: Store) throws(StoreError) -> [State.ReadRow] {
        var depths: [ViewID: Int] = [:]
        return try store.views().map { view in
            let depth = view.parent.flatMap { depths[$0] }.map { $0 + 1 } ?? 0
            depths[view.id] = depth
            return State.ReadRow(id: view.id, title: view.title, depth: depth)
        }
    }

    /// The name a new folder is born with. A constant because the row a person reads and the draft in the
    /// field are one word and two copies of it would drift apart. It is English here: a string a person
    /// reads is the formatting service's to localise, and that service is M3's; until it arrives, a string
    /// this module writes is English.
    private static let newFolderTitle = "New folder"

    /// Everything this module holds between two events: the rows as the last read produced them, the row a
    /// person chose, the rename they have open, the seat with the list in it, and the sentence they were last
    /// told. One entity, moved field by field, from which the model is computed on every read, so that nothing
    /// on screen is state in its own right and there is no second copy to keep in step (owner's reviews of #77
    /// and #101).
    ///
    /// A struct and not a class: a field of a struct held in a `var` property is mutated in place and the
    /// array inside it is copy-on-write, so a class buys nothing here and would put a second reference type
    /// into a module that is already one. The seat is a struct holding a class, so a call that changes what it
    /// holds is a mutation of this state, and it is a field of the state because the tree of live modules is
    /// the navigation state (spec section 4).
    private struct State {
        var rows: [ReadRow]
        var selection: ViewID?
        var rename: Rename?
        var taskList: Seat<TaskList, StoreError>
        var problem: String?

        /// The model a view draws: the rows with this person's session projected onto them — the highlight
        /// on the row they chose, the draft on the row they are renaming — the highlighted row's id, the
        /// list's model as the list computes it, and the sentence, if any.
        var model: Model {
            let drawn = rows.map {
                Model.Row(
                    id: $0.id, title: $0.title, depth: $0.depth,
                    isSelected: $0.id == selection, draft: rename?.text(on: $0.id)
                )
            }
            // Read off the drawn rows and not copied from `selection`: `.rowSelected` keeps an id without asking
            // the rows, and an id no row carries highlights nothing, so the model names no row for it either.
            let selection = drawn.first(where: \.isSelected)?.id
            return Model(rows: drawn, selection: selection, taskList: taskList.model, problem: problem)
        }

        /// One row of the list as a read of the store produced it, before anything about this person's
        /// session is projected onto it. It is what the store answered and nothing else, which is what lets
        /// the same read serve a highlight that moves and a field that opens without being read again.
        struct ReadRow {
            let id: ViewID
            let title: String
            let depth: Int
        }

        /// The rename a person has open: the row the field is on, and the text in it.
        struct Rename {
            let id: ViewID
            let draft: String

            /// The draft as a row carries it, which is the projection `Model.Row.draft` is documented as.
            func text(on row: ViewID) -> String? { row == id ? draft : nil }
        }
    }

    /// What can go wrong in this module, with the sentence each one reads as. The store's own error stays
    /// here: it names SQLite codes and journal rows, which is what a bug report is made of and not what a
    /// person can do anything about, and spelling it in the model would put that text on a screen.
    private enum Problem {
        case couldNotRead
        case emptyTitle
        case viewIsGone(title: String)
        case couldNotSave
        case couldNotOpenList

        var sentence: String {
            switch self {
            case .couldNotRead: "The views could not be read, so this list may be out of date."
            case .emptyTitle: "A title cannot be empty."
            case .viewIsGone(let title): "“\(title)” is no longer there, so the new name was not saved."
            case .couldNotSave: "The change could not be saved, so nothing was written."
            case .couldNotOpenList: "The list could not be opened."
            }
        }
    }
}

extension TaskViewList.Model.Row: Identifiable {}
