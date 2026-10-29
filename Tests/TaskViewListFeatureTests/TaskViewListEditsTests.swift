import Testing
import TestSupport
import FeatureModule
import SQLiteKit
import TaskListFeature
import TaskViewListFeature
import TodoCore

/// The areas' labels a model draws, in order, read off its rows' kinds: a name, "Area" in edit mode for an unnamed
/// area, and nil for an unnamed area's line outside it.
private func areaLabels(in model: TaskViewList.Model) -> [String?] {
    model.rows.compactMap { row in
        guard case .area(let label) = row.kind else { return nil }
        return .some(label)
    }
}

/// Edit mode, from "…", takes the counts off the rows and shows a label on every area, "Area" standing in for a missing
/// name, so that a tap on it renames it; a tap on any row opens its field instead of declaring its list (Lists screen
/// spec, sections 1 and 7). The list declared stays open, and the model is the one the Rename menu item opens on that
/// row in edit mode.
@Test func editModeHidesCountsLabelsEveryAreaAndATapRenames() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk"))
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    let unnamed = try store.createView(NewTaskView(title: "", kind: .area))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    #expect(listRow(inbox, in: list.model)?.countText == "1", "the Inbox counts its task; this is the setup")
    #expect(areaLabels(in: list.model) == ["Work", nil])
    #expect(list.send(.action(.editMenuItemChosen)) == nil)
    #expect(list.model.isEditing)
    #expect(list.model.rows.compactMap { listRow($0)?.countText } == Array(repeating: "", count: 6))
    #expect(areaLabels(in: list.model) == ["Work", "Area"])
    #expect(list.model.rows.map(\.id) == builtIns + [work, clients, unnamed])
    #expect(list.send(.action(.rowSelected(clients))) == nil)
    #expect(list.destination.pushed == .init(head: inbox), "no list declared")
    let reference = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    _ = reference.send(.action(.editMenuItemChosen))
    _ = reference.send(.action(.renameMenuItemChosen(clients)))
    #expect(list.model == reference.model)
    #expect(try rowBeingNamed(in: list.model).draft == "Clients")
    #expect(list.send(.action(.rowSelected(unnamed))) == nil)
    #expect(try rowBeingNamed(in: list.model).id == unnamed, "an area's line opens its field too")
    #expect(try rowBeingNamed(in: list.model).draft == "")
    #expect(list.destination.pushed == .init(head: inbox))
}

/// Done settles an open field as Return does and leaves edit mode, so the module ends as one made now on the store
/// draws it: the name in, the field closed, the counts back and nothing said. With no field open, Done ends edit mode
/// and moves nothing else.
@Test func doneKeepsTheOpenNameAndLeavesEditMode() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    let before = list.model
    #expect(list.send(.action(.editMenuItemChosen)) == nil)
    #expect(list.send(.action(.doneButtonTapped)) == nil)
    #expect(list.model == before)
    #expect(list.send(.action(.editMenuItemChosen)) == nil)
    #expect(list.send(.action(.rowSelected(BuiltInTaskViews.today))) == nil)
    #expect(list.send(.action(.titleFieldChanged("Tomorrow"))) == nil)
    #expect(list.send(.action(.doneButtonTapped)) == nil)
    #expect(try store.view(BuiltInTaskViews.today)?.title == "Tomorrow")
    #expect(list.model == (try sidebarOn(inbox, in: store)))
    #expect(!list.model.isEditing)
    #expect(listRow(inbox, in: list.model)?.countText == "1")
}

/// A name refused by Done keeps the field open on what was typed, as Return's refusal does, and edit mode with it,
/// since the person is mid-word; the next Done with a name settles both.
@Test func aRefusedNameKeepsEditMode() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    let written = try store.journal(after: 0).count
    _ = list.send(.action(.editMenuItemChosen))
    _ = list.send(.action(.rowSelected(BuiltInTaskViews.today)))
    _ = list.send(.action(.titleFieldChanged(" ")))
    #expect(list.send(.action(.doneButtonTapped)) == nil)
    #expect(list.model.isEditing)
    #expect(list.model.problem == "A title cannot be empty.")
    #expect(try rowBeingNamed(in: list.model).draft == " ")
    #expect(try store.journal(after: 0).count == written)
    let reference = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    _ = reference.send(.action(.editMenuItemChosen))
    _ = reference.send(.action(.renameMenuItemChosen(BuiltInTaskViews.today)))
    _ = reference.send(.action(.titleFieldChanged(" ")))
    _ = reference.send(.action(.titleFieldSubmitted))
    #expect(list.model == reference.model, "Done's refusal is Return's")
    _ = list.send(.action(.titleFieldChanged("Soon")))
    #expect(list.send(.action(.doneButtonTapped)) == nil)
    #expect(list.model == (try sidebarOn(inbox, in: store)))
}

