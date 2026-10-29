// Sources/Features/TaskViewList/TaskViewList.swift
import FeatureModule
import TaskListFeature
import TodoCore

/// The views a person keeps, flattened out of the store's tree into the list they are chosen from, and the list
/// of the chosen view's tasks, which that choice declares open over them.
///
/// Named for what it holds and not for where it is put: the same list is a sidebar beside a Mac window and a
/// screen of its own on a phone, and a module that knew which one it was would be two modules.
///
/// The rows are flat and carry a depth instead of holding their children: a view drawing them indents by a
/// number and decides nothing, and the walk that builds them never recurses over a chain that arrived from
/// sync (`docs/style.md`).
///
/// A row is an area's line or a list's row, and a list's row arrives with everything it draws finished: its tile and
/// its title's font, built for the width class of the window, which the root hands the module as it hands it to its
/// own layout, and the count of its open tasks as text (Lists screen spec, sections 1, 4 and 5; ADR-0007, amendment
/// of 2026-10-26). The module reads the counts beside the rows, and the width moves the tiles with no read at all.
///
/// It is the base of its window's stack, and the task list's opener. A choice here declares the list of that view's
/// tasks in this module's destination, and the window's stack makes, keeps and drops the list (ADR-0009, amendment of
/// 2026-10-22): the module holds no screen, and hears what the list asks for as `.destinationAnswered`. The list is
/// drawn on a phone as the screen pushed over this one and on the Mac as the pane beside it. The root never learns that
/// a choice opens a list. The destination is the highlight too, so the two are one fact and cannot disagree (navigation
/// state spec, section 1).
///
/// It is a routable module, one that can be opened (spec section 4): its route has no head, because a window
/// has one list of views, and its tail is the route of the list it declared, so that a link to a view declares its
/// list here, highlighted, and the route a window writes down names the view and the task declared in its list.
public final class TaskViewList: Routable {
    /// The address of the module in its window: no head, and the route of the list declared over it as the tail
    /// (spec section 4).
    public struct Route: RouteValue {
        /// The same for every one, which is what keeps the one a window holds alive on every route it is
        /// handed: it is never made again by a link, so a name half typed in it survives one.
        public var head: NoHead { NoHead() }

        /// The list declared over the views, whose head is the view it lists and is the highlight, so that the
        /// highlight and the list cannot name two views in a route. Nil says nothing of the list: at creation the
        /// module declares the Inbox's, and on a live module what it declared stays as it is (owner, 2026-10-16).
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
        /// The row's Open in New Window menu item, on the Mac and the iPad.
        case openInNewWindowMenuItemChosen(ViewID)
        /// A list's chevron, which folds and unfolds the lists inside it.
        case disclosureTapped(ViewID)
        /// New list, from a list's menu, an area's menu, "+" and the edit bar, on the row its menu is on, and nil
        /// from "+" and the bar.
        case newListMenuItemChosen(in: ViewID?)
        /// New area, from "+" and the edit bar.
        case newAreaMenuItemChosen
        /// New task, from "+".
        case newTaskMenuItemChosen
    }

    public enum Event: RoutedEvent {
        case action(UserAction)
        case changed(ChangeSet)

        /// The parent has just created this module: sent once, by the module that holds it, through the window's
        /// stack, right after `init`. It is not the creation of a list or an area, which `newListMenuItemChosen` and
        /// `newAreaMenuItemChosen` write; it is this module's own creation, and it writes nothing. It is an event of
        /// the world and not a `UserAction`, because nobody did anything and a view has no way to send it (spec
        /// section 2).
        ///
        /// It is answered with nothing and moves nothing, the sentence included: the module was made from a
        /// route its parent chose and already knows, and it declared the list of the view it starts on in its
        /// `init`, as the task list declares its task in its own.
        case created

        /// A route handed to the live module, by a link into the root's window: an event of the world, like
        /// `.changed`, that no view can send (ADR-0006, amendment of 2026-10-14). The head never differs, so it is
        /// the tail alone that the module reads.
        case route(Route)

