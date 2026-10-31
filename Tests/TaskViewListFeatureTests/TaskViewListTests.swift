import Testing
import TestSupport
import DesignSystem
import FeatureModule
import TaskListFeature
import TaskScreenFeature
import TaskViewListFeature
import TodoCore
import SQLiteKit

/// The route of a sidebar whose list is on a view, with the task open in it when there is one; its `list` is what
/// such a sidebar declares over it.
private func on(_ view: ViewID, task: TaskID? = nil) -> TaskViewList.Route {
    .init(list: .init(head: view, task: task.map { TaskScreen.Route(head: $0) }))
}

/// The model of a sidebar made now on a view, which is what the sidebar is compared with after an event: the
/// rows as a read now answers them, the highlight on the view where a row holds it, and no sentence. Not private,
/// since the rows' tests compare with it too, where a fold has moved the highlight.
func sidebarOn(_ view: ViewID, in store: Store) throws -> TaskViewList.Model {
    try TaskViewList(store: store, route: on(view), width: .narrow, capabilities: iPhone).model
}

/// What a row is called on screen, read over its kind as a view reads it: a list's title, and an area's label, nil
/// for an unnamed area's line.
private func title(of row: TaskViewList.Model.Row) -> String? {
    switch row.kind {
    case .area(let line): line.label?.text
    case .list(let list): list.title.text
    }
}

/// Whether a row carries the highlight, read over its kind as a view drawing row by row reads it, a list's row on the
/// fill colour: an area's line never does, since an area never opens.
private func isHighlighted(_ row: TaskViewList.Model.Row) -> Bool {
    switch row.kind {
    case .area: false
    case .list(let list): list.background == .fill
    }
}

@Test func initialModelListsTheBuiltInViewsInRankOrderWithInboxSelected() throws {
    let model = try TaskViewList(
        store: try makeStore(), route: .init(list: nil), width: .narrow, capabilities: iPhone
    ).model
    #expect(model.rows.map(title(of:)) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash"])
    #expect(model.rows.allSatisfy { $0.depth == 0 })
    #expect(model.rows.filter(isHighlighted).map(\.id) == [BuiltInTaskViews.inbox])
    #expect(model.problem == nil)
}

@Test func nestedViewsGetTheirDepthInTreeOrder() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    let reviews = try store.createView(NewTaskView(title: "Reviews", parent: folder))
    try store.createView(NewTaskView(title: "Notes", parent: folder))
    try store.createView(NewTaskView(title: "Deep", parent: reviews))
    let rows = try TaskViewList(
        store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone
    ).model.rows.dropFirst(5)
    #expect(rows.map(title(of:)) == ["Work", "Reviews", "Deep", "Notes"], "past the five built-in views, depth first and siblings by rank")
    #expect(rows.map(\.depth) == [0, 1, 2, 1])
}

/// A click declares the list of the view clicked, which the window's stack opens over the sidebar, and the
/// highlight is that declaration where a row holds it, so the two cannot disagree (spec section 1). The module
/// says nothing in answer, since what a click opens is its own to declare.
@Test func aClickDeclaresTheViewsListAndHighlightsIt() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    try store.createView(NewTaskView(title: "Reviews", parent: folder))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    let before = list.model
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == nil)
    #expect(list.destination.pushed == on(BuiltInTaskViews.today).list)
    #expect(list.model == (try sidebarOn(BuiltInTaskViews.today, in: store)))
    #expect(list.model.rows.filter(isHighlighted).map(\.id) == [BuiltInTaskViews.today])
    #expect(list.route == on(BuiltInTaskViews.today))
    // The highlight moved back leaves the model as it was, which is what says that a move carries every
    // other field of every row along: the title a row draws, and the depth a nested one is drawn at.
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.inbox))) == nil)
    #expect(list.model == before)
}

/// A click on the highlighted view is still a choice, and it declares the view's list again, with no task: the
/// stack keeps the list standing on that view and hands it the declaration, which closes the task open in it, so
/// the click returns to the list, as System Settings does on the Mac and a second tap on a tab does on iOS (owner,
/// 2026-10-16). The window's half is `AppModuleTests`.
@Test func aClickOnTheHighlightedViewDeclaresItsListAgain() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskViewList(
        store: store, route: on(BuiltInTaskViews.inbox, task: id), width: .narrow, capabilities: iPhone
    )
    #expect(list.destination.pushed == on(BuiltInTaskViews.inbox, task: id).list, "the task is declared with the list; this is the setup")
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.inbox))) == nil)
    #expect(list.destination.pushed == on(BuiltInTaskViews.inbox).list)
    #expect(list.model == (try sidebarOn(BuiltInTaskViews.inbox, in: store)))
    #expect(list.route == on(BuiltInTaskViews.inbox))
}

