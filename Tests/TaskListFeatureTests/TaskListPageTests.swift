import Testing
import TestSupport
import DesignSystem
import DesignSystemComponents
import FeatureModule
import TaskListFeature
import TaskScreenFeature
import TodoCore

private let inbox = BuiltInTaskViews.inbox
private let upcoming = BuiltInTaskViews.upcoming

/// The route of one of a list's own groups, its screen.
private func screen(_ group: TaskList.Route.Group, of view: ViewID) -> TaskList.Route {
    TaskList.Route(head: .init(view: view, group: group))
}

/// Whether the model is in the list layout.
private func isList(_ model: TaskList.Model) -> Bool {
    switch model.layout {
    case .list: true
    case .columns: false
    }
}

/// The ids of the blocks a model draws.
private func ids(of model: TaskList.Model) -> [TaskList.Model.BlockID] {
    blocks(of: model).map(\.id)
}

/// The titles of a block's rows, in their order.
private func titles(of block: TaskList.Model.Block) -> [String] {
    block.rows.map { row($0).title.text }
}

/// The titles of every block's rows, block by block.
private func titles(of model: TaskList.Model) -> [[String]] {
    blocks(of: model).map(titles(of:))
}

/// What a block's header says, its title and its subtitle, or its column's header in columns; nil for a block with
/// none.
private func heading(of block: TaskList.Model.Block) -> [String?]? {
    guard let header = block.header ?? block.column?.header else { return nil }
    return [header.title.text, header.subtitle?.text]
}

/// The chips of the tag bar by their titles, and none when there is no bar.
private func chips(of model: TaskList.Model) -> [String] {
    model.tagBar?.chips.map(\.title.text) ?? []
}

/// The chips that are lit.
private func lit(in model: TaskList.Model) -> [String] {
    model.tagBar?.chips.filter(\.isLit).map(\.title.text) ?? []
}

/// The item of Show as that chooses the layout.
private func item(_ kind: TaskList.Model.Layout.Kind, in model: TaskList.Model) throws -> MenuModel<TaskList.UserAction>.Item {
    try #require(model.showAs.menu.sections.flatMap(\.items).first { $0.action == .showAsChosen(kind) })
}

/// A list of the open tasks grouped by the day of When, of any day, which no seeded list is, with a list inside it
/// that claims the tasks tagged `errand`: the canvas's "This week" in the shape the test needs.
private func week(in store: Store) throws -> (week: ViewID, errands: ViewID, errand: TagID) {
    let errand = try store.createTag(title: "errand")
    let week = try store.createView(
        NewTaskView(title: "This week", color: .indigo, icon: "week", filter: .status([.open]), groupBy: .whenDay)
    )
    let errands = try store.createView(NewTaskView(title: "Errands", parent: week, color: .teal, filter: .hasTag(errand)))
    return (week, errands, errand)
}

/// A list's screen is its own tasks first, the tasks its rule selects that no list inside claims, then one block per
/// list inside in the sidebar's order, each headed by that list's title in its colour, holding what that list selects
/// (spec section 2). A list that groups by nothing has one own block, with no header.
@Test func theOwnBlocksComeFirstThenOneBlockPerListInside() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let projects = try store.createView(NewTaskView(title: "Projects", color: .indigo, filter: .status([.open])))
    let house = try store.createView(NewTaskView(title: "House", parent: projects, color: .teal, filter: .hasTag(home)))
    let soon = try store.createView(NewTaskView(title: "Soon", parent: projects, filter: .deadline(.onOrBefore(7))))
    try store.createTask(NewTask(title: "Write the plan"))
    try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    try store.createTask(NewTask(title: "Pay the rent", deadline: day(3)))
    let model = try list(projects, in: store).model
    #expect(ids(of: model) == [.own(nil), .list(house), .list(soon)])
    #expect(titles(of: model) == [["Write the plan"], ["Fix the door"], ["Pay the rent"]], "what a list inside claims is not the parent's own")
    #expect(blocks(of: model).map(heading(of:)) == [nil, ["House", nil], ["Soon", nil]])
    #expect(
        blocks(of: model)[1].header?.title.style.color == DesignSystem.Color.Components.Tile.teal.glyph,
        "in the list's own colour"
    )
    #expect(
        blocks(of: model)[2].header?.title.style.color == DesignSystem.Color.Components.Tile.stone.glyph,
        "a list with no colour is stone"
    )
}

/// A folder inside the list is one block of the tasks its lists select, as its count in the sidebar counts them
/// (spec section 2; ADR-0004, amendment of 2026-11-01).
@Test func aFolderInsideIsOneBlockOfItsListsTasks() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let work = try store.createTag(title: "work")
    let projects = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let areas = try store.createView(NewTaskView(title: "Areas", parent: projects))
    try store.createView(NewTaskView(title: "Home", parent: areas, filter: .hasTag(home)))
    try store.createView(NewTaskView(title: "Work", parent: areas, filter: .hasTag(work)))
    try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    try store.createTask(NewTask(title: "File the report", tags: [work]))
    try store.createTask(NewTask(title: "Write the plan"))
    let model = try list(projects, in: store).model
    #expect(ids(of: model) == [.own(nil), .list(areas)])
    #expect(Set(titles(of: blocks(of: model)[1])) == ["Fix the door", "File the report"])
    #expect(titles(of: blocks(of: model)[0]) == ["Write the plan"])
}

