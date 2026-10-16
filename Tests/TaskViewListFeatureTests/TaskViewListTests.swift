import Testing
import TestSupport
import FeatureModule
import TaskListFeature
import TaskScreenFeature
import TaskViewListFeature
import TodoCore
import SQLiteKit

/// The route of a sidebar whose list is on a view, with the task open in it when there is one.
private func on(_ view: ViewID, task: TaskID? = nil) -> TaskViewList.Route {
    .init(list: .init(head: view, task: task.map { TaskScreen.Route(head: $0) }))
}

/// The model of a list made now on a view, which is what the sidebar's own list is compared with: the list a
/// link to the view, and to the task in it, would make.
private func listOn(_ view: ViewID, task: TaskID? = nil, in store: Store) throws -> TaskList.Model {
    try TaskList(store: store, route: .init(head: view, task: task.map { TaskScreen.Route(head: $0) })).model
}

/// The rows of the list open in the sidebar, read before a task is written into the Inbox without its change
/// being delivered. The live list keeps the rows it last read, while a list made afresh reads the new task, so a
/// list whose rows still equal these after an event is the same instance: the mark a test tells one list from
/// another by, which only that instance holds and which adds nothing to the module's surface.
private func rowsBeforeAnUnreadTask(in list: TaskViewList, of store: Store) throws -> [TaskList.Model.Row] {
    let rows = try #require(list.model.taskList?.rows, "a list is open on the Inbox; this is the setup")
    try store.createTask(NewTask(title: "Unread"))
    #expect(try listOn(BuiltInTaskViews.inbox, in: store).rows.count == rows.count + 1, "a list made now reads the task; without that this proves nothing")
    return rows
}

@Test func initialModelListsTheBuiltInViewsInRankOrderWithInboxSelected() throws {
    let model = try TaskViewList(store: try makeStore(), route: .init(list: nil)).model
    #expect(model.rows.map(\.title) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash"])
    #expect(model.rows.allSatisfy { $0.depth == 0 })
    #expect(model.rows.filter(\.isSelected).map(\.id) == [BuiltInTaskViews.inbox])
    #expect(model.problem == nil)
}

@Test func nestedViewsGetTheirDepthInTreeOrder() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    let reviews = try store.createView(NewTaskView(title: "Reviews", parent: folder))
    try store.createView(NewTaskView(title: "Notes", parent: folder))
    try store.createView(NewTaskView(title: "Deep", parent: reviews))
    let rows = try TaskViewList(store: store, route: .init(list: nil)).model.rows.dropFirst(5)
    #expect(rows.map(\.title) == ["Work", "Reviews", "Deep", "Notes"], "past the five built-in views, depth first and siblings by rank")
    #expect(rows.map(\.depth) == [0, 1, 2, 1])
}

/// A click moves the highlight and opens the list of the view clicked, which is the list's route applied to the
/// seat (spec section 3): the list on another view is a new one, and the module says nothing in answer, since
/// opening a list is its own to do.
@Test func aClickMovesTheHighlightAndOpensTheViewsList() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    try store.createView(NewTaskView(title: "Reviews", parent: folder))
    let list = try TaskViewList(store: store, route: .init(list: nil))
    let before = list.model
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == nil)
    #expect(list.model.rows.filter(\.isSelected).map(\.id) == [BuiltInTaskViews.today])
    #expect(list.model.taskList == (try listOn(BuiltInTaskViews.today, in: store)))
    #expect(list.route == on(BuiltInTaskViews.today))
    // The highlight moved back leaves the model as it was, which is what says that a move carries every
    // other field of every row along: the title a row draws, and the depth a nested one is drawn at.
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.inbox))) == nil)
    #expect(list.model == before)
}

/// A click on the highlighted view is still a choice, and it applies the same route: the seat keeps the list on
/// that view, and the route's empty tail closes the task open in it, so the click returns to the list, as System
/// Settings does on the Mac and a second tap on a tab does on iOS (owner, 2026-10-16).
@Test func aClickOnTheHighlightedViewReturnsToItsList() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskViewList(store: store, route: on(BuiltInTaskViews.inbox, task: id))
    #expect(list.model.taskList?.task?.title == "Buy milk", "the task is open; this is the setup")
    let rows = try rowsBeforeAnUnreadTask(in: list, of: store)
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.inbox))) == nil)
    #expect(list.model.taskList?.task == nil)
    #expect(list.model.taskList?.rows == rows, "the same list, since a list made afresh reads the task written since")
    #expect(list.route == on(BuiltInTaskViews.inbox))
}

