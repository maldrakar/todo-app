// Sources/Features/TaskList/TaskList.swift
import FeatureModule
import TaskScreenFeature
import TodoCore

/// The screen of one list: its tasks as the store's page of the view lays them out, the list's own tasks first in their
/// groups and then one block per list inside it, with the tag bar, the folds and the layout the device keeps, every
/// write the screen makes, and what it declared over itself (list screen spec, sections 1 to 7 and 9).
///
/// It is declared by the sidebar, by a choice there, and stands in its window's stack over the sidebar, drawn in the
/// pane beside it on the Mac. A tap on a row opens the task in place, as a card; the card's Open full screen declares
/// the task screen over the list, and a tap on a block's title the list inside that the block is, or the list's own
/// group the block is, opened as a screen of its own, which is this module on another route; the window's stack makes,
/// keeps and drops what the list declared (ADR-0009, amendments of 2026-10-22, 2026-11-01 and 2026-11-02): the list
/// holds no screen and draws none, and hears what a screen over it asks for as `.destinationAnswered`. Neither the
/// sidebar nor the root learns what a list opens, and their code does not grow when it learns to open something
/// (navigation state spec, section 2).
///
/// A group's screen is the list it belongs to read for one of its own groups: the module reads the list's page and
/// draws that group's block of it, so the two always agree, and nothing stores the group or writes when it opens
/// (ADR-0004, amendment of 2026-11-02). It has no lists inside, no columns, no folds and no layout of its own.
///
/// It is a routable module (spec section 4): its head is the view it lists and, on a group's screen, the group, and its
/// tail is what it declared over itself, so that a link to a task or to a list inside declares it over the list, and
/// the route a window writes down names the whole chain.
public final class TaskList: Routable {
    /// What a view may send, each case named for the control and the gesture and never for the operation it triggers
    /// (ADR-0006). The way back from a screen over the list is not one: SwiftUI reports it only as the shorter path it
    /// wrote, which the root view sends the window whole, and the stack tells the list `.uncovered` (navigation state
    /// spec, section 3).
    public enum UserAction: Equatable, Sendable {
        /// A row of a block or of the strip, beside its check, tapped or clicked.
        case rowTapped(TaskID)
        /// A row's or a strip row's check, or the open card's.
        case checkTapped(TaskID)
        /// The screen's background beside the open card.
        case backgroundTapped
        /// Esc, on a keyboard, in the card or in its notes.
        case escapeKeyPressed
        /// The card's title's field: its text, Return, Esc and leaving it.
        case titleFieldChanged(String), titleFieldSubmitted, titleFieldCancelled, titleFieldLostFocus
        /// The card's notes' field: its text and leaving it.
        case notesFieldChanged(String), notesFieldLostFocus
        /// A subtask's check in the card.
        case subtaskCheckTapped(TaskID)
        /// "Add subtask" in the card.
        case addSubtaskTapped
        /// The field a new subtask is typed into: its text, Return, Esc and leaving it.
        case subtaskFieldChanged(String), subtaskFieldSubmitted, subtaskFieldCancelled, subtaskFieldLostFocus
        /// Open full screen, at the card's top.
        case openFullScreenTapped
        /// The floating "+".
        case addTaskButtonTapped
        /// "+ Add task" at the end of a block or a column.
        case addTaskRowTapped(in: Model.BlockID)
        /// "+ Add list", in both layouts.
        case addListTapped
        /// The field a new list's name is typed into: its text, Return, Esc and leaving it.
        case listNameFieldChanged(String), listNameFieldSubmitted, listNameFieldCancelled, listNameFieldLostFocus
        /// The Done strip's capsule.
        case doneStripTapped
        /// A row's Delete, uncovered by its swipe.
        case deleteSwiped(TaskID)
        /// Delete in a row's menu.
        case deleteMenuItemChosen(TaskID)
        /// A row let go: the block it was dragged from, which names one of the two that draw a task both select, the
        /// block it was let go in, and the row it stands after there, nil for the top (the controller's ruling on #176,
        /// 2026-11-05). Indirect, since every control's model holds an action inline, and inline this one case makes
        /// all of them 56 bytes on wasm32 where the rest need 14, which a debug build puts on the stack at every copy.
        indirect case rowDropped(TaskID, from: Model.BlockID, in: Model.BlockID, after: TaskID?)
        /// A block's title, in its header or its column's.
        case blockTitleTapped(Model.BlockID)
        /// A block's chevron, which folds and unfolds it.
        case blockChevronTapped(Model.BlockID)
        /// A chip of the tag bar.
        case tagChipTapped(TagID)
        /// An item of Show as, List or Columns.
        case showAsChosen(Model.Layout.Kind)
    }

    public enum Event: RoutedEvent {
        case action(UserAction)
        case changed(ChangeSet)

        /// The window's stack has just made this list: sent once, right after `init`. The list was made from a route
        /// its opener declared and already knows, what stands over it included, so it has nothing to report and
        /// answers nothing.
        case created

        /// A route handed to the live list, which its opener declared again with this list's head, by a link or by a
        /// click on the list's view: an event of the world that no view can send (ADR-0006, amendment of 2026-10-14),
        /// which the stack hands the list once, as `.declared` (navigation state spec, section 2). The head of a live
        /// list never changes, so it is the tail alone that the list reads.
        case route(Route)

        /// What the screen declared over this list answered, the task screen or a list, which the stack hands the list,
        /// its opener (ADR-0009, amendment of 2026-10-22, point 2).
        case destinationAnswered(Route.Tail.Answer)

        /// The person went back to this list, and the screen over it is gone already (navigation state spec, section
        /// 3).
        case uncovered

        /// What the list declared could not be made, the task screen or a list: why, and the route of what still stands
        /// over the list, nil when nothing does, which the list takes back as its destination (navigation state spec,
        /// section 2).
        case notOpened(StoreError, stillOpen: Route.Tail?)

        /// The device's day, which the root hands every screen of its window when the window's view reports a new one,
        /// at midnight, in a new time zone or on waking on another day: an event of the world that no view can send
        /// (spec section 8; ADR-0006, amendment of 2026-11-01). Which tasks a list selects, which day each of its
        /// blocks is and which group a group's screen shows depend on the day, so a new one rereads the page; the day
        /// the list already has reads nothing. Neither is a gesture on the list, so the sentence on screen and the
        /// destination stay.
        case dayChanged(DeviceDay)
    }