/// A list inside with lists of its own is one block of its own rule's tasks here, never a block with blocks inside:
/// those are drawn on its own screen (owner, 2026-11-01).
@Test func aListInsideWithListsOfItsOwnIsOneBlockHere() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let kitchen = try store.createTag(title: "kitchen")
    let projects = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let house = try store.createView(NewTaskView(title: "House", parent: projects, filter: .hasTag(home)))
    let room = try store.createView(NewTaskView(title: "Kitchen", parent: house, filter: .hasTag(kitchen)))
    try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    try store.createTask(NewTask(title: "Paint the wall", tags: [home, kitchen]))
    let model = try list(projects, in: store).model
    #expect(ids(of: model) == [.own(nil), .list(house)])
    #expect(Set(titles(of: blocks(of: model)[1])) == ["Fix the door", "Paint the wall"])
    #expect(ids(of: try list(house, in: store).model) == [.own(nil), .list(room)], "its own screen draws the list inside it")
}

/// A list inside with nothing in it is drawn all the same, its header over no rows, so that a list just added has a
/// place to put a task (spec section 2).
@Test func anEmptyListInsideIsDrawnAsABlock() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let empty = try store.createView(NewTaskView(title: "Someday", parent: projects, filter: .when(.onOrAfter(365))))
    let model = try list(projects, in: store).model
    #expect(ids(of: model) == [.own(nil), .list(empty)])
    #expect(heading(of: blocks(of: model)[1]) == ["Someday", nil])
    #expect(blocks(of: model)[1].rows.isEmpty)
}

/// A list grouped by day draws its own tasks as one block per day that holds one, in the page's order, each headed by
/// the day's title and its date (spec section 2; canvas).
@Test func aGroupedListsOwnBlocksAreItsDays() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Call the bank", when: day(3)))
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    try store.createTask(NewTask(title: "Water the plants", when: day(1)))
    let model = try list(upcoming, in: store).model
    #expect(ids(of: model) == [.own(.day(day(1))), .own(.day(day(3)))])
    #expect(blocks(of: model).map(heading(of:)) == [["Tomorrow", "Thu, Sep 11"], ["Saturday", "Sep 13"]])
    #expect(titles(of: model) == [["Buy milk", "Water the plants"], ["Call the bank"]])
}

/// A list grouped by tag, by parent or by status titles each block as its group's screen is titled, with no subtitle,
/// and the group with no key by what it lacks; a day group with no day is "No date". A parent is read once for its
/// group, and one that does not read is titled as no parent is (the controller's ruling on #175, 2026-11-04).
@Test func theOtherGroupingsBlocksAreTitledAsTheirGroups() throws {
    let store = try makeStore()
    let errand = try store.createTag(title: "errand")
    let byTag = try store.createView(NewTaskView(title: "By tag", filter: .status([.open]), groupBy: .tag))
    try store.createTask(NewTask(title: "Buy milk", tags: [errand]))
    try store.createTask(NewTask(title: "Write the plan"))
    #expect(blocks(of: try list(byTag, in: store).model).map(heading(of:)) == [["errand", nil], ["No tag", nil]])

    let store2 = try makeStore()
    let plan = try store2.createTask(NewTask(title: "The plan"))
    try store2.createTask(NewTask(title: "Draft it", parent: plan))
    let byParent = try store2.createView(
        NewTaskView(title: "By parent", filter: .status([.open]), sort: [SortKey(.title)], groupBy: .parent)
    )
    #expect(blocks(of: try list(byParent, in: store2).model).map(heading(of:)) == [["The plan", nil], ["No parent", nil]])

    let store3 = try makeStore()
    let done = try store3.createTask(NewTask(title: "Done already"))
    try store3.update(task: done, [.status(.done)])
    let canceled = try store3.createTask(NewTask(title: "Dropped"))
    try store3.update(task: canceled, [.status(.canceled)])
    try store3.createTask(NewTask(title: "Still open"))
    let byStatus = try store3.createView(NewTaskView(title: "By status", filter: .status([.done, .canceled]), sort: [SortKey(.title)], groupBy: .status))
    #expect(Set(blocks(of: try list(byStatus, in: store3).model).compactMap { heading(of: $0)?.first ?? nil }) == ["Done", "Canceled"])
    // A rule that also asks for open tasks draws those alone, its finished ones being the strip's (the controller's
    // ruling on #176, 2026-11-05).
    let withOpen = try store3.createView(NewTaskView(title: "With open", filter: .status([.open, .done, .canceled]), sort: [SortKey(.title)], groupBy: .status))
    #expect(blocks(of: try list(withOpen, in: store3).model).map(heading(of:)) == [["Open", nil]])

    let store4 = try makeStore()
    let byDay = try store4.createView(NewTaskView(title: "By day", filter: .status([.open]), groupBy: .whenDay))
    try store4.createTask(NewTask(title: "Someday"))
    #expect(blocks(of: try list(byDay, in: store4).model).map(heading(of:)) == [["No date", nil]])
}

