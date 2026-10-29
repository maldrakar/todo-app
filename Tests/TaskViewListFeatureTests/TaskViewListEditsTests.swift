import Testing
import TestSupport
import FeatureModule
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