    public enum Output: Equatable, Sendable {
        /// The view is gone, or the group of a group's screen names nothing any more, so the list asks its opener to
        /// close it (spec section 3; the controller's ruling on #175, 2026-11-04); the stack drops what stands over it
        /// with it.
        case closeRequested
    }

    /// What a view draws, computed from the state on every read and never kept beside it, so that what the list holds
    /// is in one place and the model cannot disagree with it (owner's review of #101).
    public var model: Model { state.model }

    /// The route the list is on, assembled and never kept beside its state (spec section 4): its own head, and as
    /// the tail what it declared. The window's stack writes the window down from what stands instead, so a
    /// declaration that has aged never reaches the text (navigation state spec, section 3).
    public var route: Route { Route(head: state.head, tail: state.destination.pushed) }

    /// What the list declared over it, the task screen, a list or nothing, which the window's stack reads after every
    /// event and follows (ADR-0009, amendment of 2026-10-22, point 2).
    public var destination: Destination<Route.Tail> { state.destination }

    private let store: Store

    private var state: State

    /// Made from its route, the one way a list is made (spec section 3): the page of the view the head names, read by
    /// the device's day, with the tags and the parents its groups name and the tasks completed that day; the folds and
    /// the layout the device keeps for the list, which a group's screen keeps none of; and what the tail names declared
    /// over it, which the stack makes in the walk after the list is made.
    ///
    /// The day is the device's, which the window's stack hands the list when it makes it, the day its root has then, so
    /// that a list made after midnight starts on the new day (spec section 8). It has no default, as the root's has
    /// none: the day is the platform's to say (`docs/style.md`, "A lower layer holds no policy of its client").
    ///
    /// Throws when the page cannot be read, a view that is gone among it, which is refused with `.notFound` and the
    /// view's id: a list that came up empty would look like a view with nothing in it, and the stack keeps what was
    /// open while the list's opener says so (navigation state spec, section 2). A group that reads but names nothing,
    /// a word that is not the list's grouping or a tag or a parent that is gone, is refused the same way, with
    /// `.invalid` or `.notFound`, and the list it was declared over stays open and says why (ADR-0009, amendment of
    /// 2026-11-02). What the tail names that cannot be made does not stop the list: a link to a task that is gone opens
    /// the view it names, and the stack tells the list, which says why with nothing open over it, which is what still
    /// exists (spec section 3, the fourth flow).
    public init(store: Store, route: Route, day: DeviceDay) throws(StoreError) {
        let snapshot = try TaskList.read(store, head: route.head, day: day)
        if let group = route.head.group, let refusal = TaskList.refusal(of: group, in: snapshot) { throw refusal }
        let isGroup = route.head.group != nil
        self.store = store
        self.state = State(
            head: route.head, title: snapshot.page.view.title, snapshot: snapshot, day: day,
            folded: isGroup ? [] : try TaskList.keptFolds(in: store, of: route.head.view),
            layout: isGroup ? .list : try TaskList.keptLayout(in: store, of: route.head.view), picks: [], card: nil,
            isDoneOpen: false, naming: nil, destination: Destination(), problem: nil
        )
        setDestination(route.tail)
    }