/// The meta line under a row's title says, in this order, the deadline, the task's tags as "#name" in the tags' own
/// order, its subtasks done over all with the subtasks' glyph, and a glyph alone where it has notes (spec section 3;
/// canvas).
@Test func aRowsMetaLineSaysDeadlineTagsSubtasksAndNotesInOrder() throws {
    let store = try makeStore()
    let errand = try store.createTag(title: "errand")
    let home = try store.createTag(title: "home")
    let id = try store.createTask(NewTask(title: "Fix the door", notes: "the hinge", deadline: day(2), tags: [home, errand]))
    let first = try store.createTask(NewTask(title: "Buy a hinge", parent: id))
    try store.createTask(NewTask(title: "Fit it", parent: id))
    try store.update(task: first, [.status(.done)])
    try store.createTask(NewTask(title: "Nothing to say"))
    let model = try list(inbox, in: store).model
    let rows = try #require(blocks(of: model).first).rows
    #expect(rows.map(\.id).first == id)
    let meta = row(rows[0]).meta
    #expect(meta.map { $0.text?.text } == ["Due Fri", "#errand", "#home", "1/2", nil], "the notes' glyph alone")
    #expect(meta.map { $0.icon?.icon } == [.flag, nil, nil, .list, .note])
    #expect(row(rows[1]).meta.isEmpty, "a task with nothing to say has no meta line")
}

/// The deadline is red from the day it is due, and a task that is not open says nothing of its deadline (spec section
/// 3; canvas).
@Test func aDeadlineIsRedFromTheDayItIsDue() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Late", deadline: day(-1)))
    try store.createTask(NewTask(title: "Due now", deadline: day(0)))
    try store.createTask(NewTask(title: "Next", deadline: day(1)))
    let done = try store.createTask(NewTask(title: "Done", deadline: day(-1)))
    try store.update(task: done, [.status(.done)])
    let rows = try #require(blocks(of: try list(inbox, in: store).model).first).rows
    #expect(rows.map { row($0).meta.first?.text?.style.color } == [.red, .red, .ink2])
    #expect(rows.map { row($0).meta.first?.icon?.style.color } == [.red, .red, .ink2])
    let logbook = try #require(blocks(of: try list(BuiltInTaskViews.logbook, in: store).model).first).rows
    #expect(logbook.map { row($0).title.text } == ["Done"])
    #expect(logbook.map { row($0).meta.isEmpty } == [true])
}

/// The chips are the tags the open tasks carry, the most used first and ties by title, and a tag every one of them
/// carries is left out, since it would filter nothing (spec section 7). Each is the tag's bare name, the hash its
/// glyph.
@Test func theTagBarCountsTheOpenTasksTagsAndDropsATagOnEveryOne() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let home = try store.createTag(title: "home")
    let errand = try store.createTag(title: "errand")
    let alpha = try store.createTag(title: "alpha")
    try store.createTask(NewTask(title: "One", tags: [work, home]))
    try store.createTask(NewTask(title: "Two", tags: [work, errand]))
    try store.createTask(NewTask(title: "Three", tags: [work, home, alpha]))
    let model = try list(inbox, in: store).model
    #expect(chips(of: model) == ["home", "alpha", "errand"])
    #expect(model.tagBar?.chips.map(\.icon.icon) == [.hash, .hash, .hash])
    #expect(model.tagBar?.chips.map(\.action) == [.tagChipTapped(home), .tagChipTapped(alpha), .tagChipTapped(errand)])
}

/// Chips tied on their count stand by title as a person reads it, whatever its case, and two titles that read the same
/// stand by their characters, so that the order is always the same (canvas, `localeCompare`; the controller's ruling on
/// #175, 2026-11-04).
@Test func chipsTiedOnTheirCountStandByTitleWhateverItsCase() throws {
    let store = try makeStore()
    let zebra = try store.createTag(title: "Zebra")
    let apple = try store.createTag(title: "apple")
    let upper = try store.createTag(title: "Apple")
    try store.createTask(NewTask(title: "One", tags: [zebra]))
    try store.createTask(NewTask(title: "Two", tags: [apple]))
    try store.createTask(NewTask(title: "Three", tags: [upper]))
    #expect(chips(of: try list(inbox, in: store).model) == ["Apple", "apple", "Zebra"])
}

/// A task two sibling lists both select is drawn in both blocks and counted once on the bar, and a tag on every task is
/// over the same tasks (the controller's ruling on #175, 2026-11-04).
@Test func aTaskTwoBlocksSelectCountsOnceOnTheTagBar() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let errand = try store.createTag(title: "errand")
    let folder = try store.createView(NewTaskView(title: "Folder"))
    try store.createView(NewTaskView(title: "Home", parent: folder, filter: .hasTag(home)))
    try store.createView(NewTaskView(title: "Errands", parent: folder, filter: .hasTag(errand)))
    try store.createTask(NewTask(title: "Both", tags: [home, errand]))
    try store.createTask(NewTask(title: "Home only", tags: [home]))
    let model = try list(folder, in: store).model
    #expect(titles(of: model).map(Set.init) == [["Both", "Home only"], ["Both"]])
    #expect(chips(of: model) == ["errand"], "home is on both tasks, counted once each")
}

