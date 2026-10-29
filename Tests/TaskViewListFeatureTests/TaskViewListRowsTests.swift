import Testing
import TestSupport
import DesignSystem
import DesignSystemComponents
import FeatureModule
import SQLiteKit
import TaskListFeature
import TaskScreenFeature
import TaskViewListFeature
import TodoCore

/// The Inbox, which a sidebar made on no list declares. Not private, like the helpers below that say so, since the
/// edits' tests read the rows with them too.
let inbox = BuiltInTaskViews.inbox

/// The five views every store starts with, in the order the seed ranks them.
let builtIns = [
    inbox, BuiltInTaskViews.today, BuiltInTaskViews.upcoming, BuiltInTaskViews.logbook, BuiltInTaskViews.trash,
]

/// What the store keeps of a view the module made, which is what says where it went and what it looks like: its title,
/// its parent, its kind, its colour and its icon.
private func stored(_ id: ViewID, in store: Store) throws -> [String?] {
    let view = try #require(try store.view(id))
    return [view.title, view.parent?.rawValue, view.kind.rawValue, view.color?.rawValue, view.icon]
}

/// The row a field is open on, which is how a test finds the row a New list or a New area just made. Not private.
func rowBeingNamed(in model: TaskViewList.Model) throws -> TaskViewList.Model.Row {
    try #require(model.rows.first { $0.draft != nil })
}

/// The key the sidebar keeps its folds under in the device's own state, as the module names it (ADR-0010). Not
/// private.
let collapsedViewsKey = "taskViewList.collapsed"

/// Opens the field on Today, types a blank name and submits it, so that the list holds a field open on a refused
/// draft and the sentence that refused it, which an event that moves nothing leaves where they are. Not private.
func refusingAName(_ list: TaskViewList) {
    _ = list.send(.action(.renameMenuItemChosen(BuiltInTaskViews.today)))
    _ = list.send(.action(.titleFieldChanged(" ")))
    _ = list.send(.action(.titleFieldSubmitted))
}

/// The list row a view's row draws, and nil for an area's line: what a test reads a tile, a font and a count off. Not
/// private.
func listRow(_ row: TaskViewList.Model.Row) -> TaskViewList.Model.ListRow? {
    guard case .list(let list) = row.kind else { return nil }
    return list
}

/// The list row the model draws for a view, and nil when no row holds the view or its row is an area's line. Not
/// private.
func listRow(_ id: ViewID, in model: TaskViewList.Model) -> TaskViewList.Model.ListRow? {
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
    #expect(model.rows.map(\.id) == builtIns + [garden, reading])
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
/// branch stay, the next one at its depth or above and those under that. The fold is the device's own (ADR-0010,
/// amendment of 2026-10-26), written on every fold as the folded ids, so a module made anew, as at the next launch,
/// reads it back, a fold inside a folded branch included. Unfolded, the branch is back as it was, the fold inside it
/// kept, and with nothing folded the set written is empty. A fold is no answer to anything a person was told, so a
/// field open on a refused name keeps its draft and its sentence throughout.
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
    #expect(try store.deviceState(collapsedViewsKey, as: [String].self).map(Set.init) == [projects.rawValue, home.rawValue])
    let made = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    refusingAName(made)
    #expect(list.model == made.model, "a module made anew reads both folds back")
    #expect(list.send(.action(.disclosureTapped(projects))) == nil)
    #expect(list.model.rows.dropFirst(5).map(\.id) == [projects, home, office, desk, errands], "the fold inside it stays")
    #expect(list.send(.action(.disclosureTapped(home))) == nil)
    #expect(list.model == open)
    #expect(try store.deviceState(collapsedViewsKey, as: [String].self) == [])
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
    #expect(try store.deviceState(collapsedViewsKey, as: [String].self) == nil, "nothing was written")
}