/// A click on a view a peer deleted, before the change saying so has arrived: the row is still there and the
/// highlight moves onto it, the list on it cannot be made, and the list that was open stays with a sentence,
/// which the click writes after it has taken any older one away.
@Test func aClickOnAViewThatIsGoneLeavesTheListAndSaysSo() throws {
    let store = try makeStore()
    let gone = try store.createView(NewTaskView(title: "Errands", filter: .status([.open])))
    let list = try TaskViewList(store: store, route: .init(list: nil))
    let open = list.model.taskList
    try store.delete(view: gone)
    #expect(list.send(.action(.rowSelected(gone))) == nil)
    #expect(list.model.selection == gone)
    #expect(list.model.taskList == open)
    #expect(list.model.problem == "The list could not be opened.")
    #expect(list.route == on(BuiltInTaskViews.inbox))
}

/// Being created is the one event that nobody chose, and the list has nothing to say in answer: it opened the
/// list of the view it starts on in its `init`, as the task list opens its task screen in its own. Nothing moves,
/// the sentence included, since being created answers nothing a person was told.
@Test func createdAnswersNothingAndMovesNothing() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(list: nil))
    let before = list.model
    #expect(list.send(.created) == nil)
    #expect(list.model == before)
    // Sent after a refusal, which is not where a parent sends it, so that there is a sentence to lose.
    let refused = try TaskViewList(store: try makeStore(), route: .init(list: nil))
    _ = refused.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox)))
    _ = refused.send(.action(.titleFieldChanged(" ")))
    _ = refused.send(.action(.titleFieldSubmitted))
    let told = refused.model
    #expect(told.problem != nil, "the refusal is the setup; without it this proves nothing")
    #expect(refused.send(.created) == nil)
    #expect(refused.model == told, "the sentence and the open field outlive it")
}

@Test func changedWithAViewRereadsTheTree() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == nil)
    let created = try changeSet(of: store) { try store.createView(NewTaskView(title: "Docs")) }
    #expect(list.send(.changed(created)) == nil)
    #expect(list.model.rows.map(\.title) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash", "Docs"])
    // A view that appeared elsewhere is no reason to lose the row the person is on, and no reason to say
    // that anything went wrong.
    #expect(list.model.rows.filter(\.isSelected).map(\.id) == [BuiltInTaskViews.today])
    #expect(list.model.problem == nil)
}

/// A change that names no view reads no view, and still reaches the list, which reads its tasks.
@Test func changedWithoutAViewRereadsNoViewAndReachesTheList() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    let before = list.model
    let taskOnly = try changeSet(of: store) { try store.createTask(NewTask(title: "Write it down")) }
    try store.createView(NewTaskView(title: "Docs"))
    #expect(list.send(.changed(taskOnly)) == nil)
    #expect(list.model.rows == before.rows, "the view created since is missing, which is how a read that never ran shows")
    #expect(list.model.taskList?.rows.map(\.title) == ["Write it down"], "the list read the task")
}

@Test func theSelectionIsDroppedWhenTheSelectedViewDisappears() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    let deleted = try changeSet(of: store) { try store.delete(view: BuiltInTaskViews.inbox) }
    #expect(list.send(.changed(deleted)) == nil, "a view a peer deleted is not a choice anybody made")
    #expect(list.model.rows.map(\.title) == ["Today", "Upcoming", "Logbook", "Trash"])
    let selected = list.model.rows.filter(\.isSelected)
    #expect(selected.isEmpty)
    // The list on the view asked to be closed, and the module dropped it: the root reads the store for nothing,
    // and neither does this module for its child (spec section 3).
    #expect(list.model.taskList == nil)
    #expect(list.route == .init(list: nil))
    #expect(list.model.problem == nil)
}

/// One highlight, read two ways: `selection` is what a list bound to one value reads, and `isSelected` what a
/// client drawing row by row reads. Two readings that disagreed would have two clients highlight different
/// rows, or bind a list to a row it does not draw.
@Test func selectionNamesTheSelectedRow() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.model.selection == BuiltInTaskViews.inbox)
    #expect(list.model.rows.filter(\.isSelected).map(\.id) == [BuiltInTaskViews.inbox])
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == nil)
    #expect(list.model.selection == BuiltInTaskViews.today)
    #expect(list.model.rows.filter(\.isSelected).map(\.id) == [BuiltInTaskViews.today])
    let deleted = try changeSet(of: store) { try store.delete(view: BuiltInTaskViews.today) }
    #expect(list.send(.changed(deleted)) == nil)
    #expect(list.model.selection == nil, "the highlight went with its row")
    #expect(list.model.rows.filter(\.isSelected).isEmpty)
    // `.rowSelected` keeps whatever id it is given without asking the rows, so an id that names no row is a
    // highlight the list holds and draws nowhere: neither reading names it.
    _ = list.send(.action(.rowSelected(ViewID())))
    #expect(list.model.selection == nil, "an id no row carries is no row to bind to")
    #expect(list.model.rows.filter(\.isSelected).isEmpty)
}