/// A tap on a chip lights it, and the rows of every block are the tasks carrying the tag; a block it empties keeps its
/// header; a second tap takes the pick back (spec section 7).
@Test func aPickedTagFiltersEveryBlock() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let work = try store.createTag(title: "work")
    let projects = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let soon = try store.createView(NewTaskView(title: "Soon", parent: projects, filter: .deadline(.onOrBefore(7))))
    try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    try store.createTask(NewTask(title: "File the report", tags: [work]))
    try store.createTask(NewTask(title: "Pay the rent", deadline: day(1), tags: [work]))
    let module = try list(projects, in: store)
    let before = module.model
    #expect(module.send(.action(.tagChipTapped(home))) == nil)
    #expect(lit(in: module.model) == ["home"])
    #expect(titles(of: module.model) == [["Fix the door"], []])
    #expect(heading(of: blocks(of: module.model)[1]) == ["Soon", nil], "an emptied block keeps its header")
    #expect(module.send(.action(.tagChipTapped(home))) == nil)
    #expect(module.model == before)
    #expect(ids(of: module.model) == [.own(nil), .list(soon)])
}

/// Several chips lit show a task carrying any of them (spec section 7).
@Test func twoPickedTagsShowATaskCarryingEither() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let work = try store.createTag(title: "work")
    let errand = try store.createTag(title: "errand")
    try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    try store.createTask(NewTask(title: "File the report", tags: [work]))
    try store.createTask(NewTask(title: "Buy milk", tags: [errand]))
    let module = try list(inbox, in: store)
    _ = module.send(.action(.tagChipTapped(home)))
    _ = module.send(.action(.tagChipTapped(work)))
    #expect(titles(of: module.model) == [["Fix the door", "File the report"]])
    #expect(Set(lit(in: module.model)) == ["home", "work"])
}

/// No bar when no chip would show: no tags at all, or a tag every task carries; and a tap on a tag that has no chip
/// moves nothing.
@Test func theTagBarIsNilWhenNoChipWouldShow() throws {
    let store = try makeStore()
    #expect(try list(inbox, in: store).model.tagBar == nil)
    let home = try store.createTag(title: "home")
    try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    try store.createTask(NewTask(title: "Paint the wall", tags: [home]))
    let module = try list(inbox, in: store)
    #expect(module.model.tagBar == nil)
    let before = module.model
    #expect(module.send(.action(.tagChipTapped(home))) == nil)
    #expect(module.model == before)
}

/// A picked tag whose chip leaves the bar, after a change or on a new day, stops filtering and is dropped from the
/// picks, so that it comes back unlit (the controller's ruling on #175, 2026-11-04).
@Test func aPickWhoseChipLeavesTheBarIsDropped() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    let other = try store.createTask(NewTask(title: "Buy milk"))
    let module = try list(inbox, in: store)
    _ = module.send(.action(.tagChipTapped(home)))
    #expect(titles(of: module.model) == [["Fix the door"]], "the pick filters; this is the setup")
    let gone = try changeSet(of: store) { try store.delete(task: other) }
    _ = module.send(.changed(gone))
    #expect(module.model.tagBar == nil, "home is on every task now")
    let back = try changeSet(of: store) { try store.createTask(NewTask(title: "Call the bank")) }
    _ = module.send(.changed(back))
    #expect(lit(in: module.model).isEmpty, "the pick was dropped")
    #expect(module.model == (try list(inbox, in: store).model))
}

/// A block's chevron folds it: its header stays and its rows go. The fold is the device's, kept under the list's key,
/// so a module made anew on the list draws it folded (spec section 2; ADR-0010).
@Test func aFoldHidesTheRowsAndIsReadBackByAModuleMadeAnew() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    try store.createTask(NewTask(title: "Call the bank", when: day(2)))
    let module = try list(upcoming, in: store)
    #expect(module.send(.action(.blockChevronTapped(.own(.day(day(1)))))) == nil)
    let folded = blocks(of: module.model)
    #expect(folded.map(\.isFolded) == [true, false])
    #expect(folded.map(\.rows.isEmpty) == [true, false])
    #expect(heading(of: folded[0]) == ["Tomorrow", "Thu, Sep 11"])
    #expect(try store.deviceState("taskList.folded.\(upcoming)", as: [String].self) == ["day/2025-09-11"])
    #expect(try list(upcoming, in: store).model == module.model)
    #expect(module.send(.action(.blockChevronTapped(.own(.day(day(1)))))) == nil)
    #expect(blocks(of: module.model).map(\.isFolded) == [false, false])
    #expect(try store.deviceState("taskList.folded.\(upcoming)", as: [String].self) == [])
}