/// The folds read back are the device's state, written by a version of the app that may be older, newer or wrong
/// (`docs/style.md`, "Data from outside"), so a stale set reads as what it can: a view deleted since, an id no view
/// ever had, a text that is no id at all and an area, whose line never folds, are dropped, and the fold a list's row
/// holds stands. The next fold writes back what the module holds, without them.
@Test func aFoldOnAnIdNoRowHoldsIsDropped() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    try store.createView(NewTaskView(title: "Home", parent: projects))
    let archive = try store.createView(NewTaskView(title: "Archive"))
    try store.createView(NewTaskView(title: "2025", parent: archive))
    try store.delete(viewTree: archive)
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    try store.setDeviceState(collapsedViewsKey, [
        archive.rawValue, projects.rawValue, ViewID().rawValue, "not an id", work.rawValue,
    ])
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    #expect(list.model.rows.dropFirst(5).map(\.id) == [projects, work, clients])
    #expect(listRow(projects, in: list.model)?.isCollapsed == true)
    #expect(list.send(.action(.disclosureTapped(projects))) == nil)
    #expect(try store.deviceState(collapsedViewsKey, as: [String].self) == [], "the stale ids were dropped when the folds were read")
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

/// "+ → New list" puts the list where the line says it belongs (Lists screen spec, section 3): with no area, at the
/// root's end, and with areas, last in the last of them, so that it stands under the last line. Either way it is
/// titled "New list", has no colour, since nothing is above it to take one from, and has the list icon.
@Test func newListFromPlusGoesIntoTheLastAreaOrToTheEndOfTheRoot() throws {
    let bare = try makeStore()
    let atTheRoot = try TaskViewList(store: bare, route: .init(list: nil), width: .narrow)
    #expect(atTheRoot.send(.action(.newListMenuItemChosen(in: nil))) == nil)
    let last = try rowBeingNamed(in: atTheRoot.model)
    #expect(atTheRoot.model.rows.map(\.id) == builtIns + [last.id])
    #expect(last.depth == 0)
    #expect(try stored(last.id, in: bare) == ["New list", nil, "list", nil, "list"])

    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    let home = try store.createView(NewTaskView(title: "Home", kind: .area))
    let garden = try store.createView(NewTaskView(title: "Garden", parent: home, color: .green))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    #expect(list.send(.action(.newListMenuItemChosen(in: nil))) == nil)
    let made = try rowBeingNamed(in: list.model)
    #expect(list.model.rows.map(\.id) == builtIns + [work, clients, home, garden, made.id])
    #expect(made.depth == 0)
    #expect(try stored(made.id, in: store) == ["New list", home.rawValue, "list", nil, "list"])
    let reference = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    _ = reference.send(.action(.renameMenuItemChosen(made.id)))
    #expect(list.model == reference.model)
}

/// New list from a list's menu makes it inside that list, last among the lists already there, with that list's colour
/// and the list icon, and the branch it was made in unfolds, written to the device's state as every fold is, so that
/// the field the new list opens is on screen (Lists screen spec, section 6).
@Test func newListFromAListsMenuGoesInsideItWithItsColourAndUnfoldsIt() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects", color: .teal, icon: "folder"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects))
    let errands = try store.createView(NewTaskView(title: "Errands"))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    #expect(list.send(.action(.disclosureTapped(projects))) == nil)
    #expect(listRow(projects, in: list.model)?.isCollapsed == true, "the branch is folded; this is the setup")
    #expect(list.send(.action(.newListMenuItemChosen(in: projects))) == nil)
    let made = try rowBeingNamed(in: list.model)
    #expect(list.model.rows.map(\.id) == builtIns + [projects, home, made.id, errands])
    #expect(listRow(projects, in: list.model)?.isCollapsed == false)
    #expect(try store.deviceState(collapsedViewsKey, as: [String].self) == [])
    #expect(made.depth == 1)
    #expect(listRow(made)?.tile == TileModel(color: .teal, icon: .list, side: 26, cornerRadius: 7, glyphSize: 16))
    #expect(try stored(made.id, in: store) == ["New list", projects.rawValue, "list", "teal", "list"])
    let reference = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    _ = reference.send(.action(.renameMenuItemChosen(made.id)))
    #expect(list.model == reference.model, "a module made anew reads the branch unfolded")
}