        /// What the list declared over this module answered, which the window's stack hands the module, its opener
        /// (ADR-0009, amendment of 2026-10-22, point 2).
        case destinationAnswered(TaskList.Output)

        /// The person went back to the views, and the list over them is gone already (navigation state spec,
        /// section 3): on a narrow window the list is a screen pushed over this one, which the back button, the
        /// swipe from the edge and the long-press menu close.
        case uncovered

        /// The list this module declared could not be made: why, and the route of the list that still stands over
        /// the module, nil when none does, which the module takes back as its destination (navigation state spec,
        /// section 2, and "Open questions").
        case notOpened(StoreError, stillOpen: TaskList.Route?)

        /// The width class of the window, which the root hands the module when its window's view reports it: an
        /// event of the world and not a `UserAction`, since nobody pressed anything, as it is for the root (navigation
        /// state spec, section 4). It moves the width alone, which the tiles and the title fonts are computed from, so
        /// they follow it with no read of the store; the sentence and an open field stay, and the width the module
        /// already has moves nothing.
        case widthChanged(WindowWidth)
    }

    public enum Output: Equatable, Sendable {
        /// A view a person asked to see in a window of its own, which only the platform can open: the module
        /// asks with its own route on that view, and its parent passes the request on under its own name (spec
        /// section 4, the rule of bubbling), so the root never spells the route of the list below it.
        case openInWindow(Route)
        /// Quick entry, which the root opens over the window, as it does for its own toolbar button (Lists screen spec,
        /// section 5).
        case newTaskRequested
    }

    /// What a view draws, computed from the state on every read and never kept beside it, so that what the
    /// list holds is in one place and the model cannot disagree with it (owner's review of #101).
    public var model: Model { state.model }

    /// The route of the module, assembled from its destination and never kept beside it (spec section 4): the route
    /// of the list it declared, which names the view that list is on and the task declared in it. The window's stack
    /// writes the window down from what stands instead, so a declaration that has aged never reaches the text
    /// (navigation state spec, section 3).
    public var route: Route { Route(list: state.destination.pushed) }

    /// What the module declared over it, the list of a view or nothing, which the window's stack reads after every
    /// event and follows (ADR-0009, amendment of 2026-10-22, point 2), and which is the highlight.
    public var destination: Destination<TaskList.Route> { state.destination }

    private let store: Store

    private var state: State

    /// Made from its route, the one way it is made (spec section 3): it declares the route's list whole, with the
    /// task in it, when the route names one, and the Inbox's list otherwise, the way the task list declares the
    /// task its route names in its own `init`. The window's stack makes the list in its first walk.
    ///
    /// The Inbox this module falls back on is declared only when a row holds it, so a person who deleted it is told
    /// nothing, having asked for nothing, and no highlight waits for the row: one would light up the moment a peer's
    /// change brought the row in, beside a list that was never opened on it. It is the invariant `create` holds for the
    /// same reason: what this module puts on a row of its own accord goes onto a row the list holds. A list the route
    /// names is declared whether or not a row holds its view; one the stack cannot make, its view gone or not yet
    /// synced, comes back as `.notOpened`, which takes the declaration back and says so in `problem`.
    ///
    /// The folds are the device's own, read from its state as this module or another window of the device last wrote
    /// them, here and at every read of the rows after (ADR-0010, amendment of 2026-10-26).
    ///
    /// The width is the class of the window the module is drawn in, which the root hands it from its own: it has no
    /// default, as the root's has none, so that the class a window is made with is always its host's to say
    /// (`docs/style.md`, "A lower layer holds no policy of its client").
    ///
    /// Throws, because a store that cannot be read at launch is the composition root's to refuse: a list that
    /// came up empty would look like a database with nothing in it (spec section 5). Only this module's own reads
    /// throw, the rows, their counts and the folds.
    public init(store: Store, route: Route, width: WindowWidth) throws(StoreError) {
        let rows = try TaskViewList.rows(of: store)
        let counts = try TaskViewList.counts(of: store)
        let collapsedViews = try TaskViewList.collapsedViews(in: store, among: rows)
        let inbox = rows.contains(where: { $0.id == BuiltInTaskViews.inbox }) ? BuiltInTaskViews.inbox : nil
        self.store = store
        self.state = State(
            rows: rows, counts: counts, collapsedViews: collapsedViews, width: width, destination: Destination()
        )
        setDestination(route.list ?? inbox.map { TaskList.Route(head: $0) })
    }