/// The folds are the device's, so two windows of one device share them: a fold made in one is read by the other at its
/// next read of the page, which every change brings, and a fold the other makes then writes the set with the first
/// window's fold in it, as the sidebar's folds are (ADR-0010).
@Test func aFoldMadeInAnotherWindowIsReadAtTheNextReread() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    try store.createTask(NewTask(title: "Call the bank", when: day(2)))
    let first = try list(upcoming, in: store)
    let second = try list(upcoming, in: store)
    #expect(first.send(.action(.blockChevronTapped(.own(.day(day(1)))))) == nil)
    #expect(blocks(of: second.model).map(\.isFolded) == [false, false], "nothing read yet; this is the setup")
    let filed = try changeSet(of: store) { try store.createTask(NewTask(title: "Water the plants", when: day(3))) }
    #expect(second.send(.changed(filed)) == nil)
    #expect(second.model == (try list(upcoming, in: store).model))
    #expect(blocks(of: second.model).map(\.isFolded) == [true, false, false])
    #expect(second.send(.action(.blockChevronTapped(.own(.day(day(2)))))) == nil)
    #expect(
        try store.deviceState("taskList.folded.\(upcoming)", as: [String].self).map(Set.init)
            == ["day/2025-09-11", "day/2025-09-12"]
    )
}

/// A block is folded under its group's key whatever the grouping, a list inside under its view's, and the own block of
/// a list that groups by nothing has no header and nothing to fold (the controller's ruling on #175, 2026-11-04).
@Test func everyBlockFoldsUnderItsGroupsKey() throws {
    let store = try makeStore()
    let errand = try store.createTag(title: "errand")
    let byTag = try store.createView(NewTaskView(title: "By tag", filter: .status([.open]), groupBy: .tag))
    let inside = try store.createView(NewTaskView(title: "Inside", parent: byTag, filter: .when(.onOrAfter(365))))
    try store.createTask(NewTask(title: "Buy milk", tags: [errand]))
    try store.createTask(NewTask(title: "Write the plan"))
    let module = try list(byTag, in: store)
    for id in [TaskList.Model.BlockID.own(.tag(errand)), .own(.tag(nil)), .list(inside)] {
        _ = module.send(.action(.blockChevronTapped(id)))
    }
    #expect(Set(try store.deviceState("taskList.folded.\(byTag)", as: [String].self) ?? []) == ["tag/\(errand)", "tag/none", "view/\(inside)"])

    let byStatus = try store.createView(NewTaskView(title: "By status", filter: .status([.open]), groupBy: .status))
    _ = try list(byStatus, in: store).send(.action(.blockChevronTapped(.own(.status(.open)))))
    #expect(try store.deviceState("taskList.folded.\(byStatus)", as: [String].self) == ["status/open"])

    let plain = try list(inbox, in: store)
    let before = plain.model
    #expect(plain.send(.action(.blockChevronTapped(.own(nil)))) == nil)
    #expect(plain.model == before)
    #expect(try store.deviceState("taskList.folded.\(inbox)", as: [String].self) == nil)
}

/// Show as's choice is the list's on this device: a module made anew on the list opens in it, and another list keeps
/// its own (spec section 5; ADR-0010).
@Test func theLayoutIsKeptPerListOnThisDevice() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let module = try list(upcoming, in: store)
    #expect(isList(module.model))
    #expect(module.send(.action(.showAsChosen(.columns))) == nil)
    #expect(!isList(module.model))
    #expect(try store.deviceState("taskList.layout.\(upcoming)", as: TaskList.Model.Layout.Kind.self) == .columns)
    #expect(try list(upcoming, in: store).model == module.model)
    let projects = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    try store.createView(NewTaskView(title: "Inside", parent: projects, filter: .when(.onOrAfter(365))))
    #expect(isList(try list(projects, in: store).model))
    #expect(module.send(.action(.showAsChosen(.list))) == nil)
    #expect(isList(module.model))
    #expect(try store.deviceState("taskList.layout.\(upcoming)", as: TaskList.Model.Layout.Kind.self) == .list)
}

/// Columns do not fold: a block folded in the list is a column like any other, its cards drawn (spec section 5).
@Test func columnsIgnoreTheFolds() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let module = try list(upcoming, in: store)
    _ = module.send(.action(.blockChevronTapped(.own(.day(day(1))))))
    _ = module.send(.action(.showAsChosen(.columns)))
    let columns = blocks(of: module.model)
    #expect(columns.map(\.isFolded) == [false])
    #expect(columns.map(titles(of:)) == [["Buy milk"]])
    let before = module.model
    #expect(module.send(.action(.blockChevronTapped(.own(.day(day(1)))))) == nil, "a column has no chevron")
    #expect(module.model == before)
}