/// New list from an area's menu makes it last under the area's line with no colour, even where the area holds a
/// colour of its own from another device, since an area has no tile to give one (Lists screen spec, section 6); it
/// stands at the root's drawn depth like the area's other lists, and its tile is stone's.
@Test func newListInAnAreaHasNoColour() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", kind: .area, color: .rose))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work, color: .violet))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    #expect(list.send(.action(.newListMenuItemChosen(in: work))) == nil)
    let made = try rowBeingNamed(in: list.model)
    #expect(list.model.rows.map(\.id) == builtIns + [work, clients, made.id])
    #expect(made.depth == 0)
    #expect(listRow(made)?.tile == TileModel(color: .stone, icon: .list, side: 30, cornerRadius: 8, glyphSize: 19))
    #expect(try stored(made.id, in: store) == ["New list", work.rawValue, "list", nil, "list"])
    let reference = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    _ = reference.send(.action(.renameMenuItemChosen(made.id)))
    #expect(list.model == reference.model)
}

/// The new list opens its name field with its title as the draft, so the first keystroke replaces it, and declares
/// nothing: the list open beside the sidebar, with the task in it, and the highlight stay where they were, since on a
/// narrow window a list declared now would be pushed over the sidebar while the field is open (Lists screen plan,
/// "Self-review"). A New list on a row that is not there makes nothing.
@Test func aNewListOpensItsFieldAndDeclaresNoList() throws {
    let store = try makeStore()
    let task = try store.createTask(NewTask(title: "Buy milk"))
    let route = TaskViewList.Route(list: .init(head: inbox, task: TaskScreen.Route(head: task)))
    let list = try TaskViewList(store: store, route: route, width: .narrow)
    let before = list.model
    let written = try store.journal(after: 0).count
    #expect(list.send(.action(.newListMenuItemChosen(in: ViewID()))) == nil)
    #expect(list.model == before)
    #expect(try store.journal(after: 0).count == written, "nothing was made")
    #expect(list.send(.action(.newListMenuItemChosen(in: nil))) == nil)
    let made = try rowBeingNamed(in: list.model)
    #expect(made.draft == "New list")
    #expect(list.destination.pushed == route.list)
    #expect(list.route == route)
    let reference = try TaskViewList(store: store, route: route, width: .narrow)
    _ = reference.send(.action(.renameMenuItemChosen(made.id)))
    #expect(list.model == reference.model, "the field on the new row, the highlight on the Inbox, and nothing said")
}

/// "+ → New area" adds the line at the root's end, after every list and area there, with its name field open and
/// empty, and declares nothing (Lists screen spec, section 3).
@Test func aNewAreaGoesToTheEndOfTheRootWithItsNameFieldOpen() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    #expect(list.send(.action(.newAreaMenuItemChosen)) == nil)
    let made = try rowBeingNamed(in: list.model)
    #expect(list.model.rows.map(\.id) == builtIns + [work, clients, made.id])
    #expect(made.kind == .area(label: nil))
    #expect(made.depth == 0)
    #expect(made.draft == "")
    #expect(try stored(made.id, in: store) == ["", nil, "area", nil, nil])
    #expect(list.destination.pushed == .init(head: inbox))
    let reference = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    _ = reference.send(.action(.renameMenuItemChosen(made.id)))
    #expect(list.model == reference.model)
}

