import Testing
import TestSupport
import DesignSystemComponents
import FeatureModule
import TaskListFeature
import TaskScreenFeature
import TodoCore

// The card in place (spec sections 3 and 4; the controller's ruling on #176, 2026-11-05): a tap opens a task where its
// row stood, its fields are written as they are left, a close writes what was typed, and a card lives while its row is
// drawn.

private let inbox = BuiltInTaskViews.inbox

/// A list on the Inbox holding one task with a title, with that task's card open.
private func cardOnATask(_ store: Store, title: String = "Buy milk") throws -> (list: TaskList, id: TaskID) {
    let id = try store.createTask(NewTask(title: title))
    let module = try list(inbox, in: store)
    module.tap(.rowTapped(id))
    return (module, id)
}

/// A tap opens the task where its row stood, one card at a time: the card holds the stored title, the notes and the
/// children the module read when it opened, and a tap on another row closes it.
@Test func aTapOpensTheRowAsACardAndClosesAnyOther() throws {
    let store = try makeStore()
    let first = try store.createTask(NewTask(title: "First", notes: "two of them"))
    let second = try store.createTask(NewTask(title: "Second"))
    try store.createTask(NewTask(title: "A subtask", parent: first))
    let module = try list(inbox, in: store)
    module.tap(.rowTapped(first))
    let opened = try #require(openCard(in: module.model))
    #expect(opened.id == first)
    #expect(opened.card.title.text == "First")
    #expect(opened.card.notes.text == "two of them")
    #expect(opened.card.subtasks.map(\.title.text) == ["A subtask"])
    #expect(opened.card.subtaskField == nil)
    #expect(module.destination.pushed == nil, "a tap no longer pushes")
    module.tap(.rowTapped(second))
    #expect(openCard(in: module.model)?.id == second)
    #expect(rows(of: module.model).map(\.id) == [first, second], "the first is a row again")
}

@Test func theTitleIsWrittenOnSubmitAndOnLeavingTheField() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    module.tap(.titleFieldChanged("Buy oat milk"))
    #expect(openCard(in: module.model)?.card.title.text == "Buy oat milk")
    #expect(try stored(id, in: store).title == "Buy milk", "nothing is written while it is typed")
    module.tap(.titleFieldSubmitted)
    #expect(try stored(id, in: store).title == "Buy oat milk")
    #expect(openCard(in: module.model)?.id == id, "Return with text keeps the card open")
    module.tap(.titleFieldChanged("  Buy soy milk "))
    module.tap(.titleFieldLostFocus)
    #expect(try stored(id, in: store).title == "Buy soy milk", "trimmed")
    #expect(openCard(in: module.model)?.card.title.text == "Buy soy milk")
    #expect(commits(of: store) { module.tap(.titleFieldSubmitted) } == 0, "it did not change")
}

@Test func notesAreWrittenOnLeavingTheField() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    module.tap(.notesFieldChanged(" two, oat "))
    #expect(try store.notes(of: id) == "")
    module.tap(.notesFieldLostFocus)
    #expect(try store.notes(of: id) == " two, oat ", "as typed")
    #expect(openCard(in: module.model)?.card.notes.text == " two, oat ")
    #expect(commits(of: store) { module.tap(.notesFieldLostFocus) } == 0, "it did not change")
}

@Test func aSubtaskIsAddedOnReturnAndTheNextFieldOpens() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    module.tap(.addSubtaskTapped)
    #expect(openCard(in: module.model)?.card.subtaskField?.text == "")
    module.tap(.subtaskFieldChanged(" First "))
    module.tap(.subtaskFieldSubmitted)
    let opened = try #require(openCard(in: module.model))
    #expect(opened.card.subtasks.map(\.title.text) == ["First"], "the written subtask shows")
    #expect(opened.card.subtaskField?.text == "", "the next field opens")
    #expect(try store.children(of: id).map(\.title) == ["First"])
    module.tap(.subtaskFieldSubmitted)
    #expect(openCard(in: module.model)?.card.subtaskField == nil, "Return on nothing closes it")
    #expect(try store.children(of: id).count == 1)
}