    public func send(_ event: Event) -> Output? {
        switch event {
        case .action(.rowTapped(let id)): openCard(on: id)
        case .action(.checkTapped(let id)): check(id)
        case .action(.backgroundTapped), .action(.titleFieldCancelled): dismissCard()
        case .action(.escapeKeyPressed):
            state.card?.subtaskDraft = nil
            dismissCard()
        case .action(.titleFieldChanged(let text)): typeTitle(text)
        case .action(.titleFieldSubmitted): submitTitle()
        case .action(.titleFieldLostFocus), .action(.notesFieldLostFocus): saveCard()
        case .action(.notesFieldChanged(let text)): typeNotes(text)
        case .action(.subtaskCheckTapped(let id)): checkSubtask(id)
        case .action(.addSubtaskTapped): openSubtaskField()
        case .action(.subtaskFieldChanged(let text)): typeSubtask(text)
        case .action(.subtaskFieldSubmitted): writeSubtask(thenOpensNext: true)
        case .action(.subtaskFieldLostFocus): writeSubtask(thenOpensNext: false)
        case .action(.subtaskFieldCancelled): state.card?.subtaskDraft = nil
        case .action(.openFullScreenTapped): openFullScreen()
        case .action(.addTaskButtonTapped): addFromFloatingButton()
        case .action(.addTaskRowTapped(let block)): addFromRow(in: block)
        case .action(.addListTapped): addList()
        case .action(.listNameFieldChanged(let text)): typeListName(text)
        case .action(.listNameFieldSubmitted), .action(.listNameFieldLostFocus): settleListName()
        case .action(.listNameFieldCancelled): state.naming = nil
        case .action(.doneStripTapped): toggleDoneStrip()
        case .action(.deleteSwiped(let id)): trash(id, offeredBy: .deleteSwiped(id))
        case .action(.deleteMenuItemChosen(let id)): trash(id, offeredBy: .deleteMenuItemChosen(id))
        case .action(.rowDropped(let id, let source, let target, let anchor)):
            drop(id, from: source, in: target, after: anchor)
        case .action(.blockTitleTapped(let id)):
            // A title the model does not draw opens nothing, a group's screen's one block among them, whose header is
            // its screen's (spec section 2). A list inside opens as itself; one of the list's own groups as the list
            // on its group's address, by the distance from today for a day; and the own block of a list that groups by
            // nothing has no group to open. Nothing is written: the group is read from the list's page when its
            // screen is made (ADR-0004, amendment of 2026-11-02).
            guard TaskList.blocks(in: model.layout).contains(where: { block in
                [block.header?.titleTapped, block.column?.header.titleTapped].contains(.blockTitleTapped(id))
            }) else { return nil }
            let declared: Route
            switch id {
            case .list(let view):
                declared = Route(head: .init(view: view))
            case .own(let key?):
                let group = TaskList.address(of: key, by: state.snapshot.page.view.groupBy, today: state.day.day)
                declared = Route(head: .init(view: state.head.view, group: group))
            case .own(nil):
                return nil
            }
            state.problem = nil
            setDestination(.list(declared))
            return nil
        case .action(.blockChevronTapped(let id)):
            // Only a block the model draws with a chevron folds, which no column has. The fold is the one thing that
            // moves: it is the device's state and no answer to anything a person was told, so the sentence stays.
            let blocks = TaskList.blocks(in: model.layout)
            guard blocks.contains(where: { $0.header?.fold?.chevron.action == .blockChevronTapped(id) }),
                  let key = TaskList.foldKey(of: id)
            else { return nil }
            let drawn = Set(blocks.compactMap { TaskList.foldKey(of: $0.id) })
            setFolded(state.folded.intersection(drawn).symmetricDifference([key]))
            closeCardIfHidden()
            return nil
        case .action(.tagChipTapped(let tag)):
            // A chip the bar does not show picks nothing. A pick is session state, which a relaunch loses (ADR-0009,
            // amendment of 2026-11-01), and no answer to anything a person was told, so the sentence stays.
            guard model.tagBar?.chips.contains(where: { $0.action == .tagChipTapped(tag) }) == true else { return nil }
            state.picks.formSymmetricDifference([tag])
            closeCardIfHidden()
            return nil
        case .action(.showAsChosen(let layout)):
            // An item is checked against the model: Columns disabled moves nothing (spec section 5). The choice is the
            // device's, kept per list (ADR-0010), and a group's screen keeps none, its one layout being the list's. The
            // sentence stays, as for a fold.
            guard model.showAs.menu.sections.flatMap(\.items).contains(where: {
                $0.action == .showAsChosen(layout) && !$0.isDisabled
            }), layout != state.layout else { return nil }
            // A write that fails is not said, as a fold's is not: the layout stays on screen until the next list made
            // on the view reads what was kept.
            try? store.setDeviceState(TaskList.layoutKey(of: state.head.view), layout)
            state.layout = layout
            closeCardIfHidden()
            return nil
        case .created:
            // Being created answers no gesture, so it moves nothing, the sentence included.
            return nil
        case .route(let route):
            // The route's own head is not read: the stack hands a live list only a route with its head, and the head
            // of a live module never changes (spec section 3). The sentence goes at the start, as it does for a tap:
            // a route is what a link or a click in the sidebar asks of this list, and the sentence on screen
            // answered something earlier (owner, 2026-10-16). What the route names that cannot be made writes a
            // fresh one, on `.notOpened`.
            state.problem = nil
            setDestination(route.tail)
            return nil
        case .destinationAnswered(.task(.closeRequested)), .destinationAnswered(.list(.closeRequested)), .uncovered:
            // The screen over the list asked to be closed, its task or its view gone (spec section 3), or the person
            // went back to the list and the screen is gone already, and a list cannot keep a destination the person
            // closed (navigation state spec, section 3). Either way the list declares nothing over it, the stack drops
            // the screen with whatever stands over it, and the route names nothing over the list. None is a gesture on
            // the list, so the sentence stays: one written while the screen was up, by a link to a task that is gone
            // or a reread that failed, is one the person first sees now that the list is uncovered. The stack tells
            // only a list with a screen over it, so the platform's write after a pop the model drove reaches nobody.
            // The arms name each screen's one answer, so that an answer either learns to give stops this file
            // compiling until the list has decided what it means (spec section 4).
            setDestination(nil)
            return nil
        case .notOpened(let error, let stillOpen):
            // What still stands is taken back, so that the declaration is tried once and the screen that was open
            // stays (navigation state spec, section 2), and the list says why under its rows, naming what it declared,
            // which is read before what stays takes its place.
            let problem = TaskList.problem(error, declared: state.destination.pushed)
            setDestination(stillOpen)
            state.problem = problem.sentence
            return nil
        case .changed(let changes):
            do {
                // Only a change naming this view can have deleted it or renamed it, and the view's read tells. A view
                // that is gone is answered at once: the opener closes this list, and the stack drops it with what
                // stands over it (spec section 3), so a page read here would be work for nothing. A view that is
                // there gives the header its title, which stands even when the page's read below fails, since the
                // read that answered it succeeded; the rest of the view, its rule among it, is the page's, read whole
                // or not at all. A read that fails is a reread that failed, and the catch says so.
                if changes.views.contains(state.head.view) {
                    guard let view = try store.view(state.head.view) else { return .closeRequested }
                    state.title = view.title
                }
                // Every change rereads the page. It reads tasks, the tags they carry, this view's rule and the lists
                // inside it, to any depth for a folder inside, and a change names the entity it touched and not what
                // moved because of it: a list made inside this one, or under a folder inside it, names itself alone,
                // and a tag deleted empties a list filtered by it and names only the tag (`ChangeSet`). Which of them
                // moved this page is the page's to say.
                let snapshot = try TaskList.read(store, head: state.head, day: state.day)
                // A group's screen whose group names nothing any more, its tag or its parent gone or its list grouped
                // another way, asks to be closed, as a list whose view is gone does (the controller's ruling on #175,
                // 2026-11-04).
                if let group = state.head.group, TaskList.refusal(of: group, in: snapshot) != nil { return .closeRequested }
                try take(snapshot)
            } catch {
                // Neither the blocks on screen nor the title is cleared, since each is assigned only after its own read
                // succeeded, and a list emptied by a failed read would take with it the only thing left to act on.
                // The sentence is written only when none is on screen, as in the sidebar: a change answers for
                // nobody, so it neither clears a sentence nor replaces one, and "may be out of date" would take the
                // place of what the person was told about something they did or a link asked for.
                if state.problem == nil { state.problem = Problem.couldNotReadTasks.sentence }
            }
            // The destination stays: a screen over the list reads the change itself, handed it by the window, and asks
            // to be closed when its subject is gone. Nothing is written in answer (ADR-0009).
            return nil
        case .dayChanged(let day):
            // The day is kept whether or not the read below holds, since it is what the world says and every later
            // read of the page is by it. A read that fails leaves the blocks and says so only when nothing is on
            // screen, as a change's reread does: the day answers for nobody. A group's screen moves onto the new day's
            // group, its key being a distance (spec section 2).
            guard day != state.day else { return nil }
            state.day = day
            do {
                try take(try TaskList.read(store, head: state.head, day: day))
            } catch {
                if state.problem == nil { state.problem = Problem.couldNotReadTasks.sentence }
            }
            return nil
        }
        return nil
    }

    // MARK: - The writes

    // The screen's writes but the card's and the drop's: the check and the Done strip, the floating "+" and "+ Add
    // task", "+ Add list" and its name, and Delete (spec sections 3, 4 and 6). Each answers a person's action and none
    // a change (ADR-0009), and every id a view sends is checked against the model.

