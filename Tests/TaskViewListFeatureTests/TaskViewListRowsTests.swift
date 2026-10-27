import Testing
import TestSupport
import DesignSystem
import DesignSystemComponents
import FeatureModule
import SQLiteKit
import TaskViewListFeature
import TodoCore

private let inbox = BuiltInTaskViews.inbox

/// The key the sidebar keeps its folds under in the device's own state, as the module names it (ADR-0010).
private let collapsedKey = "taskViewList.collapsed"

/// Opens the field on Today, types a blank name and submits it, so that the list holds a field open on a refused
/// draft and the sentence that refused it, which an event that moves nothing leaves where they are.
private func refusingAName(_ list: TaskViewList) {
    _ = list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.today)))
    _ = list.send(.action(.titleFieldChanged(" ")))
    _ = list.send(.action(.titleFieldSubmitted))
}

/// The list row a view's row draws, and nil for an area's line: what a test reads a tile, a font and a count off.
private func listRow(_ row: TaskViewList.Model.Row) -> TaskViewList.Model.ListRow? {
    guard case .list(let list) = row.kind else { return nil }
    return list
}

/// The list row the model draws for a view, and nil when no row holds the view or its row is an area's line.
private func listRow(_ id: ViewID, in model: TaskViewList.Model) -> TaskViewList.Model.ListRow? {
    model.rows.first { $0.id == id }.flatMap(listRow)
}

/// A tile's three sizes, its side, its corner radius and its glyph's size, in points, which is what the width class
/// and the drawn depth decide of a tile.
private func sizes(of row: TaskViewList.Model.Row) -> [Double]? {
    listRow(row).map { [$0.tile.side, $0.tile.cornerRadius, $0.tile.glyph.size] }
}

/// Each list's row carries the tile it is drawn with, its colour and its icon read from the store's names as the
/// design system's, and the count of its open tasks as text, nothing for a count of zero and for a list with no count
/// (spec section 4); in a narrow window a row at the root's depth has the canvas's 30 pt tile. A name this app does
/// not know, and no name at all, read as the default glyph and the stone colour, which the module picks so that a
/// platform draws every value it is given (ADR-0007, amendment of 2026-10-26).
@Test func theRowsCarryTheirKindTileAndCount() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk"))
    try store.createTask(NewTask(title: "Call the plumber"))
    let filed = try store.createTask(NewTask(title: "File the taxes"))
    try store.update(task: filed, [.status(.done)])
    let garden = try store.createView(NewTaskView(title: "Garden", color: .green, icon: "watering-can"))
    let reading = try store.createView(NewTaskView(title: "Reading", icon: "book"))
    let model = try TaskViewList(store: store, route: .init(list: nil), width: .narrow).model
    func tile(_ color: DesignSystem.Color.Components.Tile, _ icon: DesignSystem.Icon) -> TileModel {
        TileModel(color: color, icon: icon, side: 30, cornerRadius: 8, glyphSize: 19)
    }
    #expect(model.rows.map(\.id) == [
        inbox, BuiltInTaskViews.today, BuiltInTaskViews.upcoming, BuiltInTaskViews.logbook, BuiltInTaskViews.trash,
        garden, reading,
    ])
    #expect(listRow(inbox, in: model)?.tile == TileModel(color: .blue, icon: .tray, side: 30, cornerRadius: 8, glyphSize: 19))
    #expect(model.rows.map { listRow($0)?.tile } == [
        tile(.blue, .tray), tile(.amber, .sun), tile(.rose, .calendar), tile(.green, .logbook), tile(.stone, .trash),
        tile(.green, .bullets), tile(.stone, .book),
    ])
    // The Logbook holds the filed task and counts nothing, since nothing in it is open; the two lists with no rule and
    // nothing inside have no count at all, and read the same.
    #expect(model.rows.map { listRow($0)?.countText } == ["2", "", "", "", "", "", ""])
}

/// Made wide, every row takes the sidebar's 20 pt tile, at any depth (`Mac.dc.html`, the 30 pt row). Told the window
/// narrowed, the rows take the phone's tiles by their drawn depth, 30 pt at the root's depth, an area's lists among
/// them, and 26 deeper (`Phone.dc.html`, `tileSize`), from what the module holds: a view written since, with no change
/// sent, is not among the rows, so the width moved the tiles with no read of the store. Widened again, it is the
/// model it was made with.
@Test func aWideWindowsRowsCarryTheSidebarsTiles() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", color: .indigo, icon: "briefcase"))
    try store.createView(NewTaskView(title: "Reviews", parent: work, color: .indigo, icon: "pen"))
    let home = try store.createView(NewTaskView(title: "Home", kind: .area))
    try store.createView(NewTaskView(title: "Garden", parent: home, color: .green, icon: "house"))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .wide)
    let wide = list.model
    let narrow = try TaskViewList(store: store, route: .init(list: nil), width: .narrow).model
    #expect(wide.rows.map(sizes(of:)) == Array(repeating: [20, 6, 13], count: 7) + [nil, [20, 6, 13]])
    try store.createView(NewTaskView(title: "Unseen"))
    #expect(list.send(.widthChanged(.narrow)) == nil)
    #expect(list.model == narrow, "the narrow tiles, and no read: the view written since is not among the rows")
    #expect(list.model.rows.map(sizes(of:)) == Array(repeating: [30, 8, 19], count: 6) + [[26, 7, 16], nil, [30, 8, 19]])
    #expect(list.send(.widthChanged(.wide)) == nil)
    #expect(list.model == wide)
}

