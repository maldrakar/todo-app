import Testing
import TestSupport
import TaskViewListFeature
import TodoCore
import SQLiteKit

@Test func initialModelListsTheBuiltInViewsInRankOrderWithInboxSelected() throws {
    let model = try TaskViewList(store: try makeStore(), route: .init(selection: nil)).model
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
    let rows = try TaskViewList(store: store, route: .init(selection: nil)).model.rows.dropFirst(5)
    #expect(rows.map(\.title) == ["Work", "Reviews", "Deep", "Notes"], "past the five built-in views, depth first and siblings by rank")
    #expect(rows.map(\.depth) == [0, 1, 2, 1])
}

@Test func selectionMovesTheHighlightAndReportsTheChoice() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    try store.createView(NewTaskView(title: "Reviews", parent: folder))
    let list = try TaskViewList(store: store, route: .init(selection: nil))
    let before = list.model
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == .selected(BuiltInTaskViews.today))
    #expect(list.model.rows.filter(\.isSelected).map(\.id) == [BuiltInTaskViews.today])
    // Choosing the row that is already chosen is still a choice: the root opens the view again, where an
    // answer withheld would leave a person tapping a highlighted row and watching nothing happen.
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == .selected(BuiltInTaskViews.today))
    // The highlight moved back leaves the model as it was, which is what says that a move carries every
    // other field of every row along: the title a row draws, and the depth a nested one is drawn at.
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.inbox))) == .selected(BuiltInTaskViews.inbox))
    #expect(list.model == before)
}

/// Being created is the one event that nobody chose, and the list answers it with the view it starts on, so
/// that its parent learns the first choice the way it learns every later one: from an answer.
@Test func createdReportsTheViewTheListStartsOnAndLeavesTheModelAlone() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(selection: nil))
    let before = list.model
    #expect(list.send(.created) == .selected(BuiltInTaskViews.inbox))
    #expect(list.model == before, "the highlight was on the Inbox already, and being created moves nothing")
    // A view with no row is not a choice to report: the Inbox the list starts on was deleted before launch.
    let store = try makeStore()
    try store.delete(view: BuiltInTaskViews.inbox)
    let bare = try TaskViewList(store: store, route: .init(selection: nil))
    let empty = bare.model
    #expect(bare.send(.created) == nil)
    #expect(bare.model == empty)
    // Sent after a refusal, which is not where a parent sends it, so that there is a sentence to lose: an
    // answer that took the road `.rowSelected` takes would clear it, and being created is no answer to
    // what a person was told.
    let refused = try TaskViewList(store: try makeStore(), route: .init(selection: nil))
    _ = refused.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox)))
    _ = refused.send(.action(.titleFieldChanged(" ")))
    _ = refused.send(.action(.titleFieldSubmitted))
    let told = refused.model
    #expect(told.problem != nil, "the refusal is the setup; without it this proves nothing")
    #expect(refused.send(.created) == .selected(BuiltInTaskViews.inbox))
    #expect(refused.model == told, "the sentence and the open field outlive it")
}

@Test func changedWithAViewRereadsTheTree() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(selection: nil))
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == .selected(BuiltInTaskViews.today))
    let created = try changeSet(of: store) { try store.createView(NewTaskView(title: "Docs")) }
    #expect(list.send(.changed(created)) == nil)
    #expect(list.model.rows.map(\.title) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash", "Docs"])
    // A view that appeared elsewhere is no reason to lose the row the person is on, and no reason to say
    // that anything went wrong.
    #expect(list.model.rows.filter(\.isSelected).map(\.id) == [BuiltInTaskViews.today])
    #expect(list.model.problem == nil)
}

@Test func changedWithoutAViewLeavesTheModelAlone() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(selection: nil))
    let before = list.model
    let taskOnly = try changeSet(of: store) { try store.createTask(NewTask(title: "Write it down")) }
    try store.createView(NewTaskView(title: "Docs"))
    #expect(list.send(.changed(taskOnly)) == nil)
    #expect(list.model == before, "the view created since is missing, which is how a read that never ran shows")
}