    /// Writes, says what the store refused, and reads the page back at once, as the sidebar's writes do
    /// (`TaskViewList.writeAndReread`), so that a new task's card has its row; `.changed` rereads again as it always
    /// has (the controller's ruling on #176, 2026-11-05). The page is read back after a refusal too, since what the
    /// store refused can be a peer's change the module has not heard of yet. A write that held takes the sentence away;
    /// a read that fails says the list may be out of date only when nothing else was said. Answers whether both held.
    @discardableResult
    private func writeAndReread(refusal: Problem = .couldNotSave, _ write: () throws(StoreError) -> Void) -> Bool {
        let written: Bool
        do {
            try write()
            written = true
            state.problem = nil
        } catch {
            written = false
            state.problem = refusal.sentence
        }
        do {
            try take(try TaskList.read(store, head: state.head, day: state.day))
        } catch {
            if state.problem == nil { state.problem = Problem.couldNotReadTasks.sentence }
            return false
        }
        return written
    }

    /// The rows the model draws, the blocks' and the strip's, which an id a view sends is checked against.
    private var drawnRows: [Model.Row] {
        let model = state.model
        return TaskList.blocks(in: model.layout).flatMap(\.rows) + model.doneRows
    }

    /// Whether the model draws a task, as a row or as the open card.
    private func isDrawn(_ id: TaskID) -> Bool {
        drawnRows.contains { $0.id == id }
    }

    // MARK: - The check and the strip

    /// Writes a drawn task done, or open where it is not, with no timer and no done task kept among the rows: the
    /// strip's check is the undo (spec section 3). The open card's own task goes through what the card holds.
    private func check(_ id: TaskID) {
        guard isDrawn(id), let task = state.task(id) else { return }
        let status: TaskStatus = task.status == .open ? .done : .open
        guard state.card?.id == id else {
            writeAndReread { () throws(StoreError) in try store.update(task: id, [.status(status)]) }
            return
        }
        if cardHoldsNothing() { dismissCard() } else { saveCard(setting: status, withSubtask: true) }
    }

    /// Opens and closes the strip, session state; closing it closes a card under it by the rule of every close. It
    /// answers nothing a person was told, so the sentence stays.
    private func toggleDoneStrip() {
        guard model.done != nil else { return }
        state.isDoneOpen.toggle()
        closeCardIfHidden()
    }

    // MARK: - Adding a task

    /// The floating "+": a new task at the top of the block it adds to, by what that block's rule asks (spec section 4;
    /// the controller's ruling on #176, 2026-11-05). The card that was open closes first, which can change which block
    /// that is, and a close the store refused stops the add, so that its sentence stands; the card is closed, so a
    /// second tap adds.
    private func addFromFloatingButton() {
        guard model.addTask != nil else { return }
        state.problem = nil
        closeCard()
        guard state.problem == nil else { return }
        let target = TaskList.floatingTarget(
            in: state.pageBlocks, of: state.snapshot, head: state.head, today: state.day.day
        )
        guard let target else { return }
        addTask(target.edit, at: .start, onTopOf: target.view)
    }

    /// "+ Add task": a new task at the end of its block, by what the block's rule asks (spec section 4). The block's
    /// edit is read before the card that was open closes, which can take the block with it, a day whose one task it
    /// was; a close the store refused stops the add, as the floating "+"'s does.
    private func addFromRow(in id: Model.BlockID) {
        guard TaskList.blocks(in: model.layout).first(where: { $0.id == id })?.addTask != nil,
              let edit = state.pageBlocks.first(where: { $0.id == id })?.edit
        else { return }
        state.problem = nil
        closeCard()
        guard state.problem == nil else { return }
        addTask(edit, at: .end, onTopOf: nil)
    }

    /// Writes a new empty task with what the edit gives it and the tags picked in the tag bar but one the rule takes
    /// off, pinned where it pins. `onTopOf` names the view whose top it must stand at, where it does not pin: it is
    /// pinned first there unless that view orders by rank with an empty manual list, where its rank at `.start` is the
    /// top already, and a pin would put the `.start` tasks quick entry and the command line write under it (the
    /// controller's ruling on #176, 2026-11-05). A pin refused takes the task back, so that the sentence saying nothing
    /// was written is true. Its card opens, its block unfolding in the list if it was folded, columns not folding (spec
    /// section 5); and a task that landed nowhere the screen draws has no card to close, so it is taken back, and not
    /// left behind untitled.
    private func addTask(_ edit: TaskEdit, at placement: Placement, onTopOf view: TaskView?) {
        let new = NewTask(
            title: "", when: edit.when ?? nil, deadline: edit.deadline ?? nil,
            tags: edit.addTags.union(state.picks.subtracting(edit.removeTags))
        )
        var created: TaskID?
        let written = writeAndReread { () throws(StoreError) in
            let id = try store.createTask(new, at: placement)
            do throws(StoreError) {
                if let list = edit.pinIn {
                    try store.pin(task: id, in: list, at: placement)
                } else if let view, try !isAtTheTopAlready(of: view) {
                    try store.pin(task: id, in: view.id, at: .start)
                }
            } catch {
                try? store.delete(task: id)
                throw error
            }
            created = id
        }
        guard written, let created else { return }
        state.card = OpenCard(id: created, typedTitle: nil, notes: "", typedNotes: nil, subtasks: [], subtaskDraft: nil)
        unfoldTheBlocks(of: created)
        if !isDrawn(created) {
            state.card = nil
            writeAndReread { () throws(StoreError) in try store.delete(task: created) }
        }
    }

    /// Whether a task created at `.start` stands first in a view: where it orders by rank, an empty sort doing so too
    /// (`FilterCompiler.orderBy`), and no task is pinned above it.
    private func isAtTheTopAlready(of view: TaskView) throws(StoreError) -> Bool {
        let ordersByRank = view.sort.first.map { $0.field == .rank && !$0.descending } ?? true
        guard ordersByRank else { return false }
        return try store.manualList(of: view.id).isEmpty
    }

    /// Unfolds the blocks a new task landed in, in the list: columns do not fold, and a task added on the board leaves
    /// the fold the list keeps (spec section 5).
    private func unfoldTheBlocks(of id: TaskID) {
        guard case .list = model.layout else { return }
        let landed = state.pageBlocks.filter { $0.tasks.contains { $0.id == id } }
        let keys = landed.compactMap { TaskList.foldKey(of: $0.id) }
        if !state.folded.isDisjoint(with: keys) { setFolded(state.folded.subtracting(keys)) }
    }

    // MARK: - Adding a list