/// An area may go unnamed and a list may not (Lists screen spec, sections 3 and 6): Return on the new area's empty
/// field keeps it unnamed, a name given later is its label, and a name cleared, spaces and all, leaves it unnamed
/// again, each without a sentence; the empty name on a list is refused with the sentence it is refused with today, and
/// its field stays open.
@Test func anAreaAcceptsTheEmptyNameAndAListRefusesIt() throws {
    let store = try makeStore()
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    _ = list.send(.action(.newAreaMenuItemChosen))
    let area = try rowBeingNamed(in: list.model).id
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    #expect(list.model.problem == nil)
    #expect(list.model.rows.allSatisfy { $0.draft == nil })
    #expect(list.model.rows.last?.kind == .area(label: nil))
    _ = list.send(.action(.renameMenuItemChosen(area)))
    _ = list.send(.action(.titleFieldChanged("Home")))
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    #expect(list.model.rows.last?.kind == .area(label: "Home"))
    _ = list.send(.action(.renameMenuItemChosen(area)))
    #expect(try rowBeingNamed(in: list.model).draft == "Home", "the field opens on the area's name")
    _ = list.send(.action(.titleFieldChanged("  ")))
    #expect(list.send(.action(.titleFieldLostFocus)) == nil)
    #expect(list.model.problem == nil)
    #expect(list.model.rows.last?.kind == .area(label: nil))
    #expect(try stored(area, in: store) == ["", nil, "area", nil, nil])

    _ = list.send(.action(.newListMenuItemChosen(in: nil)))
    let made = try rowBeingNamed(in: list.model).id
    _ = list.send(.action(.titleFieldChanged("")))
    #expect(list.send(.action(.titleFieldSubmitted)) == nil)
    #expect(list.model.problem == "A title cannot be empty.")
    #expect(try rowBeingNamed(in: list.model).id == made, "the field stays open on the list")
    #expect(try stored(made, in: store) == ["New list", area.rawValue, "list", nil, "list"])
}

/// An area never opens (Lists screen spec, section 2), so a tap on its line and Open in New Window on it move nothing:
/// no list is declared, the one open stays, and an open field and its sentence stay where they are.
@Test func aTapOrOpenInNewWindowOnAnAreasLineMovesNothing() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let list = try TaskViewList(store: store, route: .init(list: .init(head: BuiltInTaskViews.upcoming)), width: .narrow)
    refusingAName(list)
    let before = list.model
    #expect(list.send(.action(.rowSelected(work))) == nil)
    #expect(list.model == before)
    #expect(list.destination.pushed == .init(head: BuiltInTaskViews.upcoming))
    #expect(list.send(.action(.openInNewWindowMenuItemChosen(work))) == nil)
    #expect(list.model == before)
}

/// New task is quick entry, which is the root's to open over the window (Lists screen spec, section 5), so the module
/// asks for it and moves nothing of its own, an open field and its sentence included.
@Test func newTaskAsksTheRootForQuickEntry() throws {
    let list = try TaskViewList(store: try makeStore(), route: .init(list: nil), width: .narrow)
    refusingAName(list)
    let before = list.model
    #expect(list.send(.action(.newTaskMenuItemChosen)) == .newTaskRequested)
    #expect(list.model == before)
    #expect(list.destination.pushed == .init(head: inbox))
}

/// The folds are the device's, so two windows of one device share them: a fold made in one is read by the other at its
/// next read of the rows, which a change naming a view brings, and not at a change naming only tasks, which reads the
/// counts alone; a fold the other makes then writes the set with the first window's fold in it (Lists screen spec,
/// section 5; ADR-0010).
@Test func aFoldMadeInAnotherWindowIsReadAtTheNextReread() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    try store.createView(NewTaskView(title: "Home", parent: projects))
    let errands = try store.createView(NewTaskView(title: "Errands"))
    try store.createView(NewTaskView(title: "Chores", parent: errands))
    let first = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    let second = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    #expect(first.send(.action(.disclosureTapped(projects))) == nil)
    let filed = try changeSet(of: store) { try store.createTask(NewTask(title: "Buy milk")) }
    #expect(second.send(.changed(filed)) == nil)
    #expect(listRow(projects, in: second.model)?.isCollapsed == false, "a change to a task reads the counts alone")
    let created = try changeSet(of: store) { try store.createView(NewTaskView(title: "Docs")) }
    #expect(second.send(.changed(created)) == nil)
    #expect(second.model == (try TaskViewList(store: store, route: .init(list: nil), width: .narrow)).model)
    #expect(listRow(projects, in: second.model)?.isCollapsed == true)
    #expect(second.send(.action(.disclosureTapped(errands))) == nil)
    #expect(try store.deviceState(collapsedViewsKey, as: [String].self).map(Set.init) == [projects.rawValue, errands.rawValue])
}