/// In columns every block is a column headed as its block is, with no chevron, and the block itself has no header;
/// the own block of a list that groups by nothing but has lists inside is a column titled with the list's own title,
/// whose title opens nothing (canvas, section 9; the controller's ruling on #175, 2026-11-04).
@Test func aColumnIsHeadedAsItsBlockWithNoChevron() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let inside = try store.createView(NewTaskView(title: "Inside", parent: projects, filter: .when(.onOrAfter(365))))
    let module = try list(projects, in: store)
    _ = module.send(.action(.showAsChosen(.columns)))
    let columns = blocks(of: module.model)
    #expect(columns.map(\.id) == [.own(nil), .list(inside)])
    #expect(columns.map { $0.header == nil } == [true, true])
    #expect(columns.map(heading(of:)) == [["Projects", nil], ["Inside", nil]])
    #expect(columns.map { $0.column?.header.fold == nil } == [true, true])
    #expect(columns.map { $0.column?.header.titleTapped } == [.blockTitleTapped(.own(nil)), .blockTitleTapped(.list(inside))])
    #expect(module.send(.action(.blockTitleTapped(.own(nil)))) == nil)
    #expect(module.destination.pushed == nil, "the list has no group to open")
    _ = module.send(.action(.showAsChosen(.list)))
    #expect(blocks(of: module.model).map { $0.column == nil } == [true, true], "one header per block, never two")
}

/// A list with one block and no grouping has no columns to show, and Show as says so under a disabled Columns: a
/// choice of it moves nothing and writes nothing (spec section 5; canvas).
@Test func showAsDisablesColumnsForAListWithOneBlock() throws {
    let store = try makeStore()
    let module = try list(inbox, in: store)
    let columns = try item(.columns, in: module.model)
    #expect(columns.isDisabled)
    #expect(columns.subtitle == "Group the list in its settings to get columns")
    #expect(try !item(.list, in: module.model).isDisabled)
    let before = module.model
    #expect(module.send(.action(.showAsChosen(.columns))) == nil)
    #expect(module.model == before)
    #expect(try store.deviceState("taskList.layout.\(inbox)", as: TaskList.Model.Layout.Kind.self) == nil)
    let grouped = try item(.columns, in: try list(upcoming, in: store).model)
    #expect(!grouped.isDisabled)
    #expect(grouped.subtitle == nil)
}

/// A list inside's title opens that list over this one, as itself (spec section 2): the list declares it, the stack
/// pushes it.
@Test func aBlockTitleOpensTheListInside() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let house = try store.createView(NewTaskView(title: "House", parent: projects, filter: .when(.onOrAfter(365))))
    let module = try list(projects, in: store)
    #expect(module.send(.action(.blockTitleTapped(.list(house)))) == nil)
    #expect(module.destination.pushed == .list(TaskList.Route(head: .init(view: house))))
    #expect(module.route == TaskList.Route(head: .init(view: projects), tail: .list(TaskList.Route(head: .init(view: house)))))
    let before = module.model
    #expect(module.send(.action(.blockTitleTapped(.list(ViewID())))) == nil, "a block the list does not hold")
    #expect(module.model == before)
    #expect(module.destination.pushed == .list(TaskList.Route(head: .init(view: house))))
}

/// A day block's title opens its group over the list, addressed by the list and the group's distance from today, the
/// deadline's word for a list grouped by deadline, and nothing is written (spec section 2; ADR-0009, amendment of
/// 2026-11-02). On the group's screen the one block has no title, and a tap sent anyway opens nothing.
@Test func aDayBlocksTitleOpensItsGroupOverTheListAndWritesNothing() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Call the bank", when: day(3), deadline: day(5)))
    let written = try store.journal(after: 0).count
    let module = try list(upcoming, in: store)
    #expect(module.send(.action(.blockTitleTapped(.own(.day(day(3)))))) == nil)
    #expect(module.destination.pushed == .list(screen(.day(3), of: upcoming)))
    #expect(try store.journal(after: 0).count == written)
    let byDeadline = try store.createView(NewTaskView(title: "Due", filter: .status([.open]), groupBy: .deadlineDay))
    let due = try list(byDeadline, in: store)
    _ = due.send(.action(.blockTitleTapped(.own(.day(day(5))))))
    #expect(due.destination.pushed == .list(screen(.deadline(5), of: byDeadline)))
    let group = try list(screen(.day(3), of: upcoming), in: store)
    #expect(blocks(of: group.model).map(\.header) == [nil])
    #expect(group.send(.action(.blockTitleTapped(.own(.day(day(3)))))) == nil)
    #expect(group.destination.pushed == nil)
}

/// A group's screen is exactly the block it was opened from: the list's page, its own section's group of the key, so
/// a task a list inside claims is left out as it is from the block (ADR-0004, amendment of 2026-11-02).
@Test func aGroupsScreenIsExactlyItsBlock() throws {
    let store = try makeStore()
    let (week, _, errand) = try week(in: store)
    try store.createTask(NewTask(title: "Buy milk", when: day(1), tags: [errand]))
    try store.createTask(NewTask(title: "Write the plan", when: day(1)))
    try store.createTask(NewTask(title: "Call the bank", when: day(2)))
    let block = try #require(blocks(of: try list(week, in: store).model).first { $0.id == .own(.day(day(1))) })
    let model = try list(screen(.day(1), of: week), in: store).model
    #expect(ids(of: model) == [.own(.day(day(1)))])
    #expect(titles(of: model) == [titles(of: block)])
    #expect(titles(of: model) == [["Write the plan"]])
}