/// The sentence a write the store refuses reads as, the module's one sentence for every refusal of a write.
private let couldNotSave = "The change could not be saved, so nothing was written."

/// Delete always asks (Lists screen spec, section 6): the menu item puts the confirmation up and writes nothing, and
/// Cancel takes it down and leaves the module as it was. A row that is not there asks nothing.
@Test func deleteAsksFirstAndCancelDeletesNothing() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    try store.createView(NewTaskView(title: "Home", parent: projects))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    let before = list.model
    let written = try store.journal(after: 0).count
    #expect(list.send(.action(.deleteMenuItemChosen(projects))) == nil)
    #expect(list.model.confirmation?.title == "Delete “Projects”?")
    #expect(list.model.confirmation?.message == "One list inside it goes with it. No task is deleted.")
    #expect(list.model.rows == before.rows)
    #expect(try store.journal(after: 0).count == written, "asking writes nothing")
    #expect(list.send(.action(.deleteCancelled)) == nil)
    #expect(list.model == before)
    #expect(try store.journal(after: 0).count == written)
    #expect(list.send(.action(.deleteMenuItemChosen(ViewID()))) == nil)
    #expect(list.model == before)
}

/// The confirmation says how many lists go with the one deleted, every list under it however deep, the ones a fold
/// hides among them: none, one or three (Lists screen spec, section 6).
@Test func theConfirmationNamesHowManyListsGo() throws {
    let store = try makeStore()
    let errands = try store.createView(NewTaskView(title: "Errands"))
    let projects = try store.createView(NewTaskView(title: "Projects"))
    try store.createView(NewTaskView(title: "Home", parent: projects))
    let clients = try store.createView(NewTaskView(title: "Clients"))
    let acme = try store.createView(NewTaskView(title: "Acme", parent: clients))
    try store.createView(NewTaskView(title: "Contracts", parent: acme))
    try store.createView(NewTaskView(title: "Billing", parent: clients))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    _ = list.send(.action(.disclosureTapped(acme)))
    let asked: [(ViewID, String, String)] = [
        (errands, "Delete “Errands”?", "No task is deleted."),
        (projects, "Delete “Projects”?", "One list inside it goes with it. No task is deleted."),
        (clients, "Delete “Clients”?", "3 lists inside it go with it. No task is deleted."),
    ]
    for (id, title, message) in asked {
        #expect(list.send(.action(.deleteMenuItemChosen(id))) == nil)
        #expect(list.model.confirmation?.title == title)
        #expect(list.model.confirmation?.message == message)
        #expect(list.send(.action(.deleteCancelled)) == nil)
    }
}

/// Delete confirmed takes the list and every list under it in one transaction, `Store.delete(viewTree:)`, and no task
/// (Lists screen spec, section 6): the module ends as one made now draws the store, the confirmation down and nothing
/// said. A field open on a list inside goes with it, and says nothing, since the person deleted it.
@Test func deletingAListTakesTheListsInsideItAndNoTask() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects, filter: .status([.open])))
    let garden = try store.createView(NewTaskView(title: "Garden", parent: home))
    let errands = try store.createView(NewTaskView(title: "Errands"))
    try store.createTask(NewTask(title: "Buy milk"))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    _ = list.send(.action(.renameMenuItemChosen(garden)))
    _ = list.send(.action(.titleFieldChanged("Allotment")))
    #expect(list.send(.action(.deleteMenuItemChosen(projects))) == nil)
    #expect(list.send(.action(.deleteConfirmed)) == nil)
    #expect(list.model == (try sidebarOn(inbox, in: store)))
    #expect(list.model.rows.map(\.id) == builtIns + [errands])
    #expect(try [projects, home, garden].map { try store.view($0) } == [nil, nil, nil])
    #expect(try store.allTasks(includeTrashed: true).map(\.title) == ["Buy milk"])
}