    public func send(_ event: Event) -> Output? {
        // The cases below move the state field by field and say nothing about what is on screen: the model is
        // computed from the state, so there is one place that decides what a row looks like (owner's reviews
        // of #77 and #101).
        switch event {
        case .action(.rowSelected(let id)):
            // The list's route on the view, declared every time, the highlighted row's own included: choosing the
            // row that is already chosen is still a choice, and every declaration is a new write. On the view the
            // list is on, the stack keeps the list and hands it the declaration, whose empty tail closes the task
            // open in it, so a click on the highlighted view returns to its list, as System Settings does on the
            // Mac and a second tap on a tab does on iOS (owner, 2026-10-16); on another view the stack makes a new
            // list. The highlight is the declaration, so it moves with it.
            //
            // The sentence goes with the event that produced it (spec, "The sidebar in M2"), except while a
            // field is open: then the sentence on screen is what explains the field, and this gesture leaves
            // the field where it is. A click on another row while the field holds an empty name can lose the
            // field's focus first, as it did through the List's own selection, so that the refusal that sets the
            // sentence arrives before this; cleared here, it would leave an empty field with the caret in it and
            // nothing saying why. Through the row's tap, on the Mac on 2026-10-20, this came first and the refusal
            // after it, with the same sentence on screen at the end. The owner chose this in chat on 2026-10-12.
            //
            // An open field stays open where it is. Losing focus is an action of its own, and the view is
            // what knows whether the field lost it: a module that read a selection change as a focus change
            // would settle or drop a person's half-typed name on a gesture they need not have made. The
            // owner settled this in chat on 2026-09-22, and `.titleFieldLostFocus` is the other half of it.
            //
            // The sentence goes before the list is declared, so that a list the click cannot open writes a fresh
            // one when the stack says so: it answers this click, and the one it replaces answered something earlier.
            // It does so with a field open too, over the field's own sentence, which the rule above keeps from being
            // cleared and not from being answered: the new sentence answers the gesture just made, the field stays
            // open on its draft, and Return brings the field's refusal back.
            //
            // An area never opens (Lists screen spec, section 2), so a tap on its line moves nothing, the sentence
            // included. Any other id is declared without asking the rows, as before.
            guard !state.rows.contains(where: { $0.id == id && $0.kind == .area }) else { return nil }
            if state.rename == nil { state.problem = nil }
            setDestination(TaskList.Route(head: id))
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
        case .action(.openInNewWindowMenuItemChosen(let id)):
            // Asked of the parent, because a window is the platform's to open and what it opens is the root's
            // to decide (spec section 4, the rule of bubbling). It asks with this module's own route on the view,
            // the list on it, so that the root passes it on without spelling the list's route. Nothing here
            // moves, the highlight, an open field and its sentence included: the person did nothing to this
            // module, and the window that opens beside it answers nothing they were told. A row that is not
            // there asks for nothing, the way the Rename menu item on one opens no field, and neither does an area's
            // line, since an area never opens (Lists screen spec, section 2).
            guard state.rows.contains(where: { $0.id == id && $0.kind == .list }) else { return nil }
            return .openInWindow(Route(list: TaskList.Route(head: id)))
        case .action(.newListMenuItemChosen(let id)):
            // Where the list goes is the module's to decide (Lists screen spec, section 3): inside the list or the
            // area whose menu it came from, and from "+" or the bar in the last area of the root, so that it stands
            // under the last line, or at the root's end when there is no area. A menu on a row that is not there
            // makes nothing, the way the Rename menu item on one opens no field.
            let parent: ReadRow?
            if let id {
                guard let row = state.rows.first(where: { $0.id == id }) else { return nil }
                parent = row
            } else {
                parent = state.rows.last { $0.kind == .area }
            }
            // The colour of the list it is made inside, and none in an area or at the root, where nothing gives
            // one: an area has no tile, whatever colour another device left on it (Lists screen spec, section 6). The
            // icon is the design system's list glyph, by the name the store keeps for it.
            let color = parent?.kind == .list ? parent?.color : nil
            create(NewTaskView(
                title: TaskViewList.newListTitle, parent: parent?.id, kind: .list, color: color, icon: "list"
            ))
            return nil
        case .action(.newAreaMenuItemChosen):
            // A line at the root's end, after every list and area there, and unnamed until a name is typed into the
            // field it opens with (Lists screen spec, section 3).
            create(NewTaskView(title: "", kind: .area))
            return nil
        case .action(.newTaskMenuItemChosen):
            // Quick entry is the root's modal over the window, so the module asks for it, and moves nothing of its own,
            // the highlight, an open field and its sentence included, as Open in New Window moves nothing (Lists
            // screen spec, section 5).
            return .newTaskRequested
        case .action(.disclosureTapped(let id)):
            // Only a list with lists inside it has a chevron. A leaf has nothing to fold, and an area's line defines
            // its area and never folds, so a tap on either, or on a row that is not there, moves nothing. The fold is
            // the one thing that moves: it is the device's state and no answer to anything a person was told, so an
            // open field and the sentence stay where they are.
            guard state.rows.contains(where: { $0.id == id && $0.kind == .list && $0.hasChildren }) else { return nil }
            setCollapsedViews(state.collapsedViews.symmetricDifference([id]))
            return nil
        case .created:
            // Nothing moves, the sentence included, because being created answers nothing a person was told,
            // and nothing is answered: `init` declared the list already.
            return nil
        case .route(let route):
            // The route's choice and not a person's, and its parent already knows it, so it is answered with nothing
            // (spec section 3, the third flow). The sentence goes at its start, a route that names no list included,
            // except while a field is open, whose sentence explains it and which the route leaves where it is, as a
            // click does (owner, 2026-10-16). A list the route cannot open writes a fresh sentence when the stack
            // says so, over an open field's too, as a click's does. A route carries no session state (spec section
            // 2): it declares its list whole, and the stack keeps what did not change, the list on the same view
            // with the task in it, and replaces the list on another (navigation state spec, section 3). A route that
            // names no list declares nothing, since a declaration written again would be a new one, which the stack
            // hands the list, closing what was opened in it since: the default window chooses the Inbox itself, at
            // creation and never again (owner, 2026-10-16).
            if state.rename == nil { state.problem = nil }
            guard let list = route.list else { return nil }
            setDestination(list)
            return nil
        case .destinationAnswered(.closeRequested):
            // The list's view is gone, so the list asked to be closed (spec section 3), and this module declares
            // nothing over it: the stack drops the list with whatever stands over it, and the route names no list.
            // The highlight went with its row already, by computation; the sentence stays, since the answer is no
            // gesture. The arm names the list's one answer, so that an answer it learns to give stops this file
            // compiling until this module has decided what it means (spec section 4).
            setDestination(nil)
            return nil
        case .uncovered:
            // The list is gone already, and this module cannot keep a destination the person closed (navigation
            // state spec, section 3), so the highlight goes with it: on a narrow window the list is a screen pushed
            // over this one, and Back closes that screen, so nothing stays chosen (owner, 2026-10-21), as iPhone's
            // System Settings leaves nothing chosen after Back. The route then names no list, which a window
            // restored from opens on the Inbox, as a new one does (owner, the same day). On a wide window the list
            // stands in a column of its own and no Back reaches it, so the highlight there still cannot be removed;
            // a window that widens after this shows the views with nothing chosen and no list until one is chosen.
            //
            // The stack tells only a module with a list over it, so the platform's write after a pop the model drove
            // reaches nobody. The sentence goes, as with a click, except while a field is open, whose sentence
            // explains it and which this gesture leaves where it is.
            if state.rename == nil { state.problem = nil }
            setDestination(nil)
            return nil
        case .notOpened(_, let stillOpen):
            // The list could not be made, its view gone or not yet synced, or its tasks unread, and the stack keeps
            // what stood. This module takes that back as its destination, so that the declaration is tried once and
            // the highlight returns to the list that is open, or goes when none is (navigation state spec, section
            // 2, and "Open questions"), and says so, over an open field's sentence too, since it answers the gesture
            // or the link just made. It has one sentence for every refusal.
            setDestination(stillOpen)
            state.problem = Problem.couldNotOpenList.sentence
            return nil
        case .changed(let changes):
            // Every edit to a task is a commit that touched no view, and the rows are the same afterwards, so
            // the condition is what keeps a person typing in a list out of the views table: such a commit reads
            // the counts alone, since a change to any task or tag can move any count (Lists screen spec, section
            // 4). A commit that did touch a view rereads the whole tree rather than the branch it names, because
            // views number in the tens and the tree order needs every row anyway (spec, "The sidebar in M2"), and
            // the counts with it, as every read of the rows does.
            //
            // The sentence stands unless a read replaces it. It answered what a person did, and what another device
            // did is no answer to it: a sentence cleared by a peer's edit would go between the person being told and
            // reading it. A draft stays for the same reason.
            do {
                if !changes.views.isEmpty {
                    try reread()
                } else if !changes.tasks.isEmpty || !changes.tags.isEmpty {
                    // Assigned after the read, so a read that failed leaves the counts on screen where they were.
                    state.counts = try TaskViewList.counts(of: store)
                }
            } catch {
                // Only when there is nothing on screen already. A `.changed` neither clears a sentence nor
                // replaces one, because it answers for nobody: the field can be open with a refusal on it
                // when a peer's edit arrives, and "the list may be out of date" would take the place of
                // what the person was actually told.
                if state.problem == nil { state.problem = Problem.couldNotRead.sentence }
            }
            // The destination stays: the list over this module reads the change itself, handed it by the window
            // after this module, and a list whose view is gone asks to be closed. The highlight on a row that went
            // goes by computation. Nothing is written in answer (spec section 5).
            return nil
        case .widthChanged(let width):
            // The tiles and the title fonts are computed from the width on every read of the model, so this moves
            // them alone, and the same width again moves nothing.
            state.width = width
            return nil
        }
    }