/// A chain thousands of links deep arrives from sync as easily as a shallow one, and a stack — 64 KiB of it
/// on wasm32 — is not what should decide whether the list draws (`docs/style.md`, "No recursion over
/// data-shaped depth"). The chain is journaled straight into the store, because a thousand calls to
/// `createView` would rank a thousand siblings and measure the write instead of the read.
@Test func aThousandNestedFoldersReadWithoutRecursion() throws {
    let store = try makeStore()
    let stamp = HLC(millis: 1, counter: 0)
    var ops: [JournalOperation] = []
    var ids: [String] = []
    for depth in 0..<1_000 {
        let id = "view-\(depth)"
        let fields: [(String, Value)] = [
            ("title", .text("v\(depth)")), ("parent", depth == 0 ? .null : .text(ids[depth - 1])),
            ("rank", .text(Rank.initial)), ("deleted", Value(false)),
        ]
        ops += fields.map { JournalOperation(entity: .view, entityID: id, field: $0.0, value: $0.1, clock: stamp, device: store.deviceID) }
        ids.append(id)
    }
    try store.apply(ops)
    let chain = try TaskViewList(store: store, route: .init(list: nil)).model.rows.filter { $0.id.rawValue.hasPrefix("view-") }
    #expect(chain.map(\.id.rawValue) == ids, "parents before children, however deep the chain")
    #expect(chain.map(\.depth) == Array(0..<1_000))
}

@Test func renameGoesThroughTheDraftIntoTheStore() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox))) == nil)
    #expect(list.model.rows.first?.draft == "Inbox", "the field opens on the title the person chose the menu item on")
    // Every keystroke is a round trip through the module, which is what says the draft is the model's and not
    // something the text field keeps to itself (ADR-0006).
    for draft in ["In", "Ins", "Inside"] {
        #expect(list.send(.action(.titleFieldChanged(draft))) == nil)
        #expect(list.model.rows.first?.draft == draft)
    }
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    let stored = try store.view(BuiltInTaskViews.inbox)?.title
    #expect(stored == "Inside", "the last draft is the title, and the three before it never reached the store")
    #expect(list.model.rows.first?.title == "Inside", "the row is read back out of the store, not patched")
    #expect(list.model.rows.allSatisfy { $0.draft == nil }, "no field is open on any row once the name is in")
    #expect(list.model.problem == nil)
}

@Test func cancelRenameLeavesTheTitleAndClosesTheField() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    let before = list.model
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.today))) == nil)
    #expect(list.send(.action(.titleFieldChanged("Tomorrow"))) == nil)
    #expect(list.send(.action(.titleFieldCancelled)) == nil)
    #expect(list.model == before, "a cancelled rename leaves the model it opened on, the drafts included")
    let stored = try store.view(BuiltInTaskViews.today)?.title
    #expect(stored == "Today", "nothing was written, so the store never heard of the draft")
}

@Test func anEmptyTitleIsRefusedByTheModuleAndTheFieldStaysOpen() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    let written = try store.journal(after: 0).count
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox))) == nil)
    for draft in [" \t ", ""] {
        #expect(list.send(.action(.titleFieldChanged(draft))) == nil)
        #expect(list.send(.action(.titleFieldSubmitted)) == nil)
        #expect(list.model.problem == "A title cannot be empty.")
        // The store is what the count proves nothing reached: a refusal that wrote first and complained
        // afterwards would leave a nameless view behind on every device (spec, "The sidebar in M2").
        #expect(try store.journal(after: 0).count == written)
        #expect(list.model.rows.first?.draft == draft, "the field is still open, on the text the person typed")
        #expect(list.model.rows.first?.title == "Inbox")
    }
}

@Test func createFolderAddsARowAtTheEndSelectsItAndOpensItsRename() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.send(.action(.createFolderButtonTapped)) == nil)
    #expect(list.model.rows.map(\.title) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash", "New folder"])
    let folder = try #require(list.model.rows.last)
    #expect(folder.depth == 0, "a folder from the toolbar belongs at the root and not under whatever was chosen")
    #expect(list.model.rows.filter(\.isSelected).map(\.id) == [folder.id])
    #expect(folder.draft == "New folder", "the field opens on the default name, so the first keystroke replaces it")
    // The highlight moved without anybody choosing a row, and the list opens on it as a click would have opened
    // it, or the list beside the highlight would stay on the view before this one.
    #expect(list.model.taskList == (try listOn(folder.id, in: store)))
    #expect(list.route == on(folder.id))
    let stored = try store.view(folder.id)
    #expect(stored?.title == "New folder")
    #expect(stored?.filter == nil, "a folder is a view without a filter, which is what makes it hold others")
    #expect(list.model.problem == nil)
}