    /// The name of the list just made, being typed in its header (spec section 4).
    struct ListNaming {
        let id: ViewID
        var draft: String
    }

    /// "+ Add list": a manual list inside this one, last among its lists, in its colour, with its name's field open in
    /// its header on the title it was made with (spec section 4). A name being typed is settled and the card that was
    /// open closes first, and a write the store refused there stops the add, as the floating "+"'s does.
    private func addList() {
        let model = model
        let offered = switch model.layout {
        case .list: model.addList
        case .columns(let board): board.addList
        }
        guard offered != nil else { return }
        state.problem = nil
        settleListName()
        closeCard()
        guard state.problem == nil else { return }
        let title = "New list"
        var made: ViewID?
        let color = state.snapshot.page.view.color
        let written = writeAndReread { () throws(StoreError) in
            made = try store.createManualList(title, in: state.head.view, color: color)
        }
        if written, let made { state.naming = ListNaming(id: made, draft: title) }
    }

    /// What is typed into the name's field. A field's echo of its text is no keystroke, as the card's is not.
    private func typeListName(_ text: String) {
        guard let naming = state.naming, text != naming.draft else { return }
        state.naming?.draft = text
        state.problem = nil
    }

    /// Return or leaving the field keeps what was typed, trimmed, and an empty name keeps the old, as a rename on the
    /// Lists screen does (spec section 4); the field closes either way, and a name that did not change writes nothing.
    private func settleListName() {
        guard let naming = state.naming else { return }
        state.naming = nil
        let title = naming.draft.trimmed()
        let current = state.snapshot.page.sections.first { $0.view?.id == naming.id }?.view?.title
        guard !title.isEmpty, title != current else { return }
        writeAndReread { () throws(StoreError) in try store.update(view: naming.id, [.title(title)]) }
    }

    // MARK: - Deleting

    /// Puts a task in the Trash, with no confirmation, since the Trash gives it back (spec section 6), where the model
    /// draws the control the action came from: a row of the Trash, and an open card, have none (the controller's ruling
    /// on #176, 2026-11-05).
    private func trash(_ id: TaskID, offeredBy action: UserAction) {
        let isOffered = drawnRows.contains { row in
            guard case .task(_, let model) = row else { return false }
            return model.swipe?.action == action
                || model.menu?.sections.contains { $0.items.contains { $0.action == action } } == true
        }
        guard isOffered else { return }
        writeAndReread { () throws(StoreError) in try store.trash(task: id) }
    }

    // MARK: - The open card

    // What the open card does (spec sections 3 and 4; the controller's ruling on #176, 2026-11-05). A card closes by a
    // tap beside it, on another row, Esc or Return on an empty title, on "+", on "+ Add list", and where a fold, a pick
    // or the strip hides its row. Every close writes what was typed, and an empty title is never written: a task with
    // no title and nothing else in it goes, since nothing was put in it; one with something in it, notes or a subtask,
    // stays with its title empty, a row a person can open and name or delete; and one whose title was cleared keeps it,
    // as a list's empty name keeps the old.

    /// Opens a row the model draws as one, closing the card that was open: the notes and the children are read here,
    /// since the list's read carries neither (spec section 3). A row's tap on a task a peer has deleted says so and
    /// opens nothing.
    private func openCard(on id: TaskID) {
        let isRow = drawnRows.contains { row in
            if case .task(let rowID, _) = row { rowID == id } else { false }
        }
        guard isRow else { return }
        state.problem = nil
        closeCard()
        do {
            let notes = try store.notes(of: id)
            let subtasks = try store.children(of: id)
            state.card = OpenCard(
                id: id, typedTitle: nil, notes: notes, typedNotes: nil, subtasks: subtasks, subtaskDraft: nil
            )
        } catch {
            state.problem = (error == .notFound(id) ? Problem.taskIsGone : .couldNotReadTask).sentence
        }
    }

    /// Whether nothing was put in the open card: no title, no notes and no subtask, stored or typed, a draft of spaces
    /// being nothing. Its task is the one a close deletes, since a task with anything in it is someone's (spec section
    /// 4; the controller's ruling on #176, 2026-11-05).
    private func cardHoldsNothing() -> Bool {
        guard let card = state.card, let task = state.task(card.id) else { return false }
        func isBlank(_ text: String?) -> Bool { text?.trimmed().isEmpty != false }
        return isBlank(task.title) && isBlank(card.typedTitle) && !task.hasNotes && isBlank(card.typedNotes)
            && card.subtasks.isEmpty && isBlank(card.subtaskDraft)
    }

    /// Closes the card by the rule of every close: what was typed written, and the task deleted where nothing was put
    /// in it. A failed write says so and the card closes all the same, as a rename's field does
    /// (`TaskViewList.commit`).
    private func closeCard() {
        guard let card = state.card else { return }
        if cardHoldsNothing() {
            state.card = nil
            writeAndReread { () throws(StoreError) in try store.delete(task: card.id) }
        } else {
            saveCard(withSubtask: true)
            state.card = nil
        }
    }

    /// A gesture on the card that closes it, which takes the sentence away, as a gesture on the list does.
    private func dismissCard() {
        guard state.card != nil else { return }
        state.problem = nil
        closeCard()
    }

    /// Closes the card where its row is no longer drawn, a fold, a pick or the strip having hidden it (the controller's
    /// ruling on #176, 2026-11-05).
    private func closeCardIfHidden() {
        if let card = state.card, !isDrawn(card.id) { closeCard() }
    }

    /// Writes what the card's fields hold, and `status` with them, in one transaction, with the subtask being typed
    /// after them where `withSubtask` says so; what held the fields then show as the store keeps it. A blank title is
    /// not written and stays typed, and nothing that changes nothing is written.
    private func saveCard(setting status: TaskStatus? = nil, withSubtask: Bool = false) {
        guard let card = state.card, let task = state.task(card.id) else { return }
        let title = card.typedTitle?.trimmed()
        var changes: [TaskChange] = []
        if let title, !title.isEmpty, title != task.title { changes.append(.title(title)) }
        if let notes = card.typedNotes, notes != card.notes { changes.append(.notes(notes)) }
        if let status { changes.append(.status(status)) }
        let subtask = withSubtask ? card.subtaskDraft?.trimmed() : nil
        let hasSubtask = subtask?.isEmpty == false
        let held = (changes.isEmpty && !hasSubtask) || writeAndReread { () throws(StoreError) in
            try store.update(task: card.id, changes)
            if hasSubtask, let subtask { try store.createTask(NewTask(title: subtask, parent: card.id), at: .end) }
        }
        guard held else { return }
        if title?.isEmpty == false { state.card?.typedTitle = nil }
        if let notes = card.typedNotes {
            state.card?.notes = notes
            state.card?.typedNotes = nil
        }
        if withSubtask { state.card?.subtaskDraft = nil }
    }