/// A click on a view a peer deleted, before the change saying so has arrived: the row is still there, so the click
/// declares its list and the highlight moves onto it. The stack cannot make the list, and tells the sidebar why and
/// which list still stands over it, which the sidebar takes back as its destination: the highlight returns to the
/// list that is open, and the sidebar says so, a sentence the click had taken any older one away for (spec, "Open
/// questions"). Made on a view that is gone, the sidebar declares its list on no row, and takes back nothing.
@Test func aListThatCouldNotBeOpenedTakesBackTheHighlightAndSaysSo() throws {
    let store = try makeStore()
    let gone = try store.createView(NewTaskView(title: "Errands", filter: .status([.open])))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    let open = list.model
    try store.delete(view: gone)
    #expect(list.send(.action(.rowSelected(gone))) == nil)
    #expect(list.model.selection == gone, "the click declared the list on its row; this is the setup")
    #expect(list.send(.notOpened(.notFound(gone), stillOpen: on(BuiltInTaskViews.inbox).list)) == nil)
    #expect(list.destination.pushed == on(BuiltInTaskViews.inbox).list)
    #expect(list.model.rows == open.rows)
    #expect(list.model.selection == BuiltInTaskViews.inbox)
    #expect(list.model.problem == "The list could not be opened.")
    #expect(list.route == on(BuiltInTaskViews.inbox))

    let made = try TaskViewList(store: store, route: on(gone), width: .narrow, capabilities: iPhone)
    #expect(made.destination.pushed == on(gone).list, "a link to a view that is gone declares its list all the same")
    #expect(
        made.model == (try TaskViewList(store: store, route: on(ViewID()), width: .narrow, capabilities: iPhone)).model,
        "on no row, so nothing is highlighted"
    )
    #expect(made.model.selection == nil)
    #expect(made.send(.notOpened(.notFound(gone), stillOpen: nil)) == nil)
    #expect(made.destination.pushed == nil)
    #expect(made.model.rows.map(title(of:)) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash"])
    #expect(made.model.selection == nil)
    #expect(made.model.problem == "The list could not be opened.")
    #expect(made.route == .init(list: nil))
}

/// The person went back to the views where the list is a screen pushed over them, on a narrow window: the list is
/// gone already, so the sidebar empties its destination, which it cannot keep (spec section 3), and the highlight
/// goes with it, since the screen the person chose is closed and nothing stays chosen (owner, 2026-10-21), as
/// iPhone's System Settings leaves nothing chosen after Back. The route then names no list. The sentence goes as
/// it does with a click, except while a field is open, whose sentence explains it and which the gesture leaves
/// where it is; the destination empties either way.
@Test func uncoveredTakesTheHighlightAndTheSentenceExceptAnOpenFieldsOne() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let gone = try store.createView(NewTaskView(title: "Errands", filter: .status([.open])))
    let list = try TaskViewList(
        store: store, route: on(BuiltInTaskViews.inbox, task: id), width: .narrow, capabilities: iPhone
    )
    try store.delete(view: gone)
    _ = list.send(.action(.rowSelected(gone)))
    _ = list.send(.notOpened(.notFound(gone), stillOpen: on(BuiltInTaskViews.inbox, task: id).list))
    #expect(list.model.problem == "The list could not be opened.", "the sentence is the setup; without it this proves nothing")
    #expect(list.destination.pushed != nil, "the Inbox's list stayed declared; this is the setup")
    let rows = list.model.rows
    #expect(list.send(.uncovered) == nil)
    #expect(list.destination.pushed == nil)
    #expect(list.model.rows.map(title(of:)) == rows.map(title(of:)))
    #expect(list.model.rows.filter(isHighlighted).isEmpty)
    #expect(list.model.selection == nil)
    #expect(list.model.problem == nil)
    #expect(list.route == .init(list: nil))
    let renaming = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    _ = renaming.send(.action(.renameMenuItemChosen(BuiltInTaskViews.today)))
    _ = renaming.send(.action(.titleFieldChanged(" ")))
    _ = renaming.send(.action(.titleFieldSubmitted))
    #expect(renaming.model.problem == "A title cannot be empty.", "the field's refusal is the setup")
    #expect(renaming.send(.uncovered) == nil)
    #expect(renaming.model.problem == "A title cannot be empty.")
    #expect(renaming.model.rows.first(where: { $0.id == BuiltInTaskViews.today }).flatMap(draft(of:)) == " ", "the field stays open on the draft")
    #expect(renaming.model.selection == nil)
    #expect(renaming.destination.pushed == nil)
}