/// An unnamed area has no name to say, so a field open on one that a peer deleted says that the area is gone without
/// a name, by either way the news arrives: as a change, which drops the field, or as the refusal of Return. One fact,
/// one sentence, so the two end in the same model, the area's line gone and no field open.
@Test func anUnnamedAreaGoneMidRenameIsSaidWithoutAName() throws {
    let store = try makeStore()
    let area = try store.createView(NewTaskView(title: "", kind: .area))
    let viaChange = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    let viaReturn = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    for list in [viaChange, viaReturn] {
        _ = list.send(.action(.renameMenuItemChosen(area)))
        _ = list.send(.action(.titleFieldChanged("Home")))
    }
    let deleted = try changeSet(of: store) { try store.delete(view: area) }
    #expect(viaChange.send(.changed(deleted)) == nil)
    #expect(viaReturn.send(.action(.titleFieldSubmitted)) == nil)
    #expect(viaChange.model.problem == "The area is no longer there, so the new name was not saved.")
    #expect(viaChange.model == viaReturn.model)
    #expect(viaChange.model.rows == (try TaskViewList(store: store, route: .init(list: nil), width: .narrow)).model.rows)
}

/// A fold is drawn only on a list with lists inside it, where a chevron can take it back: a leaf whose id the device's
/// state holds shows none, nor does a folded list whose lists are gone. The fold is kept for the list all the same,
/// so a list that comes back inside it comes back folded, under a chevron that unfolds it.
@Test func aFoldIsDrawnOnlyOnAListWithListsInside() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects))
    let errands = try store.createView(NewTaskView(title: "Errands"))
    try store.setDeviceState(collapsedViewsKey, [projects.rawValue, errands.rawValue])
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    #expect(listRow(projects, in: list.model)?.isCollapsed == true)
    #expect(listRow(errands, in: list.model)?.isCollapsed == false, "a leaf the device's state names")
    let deleted = try changeSet(of: store) { try store.delete(view: home) }
    #expect(list.send(.changed(deleted)) == nil)
    #expect(listRow(projects, in: list.model)?.isCollapsed == false, "its lists are gone")
    let garden = try changeSet(of: store) { try store.createView(NewTaskView(title: "Garden", parent: projects)) }
    #expect(list.send(.changed(garden)) == nil)
    #expect(listRow(projects, in: list.model)?.isCollapsed == true)
    #expect(list.model.rows.dropFirst(5).map(\.id) == [projects, errands], "the list that came back inside it is folded")
    #expect(list.model == (try TaskViewList(store: store, route: .init(list: nil), width: .narrow)).model)
}

/// A fold that hides the open list's row lights the row that hides it, the folded list a person can still see, as the
/// Finder lights a folder that closes over the selection (the owner, 2026-10-29, #158): `selection` names it, and the
/// model is the one a sidebar declared on that list draws. With two folds above the open list the outer one is lit,
/// since it is the one drawn. Only the light moves: the list declared, with the task in it, stays open, and the folds
/// taken back light its own row again.
@Test func aFoldOverTheOpenListLightsTheFoldedListThatHidesIt() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects))
    let garden = try store.createView(NewTaskView(title: "Garden", parent: home))
    try store.createView(NewTaskView(title: "Errands"))
    let task = try store.createTask(NewTask(title: "Buy seeds"))
    let route = TaskViewList.Route(list: .init(head: garden, task: TaskScreen.Route(head: task)))
    let list = try TaskViewList(store: store, route: route, width: .narrow)
    let open = list.model
    #expect(open.selection == garden, "the open list's row is lit; this is the setup")
    #expect(list.send(.action(.disclosureTapped(home))) == nil)
    #expect(list.model.selection == home)
    #expect(list.model == (try sidebarOn(home, in: store)), "Home lit, as a sidebar declared on it draws it")
    #expect(list.send(.action(.disclosureTapped(projects))) == nil)
    #expect(list.model.selection == projects, "the outer fold, the one drawn")
    #expect(list.model == (try sidebarOn(projects, in: store)))
    #expect(list.destination.pushed == route.list, "the light moved and the declaration did not")
    #expect(list.route == route)
    #expect(list.send(.action(.disclosureTapped(projects))) == nil)
    #expect(list.model == (try sidebarOn(home, in: store)), "Home still hides Garden")
    #expect(list.send(.action(.disclosureTapped(home))) == nil)
    #expect(list.model == open)
}