@Test func leavingTheSubtaskFieldAddsWhatWasTyped() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    module.tap(.addSubtaskTapped)
    module.tap(.subtaskFieldChanged("Second"))
    module.tap(.subtaskFieldLostFocus)
    #expect(try store.children(of: id).map(\.title) == ["Second"])
    #expect(openCard(in: module.model)?.card.subtaskField == nil, "and closes it")
    module.tap(.addSubtaskTapped)
    #expect(commits(of: store) { module.tap(.subtaskFieldLostFocus) } == 0, "nothing was typed")
    #expect(openCard(in: module.model)?.card.subtaskField == nil)
    module.tap(.addSubtaskTapped)
    module.tap(.subtaskFieldChanged("Dropped"))
    module.tap(.subtaskFieldCancelled)
    #expect(openCard(in: module.model)?.card.subtaskField == nil)
    #expect(openCard(in: module.model)?.id == id, "cancelling it leaves the card")
    #expect(try store.children(of: id).count == 1, "and drops what was typed")
}

@Test func aSubtasksCheckWritesItsStatusAndCascadesNowhere() throws {
    let store = try makeStore()
    let parent = try store.createTask(NewTask(title: "Parent"))
    let sub = try store.createTask(NewTask(title: "Sub", parent: parent))
    let other = try store.createTask(NewTask(title: "Other", parent: parent))
    let module = try list(inbox, in: store)
    module.tap(.rowTapped(parent))
    module.tap(.subtaskCheckTapped(sub))
    #expect(try stored(sub, in: store).status == .done)
    #expect(try stored(parent, in: store).status == .open, "the parent's check is the person's to tap")
    #expect(try stored(other, in: store).status == .open)
    let opened = try #require(openCard(in: module.model))
    #expect(opened.card.subtasks.map(\.check.isChecked) == [true, false])
    module.tap(.subtaskCheckTapped(sub))
    #expect(try stored(sub, in: store).status == .open, "its check takes it back")
    module.tap(.subtaskCheckTapped(parent))
    #expect(try stored(parent, in: store).status == .open, "a task that is no subtask of the card is no check on it")
    module.tap(.checkTapped(parent))
    #expect(try stored(sub, in: store).status == .open, "completing the parent leaves its subtasks open")
}

@Test func openFullScreenPushesTheTaskScreen() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    module.tap(.openFullScreenTapped)
    #expect(module.destination.pushed == .task(TaskScreen.Route(head: id)))
    #expect(openCard(in: module.model)?.id == id, "it does not close the card")
    let unopened = try list(inbox, in: store)
    unopened.tap(.openFullScreenTapped)
    #expect(unopened.destination.pushed == nil, "with no card there is nothing to open")
}

@Test func openFullScreenWritesTheDraftsAndLeavesTheCardOpen() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    module.tap(.titleFieldChanged("Buy oat milk"))
    module.tap(.notesFieldChanged("two"))
    module.tap(.addSubtaskTapped)
    module.tap(.subtaskFieldChanged("Find the coupon"))
    module.tap(.openFullScreenTapped)
    #expect(try stored(id, in: store).title == "Buy oat milk")
    #expect(try store.notes(of: id) == "two")
    #expect(try store.children(of: id).map(\.title) == ["Find the coupon"])
    #expect(openCard(in: module.model)?.card.subtaskField == nil)
    #expect(module.destination.pushed == .task(TaskScreen.Route(head: id)))
}

/// The back button answers that the person went back, and an open card closes first by the rule of every close, since
/// nothing after the tap reaches the list: a title typed is written, and a new task with nothing put in it is deleted
/// (the owner's review of #177, 2026-11-08).
@Test func theBackButtonClosesTheCardAndAnswersThatThePersonWentBack() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    module.tap(.titleFieldChanged("Buy oat milk"))
    #expect(module.send(.action(.backButtonTapped)) == .wentBack)
    #expect(try stored(id, in: store).title == "Buy oat milk")
    #expect(openCard(in: module.model) == nil)
    let new = try list(inbox, in: store)
    new.tap(.addTaskButtonTapped)
    let empty = try #require(openCard(in: new.model)?.id)
    #expect(new.send(.action(.backButtonTapped)) == .wentBack)
    #expect(try store.task(empty) == nil, "it never had anything in it")
    let bare = try list(inbox, in: store)
    #expect(bare.send(.action(.backButtonTapped)) == .wentBack, "with no card open it only answers")
    #expect(bare.model == (try list(inbox, in: store).model))
}

/// The back button settles a list's name being typed first, as "+ Add list" does, so the name is not lost with the
/// field's lost focus, which reaches no list once it is closed (the owner's review of #177, 2026-11-08).
@Test func theBackButtonWritesTheNameOfANewList() throws {
    let store = try makeStore()
    let parent = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let module = try list(parent, in: store)
    module.tap(.addListTapped)
    let made = try #require(try store.children(ofView: parent).last)
    module.tap(.listNameFieldChanged("Errands"))
    #expect(module.send(.action(.backButtonTapped)) == .wentBack)
    #expect(try store.view(made.id)?.title == "Errands")
}

