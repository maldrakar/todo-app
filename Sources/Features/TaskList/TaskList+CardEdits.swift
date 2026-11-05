// Sources/Features/TaskList/TaskList+CardEdits.swift
import TaskScreenFeature
import TodoCore

/// What the open card does (spec sections 3 and 4; the controller's rulings R82 to R85). A card closes by a tap beside it,
/// on another row, Esc or Return on an empty title, on "+", on "+ Add list", and where a fold, a pick or the strip hides
/// its row. Every close writes what was typed, and an empty title is never written: the task whose stored title is empty
/// too goes, since it never had anything in it, and any other keeps its title, as a list's empty name keeps the old.
extension TaskList {
    /// Opens a row the model draws as one, closing the card that was open: the notes and the children are read here, since
    /// the list's read carries neither (spec section 3). A row's tap on a task a peer has deleted says so and opens nothing.
    func openCard(on id: TaskID) {
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

    /// Whether the open card holds a task with no title stored and none typed, the one a close deletes.
    func cardIsUntitled() -> Bool {
        guard let card = state.card, let task = state.task(card.id) else { return false }
        return task.title.trimmed().isEmpty && (card.typedTitle ?? task.title).trimmed().isEmpty
    }

    /// Closes the card by the rule of every close, what was typed written and the untitled task deleted. A failed write
    /// says so and the card closes all the same, as a rename's field does (`TaskViewList.commit`).
    func closeCard() {
        guard let card = state.card else { return }
        if cardIsUntitled() {
            state.card = nil
            writeAndReread { () throws(StoreError) in try store.delete(task: card.id) }
        } else {
            saveCard(withSubtask: true)
            state.card = nil
        }
    }

    /// A gesture on the card that closes it, which takes the sentence away, as a gesture on the list does.
    func dismissCard() {
        guard state.card != nil else { return }
        state.problem = nil
        closeCard()
    }

    /// Closes the card where its row is no longer drawn, a fold, a pick or the strip having hidden it (the controller's
    /// ruling R82).
    func closeCardIfHidden() {
        if let card = state.card, !isDrawn(card.id) { closeCard() }
    }

    /// Writes what the card's fields hold, and `status` with them, in one transaction, with the subtask being typed after
    /// them where `withSubtask` says so; what held the fields then show as the store keeps it. A blank title is not written
    /// and stays typed, and nothing that changes nothing is written.
    func saveCard(setting status: TaskStatus? = nil, withSubtask: Bool = false) {
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

    /// What is typed into the title. A field writes the text it holds back through its binding, and again after Return and
    /// after a lost focus, so a text it already holds is no keystroke and takes no sentence away (`TaskViewList`, by hand on
    /// 2026-10-12).
    func typeTitle(_ text: String) {
        guard let card = state.card, let task = state.task(card.id), text != card.typedTitle ?? task.title else { return }
        state.card?.typedTitle = text
        state.problem = nil
    }

    /// Return in the title: with text it writes it and leaves the card open, and on an empty title it closes the card
    /// (canvas; the controller's ruling R84).
    func submitTitle() {
        guard let card = state.card, let task = state.task(card.id) else { return }
        if (card.typedTitle ?? task.title).trimmed().isEmpty { dismissCard() } else { saveCard() }
    }

    /// What is typed into the notes, as the title's text is taken.
    func typeNotes(_ text: String) {
        guard let card = state.card, text != card.typedNotes ?? card.notes else { return }
        state.card?.typedNotes = text
        state.problem = nil
    }

    /// Writes a subtask of the card's task done or open, which moves nothing else: completing the last subtask leaves the
    /// parent open (spec section 3).
    func checkSubtask(_ id: TaskID) {
        guard let subtask = state.card?.subtasks.first(where: { $0.id == id }) else { return }
        let status: TaskStatus = subtask.status == .open ? .done : .open
        writeAndReread { () throws(StoreError) in try store.update(task: id, [.status(status)]) }
    }

    /// "Add subtask" opens an empty field, one at a time.
    func openSubtaskField() {
        guard state.card != nil, state.card?.subtaskDraft == nil else { return }
        state.card?.subtaskDraft = ""
        state.problem = nil
    }

    /// What is typed into the subtask's field, as the title's text is taken.
    func typeSubtask(_ text: String) {
        guard let draft = state.card?.subtaskDraft, text != draft else { return }
        state.card?.subtaskDraft = text
        state.problem = nil
    }

    /// Return or leaving the field writes what was typed, trimmed, at the end of the subtasks, and Return opens the next
    /// empty field; with nothing typed the field closes (spec section 3; canvas). A refused write leaves the field and
    /// what was typed.
    func writeSubtask(thenOpensNext opensNext: Bool) {
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

    /// Open full screen writes what the card holds, leaves it open (canvas; the controller's ruling R84) and declares the
    /// task screen over the list, as a link to the task does, so a screen that cannot be made says so when the stack tells
    /// the list.
    func openFullScreen() {
        guard let id = state.card?.id else { return }
        state.problem = nil
        saveCard(withSubtask: true)
        setDestination(.task(TaskScreen.Route(head: id)))
    }
}