    /// Folds and unfolds the branches to the set, written to the device's state first and kept after (ADR-0010).
    private func setCollapsedViews(_ collapsedViews: Set<ViewID>) {
        // A write that fails is not said: the fold stays on screen until the next read of the rows takes the folds
        // back from the store, and this module's sentences stay for the data a person edits, which a fold is not
        // (Lists screen plan, "Self-review"). Sorted, so that the same folds are the same text in the file.
        try? store.setDeviceState(TaskViewList.collapsedViewsKey, collapsedViews.map(\.rawValue).sorted())
        state.collapsedViews = collapsedViews
    }

    /// The folded lists as the device's state holds them, of the lists the rows hold: what was written is the device's
    /// and may be stale or wrong (`docs/style.md`, "Data from outside"), so a text that does not read as an id, an id
    /// no row holds, a view deleted since, and an area's, whose line never folds, are dropped, and the next fold writes
    /// the set back without them. A list with no lists inside keeps its fold, which it does not draw
    /// (`ReadRow.drawnKind`), so lists that come back inside it come back folded. A value that does not decode as a
    /// list of texts reads as nothing folded, which the store decides.
    private static func collapsedViews(in store: Store, among rows: [ReadRow]) throws(StoreError) -> Set<ViewID> {
        let held = Set(rows.filter { $0.kind == .list }.map(\.id))
        let kept = try store.deviceState(collapsedViewsKey, as: [String].self) ?? []
        return Set(kept.compactMap { try? ViewID(uuidString: $0) }.filter(held.contains))
    }