/// After the way back to the views, the view that was highlighted is chosen like any other: a click declares its
/// list again and a link does too, each a write the stack follows by pushing the list (#107, #113).
@Test func aClickOrARouteAfterBeingUncoveredDeclaresTheListAgain() throws {
    let store = try makeStore()
    let clicked = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    _ = clicked.send(.uncovered)
    #expect(clicked.send(.action(.rowSelected(BuiltInTaskViews.inbox))) == nil)
    #expect(clicked.destination.pushed == on(BuiltInTaskViews.inbox).list)
    #expect(clicked.model == (try sidebarOn(BuiltInTaskViews.inbox, in: store)))
    #expect(clicked.route == on(BuiltInTaskViews.inbox))
    let linked = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    _ = linked.send(.uncovered)
    #expect(linked.send(.route(on(BuiltInTaskViews.inbox))) == nil)
    #expect(linked.destination.pushed == on(BuiltInTaskViews.inbox).list)
    #expect(linked.model == (try sidebarOn(BuiltInTaskViews.inbox, in: store)))
    #expect(linked.route == on(BuiltInTaskViews.inbox))
}

/// The list asks to be closed when its view is gone, on its own `.changed`, and the sidebar empties its
/// destination, so the stack drops the list with whatever stands over it (spec section 3). The sidebar's reread
/// left the destination to that answer and let the highlight go with its row, by computation, so what the answer
/// takes away is a declaration on no row. The answer is no gesture, so the sentence stays.
@Test func theListsAnswerToCloseTakesTheHighlight() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    _ = list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.today)))
    _ = list.send(.action(.titleFieldChanged(" ")))
    _ = list.send(.action(.titleFieldSubmitted))
    #expect(list.model.problem == "A title cannot be empty.", "the sentence is the setup; without it this proves nothing")
    let deleted = try changeSet(of: store) { try store.delete(view: BuiltInTaskViews.inbox) }
    #expect(list.send(.changed(deleted)) == nil, "a view a peer deleted is not a choice anybody made")
    #expect(list.model.rows.map(title(of:)) == ["Today", "Upcoming", "Logbook", "Trash"])
    #expect(list.model.selection == nil, "the highlight went with its row")
    #expect(list.model.rows.filter(isHighlighted).isEmpty)
    #expect(list.destination.pushed == on(BuiltInTaskViews.inbox).list, "a reread leaves the destination to the list's answer")
    let told = list.model
    #expect(list.send(.destinationAnswered(.closeRequested)) == nil)
    #expect(list.destination.pushed == nil)
    #expect(list.model == told)
    #expect(list.route == .init(list: nil))
}

/// Being created is the one event that nobody chose, and the module has nothing to say in answer: it declared the
/// list of the view it starts on in its `init`, as the task list declares its task in its own. Nothing moves, the
/// declaration and the sentence included, since being created answers nothing a person was told.
@Test func createdAnswersNothingAndMovesNothing() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(list: nil), width: .narrow, capabilities: iPhone)
    let before = list.model
    #expect(list.send(.created) == nil)
    #expect(list.model == before)
    #expect(list.destination.pushed == on(BuiltInTaskViews.inbox).list)
    // Sent after a refusal, which is not where a parent sends it, so that there is a sentence to lose.
    let refused = try TaskViewList(
        store: try makeStore(), route: .init(list: nil), width: .narrow, capabilities: iPhone
    )
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
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == nil)
    let created = try changeSet(of: store) { try store.createView(NewTaskView(title: "Docs")) }
    #expect(list.send(.changed(created)) == nil)
    #expect(list.model.rows.map(title(of:)) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash", "Docs"])
    // A view that appeared elsewhere is no reason to lose the row the person is on, and no reason to say
    // that anything went wrong.
    #expect(list.model.rows.filter(isHighlighted).map(\.id) == [BuiltInTaskViews.today])
    #expect(list.model.problem == nil)
    #expect(list.destination.pushed == on(BuiltInTaskViews.today).list)
}

/// One highlight, read two ways: `selection` is what a list bound to one value reads, and `isSelected` what a
/// client drawing row by row reads. Two readings that disagreed would have two clients highlight different
/// rows, or bind a list to a row it does not draw.
@Test func selectionNamesTheSelectedRow() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(list.model.selection == BuiltInTaskViews.inbox)
    #expect(list.model.rows.filter(isHighlighted).map(\.id) == [BuiltInTaskViews.inbox])
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == nil)
    #expect(list.model.selection == BuiltInTaskViews.today)
    #expect(list.model.rows.filter(isHighlighted).map(\.id) == [BuiltInTaskViews.today])
    let deleted = try changeSet(of: store) { try store.delete(view: BuiltInTaskViews.today) }
    #expect(list.send(.changed(deleted)) == nil)
    #expect(list.model.selection == nil, "the highlight went with its row")
    #expect(list.model.rows.filter(isHighlighted).isEmpty)
    // `.rowSelected` declares the list of whatever id it is given without asking the rows, so an id that names no
    // row is a declaration the sidebar holds, until the stack hands it back, and draws nowhere: neither reading
    // names it.
    _ = list.send(.action(.rowSelected(ViewID())))
    #expect(list.model.selection == nil, "an id no row carries is no row to bind to")
    #expect(list.model.rows.filter(isHighlighted).isEmpty)
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
    let chain = try TaskViewList(
        store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone
    ).model.rows.filter { $0.id.rawValue.hasPrefix("view-") }
    #expect(chain.map(\.id.rawValue) == ids, "parents before children, however deep the chain")
    #expect(chain.map(\.depth) == Array(0..<1_000))
}

