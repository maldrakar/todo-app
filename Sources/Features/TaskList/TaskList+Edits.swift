// Sources/Features/TaskList/TaskList+Edits.swift
import TodoCore

/// The screen's writes but the card's and the drop's (`TaskList+CardEdits.swift`, `TaskList+Drop.swift`): the check and
/// the Done strip, the floating "+" and "+ Add task", "+ Add list" and its name, and Delete (spec sections 3, 4 and 6).
/// Each answers a person's action and none a change (ADR-0009), and every id a view sends is checked against the model.
extension TaskList {
    /// Writes, says what the store refused, and reads the page back at once, as the sidebar's writes do
    /// (`TaskViewList.writeAndReread`), so that a new task's card has its row; `.changed` rereads again as it always
    /// has (the controller's ruling on #176, 2026-11-05). The page is read back after a refusal too, since what the
    /// store refused can be a peer's change the module has not heard of yet. A write that held takes the sentence away;
    /// a read that fails says the list may be out of date only when nothing else was said. Answers whether both held.
    @discardableResult
    func writeAndReread(refusal: Problem = .couldNotSave, _ write: () throws(StoreError) -> Void) -> Bool {
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
    var drawnRows: [Model.Row] {
        let model = state.model
        return TaskList.blocks(in: model.layout).flatMap(\.rows) + model.doneRows
    }

    /// Whether the model draws a task, as a row or as the open card.
    func isDrawn(_ id: TaskID) -> Bool {
        drawnRows.contains { $0.id == id }
    }

    // MARK: - The check and the strip

    /// Writes a drawn task done, or open where it is not, with no timer and no done task kept among the rows: the
    /// strip's check is the undo (spec section 3). The open card's own task goes through what the card holds.
    func check(_ id: TaskID) {
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
    func toggleDoneStrip() {
        guard model.done != nil else { return }
        state.isDoneOpen.toggle()
        closeCardIfHidden()
    }

    // MARK: - Adding a task

    /// The "+", the phone's floating one and the pane's glass one, which send the same action: a new task at the top of
    /// the block it adds to, by what that block's rule asks (spec section 4; the controller's ruling on #176,
    /// 2026-11-05). A list that takes no task has neither "+", the target being the one condition that decides both.
    /// The card that was open closes first, which can change which block that is, and a close the store refused stops
    /// the add, so that its sentence stands; the card is closed, so a second tap adds. The page's blocks are built once
    /// for the action, and again only if a card was open, whose close can change them.
    func addFromButton() {
        func target() -> (edit: TaskEdit, view: TaskView)? {
            TaskList.floatingTarget(in: state.pageBlocks, of: state.snapshot, head: state.head, today: state.day.day)
        }
        let first = target()
        guard first != nil else { return }
        let hadCard = state.card != nil
        state.problem = nil
        closeCard()
        guard state.problem == nil, let target = hadCard ? target() : first else { return }
        addTask(target.edit, at: .start, onTopOf: target.view)
    }

    /// "+ Add task": a new task at the end of its block, by what the block's rule asks (spec section 4). The block's
    /// edit is read before the card that was open closes, which can take the block with it, a day whose one task it
    /// was; a close the store refused stops the add, as the floating "+"'s does.
    func addFromRow(in id: Model.BlockID) {
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
            title: "", when: edit.when?.day, deadline: edit.deadline?.day,
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
    func addList() {
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
    func typeListName(_ text: String) {
        guard let naming = state.naming, text != naming.draft else { return }
        state.naming?.draft = text
        state.problem = nil
    }

    /// Return or leaving the field keeps what was typed, trimmed, and an empty name keeps the old, as a rename on the
    /// Lists screen does (spec section 4); the field closes either way, and a name that did not change writes nothing.
    func settleListName() {
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
    func trash(_ id: TaskID, offeredBy action: UserAction) {
        let isOffered = drawnRows.contains { row in
            guard case .task(_, let model) = row else { return false }
            return model.swipe?.action == action
                || model.menu?.sections.contains { $0.items.contains { $0.action == action } } == true
        }
        guard isOffered else { return }
        writeAndReread { () throws(StoreError) in try store.trash(task: id) }
    }
}