    /// What is typed into the title. A field writes the text it holds back through its binding, and again after Return
    /// and after a lost focus, so a text it already holds is no keystroke and takes no sentence away (`TaskViewList`,
    /// by hand on 2026-10-12).
    private func typeTitle(_ text: String) {
        guard let card = state.card, let task = state.task(card.id), text != card.typedTitle ?? task.title else {
            return
        }
        state.card?.typedTitle = text
        state.problem = nil
    }

    /// Return in the title: with text it writes it and leaves the card open, and on an empty title it closes the card
    /// (canvas; the controller's ruling on #176, 2026-11-05).
    private func submitTitle() {
        guard let card = state.card, let task = state.task(card.id) else { return }
        if (card.typedTitle ?? task.title).trimmed().isEmpty { dismissCard() } else { saveCard() }
    }

    /// What is typed into the notes, as the title's text is taken.
    private func typeNotes(_ text: String) {
        guard let card = state.card, text != card.typedNotes ?? card.notes else { return }
        state.card?.typedNotes = text
        state.problem = nil
    }

    /// Writes a subtask of the card's task done or open, which moves nothing else: completing the last subtask leaves
    /// the parent open (spec section 3).
    private func checkSubtask(_ id: TaskID) {
        guard let subtask = state.card?.subtasks.first(where: { $0.id == id }) else { return }
        let status: TaskStatus = subtask.status == .open ? .done : .open
        writeAndReread { () throws(StoreError) in try store.update(task: id, [.status(status)]) }
    }

    /// "Add subtask" opens an empty field, one at a time.
    private func openSubtaskField() {
        guard state.card != nil, state.card?.subtaskDraft == nil else { return }
        state.card?.subtaskDraft = ""
        state.problem = nil
    }

    /// What is typed into the subtask's field, as the title's text is taken.
    private func typeSubtask(_ text: String) {
        guard let draft = state.card?.subtaskDraft, text != draft else { return }
        state.card?.subtaskDraft = text
        state.problem = nil
    }

    /// Return or leaving the field writes what was typed, trimmed, at the end of the subtasks, and Return opens the
    /// next empty field; with nothing typed the field closes (spec section 3; canvas). A refused write leaves the field
    /// and what was typed.
    private func writeSubtask(thenOpensNext opensNext: Bool) {
        guard let card = state.card, let draft = card.subtaskDraft else { return }
        let title = draft.trimmed()
        guard !title.isEmpty else {
            state.card?.subtaskDraft = nil
            return
        }
        let written = writeAndReread { () throws(StoreError) in
            try store.createTask(NewTask(title: title, parent: card.id), at: .end)
        }
        if written { state.card?.subtaskDraft = opensNext ? "" : nil }
    }

    /// Open full screen writes what the card holds, leaves it open (canvas; the controller's ruling on #176,
    /// 2026-11-05) and declares the task screen over the list, as a link to the task does, so a screen that cannot be
    /// made says so when the stack tells the list.
    private func openFullScreen() {
        guard let id = state.card?.id else { return }
        state.problem = nil
        saveCard(withSubtask: true)
        setDestination(.task(TaskScreen.Route(head: id)))
    }

    // MARK: - The drop

    // A row let go (spec section 6; the controller's ruling on #176, 2026-11-05): in the block it was dragged from it
    // takes that place by the manual list, and in another block it takes what that block's rule asks. The writes of a
    // move are several transactions, each a change a window rereads for; a task's writes are skipped where they change
    // nothing, which is what keeps the rereads few.

    /// Checks a drop against the model: both blocks drawn, the task a row of the one it was dragged from, the other
    /// taking a drop, and `anchor` a row of it other than the task. Anything else writes nothing.
    private func drop(_ id: TaskID, from source: Model.BlockID, in target: Model.BlockID, after anchor: TaskID?) {
        let drawn = TaskList.blocks(in: model.layout)
        guard let drawnSource = drawn.first(where: { $0.id == source }),
              let drawnTarget = drawn.first(where: { $0.id == target }),
              drawnSource.rows.contains(where: { $0.id == id }), drawnTarget.takesDrop,
              anchor != id, anchor.map({ anchor in drawnTarget.rows.contains { $0.id == anchor } }) != false
        else { return }
        let blocks = state.pageBlocks
        guard let from = blocks.first(where: { $0.id == source }), let to = blocks.first(where: { $0.id == target }),
              let task = from.tasks.first(where: { $0.id == id })
        else { return }
        if source == target { reorder(id, in: to, after: anchor) } else { move(task, from: from, to: to) }
    }