@Test func theSelectionIsDroppedWhenTheSelectedViewDisappears() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(selection: nil))
    let deleted = try changeSet(of: store) { try store.delete(view: BuiltInTaskViews.inbox) }
    #expect(list.send(.changed(deleted)) == nil, "a view a peer deleted is not a choice anybody made")
    #expect(list.model.rows.map(\.title) == ["Today", "Upcoming", "Logbook", "Trash"])
    let selected = list.model.rows.filter(\.isSelected)
    #expect(selected.isEmpty)
}

/// One highlight, read two ways: `selection` is what a list bound to one value reads, and `isSelected` what a
/// client drawing row by row reads. Two readings that disagreed would have two clients highlight different
/// rows, or bind a list to a row it does not draw.
@Test func selectionNamesTheSelectedRow() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(selection: nil))
    #expect(list.model.selection == BuiltInTaskViews.inbox)
    #expect(list.model.rows.filter(\.isSelected).map(\.id) == [BuiltInTaskViews.inbox])
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == .selected(BuiltInTaskViews.today))
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
    let chain = try TaskViewList(store: store, route: .init(selection: nil)).model.rows.filter { $0.id.rawValue.hasPrefix("view-") }
    #expect(chain.map(\.id.rawValue) == ids, "parents before children, however deep the chain")
    #expect(chain.map(\.depth) == Array(0..<1_000))
}

@Test func renameGoesThroughTheDraftIntoTheStore() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(selection: nil))
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
    let list = try TaskViewList(store: store, route: .init(selection: nil))
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
    let list = try TaskViewList(store: store, route: .init(selection: nil))
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
    let list = try TaskViewList(store: store, route: .init(selection: nil))
    let output = list.send(.action(.createFolderButtonTapped))
    #expect(list.model.rows.map(\.title) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash", "New folder"])
    let folder = try #require(list.model.rows.last)
    #expect(folder.depth == 0, "a folder from the toolbar belongs at the root and not under whatever was chosen")
    #expect(list.model.rows.filter(\.isSelected).map(\.id) == [folder.id])
    #expect(folder.draft == "New folder", "the field opens on the default name, so the first keystroke replaces it")
    // The selection moved without anybody choosing a row, and the root learns every choice from the output,
    // the first one included: it is told what a click would have told it, or its detail pane keeps the view
    // before this one.
    #expect(output == .selected(folder.id))
    let stored = try store.view(folder.id)
    #expect(stored?.title == "New folder")
    #expect(stored?.filter == nil, "a folder is a view without a filter, which is what makes it hold others")
    #expect(list.model.problem == nil)
}

@Test func aStoreRefusalLandsInTheProblemAndTheNextActionClearsIt() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    let list = try TaskViewList(store: store, route: .init(selection: nil))
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
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == .selected(BuiltInTaskViews.today))
    #expect(list.model.problem == nil, "a sentence belongs to the event that produced it")
}

@Test func fieldActionsWithoutAnOpenRenameAreIgnored() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    let list = try TaskViewList(store: store, route: .init(selection: nil))
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
    let list = try TaskViewList(store: store, route: .init(selection: nil))
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
    let list = try TaskViewList(store: store, route: .init(selection: nil))
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
    let list = try TaskViewList(store: store, route: .init(selection: nil))
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
    let list = try TaskViewList(store: store, route: .init(selection: nil))
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
    let list = try TaskViewList(store: store, route: .init(selection: nil))
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
    let list = try TaskViewList(store: try makeStore(), route: .init(selection: nil))
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox))) == nil)
    #expect(list.send(.action(.titleFieldChanged(""))) == nil)
    #expect(list.send(.action(.titleFieldLostFocus)) == nil)
    let sentence = try #require(list.model.problem, "the refusal is the setup; without it this proves nothing")
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == .selected(BuiltInTaskViews.today))
    #expect(list.model.problem == sentence)
    #expect(list.model.selection == BuiltInTaskViews.today)
    #expect(list.model.rows.map(\.draft) == ["", nil, nil, nil, nil])
    // The same state reached in the other order, the highlight moved before the refusal, compares the model
    // whole: nothing else moved.
    let reference = try TaskViewList(store: try makeStore(), route: .init(selection: nil))
    _ = reference.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox)))
    _ = reference.send(.action(.rowSelected(BuiltInTaskViews.today)))
    _ = reference.send(.action(.titleFieldChanged("")))
    _ = reference.send(.action(.titleFieldLostFocus))
    #expect(list.model == reference.model)
}