/// An area's deletion leaves its lists where they stand: the line goes, so they stand under the line above, at the end
/// of that area, or, when the area was the first, at the root above every line, after the last list there (Lists screen
/// spec, sections 3 and 6). They keep their order, and the lists inside them go along. The confirmation names the area,
/// or says "the area" for an unnamed one, and that its lists stay.
@Test func deletingAnAreaMovesItsListsToTheAreaAboveOrAboveTheFirstArea() throws {
    let store = try makeStore()
    let errands = try store.createView(NewTaskView(title: "Errands"))
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    let acme = try store.createView(NewTaskView(title: "Acme", parent: clients))
    let billing = try store.createView(NewTaskView(title: "Billing", parent: work))
    let unnamed = try store.createView(NewTaskView(title: "", kind: .area))
    let garden = try store.createView(NewTaskView(title: "Garden", parent: unnamed))
    let chores = try store.createView(NewTaskView(title: "Chores", parent: unnamed))
    let later = try store.createView(NewTaskView(title: "Later", kind: .area))
    let someday = try store.createView(NewTaskView(title: "Someday", parent: later))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)

    #expect(list.send(.action(.deleteMenuItemChosen(unnamed))) == nil)
    #expect(list.model.confirmation?.title == "Delete the area?")
    #expect(list.model.confirmation?.message == "Its lists stay.")
    #expect(list.send(.action(.deleteConfirmed)) == nil)
    #expect(list.model == (try sidebarOn(inbox, in: store)))
    #expect(list.model.rows.map(\.id) == builtIns + [errands, work, clients, acme, billing, garden, chores, later, someday])
    #expect(try [garden, chores].map { try store.view($0)?.parent } == [work, work])

    #expect(list.send(.action(.deleteMenuItemChosen(work))) == nil)
    #expect(list.model.confirmation?.title == "Delete the “Work” area?")
    #expect(list.model.confirmation?.message == "Its lists stay.")
    #expect(list.send(.action(.deleteConfirmed)) == nil)
    #expect(list.model == (try sidebarOn(inbox, in: store)))
    #expect(list.model.rows.map(\.id) == builtIns + [errands, clients, acme, billing, garden, chores, later, someday])
    #expect(list.model.rows.map(\.depth) == Array(repeating: 0, count: 7) + [1, 0, 0, 0, 0, 0])
    #expect(try [clients, billing, garden, chores].map { try store.view($0)?.parent } == [nil, nil, nil, nil])
    #expect(try store.view(work) == nil)
}

/// A delete the store refuses says so with the module's one sentence for a refused write, takes the confirmation down
/// and reads the rows back: a list a peer deleted before the change saying so arrived is gone from them. An area is
/// refused at the first of its lists a peer deleted, after the lists before it moved, and stays, so the next attempt
/// finishes it (Lists screen spec, "Risks"), and says nothing.
@Test func aDeleteTheStoreRefusesSaysSoAndTheNextAttemptFinishesAnArea() throws {
    let store = try makeStore()
    let errands = try store.createView(NewTaskView(title: "Errands"))
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    let billing = try store.createView(NewTaskView(title: "Billing", parent: work))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    #expect(list.send(.action(.deleteMenuItemChosen(errands))) == nil)
    try store.delete(view: errands)
    #expect(list.send(.action(.deleteConfirmed)) == nil)
    #expect(list.model.problem == couldNotSave)
    #expect(list.model.confirmation == nil)
    #expect(list.model.rows == (try sidebarOn(inbox, in: store)).rows, "the rows read back, Errands gone")

    #expect(list.send(.action(.deleteMenuItemChosen(work))) == nil)
    try store.delete(view: billing)
    #expect(list.send(.action(.deleteConfirmed)) == nil)
    #expect(list.model.problem == couldNotSave)
    #expect(list.model.confirmation == nil)
    #expect(list.model.rows.map(\.id) == builtIns + [clients, work], "Clients moved and the area stayed")
    #expect(list.send(.action(.deleteMenuItemChosen(work))) == nil)
    #expect(list.send(.action(.deleteConfirmed)) == nil)
    #expect(list.model == (try sidebarOn(inbox, in: store)))
    #expect(list.model.rows.map(\.id) == builtIns + [clients])
}

/// A dialog goes with the row it is up for when a read no longer holds the row, the list a confirmation would delete or
/// the list a picker would move, and says nothing, as the highlight goes with its row: the row leaving the tree says
/// what happened. It stays gone when a peer brings the row back, since nobody asked again, and an open field and its
/// sentence stay throughout.
@Test func aDialogGoesWithTheRowItIsUpFor() throws {
    let peer = Store.newDeviceID()
    func deleted(_ id: ViewID, _ flag: Bool, at millis: Int64) -> [JournalOperation] {
        [JournalOperation(entity: .view, entityID: id.rawValue, field: "deleted", value: Value(flag), clock: HLC(millis: millis, counter: 0), device: peer)]
    }
    let store = try makeStore()
    let errands = try store.createView(NewTaskView(title: "Errands"))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    refusingAName(list)
    #expect(list.send(.action(.deleteMenuItemChosen(errands))) == nil)
    let gone = try changeSet(of: store) { _ = try store.apply(deleted(errands, true, at: 1_800_000_000_000)) }
    #expect(list.send(.changed(gone)) == nil)
    let back = try changeSet(of: store) { _ = try store.apply(deleted(errands, false, at: 1_800_000_000_001)) }
    #expect(list.send(.changed(back)) == nil)
    #expect(list.model.rows.map(\.id).contains(errands), "the list is back; without it this proves nothing")
    #expect(list.model.confirmation == nil)
    let reference = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    refusingAName(reference)
    #expect(list.model == reference.model)

    #expect(list.send(.action(.moveToMenuItemChosen(errands))) == nil)
    let goneAgain = try changeSet(of: store) { _ = try store.apply(deleted(errands, true, at: 1_800_000_000_002)) }
    #expect(list.send(.changed(goneAgain)) == nil)
    let backAgain = try changeSet(of: store) { _ = try store.apply(deleted(errands, false, at: 1_800_000_000_003)) }
    #expect(list.send(.changed(backAgain)) == nil)
    #expect(list.model.movePicker == nil)
    #expect(list.model == reference.model)
}