/// Under an area's line the lists stand at the line's own depth (Lists screen spec, section 3), and a fold among them
/// lights the same way: the folded list that hides the open one, the outer of two, and not the list after the branch,
/// which stands at the same drawn depth as the outer one.
@Test func aFoldOverTheOpenListUnderAnAreaLightsTheFoldedListThatHidesIt() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    let acme = try store.createView(NewTaskView(title: "Acme", parent: clients))
    let contracts = try store.createView(NewTaskView(title: "Contracts", parent: acme))
    try store.createView(NewTaskView(title: "Billing", parent: work))
    let list = try TaskViewList(store: store, route: .init(list: .init(head: contracts)), width: .narrow)
    let open = list.model
    #expect(open.selection == contracts, "the open list's row is lit; this is the setup")
    #expect(list.send(.action(.disclosureTapped(acme))) == nil)
    #expect(list.model == (try sidebarOn(acme, in: store)))
    #expect(list.send(.action(.disclosureTapped(clients))) == nil)
    #expect(list.model.selection == clients)
    #expect(list.model == (try sidebarOn(clients, in: store)))
    #expect(list.destination.pushed == .init(head: contracts))
    #expect(list.send(.action(.disclosureTapped(clients))) == nil)
    #expect(list.send(.action(.disclosureTapped(acme))) == nil)
    #expect(list.model == open)
}

/// The lit list is a row like any other, so a click on it declares its own list, which closes the one open under the
/// fold, as a click on any row declares that row's (`rowSelected`); unfolded, the light stays where the click put it.
@Test func aClickOnTheLitFoldedListDeclaresItsOwnList() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects))
    let list = try TaskViewList(store: store, route: .init(list: .init(head: home)), width: .narrow)
    #expect(list.send(.action(.disclosureTapped(projects))) == nil)
    #expect(list.model.selection == projects, "the fold lit Projects; this is the setup")
    #expect(list.send(.action(.rowSelected(projects))) == nil)
    #expect(list.destination.pushed == .init(head: projects))
    #expect(list.route == .init(list: .init(head: projects)))
    #expect(list.send(.action(.disclosureTapped(projects))) == nil)
    #expect(list.model == (try sidebarOn(projects, in: store)), "unfolded, Projects is lit and Home is not")
}

/// A change naming only tags can move a count too, as a deleted tag takes its tasks out of every rule that names it,
/// so it reads the counts again, and not the rows: a view written since with no change sent stays out of them (Lists
/// screen spec, section 4).
@Test func aChangeToATagRereadsTheCountsAndNotTheRows() throws {
    let store = try makeStore()
    let errands = try store.createTag(title: "errands")
    try store.createTask(NewTask(title: "Buy milk", tags: [errands]))
    let shopping = try store.createView(NewTaskView(title: "Shopping", filter: .hasTag(errands)))
    let list = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    #expect(listRow(shopping, in: list.model)?.countText == "1", "the tag's task is counted; this is the setup")
    let deleted = try changeSet(of: store) { try store.delete(tag: errands) }
    #expect(deleted.tasks.isEmpty && deleted.views.isEmpty, "a change naming the tag alone; this is the setup")
    let reference = try TaskViewList(store: store, route: .init(list: nil), width: .narrow)
    try store.createView(NewTaskView(title: "Docs"))
    #expect(list.send(.changed(deleted)) == nil)
    #expect(listRow(shopping, in: list.model)?.countText == "")
    #expect(list.model == reference.model, "the count moved, and Docs is missing")
}