@Test func aStoreRefusalLandsInTheProblemAndTheNextActionClearsIt() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.send(.action(.renameMenuItemChosen(folder))) == nil)
    #expect(list.send(.action(.titleFieldChanged("Work in progress"))) == nil)
    // The peer's delete arrives as a delete and not as a `.changed`: the list hears about it from the
    // refusal, which is the race the store's `requireView` exists for.
    try store.delete(view: folder)
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    let sentence = try #require(list.model.problem)
    #expect(sentence.contains("Work"), "the sentence names the view the field was open on")
    #expect(!sentence.contains("Work in progress"), "it names the view, not the name that never took")
    #expect(list.model.rows.map(\.title) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash"], "the reread dropped it")
    #expect(list.model.rows.allSatisfy { $0.draft == nil }, "the field closed: there is no row left to type on")
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == nil)
    #expect(list.model.problem == nil, "a sentence belongs to the event that produced it")
}

@Test func fieldActionsWithoutAnOpenRenameAreIgnored() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    let list = try TaskViewList(store: store, route: .init(list: nil))
    // A sentence on the model with no field left open: the refusal below closes the field itself, which is
    // the state these actions arrive in and the reason the model is left alone in it.
    #expect(list.send(.action(.renameMenuItemChosen(folder))) == nil)
    try store.delete(view: folder)
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    let sentence = try #require(list.model.problem, "the refusal is the setup; without it this test proves nothing")
    let before = list.model
    let written = try store.journal(after: 0).count
    // What a gesture means is the module's to know: a view sends what the person did to a text field and
    // has no way of telling whether one is open, so a keystroke with no rename behind it is nothing at all
    // — and not a rename of whichever row happens to be highlighted. Nothing at all includes the sentence:
    // a field's echo of its text and its lost focus can arrive after the field closed, and a sentence
    // cleared by them would go between the person being told and reading it.
    #expect(list.send(.action(.titleFieldChanged("Anything at all"))) == nil)
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    #expect(list.send(.action(.titleFieldLostFocus)) == nil)
    #expect(list.send(.action(.titleFieldCancelled)) == nil)
    #expect(list.model.problem == sentence, "the sentence outlives the gestures that were ignored")
    #expect(list.model == before)
    #expect(try store.journal(after: 0).count == written)
}

/// On 2026-10-12, by hand, a `TextField` wrote the text it holds back through its binding twice for every
/// keystroke, and again after Return and after a lost focus. The report after a refused Return is the one that
/// costs something: taken for a keystroke, it would clear the sentence the refusal had just set, before anybody
/// read it.
@Test func aFieldReportingTheTextItHoldsLeavesTheSentence() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox))) == nil)
    #expect(list.send(.action(.titleFieldChanged(""))) == nil)
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    let refused = list.model
    #expect(refused.problem == "A title cannot be empty.", "the refusal is the setup; without it this proves nothing")
    #expect(list.send(.action(.titleFieldChanged(""))) == nil)
    #expect(list.model == refused, "the sentence and the open field are where the refusal left them")
    // A keystroke is the person answering the sentence, and it still takes the sentence away.
    #expect(list.send(.action(.titleFieldChanged("I"))) == nil)
    #expect(list.model.problem == nil)
    #expect(list.model.rows.first?.draft == "I")
}

@Test func problemSurvivesAChangedEvent() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox))) == nil)
    #expect(list.send(.action(.titleFieldChanged(" "))) == nil)
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    let problem = try #require(list.model.problem)
    let created = try changeSet(of: store) { try store.createView(NewTaskView(title: "Docs")) }
    #expect(list.send(.changed(created)) == nil)
    // A sentence belongs to the action it answered, and what another device did is no answer to it: a
    // problem cleared by a peer's edit would vanish between a person reading it and acting on it.
    #expect(list.model.problem == problem)
    #expect(list.model.rows.map(\.title).contains("Docs"), "the tree was reread all the same")
    #expect(list.model.rows.first?.draft == " ", "the field a person is typing in outlives a peer's edit")
}

/// The selection and the rename are the module's own state, and a reread is what holds them to the rows it
/// just read: whichever of them names a row that did not come back goes with it. This is the rename's half,
/// and the half a person is told about, because a name being typed is a thing to interrupt.
@Test func aRenameEndsWhenThePeerDeletesTheRowItIsOn() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.send(.action(.renameMenuItemChosen(folder))) == nil)
    #expect(list.send(.action(.titleFieldChanged("Work in progress"))) == nil)
    let deleted = try changeSet(of: store) { try store.delete(view: folder) }
    #expect(list.send(.changed(deleted)) == nil)
    let after = list.model
    #expect(after.rows.allSatisfy { $0.draft == nil }, "no row is left for the field to be on")
    // The same fact by another route says the same thing: a person interrupted mid-name is told why the
    // field went, whether the news came back with their Return or arrived from the peer first.
    let sentence = try #require(after.problem)
    #expect(sentence.contains("Work"), "the sentence names the view the field was open on")
    #expect(!sentence.contains("Work in progress"), "it names the view, not the name that never took")
    let written = try store.journal(after: 0).count
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    #expect(list.model == after, "the rename ended with its row, so Return has nothing to submit")
    #expect(try store.journal(after: 0).count == written, "and nothing to write to a view that is gone")
}