/// Move to… opens the picker over the whole tree in tree order, each row drawn as the screen draws it with nothing
/// highlighted, the list being moved and every list inside it greyed out, and its present parent marked: a list, an
/// area's line, or "Top level" for a list of the root (Lists screen spec, section 6). Its rows follow the width and edit
/// mode as the screen's do. Asking writes nothing, and on an area or a row that is not there it opens nothing.
@Test func movePickerShowsTheWholeTreeWithTheListAndItsSubtreeDisabledAndItsParentCurrent() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk"))
    let projects = try store.createView(NewTaskView(title: "Projects"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects))
    let garden = try store.createView(NewTaskView(title: "Garden", parent: home))
    try store.createView(NewTaskView(title: "Office", parent: projects))
    let errands = try store.createView(NewTaskView(title: "Errands"))
    let work = try store.createView(NewTaskView(title: "", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    let before = list.model
    let written = try store.journal(after: 0).count
    #expect(list.send(.action(.moveToMenuItemChosen(home))) == nil)
    let picker = try #require(list.model.movePicker)
    #expect(picker.title == "Move “Home” to…")
    #expect(!picker.isTopLevelCurrent)
    #expect(picker.rows.map(\.row) == (try sidebarOn(ViewID(), in: store)).rows, "the screen's rows, nothing lit")
    #expect(picker.rows.filter(\.isDisabled).map(\.id) == [home, garden])
    #expect(picker.rows.filter(\.isCurrent).map(\.id) == [projects])
    #expect(list.model.rows == before.rows)
    #expect(try store.journal(after: 0).count == written)
    #expect(list.send(.action(.movePickerCancelled)) == nil)
    #expect(list.model == before)

    _ = list.send(.action(.moveToMenuItemChosen(errands)))
    #expect(list.model.movePicker?.isTopLevelCurrent == true)
    #expect(list.model.movePicker?.rows.filter(\.isCurrent).isEmpty == true)
    #expect(list.model.movePicker?.rows.filter(\.isDisabled).map(\.id) == [errands])
    _ = list.send(.action(.movePickerCancelled))
    _ = list.send(.action(.moveToMenuItemChosen(clients)))
    #expect(list.model.movePicker?.title == "Move “Clients” to…")
    #expect(list.model.movePicker?.isTopLevelCurrent == false)
    #expect(list.model.movePicker?.rows.filter(\.isCurrent).map(\.id) == [work], "an area's line is a parent too")
    _ = list.send(.widthChanged(.wide))
    _ = list.send(.action(.editMenuItemChosen))
    let wide = try TaskViewList(store: store, route: .init(list: .init(head: ViewID())), width: .wide)
    _ = wide.send(.action(.editMenuItemChosen))
    #expect(list.model.movePicker?.rows.map(\.row) == wide.model.rows, "the sidebar's tiles, no counts and the area's label")
    _ = list.send(.action(.movePickerCancelled))

    let shown = list.model
    #expect(list.send(.action(.moveToMenuItemChosen(work))) == nil)
    #expect(list.model == shown)
    #expect(list.send(.action(.moveToMenuItemChosen(ViewID()))) == nil)
    #expect(list.model == shown)
}

/// The picker ignores the folds: the lists of a folded branch stand in it at every level, and the folded list is drawn
/// there unfolded, since nothing in the picker is hidden for a chevron to say so (Lists screen spec, section 6).
@Test func aFoldedBranchIsStillInThePicker() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects))
    try store.createView(NewTaskView(title: "Garden", parent: home))
    let errands = try store.createView(NewTaskView(title: "Errands"))
    let unfolded = try sidebarOn(ViewID(), in: store).rows
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    _ = list.send(.action(.disclosureTapped(home)))
    _ = list.send(.action(.disclosureTapped(projects)))
    #expect(list.model.rows.dropFirst(5).map(\.id) == [projects, errands], "both folded; this is the setup")
    #expect(list.send(.action(.moveToMenuItemChosen(errands))) == nil)
    #expect(list.model.movePicker?.rows.map(\.row) == unfolded)
}