    /// Takes its place in its own block: the task and the unpinned tasks that stand above the place, in their order,
    /// are pinned in one transaction, after the last pinned task above it or first, so that it lands where it was let
    /// go and keeps it, the manual list being the view's and applied within a group (spec section 6). The order read is
    /// the page's block's, before the tag bar's filter, so that the tasks a pick hides keep their places (the
    /// controller's ruling on #176, 2026-11-05).
    private func reorder(_ id: TaskID, in block: PageBlock, after anchor: TaskID?) {
        let order = block.tasks.map(\.id)
        let others = order.filter { $0 != id }
        let place = anchor.flatMap { others.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
        guard order.firstIndex(of: id) != place else { return }
        let view = block.id.view(under: state.head)
        writeAndReread { () throws(StoreError) in
            let pinned = Set(try store.manualList(of: view))
            let above = others[..<place]
            let unpinned = above.filter { !pinned.contains($0) }
            let placement = above.last { pinned.contains($0) }.map(Placement.after) ?? .start
            try store.pin(tasks: unpinned + [id], in: view, at: placement)
        }
    }

    /// Takes what the target's rule asks, its day through `update(task:)`, its tags, its pin last in its manual list
    /// (spec section 6's table), and gives back the tags and the pins of the lists it was dragged out of: a list
    /// inside's, and a folder's every list's, so that it leaves the block it came from whichever of them held it. An
    /// own block gives nothing back, a day block's task leaving by its new day and an own block's by being claimed; a
    /// list whose rule reads as no edit gives nothing back; and what the target asks is not given back. A task two
    /// blocks draw leaves only the one it was dragged from, and the target's fold stays (the controller's ruling on
    /// #176, 2026-11-05).
    private func move(_ task: TodoTask, from source: PageBlock, to target: PageBlock) {
        guard let edit = target.edit else { return }
        let view = state.snapshot.page.view
        let ownDay: GroupBy? = if case .own(.day?) = target.id { view.groupBy } else { nil }
        let changes = edit.dayChanges(of: task, rule: target.rule, ownDay: ownDay, today: state.day.day)
        let givenBack = source.listRules.compactMap { TaskEdit.of($0, today: state.day.day, day: nil) }
        let leaving = edit.removeTags.union(givenBack.flatMap(\.addTags)).subtracting(edit.addTags)
        var unpinning = edit.unpinFrom.union(givenBack.compactMap(\.pinIn))
        if let list = edit.pinIn { unpinning.remove(list) }
        writeAndReread(refusal: .couldNotMove) { () throws(StoreError) in
            try store.update(task: task.id, changes)
            for tag in edit.addTags.subtracting(task.tags) { try store.add(tag: tag, to: task.id) }
            for tag in leaving.intersection(task.tags) { try store.remove(tag: tag, from: task.id) }
            if let list = edit.pinIn { try store.pin(task: task.id, in: list, at: .end) }
            for list in unpinning where try store.manualList(of: list).contains(task.id) {
                try store.unpin(task: task.id, from: list)
            }
        }
    }

    // MARK: - The read

    /// Takes a read of the store as the page on screen, its view's title the header's, with the folds the device keeps
    /// read again beside it, so that a fold another window of this device made since is drawn here and kept by the next
    /// fold made here, as the sidebar reads its folds with its rows (ADR-0010); a group's screen keeps none. The layout
    /// is not read again: it is one value, the last one chosen wins, and a window would change its layout on a change
    /// to anything. It drops the picks whose chips are no longer on the bar, which stop filtering and come back unlit
    /// (the controller's ruling on #175, 2026-11-04). The folds and the open card's subtasks are read before anything
    /// is assigned, so a read that fails leaves what is on screen.
    ///
    /// A card stays while its row is drawn, and a read that no longer finds it drops it with no write: this answers a
    /// change as well as a write, and a module never writes in answer to a change (ADR-0009; the controller's ruling on
    /// #176, 2026-11-05). A list being named goes with its block.
    private func take(_ snapshot: PageSnapshot) throws(StoreError) {
        let folded = state.head.group == nil ? try TaskList.keptFolds(in: store, of: state.head.view) : []
        let subtasks = try state.card.map { card throws(StoreError) in try store.children(of: card.id) }
        let blocks = TaskList.blocks(of: snapshot, head: state.head, today: state.day.day)
        let chips = TaskList.chips(in: blocks, tags: snapshot.tags)
        state.snapshot = snapshot
        state.title = snapshot.page.view.title
        state.folded = folded
        state.picks.formIntersection(chips.map(\.id))
        if let subtasks { state.card?.subtasks = subtasks }
        if let card = state.card, !isDrawn(card.id) { state.card = nil }
        if let naming = state.naming, !blocks.contains(where: { $0.id == .list(naming.id) }) { state.naming = nil }
    }

    /// Declares the task screen or a list over the list, or nothing: a tap, a route, the way back and the stack's
    /// notices each arrive here, so what a tap opens and what a link opens cannot drift apart (spec section 3). Every
    /// call is a new write, which the window's stack follows at the walk after the event.
    private func setDestination(_ tail: Route.Tail?) {
        state.destination.declare(tail.map { .pushed($0) })
    }

    /// Folds and unfolds the blocks to the set, written to the device's state first and kept after (ADR-0010), as the
    /// sidebar's folds are: only the keys of the blocks drawn now are written, so that a day's key goes once the day
    /// has no block.
    private func setFolded(_ folded: Set<String>) {
        // A write that fails is not said: the fold stays on screen until the next list made on the view reads what was
        // kept, and this module's sentences stay for the data a person edits, which a fold is not. Sorted, so that the
        // same folds are the same text in the file.
        try? store.setDeviceState(TaskList.foldedKey(of: state.head.view), folded.sorted())
        state.folded = folded
    }

    /// The blocks a layout draws, a list's or the board's columns.
    private static func blocks(in layout: Model.Layout) -> [Model.Block] {
        switch layout {
        case .list(let blocks): blocks
        case .columns(let board): board.columns
        }
    }

    /// The folded blocks of the view as the device's state keeps them, by their keys (`foldKey(of:)`). What was kept
    /// is the device's and may be stale: a key no block has now draws nothing, and the next fold writes the set back
    /// without it. A value that does not decode as a list of texts reads as nothing folded, which the store decides.
    private static func keptFolds(in store: Store, of view: ViewID) throws(StoreError) -> Set<String> {
        Set(try store.deviceState(foldedKey(of: view), as: [String].self) ?? [])
    }

    /// The layout the device keeps for the view, and the list when it keeps none.
    private static func keptLayout(in store: Store, of view: ViewID) throws(StoreError) -> Model.Layout.Kind {
        try store.deviceState(layoutKey(of: view), as: Model.Layout.Kind.self) ?? .list
    }

    /// The keys the folds and the layout of a list are kept under in the device's own state, one each per list: the
    /// module's name, what it keeps and the view's id. A write of either reports no change set, which the store's
    /// writes of a device's state never do: they are one screen's own, and another window of the same device reads
    /// them when it next makes a list on the view (spec section 9; ADR-0010).
    private static func foldedKey(of view: ViewID) -> String { "taskList.folded.\(view.rawValue)" }
    private static func layoutKey(of view: ViewID) -> String { "taskList.layout.\(view.rawValue)" }

    /// The sentence what the list declared over itself reads as when it could not be made, by what it declared.
    /// `.notFound` is what was declared being gone, which is what a link written before a delete, or a tap on a row a
    /// peer's delete has not yet reached, looks like from here: the task, the list inside, or a group's tag or parent.
    /// A group refused as `.invalid` names a grouping its list does not have, a link that outlived the grouping it
    /// names (ADR-0009, amendment of 2026-11-02). Anything else is the store failing to read what may well be there,
    /// and calling that "gone" would put on screen something that is not true (the controller's ruling on #175,
    /// 2026-11-04).
    private static func problem(_ error: StoreError, declared: Route.Tail?) -> Problem {
        switch (declared, error) {
        case (.list(let route)?, .notFound): route.head.group == nil ? .listIsGone : .groupIsGone
        case (.list(let route)?, .invalid): route.head.group == nil ? .couldNotOpenList : .notGroupedThatWay
        case (.list(let route)?, _): route.head.group == nil ? .couldNotOpenList : .couldNotOpenGroup
        case (.task?, .notFound), (nil, .notFound): .taskIsGone
        case (.task?, _), (nil, _): .couldNotReadTask
        }
    }

    /// Everything the list holds between two events: its head; its view's title, which a change naming the view gives
    /// it even when the page's read fails; the snapshot of the store the blocks, the tile, the rule and the strip are
    /// read from, and the device's day it was taken by; the folds and the layout the device keeps, and what this
    /// session keeps, the picked tags, the open card, whether the strip is open and the list being named; what it
    /// declared over itself; and the sentence a person was last told. One value, moved field by field, and the one
    /// place any of it is kept: the model is assembled from it on every read, in `model` and nowhere else (owner's
    /// reviews of #77, #101 and #188).
    ///
    /// The destination is a field of the state, because what a screen declared over it is the navigation state, which
    /// the window's stack follows (ADR-0009, amendment of 2026-10-22, point 2).
    private struct State {
        let head: Route.Head
        var title: String
        var snapshot: PageSnapshot
        var day: DeviceDay
        var folded: Set<String>
        var layout: Model.Layout.Kind
        var picks: Set<TagID>
        var card: OpenCard?
        var isDoneOpen: Bool
        var naming: ListNaming?
        var destination: Destination<Route.Tail>
        var problem: String?

        /// The blocks of the page as this snapshot reads them, before the tag bar's filter.
        var pageBlocks: [PageBlock] {
            TaskList.blocks(of: snapshot, head: head, today: day.day)
        }

        /// A task of the snapshot, in a section of the page or in the strip, finished or not, whatever the tag bar and
        /// the folds leave.
        func task(_ id: TaskID) -> TodoTask? {
            for section in snapshot.page.sections {
                for group in section.groups {
                    if let task = group.tasks.first(where: { $0.id == id }) { return task }
                }
            }
            return snapshot.done.first { $0.id == id }
        }

        /// The model a view draws, assembled here and nowhere else: the blocks of the page, the chips of their open
        /// tasks and the rows the picked ones leave, the layout the list is shown as where Show as offers Columns and
        /// the list otherwise, a block's fold where it has a header to fold by, and the header, Show as, the empty
        /// state, the strip and what stands under it, the floating "+", "+ Add list" and the sentence.
        ///
        /// Columns are offered where the list groups or has more than one block, and never on a group's screen, which
        /// has one block and no grouping (spec section 5; the controller's ruling on #175, 2026-11-04). The empty state
        /// stands when no block has a row after the filter and the page has no lists inside (canvas, the empty state;
        /// the controller's ruling on #175, 2026-11-04).
        var model: Model {
            let view = snapshot.page.view
            let today = day.day
            let blocks = pageBlocks
            let chips = TaskList.chips(in: blocks, tags: snapshot.tags)
            let picked = picks.intersection(chips.map(\.id))
            func kept(_ tasks: [TodoTask]) -> [TodoTask] {
                picked.isEmpty ? tasks : tasks.filter { !$0.tags.isDisjoint(with: picked) }
            }
            let shown = blocks.map { $0.keeping(kept($0.tasks)) }
            let canBoard = head.group == nil && (view.groupBy != nil || blocks.count > 1)
            let shape = canBoard ? layout : .list
            let metrics = Metrics.of(shape)
            let color = TaskList.tileColor(view.color)
            let icon = TaskList.tileIcon(view.icon)
            let tags = TagNames(snapshot.tags)
            let context = RowContext(today: today, tags: tags, card: card, naming: naming)
            let hasListsInside = blocks.contains { if case .list = $0.id { true } else { false } }
            let heading = TaskList.screenHeading(
                head: head, title: title, rule: view.filter, snapshot: snapshot, today: today
            )
            let empty = shown.allSatisfy(\.tasks.isEmpty) && !hasListsInside
                ? TaskList.empty(
                    TaskList.emptyWords(head: head, view: view, tags: tags), color: color, icon: icon, metrics.empty
                )
                : nil
            let addList = head.group == nil && view.filter.map(TaskList.drawsFinished) != true
                ? TaskList.addListRow(metrics.addList)
                : nil
            let done = TaskList.doneStrip(
                kept(snapshot.done), isOpen: isDoneOpen, color: color, context, metrics.blocks
            )
            return Model(
                header: TaskList.header(heading, color: color, icon: icon, metrics.header),
                tagBar: TaskList.tagBar(chips, picked: picked, colors: color.check, metrics.tagBar),
                layout: TaskList.layout(
                    shown, title: title, folded: folded, addList: addList, context, metrics.blocks
                ),
                showAs: TaskList.showAs(canBoard: canBoard),
                empty: empty,
                done: done.strip,
                doneRows: done.rows,
                addTask: TaskList.floatingTarget(in: blocks, of: snapshot, head: head, today: today).map { _ in
                    TaskList.floatingButton(metrics.floatingButton)
                },
                addList: shape == .list ? addList : nil,
                problem: problem
            )
        }
    }

    /// What can go wrong in this module, with the sentence each one reads as. The store's own error stays here:
    /// it names SQLite codes and journal rows, which is what a bug report is made of and not what a person can
    /// do anything about.
    private enum Problem {
        case couldNotSave
        case couldNotMove
        case taskIsGone
        case couldNotReadTask
        case couldNotReadTasks
        case listIsGone
        case couldNotOpenList
        case notGroupedThatWay
        case groupIsGone
        case couldNotOpenGroup

        var sentence: String {
            switch self {
            case .couldNotSave: "The change could not be saved, so nothing was written."
            case .couldNotMove: "The task could not be moved, so it may have moved only in part."
            case .taskIsGone: "The task is gone."
            case .couldNotReadTask: "The task could not be read."
            case .couldNotReadTasks: "The tasks could not be read, so this list may be out of date."
            case .listIsGone: "The list is gone."
            case .couldNotOpenList: "The list could not be opened."
            case .notGroupedThatWay: "This list is not grouped that way, so the group could not be opened."
            case .groupIsGone: "The group is gone."
            case .couldNotOpenGroup: "The group could not be opened."
            }
        }
    }
}