@Test func renameGoesThroughTheDraftIntoTheStore() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox))) == nil)
    #expect(list.model.rows.first.flatMap(draft(of:)) == "Inbox", "the field opens on the title the person chose the menu item on")
    // Every keystroke is a round trip through the module, which is what says the draft is the model's and not
    // something the text field keeps to itself (ADR-0006).
    for typed in ["In", "Ins", "Inside"] {
        #expect(list.send(.action(.titleFieldChanged(typed))) == nil)
        #expect(list.model.rows.first.flatMap(draft(of:)) == typed)
    }
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    let stored = try store.view(BuiltInTaskViews.inbox)?.title
    #expect(stored == "Inside", "the last draft is the title, and the three before it never reached the store")
    #expect(list.model.rows.first.flatMap(title(of:)) == "Inside", "the row is read back out of the store, not patched")
    #expect(list.model.rows.allSatisfy { draft(of: $0) == nil }, "no field is open on any row once the name is in")
    #expect(list.model.problem == nil)
}

@Test func cancelRenameLeavesTheTitleAndClosesTheField() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
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
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    let written = try store.journal(after: 0).count
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox))) == nil)
    for typed in [" \t ", ""] {
        #expect(list.send(.action(.titleFieldChanged(typed))) == nil)
        #expect(list.send(.action(.titleFieldSubmitted)) == nil)
        #expect(list.model.problem == "A title cannot be empty.")
        // The store is what the count proves nothing reached: a refusal that wrote first and complained
        // afterwards would leave a nameless view behind on every device (spec, "The sidebar in M2").
        #expect(try store.journal(after: 0).count == written)
        #expect(list.model.rows.first.flatMap(draft(of:)) == typed, "the field is still open, on the text the person typed")
        #expect(list.model.rows.first.flatMap(title(of:)) == "Inbox")
    }
}

@Test func aStoreRefusalLandsInTheProblemAndTheNextActionClearsIt() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(list.send(.action(.renameMenuItemChosen(folder))) == nil)
    #expect(list.send(.action(.titleFieldChanged("Work in progress"))) == nil)
    // The peer's delete arrives as a delete and not as a `.changed`: the list hears about it from the
    // refusal, which is the race the store's `requireView` exists for.
    try store.delete(view: folder)
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    let sentence = try #require(list.model.problem)
    #expect(sentence.contains("Work"), "the sentence names the view the field was open on")
    #expect(!sentence.contains("Work in progress"), "it names the view, not the name that never took")
    #expect(list.model.rows.map(title(of:)) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash"], "the reread dropped it")
    #expect(list.model.rows.allSatisfy { draft(of: $0) == nil }, "the field closed: there is no row left to type on")
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == nil)
    #expect(list.model.problem == nil, "a sentence belongs to the event that produced it")
}

@Test func fieldActionsWithoutAnOpenRenameAreIgnored() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
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
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
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
    #expect(list.model.rows.first.flatMap(draft(of:)) == "I")
}

@Test func problemSurvivesAChangedEvent() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox))) == nil)
    #expect(list.send(.action(.titleFieldChanged(" "))) == nil)
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    let problem = try #require(list.model.problem)
    let created = try changeSet(of: store) { try store.createView(NewTaskView(title: "Docs")) }
    #expect(list.send(.changed(created)) == nil)
    // A sentence belongs to the action it answered, and what another device did is no answer to it: a
    // problem cleared by a peer's edit would vanish between a person reading it and acting on it.
    #expect(list.model.problem == problem)
    #expect(list.model.rows.map(title(of:)).contains("Docs"), "the tree was reread all the same")
    #expect(list.model.rows.first.flatMap(draft(of:)) == " ", "the field a person is typing in outlives a peer's edit")
}