/// A tap on a list in the picker moves the list being moved under it, last among the lists there, unfolds it so that
/// the list is on screen where it went, and closes the picker; a tap on an area's line moves it last under the line
/// (Lists screen spec, section 6). Each time the module ends as one made now on the store draws it, the unfold read back
/// from the device's state, and says nothing.
@Test func aTapInThePickerMovesTheListLastUnfoldsTheDestinationAndClosesIt() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects))
    let office = try store.createView(NewTaskView(title: "Office", parent: projects))
    let errands = try store.createView(NewTaskView(title: "Errands"))
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    _ = list.send(.action(.disclosureTapped(projects)))
    _ = list.send(.action(.moveToMenuItemChosen(errands)))
    #expect(list.send(.action(.movePickerRowTapped(projects))) == nil)
    #expect(list.model.movePicker == nil)
    #expect(list.model.rows.map(\.id) == builtIns + [projects, home, office, errands, work, clients])
    #expect(try store.view(errands)?.parent == projects)
    #expect(try store.deviceState(collapsedViewsKey, as: [String].self) == [])
    #expect(list.model == (try sidebarOn(inbox, in: store)))

    _ = list.send(.action(.moveToMenuItemChosen(errands)))
    #expect(list.send(.action(.movePickerRowTapped(work))) == nil)
    #expect(list.model.rows.map(\.id) == builtIns + [projects, home, office, work, clients, errands])
    #expect(try store.view(errands)?.parent == work)
    #expect(list.model == (try sidebarOn(inbox, in: store)))
}

/// "Top level" puts the list at the root above every line, after the last list of the root that stands before the
/// first area, and never at the root's end, under the last line (Lists screen spec, section 3). A list that is already
/// that last list stays where it is, and with no list of the root above the first area it goes to the start of the
/// root.
@Test func topLevelPutsTheListAboveTheFirstArea() throws {
    let store = try makeStore()
    let errands = try store.createView(NewTaskView(title: "Errands"))
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    let acme = try store.createView(NewTaskView(title: "Acme", parent: clients))
    let home = try store.createView(NewTaskView(title: "Home", kind: .area))
    let garden = try store.createView(NewTaskView(title: "Garden", parent: home))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    _ = list.send(.action(.moveToMenuItemChosen(acme)))
    #expect(list.send(.action(.movePickerRowTapped(nil))) == nil)
    #expect(list.model.rows.map(\.id) == builtIns + [errands, acme, work, clients, home, garden])
    #expect(try store.view(acme)?.parent == nil)
    #expect(list.model == (try sidebarOn(inbox, in: store)))
    _ = list.send(.action(.moveToMenuItemChosen(acme)))
    #expect(list.model.movePicker?.isTopLevelCurrent == true, "this is the setup")
    #expect(list.send(.action(.movePickerRowTapped(nil))) == nil)
    #expect(list.model == (try sidebarOn(inbox, in: store)), "where it was, and nothing said")
    #expect(list.model.rows.map(\.id) == builtIns + [errands, acme, work, clients, home, garden])

    let bare = try makeStore()
    for id in builtIns { try bare.delete(view: id) }
    let area = try bare.createView(NewTaskView(title: "Work", kind: .area))
    let inside = try bare.createView(NewTaskView(title: "Clients", parent: area))
    let alone = try TaskViewList(store: bare, route: .init(list: nil), width: .narrow)
    _ = alone.send(.action(.moveToMenuItemChosen(inside)))
    #expect(alone.send(.action(.movePickerRowTapped(nil))) == nil)
    #expect(alone.model.rows.map(\.id) == [inside, area])
    #expect(alone.model.problem == nil)
}

/// A greyed-out row, the list being moved or a list inside it, cannot take it, so a tap on one moves nothing, and nor
/// does a tap on a row that is not there: the picker stays up and nothing is written.
@Test func aTapOnADisabledRowMovesNothing() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects))
    let garden = try store.createView(NewTaskView(title: "Garden", parent: home))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    _ = list.send(.action(.moveToMenuItemChosen(projects)))
    let picking = list.model
    let written = try store.journal(after: 0).count
    for id in [projects, home, garden, ViewID()] {
        #expect(list.send(.action(.movePickerRowTapped(id))) == nil)
        #expect(list.model == picking)
    }
    #expect(try store.journal(after: 0).count == written)
}