/// A group's screen is one block with no header, has no lists inside and no columns to offer: Show as's Columns is
/// disabled with the reason the canvas gives, and a choice of it moves nothing, whatever the list keeps for itself
/// (the controller's rulings on #175, 2026-11-04).
@Test func aGroupsScreenIsOneBlockWithNoColumnsAndNoAddList() throws {
    let store = try makeStore()
    let (week, _, _) = try week(in: store)
    try store.createTask(NewTask(title: "Write the plan", when: day(1)))
    _ = try list(week, in: store).send(.action(.showAsChosen(.columns)))
    let module = try list(screen(.day(1), of: week), in: store)
    #expect(isList(module.model), "the list's columns are the list's")
    #expect(blocks(of: module.model).map(\.header) == [nil])
    let columns = try item(.columns, in: module.model)
    #expect(columns.isDisabled)
    #expect(columns.subtitle == "Group the list in its settings to get columns")
    let before = module.model
    #expect(module.send(.action(.showAsChosen(.columns))) == nil)
    #expect(module.model == before)
}

/// A group's key is a distance from today, so a new day moves its screen onto the new day's group, as Today's
/// address reads as the new day (spec section 2).
@Test func aGroupsScreenFollowsTheDay() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    try store.createTask(NewTask(title: "Call the bank", when: day(2)))
    let module = try list(screen(.day(1), of: upcoming), in: store)
    #expect(titles(of: module.model) == [["Buy milk"]])
    let next = deviceDay(day(1))
    #expect(module.send(.dayChanged(next)) == nil)
    #expect(titles(of: module.model) == [["Call the bank"]])
    #expect(ids(of: module.model) == [.own(.day(day(2)))])
    #expect(module.model == (try list(screen(.day(1), of: upcoming), in: store, on: next).model))
}

/// A group's screen is titled by the day the distance falls on today, with the list's title and that day's date under
/// it, as the block's header was; the group with no day is "No date" under the list's title (spec section 2; canvas).
@Test func aGroupsScreenIsTitledByTheDayWithItsListAndDateUnder() throws {
    let store = try makeStore()
    let cases: [(TaskList.Route.Group, String, String)] = [
        (.day(0), "Today", "Upcoming · Wed, Sep 10"), (.day(1), "Tomorrow", "Upcoming · Thu, Sep 11"),
        (.day(5), "Monday", "Upcoming · Sep 15"), (.day(nil), "No date", "Upcoming"),
    ]
    for (group, title, subtitle) in cases {
        let header = try list(screen(group, of: upcoming), in: store).model.header
        #expect(header.title.text == title)
        #expect(header.subtitle?.text == subtitle)
        #expect(header.tile.style.color == .rose, "the list's tile")
    }
}

/// A group whose word is not its list's grouping names nothing, so its screen is not made: the list stays open and
/// says why (ADR-0009, amendment of 2026-11-02).
@Test func aGroupWhoseWordIsNotTheListsGroupingIsNotOpened() throws {
    let store = try makeStore()
    #expect(throws: StoreError.self) { try list(screen(.deadline(1), of: upcoming), in: store) }
    do {
        _ = try TaskList(store: store, route: screen(.day(1), of: inbox), day: testDay)
        Issue.record("the Inbox groups by nothing")
    } catch {
        guard case .invalid = error else { Issue.record("refused with \(error)"); return }
    }
    let upcomingList = try list(upcoming, in: store)
    _ = upcomingList.send(.route(TaskList.Route(head: .init(view: upcoming), tail: .list(screen(.deadline(1), of: upcoming)))))
    _ = upcomingList.send(.notOpened(.invalid("not grouped by deadline"), stillOpen: nil))
    #expect(upcomingList.model.problem == "This list is not grouped that way, so the group could not be opened.")
}

/// A group of a tag or of a parent that is gone names nothing, and its screen is not made, with the id it looked for.
@Test func aGroupOfATagThatIsGoneIsNotOpened() throws {
    let store = try makeStore()
    let gone = try store.createTag(title: "gone")
    try store.delete(tag: gone)
    let byTag = try store.createView(NewTaskView(title: "By tag", filter: .status([.open]), groupBy: .tag))
    #expect(throws: StoreError.notFound(gone)) { try list(screen(.tag(gone), of: byTag), in: store) }
    #expect(try list(screen(.tag(nil), of: byTag), in: store).model.header.title.text == "No tag")
    let byParent = try store.createView(NewTaskView(title: "By parent", filter: .status([.open]), groupBy: .parent))
    let missing = TaskID()
    #expect(throws: StoreError.notFound(missing)) { try list(screen(.parent(missing), of: byParent), in: store) }
}

/// A live group's screen whose group stops naming anything, its tag deleted or its list grouped another way, asks to
/// be closed, as a list whose view is gone does (the controller's ruling on #175, 2026-11-04).
@Test func aGroupWhoseTagIsDeletedAsksToClose() throws {
    let store = try makeStore()
    let errand = try store.createTag(title: "errand")
    let byTag = try store.createView(NewTaskView(title: "By tag", filter: .status([.open]), groupBy: .tag))
    try store.createTask(NewTask(title: "Buy milk", tags: [errand]))
    let module = try list(screen(.tag(errand), of: byTag), in: store)
    #expect(module.model.header.title.text == "errand")
    let deleted = try changeSet(of: store) { try store.delete(tag: errand) }
    #expect(module.send(.changed(deleted)) == .closeRequested)
    let regrouped = try list(screen(.tag(nil), of: byTag), in: store)
    let changed = try changeSet(of: store) { try store.update(view: byTag, [.groupBy(.status)]) }
    #expect(regrouped.send(.changed(changed)) == .closeRequested)
}