/// The selection and the rename are the module's own state, and a reread is what holds them to the rows it
/// just read: whichever of them names a row that did not come back goes with it. This is the rename's half,
/// and the half a person is told about, because a name being typed is a thing to interrupt.
@Test func aRenameEndsWhenThePeerDeletesTheRowItIsOn() throws {
    let store = try makeStore()
    let folder = try store.createView(NewTaskView(title: "Work"))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(list.send(.action(.renameMenuItemChosen(folder))) == nil)
    #expect(list.send(.action(.titleFieldChanged("Work in progress"))) == nil)
    let deleted = try changeSet(of: store) { try store.delete(view: folder) }
    #expect(list.send(.changed(deleted)) == nil)
    let after = list.model
    #expect(after.rows.allSatisfy { draft(of: $0) == nil }, "no row is left for the field to be on")
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
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.logbook))) == nil)
    #expect(list.send(.action(.titleFieldChanged("Done"))) == nil)
    // Clicking away settles a name, the way it does in the Finder: the person wrote it and then went on
    // with their work, and a name thrown away there is a name they have to type twice.
    #expect(list.send(.action(.titleFieldLostFocus)) == nil)
    let stored = try store.view(BuiltInTaskViews.logbook)?.title
    #expect(stored == "Done")
    #expect(list.model.rows.map(title(of:)) == ["Inbox", "Today", "Upcoming", "Done", "Trash"])
    #expect(list.model.rows.allSatisfy { draft(of: $0) == nil }, "the field is closed, the way Return closes it")
    #expect(list.model.problem == nil)
}

@Test func aFieldThatLosesFocusOnAnEmptyTitleIsRefusedTheWayReturnIs() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    let written = try store.journal(after: 0).count
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox))) == nil)
    #expect(list.send(.action(.titleFieldChanged("  "))) == nil)
    // One draft ended two ways is one draft: a refusal that depended on which gesture ended it would make
    // the same two spaces mean two different things.
    #expect(list.send(.action(.titleFieldLostFocus)) == nil)
    #expect(list.model.problem == "A title cannot be empty.")
    #expect(list.model.rows.first.flatMap(draft(of:)) == "  ", "the field stays open on the text, as it does for Return")
    #expect(list.model.rows.first.flatMap(title(of:)) == "Inbox")
    #expect(try store.journal(after: 0).count == written)
}

/// A click on another row while the field holds an empty name loses the field's focus first, and the refusal
/// sets the sentence; the click's own `.rowSelected` follows. The highlight moves, the field stays open and
/// empty where it was, and the sentence is still what explains it.
@Test func choosingARowWhileAFieldIsOpenLeavesTheSentence() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox))) == nil)
    #expect(list.send(.action(.titleFieldChanged(""))) == nil)
    #expect(list.send(.action(.titleFieldLostFocus)) == nil)
    let sentence = try #require(list.model.problem, "the refusal is the setup; without it this proves nothing")
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == nil)
    #expect(list.model.problem == sentence)
    #expect(list.model.selection == BuiltInTaskViews.today)
    #expect(list.model.rows.map(draft(of:)) == ["", nil, nil, nil, nil])
    // The same state reached in the other order, the highlight moved before the refusal, compares the model
    // whole: nothing else moved.
    let reference = try TaskViewList(
        store: try makeStore(), route: .init(list: nil), width: .narrow, capabilities: iPhone
    )
    _ = reference.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox)))
    _ = reference.send(.action(.rowSelected(BuiltInTaskViews.today)))
    _ = reference.send(.action(.titleFieldChanged("")))
    _ = reference.send(.action(.titleFieldLostFocus))
    #expect(list.model == reference.model)
}

@Test func choosingRenameOnASecondRowMovesTheFieldAndDropsTheFirstDraft() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox))) == nil)
    #expect(list.send(.action(.titleFieldChanged("Later"))) == nil)
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.trash))) == nil)
    // One field at a time, and the one a person walked away from takes its draft with it: a name typed
    // into a row nobody is looking at would be written by the next Return, wherever the field had moved.
    #expect(list.model.rows.map(draft(of:)) == [nil, nil, nil, nil, "Trash"])
    #expect(list.model.rows.first.flatMap(title(of:)) == "Inbox")
    let stored = try store.view(BuiltInTaskViews.inbox)?.title
    #expect(stored == "Inbox", "the dropped draft was never written, since nothing committed it")
}

@Test func aDraftIsStoredWithoutTheWhitespaceAtItsEnds() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.upcoming))) == nil)
    #expect(list.send(.action(.titleFieldChanged("  Work in progress \t "))) == nil)
    // What the person typed is what the field shows, padding and all: the trim is about what the store
    // keeps, not about moving text under a caret while it is still being typed.
    let renaming = list.model.rows.first { $0.id == BuiltInTaskViews.upcoming }
    #expect(renaming.flatMap(draft(of:)) == "  Work in progress \t ")
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    let stored = try store.view(BuiltInTaskViews.upcoming)?.title
    #expect(stored == "Work in progress", "the ends go, and the space between the words stays")
    #expect(list.model.rows.map(title(of:)) == ["Inbox", "Today", "Work in progress", "Logbook", "Trash"])
    #expect(list.model.problem == nil)
}