    /// The key the folds are kept under in the device's own state: the module's name and what it keeps, the folded
    /// lists' ids as their raw values. Its rule is that a write of it reports no change set, which the store's
    /// writes of a device's state never do: a fold is one screen's own, and another window of the same device that
    /// draws the same rows reads it at its next read of them, `reread`, and writes it back with its own next fold
    /// (Lists screen spec, section 5; ADR-0010).
    private static let collapsedViewsKey = "taskViewList.collapsed"

    /// Declares the list of a view over this module, or nothing: a click, a route, the way back and the stack's notices
    /// each arrive here, so what a click opens and what a link opens cannot drift apart (spec section 3). Every call is
    /// a new write, which the window's stack follows at the walk after the event, and the highlight is what it
    /// declares.
    private func setDestination(_ list: TaskList.Route?) {
        state.destination.declare(list.map { .pushed($0) })
    }

    /// Reads the tree, its counts and the device's folds again and keeps of this person's session whatever the new rows
    /// still hold. The folds are read with the rows, so that a fold another window of this device made since is drawn
    /// here at the next read of the rows (Lists screen spec, section 5).
    ///
    /// A rename goes when its row does, with a sentence, because a person typing a name was interrupted, and the
    /// sentence is the one a refused write gives for the same fact, since a peer's delete is that fact arriving by
    /// another route (owner's review of #77). It is dropped here rather than left to be discovered by the next
    /// write. What this module declared stays: the highlight goes silently with its row by computation, a person
    /// whose highlight moved was not interrupted, and the list on a view that is gone asks to be closed on its own
    /// `.changed`, which this module answers by declaring nothing.
    ///
    /// The rows on screen are never cleared by a read that failed, because they are assigned last, with their counts
    /// and the folds, and a throw leaves all of them where they were: `send` cannot throw (ADR-0006), and a list
    /// emptied by a failed read would take with it the only thing left to act on.
    ///
    /// What a failed read means is the caller's to say, which is why this throws instead of writing a
    /// sentence of its own. It means three different things: after a `.changed` nothing else is in flight,
    /// after a refused write there is already something more specific to say, and after a list or an area
    /// was made it means the new row cannot be shown yet — and a reread that swallowed the error had to pick
    /// one of the three for all of them, which is what left the corner this closes (owner's review of #77,
    /// 2026-09-24).
    private func reread() throws(StoreError) {
        let rows = try TaskViewList.rows(of: store)
        let counts = try TaskViewList.counts(of: store)
        let collapsedViews = try TaskViewList.collapsedViews(in: store, among: rows)
        if let rename = state.rename, !rows.contains(where: { $0.id == rename.id }) {
            // The name comes off the rows as they still are: the ones being read in no longer hold the
            // view, and after the assignment below there is nothing left to call it. A row already gone
            // from those too cannot be named at all, and an invented name is worse than silence.
            if let problem = TaskViewList.goneViewProblem(state.rows.first { $0.id == rename.id }) {
                state.problem = problem.sentence
            }
            state.rename = nil
        }
        state.rows = rows
        state.counts = counts
        state.collapsedViews = collapsedViews
    }

