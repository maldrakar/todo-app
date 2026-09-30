import Testing
import TestSupport
import TaskViewListFeature
import TodoCore
import SQLiteKit

@Test func initialModelListsTheBuiltInViewsInRankOrderWithInboxSelected() throws {
    let model = try TaskViewList(store: try makeStore()).model
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
    let rows = try TaskViewList(store: store).model.rows.dropFirst(5)
    #expect(rows.map(\.title) == ["Work", "Reviews", "Deep", "Notes"], "past the five built-in views, depth first and siblings by rank")
    #expect(rows.map(\.depth) == [0, 1, 2, 1])
}

@Test func selectionMovesTheHighlightAndReportsTheChoice() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    try store.createView(NewTaskView(title: "Reviews", parent: folder))
    let list = try TaskViewList(store: store)
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
    let list = try TaskViewList(store: try makeStore())
    let before = list.model
    #expect(list.send(.created) == .selected(BuiltInTaskViews.inbox))
    #expect(list.model == before, "the highlight was on the Inbox already, and being created moves nothing")
    // A view with no row is not a choice to report: the Inbox the list starts on was deleted before launch.
    let store = try makeStore()
    try store.delete(view: BuiltInTaskViews.inbox)
    let bare = try TaskViewList(store: store)
    let empty = bare.model
    #expect(bare.send(.created) == nil)
    #expect(bare.model == empty)
    // Sent after a refusal, which is not where a parent sends it, so that there is a sentence to lose: an
    // answer that took the road `.rowSelected` takes would clear it, and being created is no answer to
    // what a person was told.
    let refused = try TaskViewList(store: try makeStore())
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
    let list = try TaskViewList(store: store)
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
    let list = try TaskViewList(store: store)
    let before = list.model
    let taskOnly = try changeSet(of: store) { try store.createTask(NewTask(title: "Write it down")) }
    try store.createView(NewTaskView(title: "Docs"))
    #expect(list.send(.changed(taskOnly)) == nil)
    #expect(list.model == before, "the view created since is missing, which is how a read that never ran shows")
}

@Test func theSelectionIsDroppedWhenTheSelectedViewDisappears() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store)
    let deleted = try changeSet(of: store) { try store.delete(view: BuiltInTaskViews.inbox) }
    #expect(list.send(.changed(deleted)) == nil, "a view a peer deleted is not a choice anybody made")
    #expect(list.model.rows.map(\.title) == ["Today", "Upcoming", "Logbook", "Trash"])
    let selected = list.model.rows.filter(\.isSelected)
    #expect(selected.isEmpty)
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
    let chain = try TaskViewList(store: store).model.rows.filter { $0.id.rawValue.hasPrefix("view-") }
    #expect(chain.map(\.id.rawValue) == ids, "parents before children, however deep the chain")
    #expect(chain.map(\.depth) == Array(0..<1_000))
}

@Test func renameGoesThroughTheDraftIntoTheStore() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store)
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
    let list = try TaskViewList(store: store)
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
    let list = try TaskViewList(store: store)
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
    let list = try TaskViewList(store: store)
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
    let list = try TaskViewList(store: store)
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
    let list = try TaskViewList(store: store)
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
    // the field that just closed behind the refusal sends its cancellation here, and a sentence cleared by
    // it would go between the person being told and reading it.
    #expect(list.send(.action(.titleFieldChanged("Anything at all"))) == nil)
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    #expect(list.send(.action(.titleFieldLostFocus)) == nil)
    #expect(list.send(.action(.titleFieldCancelled)) == nil)
    #expect(list.model.problem == sentence, "the sentence outlives the gestures that were ignored")
    #expect(list.model == before)
    #expect(try store.journal(after: 0).count == written)
}

@Test func problemSurvivesAChangedEvent() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store)
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
    let list = try TaskViewList(store: store)
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
    let list = try TaskViewList(store: store)
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
    let list = try TaskViewList(store: store)
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

@Test func choosingRenameOnASecondRowMovesTheFieldAndDropsTheFirstDraft() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store)
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
    let list = try TaskViewList(store: store)
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