/// The default window's route names no list, so the module starts on its own first choice, the Inbox, and declares
/// the Inbox's list in its `init`, the way the task list declares the task its route names in its own.
@Test func theSidebarCreatedFromNoListDeclaresInbox() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(list.destination.pushed == on(BuiltInTaskViews.inbox).list)
    #expect(list.model == (try sidebarOn(BuiltInTaskViews.inbox, in: store)), "the sidebar a link to the Inbox makes")
    #expect(list.model.selection == BuiltInTaskViews.inbox)
    #expect(list.model.problem == nil)
    #expect(list.route == on(BuiltInTaskViews.inbox))
}

/// A route that names a list is a choice already made, by a link or by the window a relaunch restores: the module
/// declares the route's list whole, with the task in it, and the highlight starts on its view.
@Test func theSidebarCreatedFromAListDeclaresIt() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskViewList(store: store, route: on(BuiltInTaskViews.today), width: .narrow, capabilities: iPhone)
    #expect(list.destination.pushed == on(BuiltInTaskViews.today).list)
    #expect(list.model.selection == BuiltInTaskViews.today)
    #expect(list.model.rows.filter(isHighlighted).map(\.id) == [BuiltInTaskViews.today])
    let linked = try TaskViewList(
        store: store, route: on(BuiltInTaskViews.inbox, task: id), width: .narrow, capabilities: iPhone
    )
    #expect(linked.destination.pushed == on(BuiltInTaskViews.inbox, task: id).list)
    #expect(linked.model == (try sidebarOn(BuiltInTaskViews.inbox, in: store)), "the task is the list's to declare, and draws nothing here")
    #expect(linked.route == on(BuiltInTaskViews.inbox, task: id))
}

/// A person who deleted the Inbox leaves the module starting on no row: it declares nothing and says nothing,
/// since nothing was asked for.
@Test func theSidebarCreatedWithNoInboxDeclaresNothing() throws {
    let store = try makeStore()
    try store.delete(view: BuiltInTaskViews.inbox)
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(list.destination.pushed == nil)
    #expect(list.model.rows.map(title(of:)) == ["Today", "Upcoming", "Logbook", "Trash"])
    #expect(list.model.selection == nil)
    #expect(list.model.problem == nil)
    #expect(list.route == .init(list: nil))
}

/// A starting choice the stack could not open is not kept for a row that may arrive later, whichever its source:
/// the route's list, as with a link to a view that has not synced to this device yet, is declared, and taken back
/// when the stack says it could not be made; the Inbox the module falls back on is declared only when a row holds
/// it. Kept, either would light up when a peer's change brought the row in, beside a list that was never opened on
/// it. The rows come in from a peer's journal, which is how a view with an id chosen elsewhere reaches this store.
@Test func aStartingSelectionWithNoRowStaysUnhighlightedWhenTheRowArrives() throws {
    let peer = Store.newDeviceID()
    let later = HLC(millis: 1_800_000_000_000, counter: 0)
    func written(_ id: ViewID, _ fields: [(String, Value)]) -> [JournalOperation] {
        fields.map { JournalOperation(entity: .view, entityID: id.rawValue, field: $0.0, value: $0.1, clock: later, device: peer) }
    }

    let store = try makeStore()
    let linked = ViewID()
    let list = try TaskViewList(store: store, route: on(linked), width: .narrow, capabilities: iPhone)
    _ = list.send(.notOpened(.notFound(linked), stillOpen: nil))
    #expect(list.destination.pushed == nil, "no view, no list; this is the setup")
    let synced = try changeSet(of: store) {
        _ = try store.apply(written(linked, [
            ("title", .text("Work")), ("parent", .null), ("rank", .text(Rank.initial)), ("deleted", Value(false)),
        ]))
    }
    #expect(list.send(.changed(synced)) == nil)
    #expect(list.model.rows.map(\.id).contains(linked), "the view arrived; without it this proves nothing")
    #expect(list.model.selection == nil, "a highlight beside no list")
    #expect(list.model.rows.filter(isHighlighted).isEmpty)
    #expect(list.destination.pushed == nil)

    let bare = try makeStore()
    try bare.delete(view: BuiltInTaskViews.inbox)
    let fallback = try TaskViewList(store: bare, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(fallback.destination.pushed == nil, "the Inbox is gone before launch; this is the setup")
    let restored = try changeSet(of: bare) { _ = try bare.apply(written(BuiltInTaskViews.inbox, [("deleted", Value(false))])) }
    #expect(fallback.send(.changed(restored)) == nil)
    #expect(fallback.model.rows.map(\.id).contains(BuiltInTaskViews.inbox), "the Inbox is back; without it this proves nothing")
    #expect(fallback.model.selection == nil, "a highlight beside no list")
    #expect(fallback.destination.pushed == nil)
}

/// A route is its parent's choice and not a person's, and it answers nothing: it declares its list, and the highlight
/// goes onto its view, so the module ends where a link to the view would have made it.
@Test func aRouteDeclaresItsListAndHighlightsIt() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(list.send(.route(on(BuiltInTaskViews.today))) == nil)
    #expect(list.destination.pushed == on(BuiltInTaskViews.today).list)
    #expect(list.model == (try sidebarOn(BuiltInTaskViews.today, in: store)), "the module a link to Today would have created")
    #expect(list.model.selection == BuiltInTaskViews.today)
    #expect(list.route == on(BuiltInTaskViews.today))
}