/// The built-ins are default views and nothing more (Lists screen spec, sections 1 and 6): the Logbook moves into an
/// area from the picker, and the Trash is deleted from the confirmation, like any list.
@Test func aBuiltInMovesAndDeletesLikeAnyList() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    _ = list.send(.action(.moveToMenuItemChosen(BuiltInTaskViews.logbook)))
    #expect(list.model.movePicker?.title == "Move “Logbook” to…")
    #expect(list.send(.action(.movePickerRowTapped(work))) == nil)
    #expect(list.send(.action(.deleteMenuItemChosen(BuiltInTaskViews.trash))) == nil)
    #expect(list.model.confirmation?.title == "Delete “Trash”?")
    #expect(list.model.confirmation?.message == "No task is deleted.")
    #expect(list.send(.action(.deleteConfirmed)) == nil)
    #expect(list.model == (try sidebarOn(inbox, in: store)))
    #expect(list.model.rows.map(\.id) == [inbox, BuiltInTaskViews.today, BuiltInTaskViews.upcoming, work, BuiltInTaskViews.logbook])
}

/// A dialog's actions with no such dialog up move nothing, the sentence and an open field included: SwiftUI writes a
/// dismissal into an alert's or a sheet's binding after a close the module drove, which lands here, and so does a tap
/// that arrives after its dialog went (Lists screen plan, Task 6). With the picker up the confirmation's actions move
/// nothing, and with the confirmation up the picker's.
@Test func aDialogActionWithNoDialogUpMovesNothing() throws {
    let store = try makeStore()
    let errands = try store.createView(NewTaskView(title: "Errands"))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    refusingAName(list)
    let written = try store.journal(after: 0).count
    let confirmations: [TaskViewList.UserAction] = [.deleteConfirmed, .deleteCancelled]
    let pickers: [TaskViewList.UserAction] = [.movePickerRowTapped(nil), .movePickerRowTapped(inbox), .movePickerCancelled]
    let before = list.model
    for action in confirmations + pickers {
        #expect(list.send(.action(action)) == nil)
        #expect(list.model == before)
    }
    _ = list.send(.action(.moveToMenuItemChosen(errands)))
    let picking = list.model
    for action in confirmations {
        #expect(list.send(.action(action)) == nil)
        #expect(list.model == picking)
    }
    _ = list.send(.action(.movePickerCancelled))
    _ = list.send(.action(.deleteMenuItemChosen(errands)))
    let asking = list.model
    for action in pickers {
        #expect(list.send(.action(action)) == nil)
        #expect(list.model == asking)
    }
    #expect(try store.journal(after: 0).count == written)
}

/// A move from the picker or a drop the store refuses says so with the module's one sentence for a refused write and
/// reads the rows back, the picker closed: a list a peer deleted before the change saying so arrived is gone from
/// them, the destination of the picker's move and the row a drop was let go after.
@Test func aMoveFromThePickerOrADropTheStoreRefusesSaysSo() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    let errands = try store.createView(NewTaskView(title: "Errands"))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    _ = list.send(.action(.moveToMenuItemChosen(errands)))
    try store.delete(view: projects)
    #expect(list.send(.action(.movePickerRowTapped(projects))) == nil)
    #expect(list.model.problem == couldNotSave)
    #expect(list.model.movePicker == nil)
    #expect(list.model.rows == (try sidebarOn(inbox, in: store)).rows, "the rows read back, Projects gone")
    #expect(try store.view(errands)?.parent == nil)

    let tree = try Tree()
    let dropping = try tree.sidebar()
    try tree.store.delete(view: tree.office)
    #expect(dropping.send(.action(.rowDropped(tree.errands, after: tree.office, depth: 1))) == nil)
    #expect(dropping.model.problem == couldNotSave)
    #expect(dropping.model.rows == (try sidebarOn(inbox, in: tree.store)).rows, "the rows read back, Office gone")
    #expect(try tree.store.view(tree.errands)?.parent == nil)
}

/// The tree the drop's tests move rows about in, past the five built-in views, each drawn at the depth beside it:
/// Projects 0, with Home 1 and Office 1 inside, Home with Garden 2 and Garden with Seeds 3; Errands 0 at the root; the
/// area Work 0, with Clients 0, which holds Acme 1, and Billing 0; and the area Later 0, with Someday 0.
private struct Tree {
    let store: Store
    let projects, home, garden, seeds, office, errands, work, clients, acme, billing, later, someday: ViewID