/// A close the store refused keeps the list on Back, so that its sentence stands and a title that was not saved is not
/// passed over in silence; the card is closed, so a second Back goes (the owner's review of #177, 2026-11-08).
@Test func aCloseTheStoreRefusedKeepsTheListOnBack() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    module.tap(.titleFieldChanged("Typed"))
    try store.delete(task: id)
    #expect(module.send(.action(.backButtonTapped)) == nil)
    #expect(module.model.problem == "The change could not be saved, so nothing was written.")
    #expect(openCard(in: module.model) == nil)
    #expect(module.send(.action(.backButtonTapped)) == .wentBack)
}

@Test func aCardClosingWithNoTitleDeletesTheTask() throws {
    let store = try makeStore()
    let module = try list(inbox, in: store)
    module.tap(.addTaskButtonTapped)
    let id = try #require(openCard(in: module.model)?.id)
    module.tap(.backgroundTapped)
    #expect(try store.task(id) == nil, "it never had anything in it")
    #expect(module.model == (try list(inbox, in: store).model))
}

/// A card with no title goes on closing only where nothing was put in it: notes typed stay, with the task, its stored
/// title empty, a row a person can open and name or delete (spec section 4; the controller's ruling on #176,
/// 2026-11-05).
@Test func aCardWithNoTitleAndNotesTypedStaysWithItsNotes() throws {
    let store = try makeStore()
    let module = try list(inbox, in: store)
    module.tap(.addTaskButtonTapped)
    let id = try #require(openCard(in: module.model)?.id)
    module.tap(.notesFieldChanged("Call at 5"))
    module.tap(.backgroundTapped)
    #expect(openCard(in: module.model) == nil)
    let task = try stored(id, in: store)
    #expect(task.title == "" && !task.trashed)
    #expect(try store.notes(of: id) == "Call at 5")
    #expect(rows(of: module.model).map(\.id) == [id])
    module.tap(.rowTapped(id))
    module.tap(.titleFieldSubmitted)
    #expect(openCard(in: module.model) == nil, "Return on its empty title closes it")
    #expect(try store.task(id) != nil, "and its stored notes keep it")
}

/// The subtask being typed is written and keeps the task, as what stands under it; a draft of spaces is nothing.
@Test func aCardWithNoTitleAndASubtaskTypedStaysWithIt() throws {
    let store = try makeStore()
    let module = try list(inbox, in: store)
    module.tap(.addTaskButtonTapped)
    let id = try #require(openCard(in: module.model)?.id)
    module.tap(.addSubtaskTapped)
    module.tap(.subtaskFieldChanged(" Typed "))
    module.tap(.backgroundTapped)
    #expect(try store.task(id)?.title == "")
    #expect(try store.children(of: id).map(\.title) == ["Typed"])
    let spaces = try list(inbox, in: store)
    spaces.tap(.addTaskButtonTapped)
    let blank = try #require(openCard(in: spaces.model)?.id)
    spaces.tap(.addSubtaskTapped)
    spaces.tap(.subtaskFieldChanged("   "))
    spaces.tap(.notesFieldChanged("  "))
    spaces.tap(.backgroundTapped)
    #expect(try store.task(blank) == nil, "spaces are nothing put in it")
}

/// A subtask stored under a task with no title keeps it, on Return and on a tap beside the card alike, and so do notes
/// stored, a task the command line or a peer wrote.
@Test func aCardWithNoTitleAndASubtaskStoredStays() throws {
    let store = try makeStore()
    let parent = try store.createTask(NewTask(title: ""))
    try store.createTask(NewTask(title: "Old subtask", parent: parent))
    let noted = try store.createTask(NewTask(title: "", notes: "Old notes"))
    let module = try list(inbox, in: store)
    for id in [parent, noted] {
        module.tap(.rowTapped(id))
        module.tap(.backgroundTapped)
        #expect(try store.task(id) != nil)
    }
    module.tap(.rowTapped(parent))
    module.tap(.escapeKeyPressed)
    #expect(try store.task(parent) != nil)
}

/// A card with nothing in it but a subtask draft Esc drops is deleted: the draft goes first, and then nothing was put
/// in it.
@Test func escapeOnACardWithOnlyASubtaskDraftDeletesTheTask() throws {
    let store = try makeStore()
    let module = try list(inbox, in: store)
    module.tap(.addTaskButtonTapped)
    let id = try #require(openCard(in: module.model)?.id)
    module.tap(.addSubtaskTapped)
    module.tap(.subtaskFieldChanged("Dropped"))
    module.tap(.escapeKeyPressed)
    #expect(try store.task(id) == nil)
    #expect(try store.allTasks().isEmpty)
}