    /// Writes the draft and closes the field, or refuses it and leaves the field where it is.
    ///
    /// The empty title is refused here and not by the store: what a person's word for a view has to be is
    /// this list's rule, and a core that had an opinion about it would hold the policy of its client
    /// (`docs/style.md`). A list's title cannot be empty, and an area's can, since an unnamed area is a line
    /// alone (Lists screen spec, section 3). The field stays open on the refusal, because the person is
    /// mid-word and the text they typed is the only place the name exists.
    private func commit(_ rename: State.Rename) {
        // Trimmed once, and the one value both the refusal and the write work off: a draft that is nothing
        // but whitespace trims to nothing, which is what empty means here, and no second rule has to agree
        // with this one. Nothing else in the state moves, which is what leaves the field open on the raw
        // text a person is still looking at.
        let title = rename.draft.trimmed()
        let row = state.rows.first { $0.id == rename.id }
        guard !title.isEmpty || row?.kind == .area else {
            state.problem = Problem.emptyTitle.sentence
            return
        }
        // The row a refusal names is the one read before the write: the reread below drops it, and by then
        // there is nothing left to call the view.
        var problem: String?
        do {
            // One change and no other: two changes to one field in one call keep only the last (#40), and a
            // rename has nothing else to say. The trimmed title goes in: what the person typed is what the
            // field shows them, and what a view is called is what the store keeps — padding is neither.
            try store.update(view: rename.id, [.title(title)])
        } catch {
            problem = TaskViewList.problem(error, renaming: row).sentence
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
    /// that is not true. A `.notFound` with no row to name it by is the general sentence for the same
    /// reason: the specific one would have to invent the name it names.
    private static func problem(_ error: StoreError, renaming row: ReadRow?) -> Problem {
        switch error {
        case .notFound: goneViewProblem(row) ?? .couldNotSave
        default: .couldNotSave
        }
    }

    /// The problem a gone view gives the rename open on it.
    ///
    /// The row the field was open on picks it: the sentence that names the view, and for an unnamed area, which has
    /// no name to give, a sentence of its own that names none. An empty title is no name, so a list that has one,
    /// written so by another device, and a row that is not there have nothing to say: an invented name is worse than
    /// silence.
    private static func goneViewProblem(_ row: ReadRow?) -> Problem? {
        guard let row else { return nil }
        if !row.title.isEmpty { return .viewIsGone(title: row.title) }
        return row.kind == .area ? .areaIsGone : nil
    }

    /// Makes a list or an area at the end of its new siblings with its field open on the title it is made with, so
    /// that a person names it straight away instead of hunting for the row the menu just made (Lists screen spec,
    /// section 6). The branch it is made in unfolds once the rows are read, written to the device's state as every
    /// fold is, so that the row and its field are on screen.
    ///
    /// It declares nothing, so the highlight and the list open beside the sidebar stay where they were: on a narrow
    /// window a list declared here would be pushed over the sidebar while the field is open (Lists screen plan,
    /// "Self-review").
    ///
    /// The write goes first and the rows come back out of the store: the id, the rank and the place in the
    /// tree are the store's to decide, and a row put together here would be this module's guess at them.
    private func create(_ new: NewTaskView) {
        let id: ViewID
        do {
            id = try store.createView(new, at: .end)
        } catch {
            // The rows stand: nothing was written, so there is nothing to reread and nothing has moved.
            state.problem = Problem.couldNotSave.sentence
            return
        }
        state.problem = nil
        do {
            try reread()
        } catch {
            // The view is written and cannot be shown yet, so the field does not move onto it: the rows here
            // are the ones from before the menu, and a rename left on a row this list does not hold would be
            // waiting there when the next unrelated `.changed` brought the row in, opening a text field on a list
            // made minutes ago.
            state.problem = Problem.couldNotRead.sentence
            return
        }
        // The unfold comes after the read, which takes the folds back from the store: before it, a write of the
        // unfold that failed would be read back as the branch folded, and the field would open on a row the model
        // does not draw. After it, the branch is unfolded on screen whether or not the write held, as every fold is.
        if let parent = new.parent, state.collapsedViews.contains(parent) {
            setCollapsedViews(state.collapsedViews.subtracting([parent]))
        }
        // The invariant that holds this shut, and it is exactly this wide: what this module puts on a row
        // of its own accord goes onto a row the list holds, here after a write of its own, and in `init` for
        // the Inbox it falls back on. Here the read that just ran is the only thing that can say whether the
        // list holds the row. It does not cover `.rowSelected` and `.route`, which declare the list of the id
        // they name without asking the rows, and which the stack hands back when the list cannot be made.
        //
        // A peer can have deleted the view between the write and this read, and a field on a row that came
        // back deleted is a field on nothing.
        guard state.rows.contains(where: { $0.id == id }) else { return }
        state.rename = State.Rename(id: id, draft: new.title)
    }

    /// The name a new list is born with. A constant because the row a person reads and the draft in the
    /// field are one word and two copies of it would drift apart. It is English here: a string a person
    /// reads is the formatting service's to localise, and until it arrives a string this module writes is
    /// English (Lists screen spec, "Goals and non-goals").
    private static let newListTitle = "New list"

    /// Everything this module holds between two events: the rows and their counts as the last reads produced them, the
    /// lists folded on this device, the width class of the window, the rename a person has open, the list declared over
    /// the module, and the sentence they were last told. One entity, moved field by field, from which the model is
    /// computed on every read, so that nothing on screen is state in its own right and there is no second copy to keep
    /// in step (owner's reviews of #77 and #101): the highlight is read off the destination, and is not kept beside it.
    ///
    /// A struct and not a class: a field of a struct held in a `var` property is mutated in place and the
    /// array inside it is copy-on-write, so a class buys nothing here and would put a second reference type
    /// into a module that is already one. The destination is a field of the state because what a screen declared
    /// over it is the navigation state, which the window's stack follows (ADR-0009, amendment of 2026-10-22).
    private struct State {
        var rows: [ReadRow]
        var counts: [ViewID: Int]
        var collapsedViews: Set<ViewID>
        var width: WindowWidth
        var rename: Rename?
        var destination: Destination<TaskList.Route>
        var problem: String?

        /// The model a view draws: the rows a person sees, those inside a folded list left out, with the window and
        /// this person's session projected onto them — the tiles and fonts for the width, the counts, the folds, the
        /// highlight on the list's row of the view whose list is declared, or on the folded list that hides that row,
        /// the draft on the row they are renaming — the highlighted row's id, and the sentence, if any.
        var model: Model {
            let shown = TaskViewList.unfolded(rows, collapsedViews: collapsedViews, declared: destination.pushed?.head)
            let drawn = shown.rows.map {
                Model.Row(
                    id: $0.id, depth: $0.depth,
                    kind: $0.drawnKind(
                        in: width, count: counts[$0.id], isFolded: collapsedViews.contains($0.id),
                        isSelected: $0.id == shown.highlighted
                    ),
                    draft: rename?.text(on: $0.id)
                )
            }
            // Read off the drawn rows and not copied from the destination or the walk: `.rowSelected` and `.route`
            // declare the list of an id without asking the rows, and an id no list's row carries, an area's line's
            // among them, highlights nothing, so the model names no row for it either.
            let selection = drawn.first { row in
                guard case .list(let list) = row.kind else { return false }
                return list.isSelected
            }?.id
            return Model(rows: drawn, selection: selection, problem: problem)
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
        case areaIsGone
        case couldNotSave
        case couldNotOpenList

        var sentence: String {
            switch self {
            case .couldNotRead: "The views could not be read, so this list may be out of date."
            case .emptyTitle: "A title cannot be empty."
            case .viewIsGone(let title): "“\(title)” is no longer there, so the new name was not saved."
            case .areaIsGone: "The area is no longer there, so the new name was not saved."
            case .couldNotSave: "The change could not be saved, so nothing was written."
            case .couldNotOpenList: "The list could not be opened."
            }
        }
    }
}