/// A list's subtitle is the date of the one day its rule's When condition gives when that condition is on a day or
/// on or before one, Today's date; a list whose rule gives no such day has none (spec section 1).
@Test func todaysSubtitleIsItsDateAndUpcomingHasNone() throws {
    let store = try makeStore()
    #expect(try list(BuiltInTaskViews.today, in: store).model.header.subtitle?.text == "Wednesday, September 10")
    #expect(try list(upcoming, in: store).model.header.subtitle == nil)
    #expect(try list(inbox, in: store).model.header.subtitle == nil)
    let friday = try store.createView(NewTaskView(title: "Friday", filter: .when(.on(2))))
    #expect(try list(friday, in: store).model.header.subtitle?.text == "Friday, September 12")
    #expect(try list(friday, in: store).model.header.title.text == "Friday")
}

/// A new day rereads the page, since which tasks a list holds, and which day each block is, can depend on the day: the
/// list is the one made on the new day.
@Test func aNewDayRereadsThePage() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    try store.createTask(NewTask(title: "Call the bank", when: day(2)))
    let module = try list(upcoming, in: store)
    #expect(blocks(of: module.model).map(heading(of:)) == [["Tomorrow", "Thu, Sep 11"], ["Friday", "Sep 12"]])
    let next = deviceDay(day(1))
    #expect(module.send(.dayChanged(next)) == nil)
    #expect(module.model == (try list(upcoming, in: store, on: next).model))
    #expect(blocks(of: module.model).map(heading(of:)) == [["Tomorrow", "Fri, Sep 12"]])
}

/// A change to a list inside, its title or its rule, and a list made inside, each name that list alone, and the page
/// is read again for them (spec section 2).
@Test func aChangeToAListInsideRereadsThePage() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let house = try store.createView(NewTaskView(title: "House", parent: projects, filter: .when(.onOrAfter(365))))
    let module = try list(projects, in: store)
    let renamed = try changeSet(of: store) { try store.update(view: house, [.title("Home")]) }
    #expect(module.send(.changed(renamed)) == nil)
    #expect(heading(of: blocks(of: module.model)[1]) == ["Home", nil])
    let made = try changeSet(of: store) { try store.createView(NewTaskView(title: "Garden", parent: projects)) }
    #expect(module.send(.changed(made)) == nil)
    #expect(module.model == (try list(projects, in: store).model))
    #expect(blocks(of: module.model).count == 3)
}

/// The empty state stands when no block has a row, after the tag bar's filter, and the page has no lists inside, a
/// group's screen included; it says what the list is, in the list's own tile (canvas, section 1; the controller's
/// ruling on #175, 2026-11-04).
@Test func theEmptyStateSaysWhatTheListIs() throws {
    let store = try makeStore()
    let errand = try store.createTag(title: "errand")
    let folder = try store.createView(NewTaskView(title: "Folder"))
    let manual = try store.createManualList("Shopping", in: folder, color: .green)
    let tagged = try store.createView(NewTaskView(title: "Errands", filter: .hasTag(errand)))
    let lonely = try store.createView(NewTaskView(title: "New list"))
    let rule = "Tasks that match this list’s rule will show up here."
    let cases: [(TaskList.Route, String, String)] = [
        (TaskList.Route(head: .init(view: BuiltInTaskViews.trash)), "Trash is empty", "Deleted tasks wait here until you empty it."),
        (TaskList.Route(head: .init(view: BuiltInTaskViews.logbook)), "Nothing done yet", rule),
        (TaskList.Route(head: .init(view: manual)), "Nothing here yet", "Add a task here, or drag one in."),
        (TaskList.Route(head: .init(view: lonely)), "A new list", "Put lists inside it, or give it a rule here."),
        (TaskList.Route(head: .init(view: tagged)), "Nothing here yet", "Tasks tagged #errand will show up here."),
        (TaskList.Route(head: .init(view: inbox)), "Nothing here yet", rule),
        (screen(.day(1), of: upcoming), "Nothing here yet", rule),
    ]
    for (route, title, text) in cases {
        let empty = try #require(try list(route, in: store).model.empty, "\(route)")
        #expect(empty.title.text == title)
        #expect(empty.text.text == text)
    }
    #expect(try list(folder, in: store).model.empty == nil, "a list inside is a block to add into")
    let trash = try #require(try list(BuiltInTaskViews.trash, in: store).model.empty)
    #expect(trash.tile.style.color == .stone)
    #expect(trash.tile.icon == .trash)
    try store.createTask(NewTask(title: "Buy milk", tags: [errand]))
    #expect(try list(inbox, in: store).model.empty == nil)
    #expect(try list(tagged, in: store).model.empty == nil)
}