@Test func choosingRenameOnASecondRowMovesTheFieldAndDropsTheFirstDraft() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(selection: nil))
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
    let list = try TaskViewList(store: store, route: .init(selection: nil))
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

/// The default window's route names no view, so the list starts on its own first choice, the Inbox, and says
/// so in answer to being created, as it did before it had a route (ADR-0006, amendment of 2026-10-14).
@Test func theSidebarCreatedFromNoSelectionStartsOnInboxAndSaysSo() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(selection: nil))
    #expect(list.model.selection == BuiltInTaskViews.inbox)
    #expect(list.send(.created) == .selected(BuiltInTaskViews.inbox))
}

/// A route that carries a selection is a choice already made, by a link or by the window a relaunch restores,
/// and the list's answer to being created is that choice, on the road every later one takes (spec section 4).
@Test func theSidebarCreatedFromASelectionStartsThereAndSaysSo() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(selection: BuiltInTaskViews.today))
    #expect(list.send(.created) == .selected(BuiltInTaskViews.today))
    #expect(list.model.selection == BuiltInTaskViews.today)
    #expect(list.model.rows.filter(\.isSelected).map(\.id) == [BuiltInTaskViews.today])
}

/// A link to a view deleted since, or a window restored onto one: an id that is gone is data from outside, and
/// the list opens on what still exists, with no row highlighted and no choice to report (spec section 2).
@Test func theSidebarCreatedFromAGoneSelectionAnswersNothing() throws {
    let store = try makeStore()
    let gone = try store.createView(NewTaskView(title: "Work"))
    try store.delete(view: gone)
    let list = try TaskViewList(store: store, route: .init(selection: gone))
    #expect(list.send(.created) == nil)
    #expect(list.model.rows.map(\.title) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash"])
    #expect(list.model.selection == nil)
    #expect(list.model.rows.filter(\.isSelected).isEmpty)
}

/// A starting choice with no row is not kept for a row that may arrive later, whichever its source: the route's
/// selection, as with a link to a view that has not synced to this device yet, or the Inbox the list falls back
/// on. Kept, it would light up when a peer's change brought the row in, and the parent, told nothing in answer
/// to `.created`, would hold a pane on another view or none beside it. The rows come in from a peer's journal,
/// which is how a view with an id chosen elsewhere reaches this store.
@Test func aStartingSelectionWithNoRowStaysUnhighlightedWhenTheRowArrives() throws {
    let peer = Store.newDeviceID()
    let later = HLC(millis: 1_800_000_000_000, counter: 0)
    func written(_ id: ViewID, _ fields: [(String, Value)]) -> [JournalOperation] {
        fields.map { JournalOperation(entity: .view, entityID: id.rawValue, field: $0.0, value: $0.1, clock: later, device: peer) }
    }

    let store = try makeStore()
    let linked = ViewID()
    let list = try TaskViewList(store: store, route: .init(selection: linked))
    #expect(list.send(.created) == nil, "no row, no choice to report; this is the setup")
    let synced = try changeSet(of: store) {
        _ = try store.apply(written(linked, [
            ("title", .text("Work")), ("parent", .null), ("rank", .text(Rank.initial)), ("deleted", Value(false)),
        ]))
    }
    #expect(list.send(.changed(synced)) == nil)
    #expect(list.model.rows.map(\.id).contains(linked), "the view arrived; without it this proves nothing")
    #expect(list.model.selection == nil, "a highlight the root was never told of")
    #expect(list.model.rows.filter(\.isSelected).isEmpty)

    let bare = try makeStore()
    try bare.delete(view: BuiltInTaskViews.inbox)
    let fallback = try TaskViewList(store: bare, route: .init(selection: nil))
    #expect(fallback.send(.created) == nil, "the Inbox is gone before launch; this is the setup")
    let restored = try changeSet(of: bare) { _ = try bare.apply(written(BuiltInTaskViews.inbox, [("deleted", Value(false))])) }
    #expect(fallback.send(.changed(restored)) == nil)
    #expect(fallback.model.rows.map(\.id).contains(BuiltInTaskViews.inbox), "the Inbox is back; without it this proves nothing")
    #expect(fallback.model.selection == nil, "a highlight the root was never told of")
}