/// A row's title is one of the design system's four, chosen by the module (ADR-0007, amendment of 2026-10-26): in a
/// narrow window the row title at the root's drawn depth, an area's lists among them, and the nested row title deeper,
/// each emphasized when the row has lists inside it; in a wide window the row title at every depth, which a platform
/// draws at its sidebar's size, emphasized the same way.
@Test func aRowsTitleFontFollowsItsDepthAndChildren() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects))
    try store.createView(NewTaskView(title: "Garden", parent: home))
    try store.createView(NewTaskView(title: "Errands"))
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    try store.createView(NewTaskView(title: "Acme", parent: clients))
    let builtIns: [DesignSystem.Font?] = Array(repeating: .rowTitle, count: 5)
    let narrow = try TaskViewList(store: store, route: .init(list: nil), width: .narrow).model
    #expect(narrow.rows.dropFirst(5).map { listRow($0)?.titleFont } == [
        .rowTitleEmphasized, .nestedRowTitleEmphasized, .nestedRowTitle, .rowTitle, nil, .rowTitleEmphasized,
        .nestedRowTitle,
    ])
    #expect(narrow.rows.prefix(5).map { listRow($0)?.titleFont } == builtIns)
    let wide = try TaskViewList(store: store, route: .init(list: nil), width: .wide).model
    #expect(wide.rows.dropFirst(5).map { listRow($0)?.titleFont } == [
        .rowTitleEmphasized, .rowTitleEmphasized, .rowTitle, .rowTitle, nil, .rowTitleEmphasized, .rowTitle,
    ])
    #expect(wide.rows.prefix(5).map { listRow($0)?.titleFont } == builtIns)
}

/// An area is a line across the tree, and the lists under it stand at the root's drawn depth, their own lists one
/// deeper (spec sections 1 and 3): an area with two lists, one inside the other, draws at 0, 0 and 1. A named line
/// carries its name as its label, and an unnamed one is the line alone.
@Test func anAreaIsALineAndItsListsStandAtTheRootsDepth() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    let acme = try store.createView(NewTaskView(title: "Acme", parent: clients))
    let unnamed = try store.createView(NewTaskView(title: "", kind: .area))
    let model = try TaskViewList(store: store, route: .init(list: nil), width: .narrow).model
    let past = model.rows.dropFirst(5)
    #expect(past.map(\.id) == [work, clients, acme, unnamed], "past the five built-in views")
    #expect(past.map(\.depth) == [0, 0, 1, 0])
    #expect(past.first?.kind == .area(label: "Work"))
    #expect(past.last?.kind == .area(label: nil))
    #expect(past.map { listRow($0)?.title } == [nil, "Clients", "Acme", nil])
    #expect(past.map { listRow($0)?.hasChildren } == [nil, true, false, nil])
}

/// Every edit to a task can move any count, so a change naming only tasks reads the counts again and not the rows: the
/// Inbox's count moves, a view written since with no change sent stays out of the rows, and the field open on a
/// refused name keeps its draft and its sentence, since a change answers nobody (spec section 4).
@Test func aChangeToATaskRereadsTheCountsAndNotTheRows() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    refusingAName(list)
    #expect(list.model.problem == "A title cannot be empty.", "the refusal is the setup; without it this proves nothing")
    let created = try changeSet(of: store) { try store.createTask(NewTask(title: "Buy milk")) }
    let reference = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    refusingAName(reference)
    try store.createView(NewTaskView(title: "Docs"))
    #expect(list.send(.changed(created)) == nil)
    #expect(listRow(inbox, in: list.model)?.countText == "1")
    #expect(list.model == reference.model, "the count moved, Docs is missing, and the draft and the sentence stayed")
}