/// A route takes the sentence away at its start, except while a field is open: the sentence on screen is then what
/// explains the field, which the route leaves where it is, as a click does (owner, 2026-10-16). The route carries no
/// session state (spec section 2).
@Test func aRouteTakesTheSentenceAwayUnlessAFieldIsOpen() throws {
    let store = try makeStore()
    let gone = try store.createView(NewTaskView(title: "Errands", filter: .status([.open])))
    try store.delete(view: gone)
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(list.send(.route(on(gone))) == nil)
    _ = list.send(.notOpened(.notFound(gone), stillOpen: on(BuiltInTaskViews.inbox).list))
    #expect(list.model.problem == "The list could not be opened.", "the sentence is the setup; without it this proves nothing")
    // A route that names no list takes the sentence too, and leaves the destination where it is.
    #expect(list.send(.route(.init(list: nil))) == nil)
    #expect(list.model == (try sidebarOn(BuiltInTaskViews.inbox, in: store)))
    #expect(list.destination.pushed == on(BuiltInTaskViews.inbox).list)
    #expect(list.route == on(BuiltInTaskViews.inbox))
    #expect(list.send(.route(on(gone))) == nil)
    _ = list.send(.notOpened(.notFound(gone), stillOpen: on(BuiltInTaskViews.inbox).list))
    #expect(list.model.problem == "The list could not be opened.", "the sentence is the setup again")
    #expect(list.send(.route(on(BuiltInTaskViews.today))) == nil)
    #expect(list.model == (try sidebarOn(BuiltInTaskViews.today, in: store)))
    // With a field open on a refused name, the sentence explains the field, and a route leaves both.
    _ = list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox)))
    _ = list.send(.action(.titleFieldChanged(" ")))
    _ = list.send(.action(.titleFieldSubmitted))
    #expect(list.model.problem != nil, "the refusal is the setup; without it this proves nothing")
    #expect(list.send(.route(on(BuiltInTaskViews.upcoming))) == nil)
    #expect(list.model.selection == BuiltInTaskViews.upcoming)
    // The same state reached with the highlight on Upcoming before the refusal compares the model whole.
    let reference = try TaskViewList(
        store: store, route: on(BuiltInTaskViews.upcoming), width: .narrow, capabilities: iPhone
    )
    _ = reference.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox)))
    _ = reference.send(.action(.titleFieldChanged(" ")))
    _ = reference.send(.action(.titleFieldSubmitted))
    #expect(list.model == reference.model)
}

/// With a field open on a refused name, a list that a click or a route declared and the stack could not open says
/// so over the field's sentence: it answers the gesture just made, and the field stays open on the draft, so Return
/// brings the field's own refusal back.
@Test func aListThatCannotBeOpenedSpeaksOverAnOpenFieldsSentence() throws {
    let store = try makeStore()
    let gone = try store.createView(NewTaskView(title: "Errands", filter: .status([.open])))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    _ = list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.inbox)))
    _ = list.send(.action(.titleFieldChanged(" ")))
    _ = list.send(.action(.titleFieldSubmitted))
    #expect(list.model.problem == "A title cannot be empty.", "the field's refusal is the setup; without it this proves nothing")
    try store.delete(view: gone)
    #expect(list.send(.action(.rowSelected(gone))) == nil)
    #expect(list.model.problem == "A title cannot be empty.", "the click leaves the field's sentence")
    #expect(list.send(.notOpened(.notFound(gone), stillOpen: on(BuiltInTaskViews.inbox).list)) == nil)
    #expect(list.model.problem == "The list could not be opened.")
    #expect(list.model.rows.first.flatMap(draft(of:)) == " ", "the field stays open on the draft")
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    #expect(list.model.problem == "A title cannot be empty.", "Return brings the field's refusal back")
    #expect(list.send(.route(on(gone))) == nil)
    #expect(list.send(.notOpened(.notFound(gone), stillOpen: on(BuiltInTaskViews.inbox).list)) == nil)
    #expect(list.model.problem == "The list could not be opened.")
    #expect(list.model.rows.first.flatMap(draft(of:)) == " ")
}