/// The check on a card with no title and something in it completes the task, what was typed written with it, and the
/// task stays, in the strip.
@Test func theCheckOnACardWithNoTitleAndNotesCompletesIt() throws {
    let store = try makeStore()
    let module = try list(inbox, in: store)
    module.tap(.addTaskButtonTapped)
    let id = try #require(openCard(in: module.model)?.id)
    module.tap(.notesFieldChanged("Call at 5"))
    module.tap(.checkTapped(id))
    let task = try stored(id, in: store)
    #expect(task.status == .done && task.title == "")
    #expect(try store.notes(of: id) == "Call at 5")
    #expect(module.model.done != nil)
}

/// Clearing the title of a task that has one and tapping away keeps the old title, as a list's empty name keeps the old
/// (the controller's ruling on #176, 2026-11-05): `delete(task:)` is a tombstone with no Trash, which that must not
/// reach.
@Test func clearingATitleKeepsTheOldWhenTheCardCloses() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    module.tap(.titleFieldChanged(""))
    #expect(openCard(in: module.model)?.card.title.text == "", "the field holds what was typed")
    module.tap(.backgroundTapped)
    #expect(try stored(id, in: store).title == "Buy milk")
    #expect(openCard(in: module.model) == nil)
    #expect(module.model == (try list(inbox, in: store).model))
}

@Test func anEmptyTitleIsNeverWritten() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    for end in [TaskList.UserAction.titleFieldLostFocus, .titleFieldSubmitted] {
        module.tap(.titleFieldChanged("   "))
        module.tap(end)
        #expect(try stored(id, in: store).title == "Buy milk")
        if openCard(in: module.model) == nil { module.tap(.rowTapped(id)) }
    }
    module.tap(.titleFieldChanged("  "))
    module.tap(.openFullScreenTapped)
    #expect(try stored(id, in: store).title == "Buy milk")
}

/// Esc closes the card and keeps what was typed, as the canvas does; of the subtask field it drops only that (the
/// controller's ruling on #176, 2026-11-05). Esc in the title field and a tap on the background keep an open subtask
/// draft too.
@Test func escapeKeepsWhatWasTypedAndClosesTheCard() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    module.tap(.titleFieldChanged("Buy oat milk"))
    module.tap(.notesFieldChanged("two"))
    module.tap(.addSubtaskTapped)
    module.tap(.subtaskFieldChanged("Dropped"))
    module.tap(.escapeKeyPressed)
    #expect(openCard(in: module.model) == nil)
    #expect(try stored(id, in: store).title == "Buy oat milk")
    #expect(try store.notes(of: id) == "two")
    #expect(try store.children(of: id).isEmpty, "Esc drops the subtask being typed")
    for closing in [TaskList.UserAction.titleFieldCancelled, .backgroundTapped] {
        module.tap(.rowTapped(id))
        module.tap(.addSubtaskTapped)
        module.tap(.subtaskFieldChanged("Kept"))
        let before = try store.children(of: id).count
        module.tap(closing)
        #expect(try store.children(of: id).count == before + 1)
    }
}

/// Return on an empty title closes the card (canvas): a new task's goes, an old task's keeps its title.
@Test func returnOnAnEmptyTitleClosesTheCard() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    module.tap(.titleFieldChanged(""))
    module.tap(.titleFieldSubmitted)
    #expect(openCard(in: module.model) == nil)
    #expect(try stored(id, in: store).title == "Buy milk")
    module.tap(.addTaskButtonTapped)
    let new = try #require(openCard(in: module.model)?.id)
    module.tap(.titleFieldSubmitted)
    #expect(openCard(in: module.model) == nil)
    #expect(try store.task(new) == nil)
}

/// Leaving an empty title does nothing, the card and the task stay (canvas).
@Test func leavingAnEmptyTitleLeavesTheCardOpen() throws {
    let store = try makeStore()
    let module = try list(inbox, in: store)
    module.tap(.addTaskButtonTapped)
    let id = try #require(openCard(in: module.model)?.id)
    #expect(commits(of: store) { module.tap(.titleFieldLostFocus) } == 0)
    #expect(openCard(in: module.model)?.id == id)
    #expect(try store.task(id) != nil)
}

@Test func checkingTheOpenCardsTaskWritesItsDraftsFirst() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    module.tap(.titleFieldChanged("Buy oat milk"))
    module.tap(.notesFieldChanged("two"))
    #expect(commits(of: store) { module.tap(.checkTapped(id)) } == 1, "one transaction")
    let task = try stored(id, in: store)
    #expect(task.title == "Buy oat milk" && task.status == .done)
    #expect(try store.notes(of: id) == "two")
    #expect(openCard(in: module.model) == nil, "its row left the rows")
}