    init() throws {
        store = try makeStore()
        projects = try store.createView(NewTaskView(title: "Projects"))
        home = try store.createView(NewTaskView(title: "Home", parent: projects))
        garden = try store.createView(NewTaskView(title: "Garden", parent: home))
        seeds = try store.createView(NewTaskView(title: "Seeds", parent: garden))
        office = try store.createView(NewTaskView(title: "Office", parent: projects))
        errands = try store.createView(NewTaskView(title: "Errands"))
        work = try store.createView(NewTaskView(title: "Work", kind: .area))
        clients = try store.createView(NewTaskView(title: "Clients", parent: work))
        acme = try store.createView(NewTaskView(title: "Acme", parent: clients))
        billing = try store.createView(NewTaskView(title: "Billing", parent: work))
        later = try store.createView(NewTaskView(title: "Later", kind: .area))
        someday = try store.createView(NewTaskView(title: "Someday", parent: later))
    }

    /// A sidebar made on the tree, on no list.
    func sidebar() throws -> TaskViewList {
        try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    }

    /// The lists and areas a parent holds in the store, in rank order, nil for the root's.
    func children(of parent: ViewID?) throws -> [ViewID] {
        try store.children(ofView: parent).map(\.id)
    }
}

/// A row let go one level deeper than the row above it becomes that row's first child, before the lists already inside
/// it, and the row above unfolds when it was folded, so that the row is on screen where it went (Lists screen spec,
/// section 5). The module then draws what one made now on the store draws, and says nothing.
@Test func aDropDeeperMakesTheRowTheFirstChildOfTheRowAbove() throws {
    let tree = try Tree()
    let list = try tree.sidebar()
    _ = list.send(.action(.disclosureTapped(tree.home)))
    #expect(list.send(.action(.rowDropped(tree.errands, after: tree.home, depth: 2))) == nil)
    #expect(try tree.children(of: tree.home) == [tree.errands, tree.garden])
    #expect(try tree.store.deviceState(collapsedViewsKey, as: [String].self) == [])
    #expect(list.model == (try sidebarOn(inbox, in: tree.store)))
    #expect(list.model.rows.dropFirst(5).map(\.depth) == [0, 1, 2, 2, 3, 1, 0, 0, 1, 0, 0, 0])
}

/// A row let go at the depth of the row above it becomes that row's next sibling, in the same parent: after Office in
/// Projects, and, with Home folded, after Home, since the drop reads the rows as they are drawn, where the row under a
/// folded list is the one after its branch.
@Test func aDropAtTheSameDepthMakesItTheNextSibling() throws {
    let tree = try Tree()
    let list = try tree.sidebar()
    #expect(list.send(.action(.rowDropped(tree.errands, after: tree.office, depth: 1))) == nil)
    #expect(try tree.children(of: tree.projects) == [tree.home, tree.office, tree.errands])
    #expect(list.model == (try sidebarOn(inbox, in: tree.store)))
    _ = list.send(.action(.disclosureTapped(tree.home)))
    #expect(list.send(.action(.rowDropped(tree.errands, after: tree.home, depth: 1))) == nil)
    #expect(try tree.children(of: tree.projects) == [tree.home, tree.errands, tree.office])
    #expect(listRow(tree.home, in: list.model)?.isCollapsed == true, "the fold stays")
    #expect(list.model == (try sidebarOn(inbox, in: tree.store)))
}

/// A row let go shallower than the row above it becomes the next sibling of that row's ancestor at the depth it was let
/// go at, found by walking up the parents: after Seeds at depth 2 it follows Garden in Home, and at depth 1 Home in
/// Projects. Under an area the drawn depths start at its line's, so after Acme at depth 0 a row follows Clients in the
/// area and does not go to the root (Lists screen spec, sections 3 and 5).
@Test func aDropShallowerMakesItTheNextSiblingOfTheAncestorAtThatDepth() throws {
    let tree = try Tree()
    let list = try tree.sidebar()
    #expect(list.send(.action(.rowDropped(tree.errands, after: tree.seeds, depth: 2))) == nil)
    #expect(try tree.children(of: tree.home) == [tree.garden, tree.errands])
    #expect(list.send(.action(.rowDropped(tree.errands, after: tree.seeds, depth: 1))) == nil)
    #expect(try tree.children(of: tree.projects) == [tree.home, tree.errands, tree.office])
    #expect(list.send(.action(.rowDropped(tree.errands, after: tree.acme, depth: 0))) == nil)
    #expect(try tree.children(of: tree.work) == [tree.clients, tree.errands, tree.billing])
    #expect(list.model == (try sidebarOn(inbox, in: tree.store)))
}

/// A list let go right under an area's line goes into the area, first under the line, at whatever depth it was let go,
/// and never onto the root (Lists screen spec, section 7).
@Test func aDropUnderAnAreasLineGoesIntoTheArea() throws {
    let tree = try Tree()
    let list = try tree.sidebar()
    #expect(list.send(.action(.rowDropped(tree.errands, after: tree.work, depth: 0))) == nil)
    #expect(try tree.children(of: tree.work) == [tree.errands, tree.clients, tree.billing])
    #expect(list.send(.action(.rowDropped(tree.office, after: tree.later, depth: 3))) == nil)
    #expect(try tree.children(of: tree.later) == [tree.office, tree.someday])
    #expect(list.model == (try sidebarOn(inbox, in: tree.store)))
}