/// A route to a view the module holds no row for, a link to one that is gone, declares its list on no row, so the
/// highlight is on nothing until the stack hands back the list that stays, Today's, and the sidebar says it could
/// not open the other (spec section 2).
@Test func aRouteToAViewThatIsGoneLeavesTheHighlightAndTheListAndSaysSo() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: on(BuiltInTaskViews.today), width: .narrow, capabilities: iPhone)
    let before = list.model
    let gone = ViewID()
    #expect(list.send(.route(on(gone))) == nil)
    #expect(list.model.selection == nil, "declared on no row; this is the setup")
    #expect(list.send(.notOpened(.notFound(gone), stillOpen: on(BuiltInTaskViews.today).list)) == nil)
    #expect(list.model.rows == before.rows)
    #expect(list.model.selection == before.selection, "the highlight is back on Today")
    #expect(list.model.problem == "The list could not be opened.")
    #expect(list.destination.pushed == on(BuiltInTaskViews.today).list)
    #expect(list.route == on(BuiltInTaskViews.today))
}

/// A route that names no list says nothing of it, so the module declares nothing and the list and the task open in
/// it stay where a person put them: the default window chooses the Inbox itself when it is created and never again
/// (owner, 2026-10-16). A declaration written again would be a new one, which the stack hands the list, so it is
/// not written at all; the window's half is `AppModuleTests`.
@Test func aRouteThatNamesNoListLeavesTheDestination() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskViewList(
        store: store, route: on(BuiltInTaskViews.inbox, task: id), width: .narrow, capabilities: iPhone
    )
    let before = list.model
    #expect(list.send(.route(.init(list: nil))) == nil)
    #expect(list.model == before)
    #expect(list.destination.pushed == on(BuiltInTaskViews.inbox, task: id).list)
    #expect(list.route == on(BuiltInTaskViews.inbox, task: id))
}

/// A change and being created answer no gesture, so the sentence outlives them, and the next click takes it away.
@Test func theSentenceOutlivesAChangeAndBeingCreatedAndGoesWithTheNextClick() throws {
    let store = try makeStore()
    let gone = try store.createView(NewTaskView(title: "Errands", filter: .status([.open])))
    try store.delete(view: gone)
    let list = try TaskViewList(store: store, route: on(gone), width: .narrow, capabilities: iPhone)
    _ = list.send(.notOpened(.notFound(gone), stillOpen: nil))
    let sentence = try #require(list.model.problem, "the sentence is the setup; without it this proves nothing")
    let created = try changeSet(of: store) { try store.createView(NewTaskView(title: "Docs")) }
    #expect(list.send(.changed(created)) == nil)
    #expect(list.send(.created) == nil)
    #expect(list.model.problem == sentence)
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.inbox))) == nil)
    #expect(list.model == (try sidebarOn(BuiltInTaskViews.inbox, in: store)))
    #expect(list.destination.pushed == on(BuiltInTaskViews.inbox).list)
}

/// The route of the module is what it declared, which names the view of its list and the task declared in it, so
/// that what the window's stack writes down from it is what was asked for; a click on an id no row holds declares
/// its list too, until the stack hands back the list that stays.
@Test func theRouteIsWhatItDeclared() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow, capabilities: iPhone)
    #expect(list.route == on(BuiltInTaskViews.inbox), "the module's own first choice")
    _ = list.send(.action(.rowSelected(BuiltInTaskViews.today)))
    #expect(list.route == on(BuiltInTaskViews.today))
    let unknown = ViewID()
    _ = list.send(.action(.rowSelected(unknown)))
    #expect(list.route == on(unknown))
    _ = list.send(.notOpened(.notFound(unknown), stillOpen: on(BuiltInTaskViews.today).list))
    #expect(list.route == on(BuiltInTaskViews.today), "the list that stays")
}

/// A new window is the platform's to open, so the module asks its parent with the route of a window on the view,
/// its own route with the list on it, and moves nothing of its own, the highlight, an open field and its sentence
/// included: what the request becomes is the root's to decide, by the rule of bubbling (spec section 4).
@Test func openInNewWindowAsksTheRootAndMovesNothing() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(list: nil), width: .narrow, capabilities: iPhone)
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
    let list = try TaskViewList(store: try makeStore(), route: .init(list: nil), width: .narrow, capabilities: iPhone)
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