@Test func aFieldThatLosesFocusKeepsWhatWasTyped() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.logbook))) == nil)
    #expect(list.send(.action(.titleFieldChanged("Done"))) == nil)
    // Clicking away settles a name, the way it does in the Finder: the person wrote it and then went on
    // with their work, and a name thrown away there is a name they have to type twice.
    #expect(list.send(.action(.titleFieldLostFocus)) == nil)
    let stored = try store.view(BuiltInTaskViews.logbook)?.title
    #expect(stored == "Done")
    #expect(list.model.rows.map(\.title) == ["Inbox", "Today", "Upcoming", "Done", "Trash"])
    #expect(list.model.rows.allSatisfy { $0.draft == nil }, "the field is closed, the way Return closes it")
    #expect(list.model.problem == nil)
}

@Test func aFieldThatLosesFocusOnAnEmptyTitleIsRefusedTheWayReturnIs() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    let written = try store.journal(after: 0).count
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox))) == nil)
    #expect(list.send(.action(.titleFieldChanged("  "))) == nil)
    // One draft ended two ways is one draft: a refusal that depended on which gesture ended it would make
    // the same two spaces mean two different things.
    #expect(list.send(.action(.titleFieldLostFocus)) == nil)
    #expect(list.model.problem == "A title cannot be empty.")
    #expect(list.model.rows.first?.draft == "  ", "the field stays open on the text, as it does for Return")
    #expect(list.model.rows.first?.title == "Inbox")
    #expect(try store.journal(after: 0).count == written)
}

/// A click on another row while the field holds an empty name loses the field's focus first, and the refusal
/// sets the sentence; the click's own `.rowSelected` follows. The highlight moves, the field stays open and
/// empty where it was, and the sentence is still what explains it.
@Test func choosingARowWhileAFieldIsOpenLeavesTheSentence() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(list: nil))
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox))) == nil)
    #expect(list.send(.action(.titleFieldChanged(""))) == nil)
    #expect(list.send(.action(.titleFieldLostFocus)) == nil)
    let sentence = try #require(list.model.problem, "the refusal is the setup; without it this proves nothing")
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == nil)
    #expect(list.model.problem == sentence)
    #expect(list.model.selection == BuiltInTaskViews.today)
    #expect(list.model.rows.map(\.draft) == ["", nil, nil, nil, nil])
    // The same state reached in the other order, the highlight moved before the refusal, compares the model
    // whole: nothing else moved.
    let reference = try TaskViewList(store: try makeStore(), route: .init(list: nil))
    _ = reference.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox)))
    _ = reference.send(.action(.rowSelected(BuiltInTaskViews.today)))
    _ = reference.send(.action(.titleFieldChanged("")))
    _ = reference.send(.action(.titleFieldLostFocus))
    #expect(list.model == reference.model)
}

@Test func choosingRenameOnASecondRowMovesTheFieldAndDropsTheFirstDraft() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox))) == nil)
    #expect(list.send(.action(.titleFieldChanged("Later"))) == nil)
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.trash))) == nil)
    // One field at a time, and the one a person walked away from takes its draft with it: a name typed
    // into a row nobody is looking at would be written by the next Return, wherever the field had moved.
    #expect(list.model.rows.map(\.draft) == [nil, nil, nil, nil, "Trash"])
    #expect(list.model.rows.first?.title == "Inbox")
    let stored = try store.view(BuiltInTaskViews.inbox)?.title
    #expect(stored == "Inbox", "the dropped draft was never written, since nothing committed it")
}

@Test func aDraftIsStoredWithoutTheWhitespaceAtItsEnds() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.upcoming))) == nil)
    #expect(list.send(.action(.titleFieldChanged("  Work in progress \t "))) == nil)
    // What the person typed is what the field shows, padding and all: the trim is about what the store
    // keeps, not about moving text under a caret while it is still being typed.
    let renaming = list.model.rows.first { $0.id == BuiltInTaskViews.upcoming }
    #expect(renaming?.draft == "  Work in progress \t ")
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    let stored = try store.view(BuiltInTaskViews.upcoming)?.title
    #expect(stored == "Work in progress", "the ends go, and the space between the words stays")
    #expect(list.model.rows.map(\.title) == ["Inbox", "Today", "Work in progress", "Logbook", "Trash"])
    #expect(list.model.problem == nil)
}

/// The default window's route names no list, so the module starts on its own first choice, the Inbox, and opens
/// the Inbox's list in its `init`, the way the task list opens its task screen in its own.
@Test func theSidebarCreatedFromNoListStartsOnInboxAndOpensItsList() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.model.selection == BuiltInTaskViews.inbox)
    #expect(list.model.taskList == (try listOn(BuiltInTaskViews.inbox, in: store)))
    #expect(list.model.taskList?.rows.map(\.title) == ["Buy milk"])
    #expect(list.model.problem == nil)
    #expect(list.route == on(BuiltInTaskViews.inbox))
}