/// A route is its parent's choice and not a person's, and the parent already knows it, so the list moves its
/// highlight and answers nothing: an answer would have the root open again the pane the route opened.
@Test func aRouteMovesTheHighlightAndAnswersNothing() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(selection: nil))
    #expect(list.send(.route(.init(selection: BuiltInTaskViews.today))) == nil)
    #expect(list.model.selection == BuiltInTaskViews.today)
    let routed = try TaskViewList(store: store, route: .init(selection: BuiltInTaskViews.today))
    #expect(list.model == routed.model, "the list a link to Today would have created")
    // The highlight and nothing else: a route carries no session state and keeps what did not change (spec
    // sections 2 and 3), so a field a person has open, and the sentence that explains it, stay where they were.
    _ = list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox)))
    _ = list.send(.action(.titleFieldChanged(" ")))
    _ = list.send(.action(.titleFieldSubmitted))
    #expect(list.model.problem != nil, "the refusal is the setup; without it this proves nothing")
    #expect(list.send(.route(.init(selection: BuiltInTaskViews.upcoming))) == nil)
    #expect(list.model.selection == BuiltInTaskViews.upcoming)
    // The same state reached with the highlight on Upcoming before the refusal compares the model whole.
    let reference = try TaskViewList(store: store, route: .init(selection: BuiltInTaskViews.upcoming))
    _ = reference.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox)))
    _ = reference.send(.action(.titleFieldChanged(" ")))
    _ = reference.send(.action(.titleFieldSubmitted))
    #expect(list.model == reference.model)
}

/// A route to a view the list holds no row for, a link to a view that is gone, moves nothing: a highlight on
/// no row is a highlight nobody can see.
@Test func aRouteToAViewNotInTheRowsMovesNothing() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(selection: BuiltInTaskViews.today))
    let before = list.model
    #expect(list.send(.route(.init(selection: ViewID()))) == nil)
    #expect(list.model == before, "the highlight stays on Today")
}

/// The default window chooses the Inbox itself when it is created and never again, so a route that names no
/// view leaves the highlight where a person put it.
@Test func aRouteWithNoSelectionLeavesTheHighlight() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(selection: nil))
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == .selected(BuiltInTaskViews.today))
    let before = list.model
    #expect(list.send(.route(.init(selection: nil))) == nil)
    #expect(list.model == before)
}

/// The route is assembled from the highlight as the model draws it, so the route written down after a click
/// names the row clicked, and one written after an id no row holds names no view, as the model names no row.
@Test func theRouteReportsTheHighlight() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(selection: nil))
    #expect(list.route == .init(selection: BuiltInTaskViews.inbox), "the list's own first choice")
    _ = list.send(.action(.rowSelected(BuiltInTaskViews.today)))
    #expect(list.route.selection == BuiltInTaskViews.today)
    _ = list.send(.action(.rowSelected(ViewID())))
    #expect(list.route.selection == nil, "an id no row carries is no view to name")
}

/// A new window is the platform's to open, so the list asks its parent and moves nothing of its own, the
/// highlight, an open field and its sentence included: what the request becomes is the root's to decide, by
/// the rule of bubbling (spec section 4).
@Test func openInNewWindowAsksTheRootAndMovesNothing() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(selection: nil))
    _ = list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox)))
    _ = list.send(.action(.titleFieldChanged(" ")))
    _ = list.send(.action(.titleFieldSubmitted))
    let told = list.model
    #expect(told.problem != nil, "the refusal is the setup; without it this proves nothing")
    let asked = list.send(.action(.openInNewWindowMenuItemChosen(BuiltInTaskViews.today)))
    #expect(asked == .openInWindow(BuiltInTaskViews.today))
    #expect(list.model == told)
}

/// The menu item is on a row, and a row the list no longer holds is no view to open, the way the Rename menu
/// item on one opens no field.
@Test func openInNewWindowForAViewNotInTheRowsAnswersNothing() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(selection: nil))
    let before = list.model
    #expect(list.send(.action(.openInNewWindowMenuItemChosen(ViewID()))) == nil)
    #expect(list.model == before)
}