/// A fold on a list with lists inside it hides the branch, the lists under it however deep, and the rows after the
/// branch stay, the next one at its depth or above and those under that. The fold is the device's own (ADR-0010, amendment of 2026-10-26), written on every fold as the
/// folded ids, so a module made anew, as at the next launch, reads it back, a fold inside a folded branch included.
/// Unfolded, the branch is back as it was, the fold inside it kept, and with nothing folded the set written is empty.
/// A fold is no answer to anything a person was told, so a field open on a refused name keeps its draft and its
/// sentence throughout.
@Test func aFoldHidesTheBranchAndIsReadBackByAModuleMadeAnew() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects))
    try store.createView(NewTaskView(title: "Garden", parent: home))
    let office = try store.createView(NewTaskView(title: "Office", parent: projects))
    let desk = try store.createView(NewTaskView(title: "Desk", parent: office))
    let errands = try store.createView(NewTaskView(title: "Errands"))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    refusingAName(list)
    let open = list.model
    #expect(list.send(.action(.disclosureTapped(home))) == nil)
    #expect(list.model.rows.dropFirst(5).map(\.id) == [projects, home, office, desk, errands])
    #expect(listRow(home, in: list.model)?.isCollapsed == true)
    #expect(list.send(.action(.disclosureTapped(projects))) == nil)
    #expect(list.model.rows.dropFirst(5).map(\.id) == [projects, errands], "the branch goes whole, and the row after it stays")
    #expect(listRow(projects, in: list.model)?.isCollapsed == true)
    #expect(try store.deviceState(collapsedKey, as: [String].self).map(Set.init) == [projects.rawValue, home.rawValue])
    let made = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    refusingAName(made)
    #expect(list.model == made.model, "a module made anew reads both folds back")
    #expect(list.send(.action(.disclosureTapped(projects))) == nil)
    #expect(list.model.rows.dropFirst(5).map(\.id) == [projects, home, office, desk, errands], "the fold inside it stays")
    #expect(list.send(.action(.disclosureTapped(home))) == nil)
    #expect(list.model == open)
    #expect(try store.deviceState(collapsedKey, as: [String].self) == [])
}

/// The chevron is on a list with lists inside it, and a fold anywhere else is no fold: on a leaf, on an area's line,
/// which defines its area and never folds although lists stand under it, and on an id no row holds, it moves nothing,
/// the field and its sentence included, and writes nothing.
@Test func aFoldOnALeafOrALineMovesNothing() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    try store.createView(NewTaskView(title: "Clients", parent: work))
    let errands = try store.createView(NewTaskView(title: "Errands"))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    refusingAName(list)
    let before = list.model
    for id in [errands, work, ViewID()] {
        #expect(list.send(.action(.disclosureTapped(id))) == nil)
        #expect(list.model == before)
    }
    #expect(try store.deviceState(collapsedKey, as: [String].self) == nil, "nothing was written")
}

/// The folds read back are the device's state, written by a version of the app that may be older, newer or wrong
/// (`docs/style.md`, "Data from outside"), so a stale set reads as what it can: a view deleted since, an id no view ever
/// had, a text that is no id at all and an area, whose line never folds, are dropped, and the fold a list's row holds
/// stands. The next fold writes back what the module holds, without them.
@Test func aFoldOnAnIdNoRowHoldsIsDropped() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    try store.createView(NewTaskView(title: "Home", parent: projects))
    let archive = try store.createView(NewTaskView(title: "Archive"))
    try store.createView(NewTaskView(title: "2025", parent: archive))
    try store.delete(viewTree: archive)
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    try store.setDeviceState(collapsedKey, [
        archive.rawValue, projects.rawValue, ViewID().rawValue, "not an id", work.rawValue,
    ])
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    #expect(list.model.rows.dropFirst(5).map(\.id) == [projects, work, clients])
    #expect(listRow(projects, in: list.model)?.isCollapsed == true)
    #expect(list.send(.action(.disclosureTapped(projects))) == nil)
    #expect(try store.deviceState(collapsedKey, as: [String].self) == [], "the stale ids were dropped when the folds were read")
}

/// Only a list folds, an area's line never, even one that was folded as a list. An area that arrived nested, moved
/// by an app older than the kind, reads as a list with no rule (ADR-0004, amendment of 2026-10-25), so its chevron
/// folds its branch; when a peer moves it back to the root it reads as an area again, and its lists stand under its
/// line, a list inside one of them too, whatever the module still holds, since no chevron on the line could unfold
/// them.
@Test func aFoldedListThatComesToReadAsAnAreaHidesNothing() throws {
    let peer = Store.newDeviceID()
    func parent(of id: ViewID, _ value: Value, at millis: Int64) -> JournalOperation {
        JournalOperation(entity: .view, entityID: id.rawValue, field: "parent", value: value, clock: HLC(millis: millis, counter: 0), device: peer)
    }
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    let acme = try store.createView(NewTaskView(title: "Acme", parent: clients))
    _ = try store.apply([parent(of: work, .text(projects.rawValue), at: 1_800_000_000_000)])
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    #expect(listRow(work, in: list.model)?.hasChildren == true, "nested, the area reads as a list; this is the setup")
    #expect(list.send(.action(.disclosureTapped(work))) == nil)
    #expect(list.model.rows.dropFirst(5).map(\.id) == [projects, work], "folded as a list")
    let moved = try changeSet(of: store) { _ = try store.apply([parent(of: work, .null, at: 1_800_000_000_001)]) }
    #expect(list.send(.changed(moved)) == nil)
    #expect(list.model.rows.dropFirst(5).map(\.id) == [projects, work, clients, acme])
    #expect(list.model.rows.first { $0.id == work }?.kind == .area(label: "Work"))
}