/// A route that names a list is a choice already made, by a link or by the window a relaunch restores: the
/// highlight starts on its view, and the list opens on the route, with the task in it.
@Test func theSidebarCreatedFromAListStartsThereAndOpensIt() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskViewList(store: store, route: on(BuiltInTaskViews.today))
    #expect(list.model.selection == BuiltInTaskViews.today)
    #expect(list.model.rows.filter(\.isSelected).map(\.id) == [BuiltInTaskViews.today])
    #expect(list.model.taskList == (try listOn(BuiltInTaskViews.today, in: store)))
    let linked = try TaskViewList(store: store, route: on(BuiltInTaskViews.inbox, task: id))
    #expect(linked.model.taskList == (try listOn(BuiltInTaskViews.inbox, task: id, in: store)))
    #expect(linked.model.taskList?.task?.title == "Buy milk")
    #expect(linked.route == on(BuiltInTaskViews.inbox, task: id))
}

/// A link to a view deleted since, or a window restored onto one: an id that is gone is data from outside, so the
/// module opens what still exists, with no row highlighted and no list, and says why (spec sections 2 and 3). Only
/// its own read throws; a list that cannot be made is a sentence, and being created afterwards leaves it.
@Test func theSidebarCreatedOnAViewThatIsGoneOpensNoListAndSaysSo() throws {
    let store = try makeStore()
    let gone = try store.createView(NewTaskView(title: "Work"))
    try store.delete(view: gone)
    let list = try TaskViewList(store: store, route: on(gone))
    #expect(list.send(.created) == nil)
    #expect(list.model.rows.map(\.title) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash"])
    #expect(list.model.selection == nil)
    #expect(list.model.rows.filter(\.isSelected).isEmpty)
    #expect(list.model.taskList == nil)
    #expect(list.model.problem == "The list could not be opened.")
    #expect(list.route == .init(list: nil))
}

/// A person who deleted the Inbox leaves the module starting on no row: no list opens and nothing is said, since
/// nothing was asked for.
@Test func theSidebarCreatedWithNoInboxOpensNoList() throws {
    let store = try makeStore()
    try store.delete(view: BuiltInTaskViews.inbox)
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.model.selection == nil)
    #expect(list.model.taskList == nil)
    #expect(list.model.problem == nil)
    #expect(list.route == .init(list: nil))
}

/// A starting choice with no row is not kept for a row that may arrive later, whichever its source: the route's
/// list, as with a link to a view that has not synced to this device yet, or the Inbox the module falls back on.
/// Kept, it would light up when a peer's change brought the row in, beside a list that was never opened on it.
/// The rows come in from a peer's journal, which is how a view with an id chosen elsewhere reaches this store.
@Test func aStartingSelectionWithNoRowStaysUnhighlightedWhenTheRowArrives() throws {
    let peer = Store.newDeviceID()
    let later = HLC(millis: 1_800_000_000_000, counter: 0)
    func written(_ id: ViewID, _ fields: [(String, Value)]) -> [JournalOperation] {
        fields.map { JournalOperation(entity: .view, entityID: id.rawValue, field: $0.0, value: $0.1, clock: later, device: peer) }
    }

    let store = try makeStore()
    let linked = ViewID()
    let list = try TaskViewList(store: store, route: on(linked))
    #expect(list.model.taskList == nil, "no view, no list; this is the setup")
    let synced = try changeSet(of: store) {
        _ = try store.apply(written(linked, [
            ("title", .text("Work")), ("parent", .null), ("rank", .text(Rank.initial)), ("deleted", Value(false)),
        ]))
    }
    #expect(list.send(.changed(synced)) == nil)
    #expect(list.model.rows.map(\.id).contains(linked), "the view arrived; without it this proves nothing")
    #expect(list.model.selection == nil, "a highlight beside no list")
    #expect(list.model.rows.filter(\.isSelected).isEmpty)

    let bare = try makeStore()
    try bare.delete(view: BuiltInTaskViews.inbox)
    let fallback = try TaskViewList(store: bare, route: .init(list: nil))
    #expect(fallback.model.taskList == nil, "the Inbox is gone before launch; this is the setup")
    let restored = try changeSet(of: bare) { _ = try bare.apply(written(BuiltInTaskViews.inbox, [("deleted", Value(false))])) }
    #expect(fallback.send(.changed(restored)) == nil)
    #expect(fallback.model.rows.map(\.id).contains(BuiltInTaskViews.inbox), "the Inbox is back; without it this proves nothing")
    #expect(fallback.model.selection == nil, "a highlight beside no list")
}

