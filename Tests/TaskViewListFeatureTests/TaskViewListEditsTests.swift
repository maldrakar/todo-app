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

/// A dialog goes with the row it is up for when a read no longer holds the row, and says nothing, as the highlight goes
/// with its row: the row leaving the tree says what happened. It stays gone when a peer brings the row back, since
/// nobody asked again, and an open field and its sentence stay throughout.
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
}
