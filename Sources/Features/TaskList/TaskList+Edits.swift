// Sources/Features/TaskList/TaskList+Edits.swift
import TaskScreenFeature
import TodoCore

/// The screen's writes but the card's and the drop's (`TaskList+CardEdits.swift`, `TaskList+Drop.swift`): the check and
/// the Done strip, the floating "+" and "+ Add task", "+ Add list" and its name, and Delete (spec sections 3, 4 and 6).
/// Each answers a person's action and none a change (ADR-0009), and every id a view sends is checked against the model.
extension TaskList {
    /// Writes, says what the store refused, and reads the page back at once, as the sidebar's writes do
    /// (`TaskViewList.writeAndReread`), so that a new task's card has its row; `.changed` rereads again as it always has
    /// (the controller's ruling R85). The page is read back after a refusal too, since what the store refused can be a
    /// peer's change the module has not heard of yet. A write that held takes the sentence away; a read that fails says the
    /// list may be out of date only when nothing else was said. Answers whether both held.
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

    /// Writes a drawn task done, or open where it is not, with no timer and no done task kept among the rows: the strip's
    /// check is the undo (spec section 3). The open card's own task goes through what the card holds.
    func check(_ id: TaskID) {
        guard isDrawn(id), let task = state.task(id) else { return }
        let status: TaskStatus = task.status == .open ? .done : .open
        guard state.card?.id == id else {
            writeAndReread { () throws(StoreError) in try store.update(task: id, [.status(status)]) }
            return
        }
        if cardIsUntitled() { dismissCard() } else { saveCard(setting: status, withSubtask: true) }
    }

    /// Opens and closes the strip, session state; closing it closes a card under it by the rule of every close. It answers
    /// nothing a person was told, so the sentence stays.
    func toggleDoneStrip() {
        guard model.done != nil else { return }
        state.isDoneOpen.toggle()
        closeCardIfHidden()
    }

    // MARK: - Adding a task

    /// The floating "+": a new task at the top of the block it adds to, by what that block's rule asks (spec section 4; the
    /// controller's ruling R81). The card that was open closes first, which can change which block that is.
    func addFromFloatingButton() {
        guard model.addTask != nil else { return }
        state.problem = nil
        closeCard()
        let target = TaskList.floatingTarget(
            in: state.pageBlocks, head: state.head, rule: state.snapshot.page.view.filter, today: state.day.day
        )
        guard let target else { return }
        addTask(target.edits, at: .start, onTopOf: target.view)
    }

    /// "+ Add task": a new task at the end of its block, by what the block's rule asks (spec section 4). The block's edits
    /// are read before the card that was open closes, which can take the block with it, a day whose one task it was.
    func addFromRow(in id: Model.BlockID) {
        guard TaskList.blocks(in: model.layout).first(where: { $0.id == id })?.addTask != nil,
              let edits = state.pageBlocks.first(where: { $0.id == id })?.edits
        else { return }
        state.problem = nil
        closeCard()
        addTask(edits, at: .end, onTopOf: nil)
    }

    /// Writes a new empty task with what the edits give it and the tags picked in the tag bar but one the rule takes off,
    /// pinned where they pin; `onTopOf` names the view whose manual list it must stand above, where they do not pin and
    /// that view has one, an unpinned task landing under the pinned ones (the controller's ruling R81). Its card opens,
    /// its block unfolding if it was folded (the controller's ruling R82); and a task that landed nowhere the screen draws
    /// has no card to close, so it is taken back, and not left behind untitled.
    private func addTask(_ edits: Edits, at placement: Placement, onTopOf view: ViewID?) {
        let new = NewTask(
            title: "", when: edits.when ?? nil, deadline: edits.deadline ?? nil,
            tags: edits.addTags.union(state.picks.subtracting(edits.removeTags))
        )
        var created: TaskID?
        let written = writeAndReread { () throws(StoreError) in
            let id = try store.createTask(new, at: placement)
            created = id
            if let list = edits.pinIn {
                try store.pin(task: id, in: list, at: placement)
            } else if let view, try !store.manualList(of: view).isEmpty {
                try store.pin(task: id, in: view, at: .start)
            }
        }
        guard written, let created else { return }
        state.card = OpenCard(id: created, typedTitle: nil, notes: "", typedNotes: nil, subtasks: [], subtaskDraft: nil)
        let landed = state.pageBlocks.filter { $0.tasks.contains { $0.id == created } }
        let keys = landed.compactMap { TaskList.foldKey(of: $0.id) }
        if !state.folded.isDisjoint(with: keys) { setFolded(state.folded.subtracting(keys)) }
        if !isDrawn(created) {
            state.card = nil
            writeAndReread { () throws(StoreError) in try store.delete(task: created) }
        }
    }

    // MARK: - Adding a list

    /// "+ Add list": a manual list inside this one, last among its lists, in its colour, with its name's field open in its
    /// header on the title it was made with (spec section 4). The card that was open closes first.
    func addList() {
        let model = model
        let offered = switch model.layout {
        case .list: model.addList
        case .columns(let board): board.addList
        }
        guard offered != nil else { return }
        state.problem = nil
        closeCard()
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

    /// Return or leaving the field keeps what was typed, trimmed, and an empty name keeps the old, as a rename on the Lists
    /// screen does (spec section 4); the field closes either way, and a name that did not change writes nothing.
    func settleListName() {
        guard let naming = state.naming else { return }
        state.naming = nil
        let title = naming.draft.trimmed()
        let current = state.snapshot.page.sections.first { $0.view?.id == naming.id }?.view?.title
        guard !title.isEmpty, title != current else { return }
        writeAndReread { () throws(StoreError) in try store.update(view: naming.id, [.title(title)]) }
    }

    // MARK: - Deleting

    /// Puts a task in the Trash, with no confirmation, since the Trash gives it back (spec section 6), where the model draws
    /// the control the action came from: a row of the Trash, and an open card, have none (the controller's ruling R73).
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