/// A row let go at the top of the tree, after no row, goes to the start of the root, at whatever depth it was let go.
@Test func aDropAtTheTopGoesToTheStartOfTheRoot() throws {
    let tree = try Tree()
    let list = try tree.sidebar()
    #expect(list.send(.action(.rowDropped(tree.seeds, after: nil, depth: 2))) == nil)
    #expect(try tree.children(of: nil).first == tree.seeds)
    #expect(list.model.rows.first?.id == tree.seeds)
    #expect(list.model == (try sidebarOn(inbox, in: tree.store)))
}

/// The depth a view sends is clamped to what the rows allow and never trusted (Lists screen plan, global constraints):
/// no deeper than one past the row above, and no shallower than the row below once the row being moved and the lists
/// inside it are passed over, so that Garden, let go under Home with its Seeds, can follow Home.
@Test func aDepthOutsideWhatTheRowsAllowIsClamped() throws {
    let tree = try Tree()
    let list = try tree.sidebar()
    #expect(list.send(.action(.rowDropped(tree.errands, after: tree.office, depth: 7))) == nil)
    #expect(try tree.children(of: tree.office) == [tree.errands])
    #expect(list.send(.action(.rowDropped(tree.errands, after: tree.seeds, depth: -3))) == nil)
    #expect(try tree.children(of: tree.projects) == [tree.home, tree.errands, tree.office])
    #expect(list.send(.action(.rowDropped(tree.garden, after: tree.home, depth: -1))) == nil)
    #expect(try tree.children(of: tree.projects) == [tree.home, tree.garden, tree.errands, tree.office])
    #expect(try tree.children(of: tree.garden) == [tree.seeds])
    #expect(list.model == (try sidebarOn(inbox, in: tree.store)))
}

/// An area moves along the root alone, as one block with its lists (Lists screen spec, section 7): let go at the top it
/// goes to the start of the root, and let go after any other row it goes, at the root, after the block that row stands
/// in, its topmost ancestor, whatever the depth: after Someday, inside Later's block, Work follows Later, and after
/// Errands it stands above Later again.
@Test func anAreaDropsAfterTheBlockOfTheRowAbove() throws {
    let tree = try Tree()
    let list = try tree.sidebar()
    let roots = Array(try tree.children(of: nil).prefix(7))
    #expect(roots == builtIns + [tree.projects, tree.errands], "this is the setup")
    #expect(list.send(.action(.rowDropped(tree.work, after: tree.someday, depth: 0))) == nil)
    #expect(try tree.children(of: nil) == roots + [tree.later, tree.work])
    #expect(list.send(.action(.rowDropped(tree.work, after: tree.errands, depth: 2))) == nil)
    #expect(try tree.children(of: nil) == roots + [tree.work, tree.later])
    #expect(list.send(.action(.rowDropped(tree.later, after: nil, depth: 1))) == nil)
    #expect(try tree.children(of: nil) == [tree.later] + roots + [tree.work])
    #expect(try tree.children(of: tree.work) == [tree.clients, tree.billing], "the lists went with it")
    #expect(list.model == (try sidebarOn(inbox, in: tree.store)))
}

/// A drop names rows a view drew, and one naming a row the module does not draw moves nothing: an id or an `after` no
/// row holds, or a row hidden in a folded branch, beside which no slot is drawn. Nor can a row be put inside itself, so
/// an `after` that is the row being moved, a list inside it, or a list of an area being moved moves nothing too. Nothing
/// moves, an open field and its sentence included, and nothing is written.
@Test func aDropOfOrOntoARowTheModuleDoesNotHoldMovesNothing() throws {
    let tree = try Tree()
    let list = try tree.sidebar()
    refusingAName(list)
    _ = list.send(.action(.disclosureTapped(tree.home)))
    let before = list.model
    let written = try tree.store.journal(after: 0).count
    let drops: [(ViewID, ViewID?, Int)] = [
        (ViewID(), tree.errands, 0), (tree.errands, ViewID(), 0), (tree.errands, tree.garden, 2),
        (tree.garden, tree.office, 1), (tree.projects, tree.projects, 0), (tree.projects, tree.office, 1),
        (tree.work, tree.acme, 0), (tree.work, tree.work, 0),
    ]
    for (id, after, depth) in drops {
        #expect(list.send(.action(.rowDropped(id, after: after, depth: depth))) == nil)
        #expect(list.model == before)
    }
    #expect(try tree.store.journal(after: 0).count == written)
}