@Test func checkingAnUntitledCardsTaskDeletesIt() throws {
    let store = try makeStore()
    let module = try list(inbox, in: store)
    module.tap(.addTaskButtonTapped)
    let id = try #require(openCard(in: module.model)?.id)
    module.tap(.checkTapped(id))
    #expect(try store.task(id) == nil, "an empty task is not filed as done")
    #expect(openCard(in: module.model) == nil)
}

/// A fold that hides the card closes it by the rule of every close, and writes what was typed (the controller's ruling
/// on #176, 2026-11-05).
@Test func aFoldThatHidesTheCardClosesIt() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let module = try list(BuiltInTaskViews.upcoming, in: store)
    module.tap(.rowTapped(id))
    module.tap(.titleFieldChanged("Buy oat milk"))
    module.tap(.blockChevronTapped(.own(.day(day(1)))))
    #expect(openCard(in: module.model) == nil)
    #expect(try stored(id, in: store).title == "Buy oat milk")
    module.tap(.blockChevronTapped(.own(.day(day(1)))))
    #expect(openCard(in: module.model) == nil, "it does not come back with the row")
}

@Test func aPickThatHidesTheCardClosesIt() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let kept = try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    let module = try list(inbox, in: store)
    module.tap(.rowTapped(id))
    module.tap(.titleFieldChanged("Buy oat milk"))
    module.tap(.tagChipTapped(home))
    #expect(openCard(in: module.model) == nil)
    #expect(try stored(id, in: store).title == "Buy oat milk")
    module.tap(.rowTapped(kept))
    module.tap(.tagChipTapped(home))
    #expect(openCard(in: module.model)?.id == kept, "a pick that keeps its row leaves the card")
}

/// A reread that no longer finds the card's task drops the card and writes nothing, since a module never writes in
/// answer to `.changed` (ADR-0009).
@Test func aChangeThatTakesTheCardsTaskDropsTheCardAndWritesNothing() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    module.tap(.titleFieldChanged("Buy oat milk"))
    let trashed = try changeSet(of: store) { try store.trash(task: id) }
    #expect(commits(of: store) { _ = module.send(.changed(trashed)) } == 0)
    #expect(openCard(in: module.model) == nil)
    #expect(try stored(id, in: store).title == "Buy milk")
    #expect(module.model == (try list(inbox, in: store).model))
    let restored = try changeSet(of: store) { try store.restore(task: id) }
    #expect(module.send(.changed(restored)) == nil)
    #expect(openCard(in: module.model) == nil, "the card went with the read, and does not come back with the row")
}

/// A change keeps what was typed and shows what it wrote beside it: a subtask a screen over the list added, and a title
/// nothing was typed over.
@Test func aChangeRereadsTheCardsSubtasksAndKeepsWhatWasTyped() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    let renamed = try changeSet(of: store) { try store.update(task: id, [.title("Renamed")]) }
    #expect(module.send(.changed(renamed)) == nil)
    #expect(openCard(in: module.model)?.card.title.text == "Renamed", "nothing was typed over it")
    module.tap(.titleFieldChanged("Typed"))
    let added = try changeSet(of: store) { try store.createTask(NewTask(title: "A subtask", parent: id)) }
    #expect(module.send(.changed(added)) == nil)
    let opened = try #require(openCard(in: module.model))
    #expect(opened.card.title.text == "Typed")
    #expect(opened.card.subtasks.map(\.title.text) == ["A subtask"])
}

/// A field writes the text it holds back through its binding, after Return and after a lost focus too (`TaskViewList`,
/// by hand on 2026-10-12): that echo is no keystroke, so the sentence stays, and a field with no card to write to moves
/// nothing.
@Test func aFieldsEchoOfItsTextLeavesTheSentence() throws {
    let store = try makeStore()
    let (module, id) = try cardOnATask(store)
    module.tap(.titleFieldChanged("Typed"))
    try store.delete(task: id)
    module.tap(.titleFieldSubmitted)
    let told = try #require(module.model.problem, "the refused write is the setup")
    let closed = module.model
    module.tap(.titleFieldChanged("Typed"))
    #expect(module.model == closed)
    module.tap(.notesFieldChanged("Typed"))
    module.tap(.subtaskFieldChanged("Typed"))
    module.tap(.addSubtaskTapped)
    #expect(module.model == closed, "no card")
    #expect(module.model.problem == told)
}