/// A route is its parent's choice and not a person's, and it answers nothing: it moves the highlight onto its
/// list's view and applies its list to the seat, so the module ends where a link to the view would have made it.
@Test func aRouteMovesTheHighlightAndOpensItsList() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.send(.route(on(BuiltInTaskViews.today))) == nil)
    #expect(list.model.selection == BuiltInTaskViews.today)
    let routed = try TaskViewList(store: store, route: on(BuiltInTaskViews.today))
    #expect(list.model == routed.model, "the module a link to Today would have created")
    #expect(list.route == on(BuiltInTaskViews.today))
}

/// A route takes the sentence away at its start, except while a field is open: the sentence on screen is then what
/// explains the field, which the route leaves where it is, as a click does (owner, 2026-10-16). The route carries no
/// session state and keeps what did not change (spec sections 2 and 3).
@Test func aRouteTakesTheSentenceAwayUnlessAFieldIsOpen() throws {
    let store = try makeStore()
    let gone = try store.createView(NewTaskView(title: "Errands", filter: .status([.open])))
    try store.delete(view: gone)
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.send(.route(on(gone))) == nil)
    #expect(list.model.problem == "The list could not be opened.", "the sentence is the setup; without it this proves nothing")
    #expect(list.send(.route(on(BuiltInTaskViews.today))) == nil)
    #expect(list.model.problem == nil)
    // With a field open on a refused name, the sentence explains the field, and a route leaves both.
    _ = list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox)))
    _ = list.send(.action(.titleFieldChanged(" ")))
    _ = list.send(.action(.titleFieldSubmitted))
    #expect(list.model.problem != nil, "the refusal is the setup; without it this proves nothing")
    #expect(list.send(.route(on(BuiltInTaskViews.upcoming))) == nil)
    #expect(list.model.selection == BuiltInTaskViews.upcoming)
    // The same state reached with the highlight on Upcoming before the refusal compares the model whole.
    let reference = try TaskViewList(store: store, route: on(BuiltInTaskViews.upcoming))
    _ = reference.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox)))
    _ = reference.send(.action(.titleFieldChanged(" ")))
    _ = reference.send(.action(.titleFieldSubmitted))
    #expect(list.model == reference.model)
}

/// A route to a view the module holds no row for, a link to one that is gone, leaves the highlight, since a
/// highlight on no row is a highlight nobody can see, and leaves the list, which cannot be made on it, with a
/// sentence (spec section 3).
@Test func aRouteToAViewThatIsGoneLeavesTheHighlightAndTheListAndSaysSo() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: on(BuiltInTaskViews.today))
    let before = list.model
    #expect(list.send(.route(on(ViewID()))) == nil)
    #expect(list.model.selection == before.selection, "the highlight stays on Today")
    #expect(list.model.taskList == before.taskList)
    #expect(list.model.problem == "The list could not be opened.")
    #expect(list.route == on(BuiltInTaskViews.today))
}

/// A route that names no list says nothing of it, so the highlight, the list and the task open in it stay where a
/// person put them, by the same list instance: the default window chooses the Inbox itself when it is created and
/// never again (owner, 2026-10-16).
@Test func aRouteThatNamesNoListLeavesTheHighlightAndTheList() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskViewList(store: store, route: on(BuiltInTaskViews.inbox, task: id))
    let rows = try rowsBeforeAnUnreadTask(in: list, of: store)
    let before = list.model
    #expect(list.send(.route(.init(list: nil))) == nil)
    #expect(list.model == before)
    #expect(list.model.taskList?.rows == rows, "the same list, since a list made afresh reads the task written since")
    #expect(list.route == on(BuiltInTaskViews.inbox, task: id))
}

/// A change and being created answer no gesture, so the sentence outlives them, and the next click takes it away.
@Test func theSentenceOutlivesAChangeAndBeingCreatedAndGoesWithTheNextClick() throws {
    let store = try makeStore()
    let gone = try store.createView(NewTaskView(title: "Errands", filter: .status([.open])))
    try store.delete(view: gone)
    let list = try TaskViewList(store: store, route: on(gone))
    let sentence = try #require(list.model.problem, "the sentence is the setup; without it this proves nothing")
    let created = try changeSet(of: store) { try store.createView(NewTaskView(title: "Docs")) }
    #expect(list.send(.changed(created)) == nil)
    #expect(list.send(.created) == nil)
    #expect(list.model.problem == sentence)
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.inbox))) == nil)
    #expect(list.model.problem == nil)
    #expect(list.model.taskList == (try listOn(BuiltInTaskViews.inbox, in: store)))
}

/// An action of the list is handed to it as it came, and a tap opens the task. It never touches this module's
/// sentence: a sentence goes with this module's own gestures and a route, and a gesture in the list is the list's,
/// as a gesture on the task screen leaves the list's own sentence.
@Test func aListActionReachesTheListAndLeavesTheSentence() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.send(.route(on(ViewID()))) == nil)
    let sentence = try #require(list.model.problem, "the sentence is the setup; without it this proves nothing")
    #expect(list.send(.action(.taskList(.rowTapped(id)))) == nil)
    #expect(list.model.taskList == (try listOn(BuiltInTaskViews.inbox, task: id, in: store)))
    #expect(list.route == on(BuiltInTaskViews.inbox, task: id))
    #expect(list.send(.action(.taskList(.backButtonTapped))) == nil)
    #expect(list.model.taskList?.task == nil)
    #expect(list.model.problem == sentence)
}

/// An action of a list that is not open, a row or a back button no longer on screen, has nobody to act on it and
/// moves nothing, the sentence included: the platform sends one through a binding after a close the model drove.
@Test func aListActionWithNoListOpenMovesNothing() throws {
    let store = try makeStore()
    let gone = try store.createView(NewTaskView(title: "Errands", filter: .status([.open])))
    try store.delete(view: gone)
    let task = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskViewList(store: store, route: on(gone))
    let before = list.model
    #expect(before.taskList == nil, "no list is open; this is the setup")
    #expect(before.problem != nil, "the sentence is the setup; without it this proves nothing")
    #expect(list.send(.action(.taskList(.backButtonTapped))) == nil)
    #expect(list.send(.action(.taskList(.rowTapped(task)))) == nil)
    #expect(list.model == before)
    #expect(list.route == .init(list: nil))
}

/// Every change reaches the list after the module has read its own, whatever the change names: the list decides
/// for itself whether it reads it, and the task screen open in it gets it from the list.
@Test func aChangeReachesTheListAndTheTaskOpenInIt() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskViewList(store: store, route: on(BuiltInTaskViews.inbox, task: id))
    let changes = try [
        changeSet(of: store) { try store.createView(NewTaskView(title: "Docs")) },
        changeSet(of: store) { try store.createTask(NewTask(title: "Water the plants")) },
        changeSet(of: store) { try store.update(task: id, [.title("Buy oat milk")]) },
    ]
    for change in changes { #expect(list.send(.changed(change)) == nil) }
    #expect(list.model.rows.last?.title == "Docs")
    #expect(list.model.taskList?.rows.map(\.title) == ["Buy oat milk", "Water the plants"])
    #expect(list.model.taskList?.task?.title == "Buy oat milk")
}

/// The route of the module is the route of the list open in it, which names the view that list is on, so what a
/// window writes down is what is open; a click on an id no row holds opens no list, and the route keeps the one
/// that is open.
@Test func theRouteIsTheOpenList() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil))
    #expect(list.route == on(BuiltInTaskViews.inbox), "the module's own first choice")
    _ = list.send(.action(.rowSelected(BuiltInTaskViews.today)))
    #expect(list.route == on(BuiltInTaskViews.today))
    _ = list.send(.action(.rowSelected(ViewID())))
    #expect(list.route == on(BuiltInTaskViews.today), "no list was made on an id no row carries")
}

/// A new window is the platform's to open, so the module asks its parent with the route of a window on the view,
/// its own route with the list on it, and moves nothing of its own, the highlight, an open field and its sentence
/// included: what the request becomes is the root's to decide, by the rule of bubbling (spec section 4).
@Test func openInNewWindowAsksTheRootAndMovesNothing() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(list: nil))
    _ = list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox)))
    _ = list.send(.action(.titleFieldChanged(" ")))
    _ = list.send(.action(.titleFieldSubmitted))
    let told = list.model
    #expect(told.problem != nil, "the refusal is the setup; without it this proves nothing")
    let asked = list.send(.action(.openInNewWindowMenuItemChosen(BuiltInTaskViews.today)))
    #expect(asked == .openInWindow(on(BuiltInTaskViews.today)))
    #expect(list.model == told)
}

/// The menu item is on a row, and a row the list no longer holds is no view to open, the way the Rename menu
/// item on one opens no field.
@Test func openInNewWindowForAViewNotInTheRowsAnswersNothing() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(list: nil))
    let before = list.model
    #expect(list.send(.action(.openInNewWindowMenuItemChosen(ViewID()))) == nil)
    #expect(list.model == before)
}

/// The sidebar's route owns no segment of a window's path: it hands the path whole to its list's route, an empty
/// path naming no list, and writes what its list writes, nothing for no list.
@Test func theRouteHandsThePathToItsList() throws {
    let view = BuiltInTaskViews.today.rawValue
    var empty: ArraySlice<String> = []
    let none = try TaskViewList.Route(reading: &empty)
    #expect(none == .init(list: nil))
    #expect(none.segments == [])
    var path: ArraySlice = ["view", view]
    let route = try TaskViewList.Route(reading: &path)
    #expect(route == on(BuiltInTaskViews.today))
    #expect(path.isEmpty)
    #expect(route.segments == ["view", view])
    var task: ArraySlice = ["task", view]
    #expect(throws: RouteError.segmentOutOfPlace("task"), "what the list's route refuses") { try TaskViewList.Route(reading: &task) }
}
