import Testing
import TestSupport
import DesignSystemComponents
import FeatureModule
import TaskListFeature
import TaskScreenFeature
import TodoCore

// The module's writes other than the card and the drop (spec sections 3, 4 and 6): adding a task, adding a list, the
// check and the Done strip, the swipe and the menu's Delete, each through `TaskList`, read back from the store and the
// model.

private let inbox = BuiltInTaskViews.inbox

/// A list with a tag and a week's days for a rule, grouped by its days, which stands for any list with a rule and a
/// grouping (spec section 2).
private func thisWeek(_ store: Store, tag: TagID) throws -> ViewID {
    try store.createView(NewTaskView(
        title: "This week", color: .indigo, filter: .and([.status([.open]), .hasTag(tag), .when(.between(0, 6))]),
        sort: [SortKey(.when)], groupBy: .whenDay
    ))
}

// MARK: - Adding a task

@Test func theFloatingPlusAddsAnEmptyTaskAtTheTopOfTheFirstBlockWithItsCardOpen() throws {
    let store = try makeStore()
    let old = try store.createTask(NewTask(title: "Buy milk"))
    let module = try list(inbox, in: store)
    module.tap(.addTaskButtonTapped)
    let opened = try #require(openCard(in: module.model))
    #expect(rows(of: module.model).map(\.id) == [opened.id, old])
    #expect(opened.card.title.text == "")
    let task = try stored(opened.id, in: store)
    #expect(task.title == "" && task.when == nil && task.status == .open && task.parent == nil)
}

/// "+ Add task" gives a new task what its block's rule asks, a day block's day and the rule's tag, and adds it at the
/// block's end, closing the card that was open.
@Test func addTaskAtABlocksEndTakesTheBlocksEdits() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let week = try thisWeek(store, tag: work)
    let first = try store.createTask(NewTask(title: "Standup", when: day(2), tags: [work]))
    let other = try store.createTask(NewTask(title: "Review", when: day(1), tags: [work]))
    let module = try list(week, in: store)
    module.tap(.rowTapped(other))
    module.tap(.titleFieldChanged("Review the plan"))
    let block = TaskList.Model.BlockID.own(.day(day(2)))
    module.tap(.addTaskRowTapped(in: block))
    #expect(try stored(other, in: store).title == "Review the plan", "the other card closed first")
    let opened = try #require(openCard(in: module.model))
    let task = try stored(opened.id, in: store)
    #expect(task.when == day(2) && task.tags == [work])
    #expect(rowIDs(of: block, in: module.model) == [first, opened.id])
}

@Test func aPickedTagGoesOnANewTask() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    try store.createTask(NewTask(title: "Buy milk"))
    let module = try list(inbox, in: store)
    module.tap(.tagChipTapped(home))
    module.tap(.addTaskRowTapped(in: .own(nil)))
    let opened = try #require(openCard(in: module.model))
    #expect(try stored(opened.id, in: store).tags == [home], "so the filter shows it")
}

@Test func aNewTaskInAManualListIsPinnedLast() throws {
    let store = try makeStore()
    let parent = try store.createView(NewTaskView(title: "Projects"))
    let manual = try store.createManualList("Errands", in: parent, color: .teal)
    let old = try store.createTask(NewTask(title: "Post the letter"))
    try store.pin(task: old, in: manual)
    let module = try list(manual, in: store)
    module.tap(.addTaskRowTapped(in: .own(nil)))
    let opened = try #require(openCard(in: module.model))
    #expect(try store.manualList(of: manual) == [old, opened.id])
    #expect(rows(of: module.model).map(\.id) == [old, opened.id])
    module.tap(.addTaskButtonTapped)
    let top = try #require(openCard(in: module.model))
    #expect(try store.manualList(of: manual).first == top.id, "the floating \"+\" pins it first")
    #expect(try store.task(opened.id) == nil, "the untitled card before it closed")
}

/// A pinned task stands above an unpinned one, so the floating "+" pins a new task first in a list with pins, whose
/// rule does not, to land at the top of the block; "+ Add task" does not, the end being the end (the controller's
/// ruling on #176, 2026-11-05).
@Test func theFloatingPlusOnAListWithPinsLandsAtTheTop() throws {
    let store = try makeStore()
    let pinned = try store.createTask(NewTask(title: "Pinned"))
    let loose = try store.createTask(NewTask(title: "Loose"))
    try store.pin(task: pinned, in: inbox)
    let module = try list(inbox, in: store)
    module.tap(.addTaskButtonTapped)
    let opened = try #require(openCard(in: module.model))
    #expect(try store.manualList(of: inbox) == [opened.id, pinned])
    #expect(rows(of: module.model).map(\.id) == [opened.id, pinned, loose])
    module.tap(.backgroundTapped)
    module.tap(.addTaskRowTapped(in: .own(nil)))
    let last = try #require(openCard(in: module.model))
    #expect(try store.manualList(of: inbox) == [pinned], "the first went with its card")
    #expect(rows(of: module.model).map(\.id) == [pinned, loose, last.id])
}

/// A list that orders by anything but rank puts a task where its sort says, so the floating "+" pins a new task first
/// to land it at the top of the block, above a task overdue on Today (spec section 4; the controller's ruling on #176,
/// 2026-11-05).
@Test func theFloatingPlusOnTodayLandsAboveAnOverdueTask() throws {
    let store = try makeStore()
    let overdue = try store.createTask(NewTask(title: "Late", when: day(-1)))
    let module = try list(BuiltInTaskViews.today, in: store)
    module.tap(.addTaskButtonTapped)
    let opened = try #require(openCard(in: module.model))
    #expect(rows(of: module.model).map(\.id) == [opened.id, overdue])
    #expect(try store.manualList(of: BuiltInTaskViews.today) == [opened.id])
    let descending = try store.createView(NewTaskView(
        title: "Newest ranks first", filter: .status([.open]), sort: [SortKey(.rank, descending: true)]
    ))
    let onDescending = try list(descending, in: store)
    onDescending.tap(.addTaskButtonTapped)
    let onTop = try #require(openCard(in: onDescending.model))
    #expect(rows(of: onDescending.model).first?.id == onTop.id, "a descending rank puts the lowest last")
    #expect(try store.manualList(of: descending) == [onTop.id])
}

/// A list ordered by rank with no pins has the new task at the top by its rank alone, and takes no pin, which would put
/// the `.start` tasks quick entry and the command line write under it. An empty sort orders by rank too
/// (`FilterCompiler.orderBy`).
@Test func theFloatingPlusOnARankOrderedListWritesNoPin() throws {
    let store = try makeStore()
    let old = try store.createTask(NewTask(title: "Buy milk"))
    let module = try list(inbox, in: store)
    module.tap(.addTaskButtonTapped)
    let opened = try #require(openCard(in: module.model))
    #expect(rows(of: module.model).map(\.id) == [opened.id, old])
    #expect(try store.manualList(of: inbox).isEmpty)
    module.tap(.backgroundTapped)
    let unsorted = try store.createView(NewTaskView(title: "No sort", filter: .status([.open])))
    let onUnsorted = try list(unsorted, in: store)
    onUnsorted.tap(.addTaskButtonTapped)
    let onTop = try #require(openCard(in: onUnsorted.model))
    #expect(rows(of: onUnsorted.model).first?.id == onTop.id)
    #expect(try store.manualList(of: unsorted).isEmpty)
}

/// A grouped list with no tasks has no block, and its floating "+" takes the rule's edit (the controller's ruling on
/// #176, 2026-11-05).
@Test func theFloatingPlusOnAnEmptyGroupedListTakesTheRulesEdits() throws {
    let store = try makeStore()
    let module = try list(BuiltInTaskViews.upcoming, in: store)
    #expect(blocks(of: module.model).isEmpty)
    module.tap(.addTaskButtonTapped)
    let opened = try #require(openCard(in: module.model))
    #expect(try stored(opened.id, in: store).when == day(1), "tomorrow")
    #expect(blocks(of: module.model).map(\.id) == [.own(.day(day(1)))])
}

@Test func theFloatingPlusUnfoldsItsBlock() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let module = try list(BuiltInTaskViews.upcoming, in: store)
    let id = TaskList.Model.BlockID.own(.day(day(1)))
    module.tap(.blockChevronTapped(id))
    #expect(block(id, of: module.model)?.isFolded == true)
    module.tap(.addTaskButtonTapped)
    #expect(block(id, of: module.model)?.isFolded == false)
    #expect(openCard(in: module.model) != nil)
    #expect(block(id, of: try list(BuiltInTaskViews.upcoming, in: store).model)?.isFolded == false, "the device keeps it")
}

/// Columns do not fold (spec section 5), so a task added on the board leaves the fold the list keeps for that block
/// (the controller's ruling on #176, 2026-11-05).
@Test func addingInAColumnKeepsTheListsFold() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let module = try list(BuiltInTaskViews.upcoming, in: store)
    let id = TaskList.Model.BlockID.own(.day(day(1)))
    module.tap(.blockChevronTapped(id))
    module.tap(.showAsChosen(.columns))
    module.tap(.addTaskRowTapped(in: id))
    #expect(openCard(in: module.model) != nil)
    module.tap(.backgroundTapped)
    module.tap(.showAsChosen(.list))
    #expect(block(id, of: module.model)?.isFolded == true)
}

/// A folded block has no "+ Add task" (canvas), and one sent for it adds nothing.
@Test func aFoldedBlockHasNoAddRow() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let module = try list(BuiltInTaskViews.upcoming, in: store)
    let id = TaskList.Model.BlockID.own(.day(day(1)))
    #expect(block(id, of: module.model)?.addTask != nil)
    module.tap(.blockChevronTapped(id))
    #expect(block(id, of: module.model)?.addTask == nil)
    #expect(commits(of: store) { module.tap(.addTaskRowTapped(in: id)) } == 0)
}

/// A rule read as no edit has no "+ Add task" and no floating "+", which is how Logbook and Trash have none, and
/// neither has a list inside that this app cannot read, which reads as no rule and is no folder (spec section 4).
@Test func aListThatRefusesHasNoWayToAdd() throws {
    let store = try makeStore()
    for view in [BuiltInTaskViews.logbook, BuiltInTaskViews.trash] {
        let module = try list(view, in: store)
        #expect(module.model.addTask == nil)
        #expect(commits(of: store) { module.tap(.addTaskButtonTapped) } == 0)
    }
    let parent = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let either = try store.createView(NewTaskView(title: "Either", parent: parent, filter: .or([.when(.on(0)), .when(.on(1))])))
    let model = try list(parent, in: store).model
    #expect(block(.list(either), of: model)?.addTask == nil)
    #expect(block(.own(nil), of: model)?.addTask != nil)
}

@Test func aFoldersEditsAreItsFirstLists() throws {
    let store = try makeStore()
    let tag = try store.createTag(title: "first")
    let parent = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let folder = try store.createView(NewTaskView(title: "Folder", parent: parent))
    let empty = try store.createView(NewTaskView(title: "Empty", parent: parent))
    let inner = try store.createView(NewTaskView(title: "Inner", parent: folder))
    try store.createView(NewTaskView(title: "First", parent: inner, filter: .hasTag(tag)))
    try store.createView(NewTaskView(title: "Second", parent: folder, filter: .hasTag(try store.createTag(title: "second"))))
    let module = try list(parent, in: store)
    #expect(block(.list(empty), of: module.model)?.addTask == nil, "a folder with no lists has none")
    #expect(block(.list(empty), of: module.model)?.takesDrop == false)
    module.tap(.addTaskRowTapped(in: .list(folder)))
    let opened = try #require(openCard(in: module.model))
    #expect(try stored(opened.id, in: store).tags == [tag], "through a folder inside it, to any depth")
    let onFolder = try list(folder, in: store)
    onFolder.tap(.addTaskButtonTapped)
    let added = try #require(openCard(in: onFolder.model))
    #expect(try stored(added.id, in: store).tags == [tag], "a folder hands its \"+\" to its first list")
    #expect(try list(empty, in: store).model.addTask == nil)
}

/// A list grouped by a deadline's day gives a new task the block's day as its deadline, and what the rule's When gives
/// as its When (the controller's ruling on #176, 2026-11-05).
@Test func aDeadlineDayBlockGivesItsDeadline() throws {
    let store = try makeStore()
    let due = try store.createView(NewTaskView(
        title: "Due", filter: .and([.status([.open]), .when(.onOrBefore(0))]), sort: [SortKey(.deadline)], groupBy: .deadlineDay
    ))
    try store.createTask(NewTask(title: "Pay", when: day(0), deadline: day(2)))
    let module = try list(due, in: store)
    module.tap(.addTaskRowTapped(in: .own(.day(day(2)))))
    let opened = try #require(openCard(in: module.model))
    let task = try stored(opened.id, in: store)
    #expect(task.deadline == day(2) && task.when == day(0))
}

/// An own block of a grouping by tag, parent or status has no one field to set: no "+ Add task", no drop, no reorder.
/// The list's floating "+" takes the rule's edit, and its group's screen has none (the controller's ruling on #176,
/// 2026-11-05).
@Test func aListThatGroupsByTagHasNoEditsOnItsBlocks() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let byTag = try store.createView(NewTaskView(title: "By tag", filter: .status([.open]), groupBy: .tag))
    let first = try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    let second = try store.createTask(NewTask(title: "Fix the sink", tags: [home]))
    let module = try list(byTag, in: store)
    let id = TaskList.Model.BlockID.own(.tag(home))
    #expect(block(id, of: module.model)?.addTask == nil)
    #expect(block(id, of: module.model)?.takesDrop == false)
    #expect(commits(of: store) { module.tap(.rowDropped(second, from: id, in: id, after: nil)) } == 0)
    #expect(rowIDs(of: id, in: module.model) == [first, second])
    module.tap(.addTaskButtonTapped)
    let opened = try #require(openCard(in: module.model))
    #expect(try stored(opened.id, in: store).tags == [])
    module.tap(.backgroundTapped)
    let group = try list(TaskList.Route(head: .init(view: byTag, group: .tag(home))), in: store)
    #expect(group.model.addTask == nil)
    #expect(blocks(of: group.model).first?.addTask == nil)
}

/// A new task that lands in no block of the screen is not left behind untitled where nothing draws it: its card closes
/// as it was drawn, by the rule of every close.
@Test func aNewTaskThatDoesNotLandIsNotLeftBehind() throws {
    let store = try makeStore()
    let overdue = try store.createView(NewTaskView(
        title: "Overdue", filter: .and([.status([.open]), .when(.onOrBefore(-1))]), sort: [SortKey(.when)], groupBy: .whenDay
    ))
    let group = try list(TaskList.Route(head: .init(view: overdue, group: .day(3))), in: store)
    group.tap(.addTaskButtonTapped)
    #expect(openCard(in: group.model) == nil)
    #expect(try store.allTasks().isEmpty)
}

// MARK: - A group's screen

/// A group's "+" and its block's "+ Add task" give what that block's "+ Add task" gives on the list's screen: the
/// list's edit with the group's day (spec section 2).
@Test func aGroupsScreenAddsWhatItsBlockAdds() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let week = try thisWeek(store, tag: work)
    try store.createTask(NewTask(title: "Standup", when: day(2), tags: [work]))
    let module = try list(TaskList.Route(head: .init(view: week, group: .day(2))), in: store)
    #expect(module.model.addList == nil, "a group holds no lists")
    module.tap(.addTaskButtonTapped)
    let floated = try #require(openCard(in: module.model))
    #expect(try stored(floated.id, in: store).when == day(2))
    #expect(try stored(floated.id, in: store).tags == [work])
    module.tap(.titleFieldChanged("Plan"))
    module.tap(.addTaskRowTapped(in: .own(.day(day(2)))))
    let added = try #require(openCard(in: module.model))
    #expect(try stored(added.id, in: store).when == day(2))
    #expect(try stored(added.id, in: store).tags == [work])
    #expect(rows(of: module.model).last?.id == added.id)
}

/// A group's strip is the list's kept to the tasks the list's grouping puts under the group, by the page's own rule
/// (spec section 2; `GroupKey(of:by:)`).
@Test func aGroupsStripIsTheListsKeptToTheGroup() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let week = try thisWeek(store, tag: work)
    let kept = try store.createTask(NewTask(title: "Kept", when: day(2), tags: [work]))
    let other = try store.createTask(NewTask(title: "Other", when: day(3), tags: [work]))
    try store.update(task: kept, [.status(.done)])
    try store.update(task: other, [.status(.done)])
    #expect(try list(week, in: store).model.done?.label.text == "Done today · 2")
    let module = try list(TaskList.Route(head: .init(view: week, group: .day(2))), in: store)
    #expect(module.model.done?.label.text == "Done today · 1")
    module.tap(.doneStripTapped)
    #expect(module.model.doneRows.map(\.id) == [kept])
}

// MARK: - The check and the Done strip

@Test func aCheckCompletesAndTheRowLeavesTheRows() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let other = try store.createTask(NewTask(title: "Call the bank"))
    let module = try list(inbox, in: store)
    let today = try list(BuiltInTaskViews.today, in: store)
    module.tap(.checkTapped(id))
    #expect(try stored(id, in: store).status == .done)
    #expect(rows(of: module.model).map(\.id) == [other], "no pause in which a done task stays among the rows")
    #expect(module.model == (try list(inbox, in: store).model))
    #expect(commits(of: store) { today.tap(.checkTapped(other)) } == 0, "a row the list does not draw")
}

/// The strip holds the tasks completed today that the page's rules select with their status lifted: the list's own and
/// the rules of the lists inside it, newest first (spec section 3).
@Test func theStripHoldsWhatThePagesRulesCompletedToday() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let work = try store.createTag(title: "work")
    let parent = try store.createView(NewTaskView(title: "Projects", filter: .and([.status([.open]), .hasTag(work)])))
    try store.createView(NewTaskView(title: "House", parent: parent, filter: .and([.status([.open]), .hasTag(home)])))
    let own = try store.createTask(NewTask(title: "Own", tags: [work]))
    let inside = try store.createTask(NewTask(title: "Inside", tags: [home]))
    let outside = try store.createTask(NewTask(title: "Outside"))
    let module = try list(parent, in: store)
    #expect(module.model.done == nil)
    for id in [own, inside, outside] { try store.update(task: id, [.status(.done)]) }
    let changed = try changeSet(of: store) { try store.update(task: own, [.title("Own task")]) }
    #expect(module.send(.changed(changed)) == nil)
    #expect(module.model.done?.label.text == "Done today · 2")
    #expect(module.model.doneRows.isEmpty, "closed")
    module.tap(.doneStripTapped)
    #expect(module.model.doneRows.map(\.id) == [inside, own])
    module.tap(.doneStripTapped)
    #expect(module.model.doneRows.isEmpty)
}

@Test func theStripIsNilForLogbookTrashAndNothingDone() throws {
    let store = try makeStore()
    let done = try store.createTask(NewTask(title: "Filed"))
    try store.update(task: done, [.status(.done)])
    let binned = try store.createTask(NewTask(title: "Binned"))
    try store.trash(task: binned)
    let upcoming = try list(BuiltInTaskViews.upcoming, in: store)
    #expect(upcoming.model.done == nil, "nothing done there")
    upcoming.tap(.doneStripTapped)
    #expect(upcoming.model.doneRows.isEmpty, "there is no strip to open")
    #expect(try list(BuiltInTaskViews.logbook, in: store).model.done == nil)
    #expect(try list(BuiltInTaskViews.trash, in: store).model.done == nil)
    #expect(try list(BuiltInTaskViews.logbook, in: store).model.addList == nil)
    #expect(try list(BuiltInTaskViews.trash, in: store).model.addList == nil)
}

/// The strip's own check reopens a task, which leaves the strip and returns to the block the page puts it in (spec
/// section 3).
@Test func aStripRowsCheckReopensTheTask() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let module = try list(inbox, in: store)
    module.tap(.checkTapped(id))
    module.tap(.doneStripTapped)
    #expect(module.model.doneRows.map(\.id) == [id])
    #expect(rows(of: module.model).isEmpty)
    module.tap(.checkTapped(id))
    #expect(try stored(id, in: store).status == .open)
    #expect(module.model.doneRows.isEmpty)
    #expect(module.model.done == nil)
    #expect(rows(of: module.model).map(\.id) == [id])
}

@Test func aNewDayEmptiesTheStrip() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let module = try list(inbox, in: store)
    module.tap(.checkTapped(id))
    #expect(module.model.done?.label.text == "Done today · 1")
    let nextDay = deviceDay(day(1))
    #expect(module.send(.dayChanged(nextDay)) == nil)
    #expect(module.model.done == nil)
    #expect(module.model == (try list(inbox, in: store, on: nextDay).model))
}

/// A tap on a row of the strip opens its card under the capsule, like any row's (spec section 3, over the canvas's full
/// screen; the controller's ruling on #176, 2026-11-05); closing the strip closes the card by the rule of every close.
@Test func aCardOpensFromAStripRow() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let other = try store.createTask(NewTask(title: "Post the letter"))
    let module = try list(inbox, in: store)
    module.tap(.checkTapped(id))
    module.tap(.checkTapped(other))
    module.tap(.rowTapped(id))
    #expect(openCard(in: module.model) == nil, "the strip is closed, so that row is not drawn")
    module.tap(.doneStripTapped)
    module.tap(.rowTapped(id))
    #expect(openCard(in: module.model)?.id == id)
    #expect(module.model.doneRows.map(\.id) == [other, id], "in its place")
    module.tap(.titleFieldChanged("Buy oat milk"))
    module.tap(.doneStripTapped)
    #expect(openCard(in: module.model) == nil)
    #expect(try stored(id, in: store).title == "Buy oat milk")
}

@Test func aCardOpensFromALogbookRow() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Filed"))
    try store.update(task: id, [.status(.done)])
    let module = try list(BuiltInTaskViews.logbook, in: store)
    module.tap(.rowTapped(id))
    let opened = try #require(openCard(in: module.model))
    #expect(opened.id == id)
    #expect(opened.card.check.isChecked)
    #expect(opened.card.title.color == .ink2)
    module.tap(.checkTapped(id))
    #expect(try stored(id, in: store).status == .open)
    #expect(openCard(in: module.model) == nil, "the task left the Logbook")
}

/// The board has no strip (canvas; the controller's ruling on #176, 2026-11-05), and a card under the strip closes when
/// the layout changes.
@Test func theStripIsNilInColumns() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    try store.createTask(NewTask(title: "Call the bank", when: day(1)))
    let module = try list(BuiltInTaskViews.upcoming, in: store)
    module.tap(.checkTapped(id))
    module.tap(.doneStripTapped)
    module.tap(.rowTapped(id))
    module.tap(.titleFieldChanged("Buy oat milk"))
    #expect(module.model.done != nil)
    module.tap(.showAsChosen(.columns))
    #expect(module.model.done == nil)
    #expect(module.model.doneRows.isEmpty)
    #expect(openCard(in: module.model) == nil)
    #expect(try stored(id, in: store).title == "Buy oat milk")
}

/// N counts what the tag bar's filter leaves, and a filter that leaves nothing leaves no strip (the controller's ruling
/// on #176, 2026-11-05).
@Test func theStripCountsWhatThePicksLeave() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let work = try store.createTag(title: "work")
    let first = try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    let second = try store.createTask(NewTask(title: "Send the plan", tags: [work]))
    try store.createTask(NewTask(title: "Fix the sink", tags: [home]))
    try store.createTask(NewTask(title: "Read the plan", tags: [work]))
    let module = try list(inbox, in: store)
    module.tap(.checkTapped(first))
    module.tap(.checkTapped(second))
    #expect(module.model.done?.label.text == "Done today · 2")
    module.tap(.tagChipTapped(home))
    #expect(module.model.done?.label.text == "Done today · 1")
    module.tap(.doneStripTapped)
    #expect(module.model.doneRows.map(\.id) == [first])
    module.tap(.checkTapped(first))
    #expect(module.model.done == nil, "nothing done under the pick")
}

/// A manual list's rule names no status, and its rows are its open tasks all the same, its done ones the strip's (spec
/// section 3; the controller's ruling on #176, 2026-11-05).
@Test func aManualListDrawsNoDoneTask() throws {
    let store = try makeStore()
    let parent = try store.createView(NewTaskView(title: "Projects"))
    let manual = try store.createManualList("Errands", in: parent, color: .teal)
    let open = try store.createTask(NewTask(title: "Open"))
    let done = try store.createTask(NewTask(title: "Done"))
    try store.pin(task: open, in: manual)
    try store.pin(task: done, in: manual)
    try store.update(task: done, [.status(.done)])
    let model = try list(manual, in: store).model
    #expect(rows(of: model).map(\.id) == [open])
    #expect(model.done?.label.text == "Done today · 1")
    let onParent = try list(parent, in: store).model
    #expect(rows(of: onParent).map(\.id) == [open], "and in its block on its parent's screen")
}

@Test func aGroupLeftWithOnlyDoneTasksIsNoBlock() throws {
    let store = try makeStore()
    let days = try store.createView(NewTaskView(title: "Days", filter: .trashed(false), sort: [SortKey(.when)], groupBy: .whenDay))
    let done = try store.createTask(NewTask(title: "Done", when: day(1)))
    let open = try store.createTask(NewTask(title: "Open", when: day(2)))
    try store.update(task: done, [.status(.done)])
    let model = try list(days, in: store).model
    #expect(blocks(of: model).map(\.id) == [.own(.day(day(2)))])
    #expect(rows(of: model).map(\.id) == [open])
    #expect(model.done?.label.text == "Done today · 1")
}

// MARK: - Adding a list

/// "+ Add list" adds a manual list inside this one, last among its lists, with the parent's colour and the `list` icon,
/// titled "New list" with its name field open in its block's header, closing the card that was open (spec section 4).
@Test func addListMakesAManualListLastWithTheParentsColourAndOpensItsName() throws {
    let store = try makeStore()
    let parent = try store.createView(NewTaskView(title: "Projects", color: .indigo, filter: .status([.open])))
    let first = try store.createView(NewTaskView(title: "First", parent: parent, filter: .status([.open])))
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let module = try list(parent, in: store)
    module.tap(.rowTapped(id))
    module.tap(.titleFieldChanged("Buy oat milk"))
    module.tap(.addListTapped)
    #expect(try stored(id, in: store).title == "Buy oat milk", "the card closed first")
    #expect(openCard(in: module.model) == nil)
    let lists = try store.children(ofView: parent)
    let made = try #require(lists.last)
    #expect(lists.map(\.id).first == first && lists.count == 2)
    #expect(made.title == "New list" && made.color == .indigo && made.icon == "list")
    #expect(made.filter == .listedIn(made.id))
    let header = try #require(block(.list(made.id), of: module.model)?.header)
    #expect(header.field?.text == "New list")
    module.tap(.listNameFieldChanged("  Errands "))
    #expect(try store.view(made.id)?.title == "New list", "nothing is written while it is typed")
    module.tap(.listNameFieldSubmitted)
    #expect(try store.view(made.id)?.title == "Errands", "trimmed")
    #expect(block(.list(made.id), of: module.model)?.header?.field == nil)
    module.tap(.addListTapped)
    let second = try #require(try store.children(ofView: parent).last)
    module.tap(.listNameFieldChanged("Chores"))
    module.tap(.listNameFieldLostFocus)
    #expect(try store.view(second.id)?.title == "Chores")
    module.tap(.addListTapped)
    let third = try #require(try store.children(ofView: parent).last)
    module.tap(.listNameFieldChanged("Dropped"))
    module.tap(.listNameFieldCancelled)
    #expect(try store.view(third.id)?.title == "New list", "Esc closes the field and the list stays")
    #expect(block(.list(third.id), of: module.model)?.header?.field == nil)
}

/// "+ Add list" tapped while a name is being typed keeps what was typed, a natural way to add two lists in a row (spec
/// section 4; the controller's ruling on #176, 2026-11-05).
@Test func addingAListWhileNamingKeepsWhatWasTyped() throws {
    let store = try makeStore()
    let parent = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let module = try list(parent, in: store)
    module.tap(.addListTapped)
    let first = try #require(try store.children(ofView: parent).last)
    module.tap(.listNameFieldChanged("Errands"))
    module.tap(.addListTapped)
    #expect(try store.view(first.id)?.title == "Errands")
    let second = try #require(try store.children(ofView: parent).last)
    #expect(second.id != first.id)
    #expect(block(.list(second.id), of: module.model)?.header?.field?.text == "New list")
    #expect(block(.list(first.id), of: module.model)?.header?.field == nil)
}

@Test func anEmptyNameKeepsTheOld() throws {
    let store = try makeStore()
    let parent = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let module = try list(parent, in: store)
    module.tap(.addListTapped)
    let made = try #require(try store.children(ofView: parent).last)
    module.tap(.listNameFieldChanged("   "))
    #expect(commits(of: store) { module.tap(.listNameFieldSubmitted) } == 0)
    #expect(try store.view(made.id)?.title == "New list")
    #expect(block(.list(made.id), of: module.model)?.header?.field == nil)
    module.tap(.listNameFieldChanged("Echo of a closed field"))
    #expect(commits(of: store) { module.tap(.listNameFieldLostFocus) } == 0, "no field is open")
}

/// A list made in columns is named in its column's header, and the board's "+ Add list" adds it as the list's does.
@Test func aListIsNamedInItsColumn() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let module = try list(BuiltInTaskViews.upcoming, in: store)
    module.tap(.showAsChosen(.columns))
    module.tap(.addListTapped)
    let made = try #require(try store.children(ofView: BuiltInTaskViews.upcoming).last)
    #expect(block(.list(made.id), of: module.model)?.column?.header.field?.text == "New list")
}

// MARK: - Deleting

@Test func deleteSwipedTrashesTheTask() throws {
    let store = try makeStore()
    let swiped = try store.createTask(NewTask(title: "Swiped"))
    let chosen = try store.createTask(NewTask(title: "Chosen"))
    let kept = try store.createTask(NewTask(title: "Kept"))
    let module = try list(inbox, in: store)
    module.tap(.deleteSwiped(swiped))
    #expect(try stored(swiped, in: store).trashed)
    module.tap(.deleteMenuItemChosen(chosen))
    #expect(try stored(chosen, in: store).trashed)
    #expect(rows(of: module.model).map(\.id) == [kept])
    #expect(try list(BuiltInTaskViews.trash, in: store).model.empty == nil, "the Trash gives it back")
}

/// A control the model does not draw writes nothing: a task in the Trash has no Delete, and neither has a column's card
/// a swipe nor the open card either.
@Test func aDeleteTheModelDoesNotDrawWritesNothing() throws {
    let store = try makeStore()
    let binned = try store.createTask(NewTask(title: "Binned"))
    try store.trash(task: binned)
    let trash = try list(BuiltInTaskViews.trash, in: store)
    #expect(commits(of: store) { trash.tap(.deleteSwiped(binned)) } == 0)
    #expect(commits(of: store) { trash.tap(.deleteMenuItemChosen(binned)) } == 0)
    let id = try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let board = try list(BuiltInTaskViews.upcoming, in: store)
    board.tap(.showAsChosen(.columns))
    #expect(commits(of: store) { board.tap(.deleteSwiped(id)) } == 0)
    board.tap(.deleteMenuItemChosen(id))
    #expect(try stored(id, in: store).trashed, "a column's card has the menu")
    let other = try store.createTask(NewTask(title: "Call the bank"))
    let card = try list(inbox, in: store)
    card.tap(.rowTapped(other))
    #expect(commits(of: store) { card.tap(.deleteSwiped(other)) } == 0)
}

// MARK: - A refusal

/// The new task and its pin are two transactions: where the pin is refused, a peer having deleted the manual list, the
/// task is taken back, so that "nothing was written" is true and no untitled task stays behind (the controller's ruling
/// on #176, 2026-11-05).
@Test func aRefusedPinTakesTheNewTaskBack() throws {
    let store = try makeStore()
    let parent = try store.createView(NewTaskView(title: "Projects", filter: .status([.open]), sort: [SortKey(.rank)]))
    let manual = try store.createManualList("Errands", in: parent, color: nil)
    let module = try list(parent, in: store)
    try store.delete(view: manual)
    module.tap(.addTaskRowTapped(in: .list(manual)))
    #expect(try store.allTasks().isEmpty)
    #expect(openCard(in: module.model) == nil)
    #expect(rows(of: module.model).isEmpty)
    #expect(module.model.problem == "The change could not be saved, so nothing was written.")
}

/// A close the store refused stops the add that followed it, so that its sentence stands and a title that was not saved
/// is not passed over in silence; the card is closed, so a second tap adds (the controller's ruling on #176,
/// 2026-11-05).
@Test func aCloseTheStoreRefusedStopsTheAddThatFollowed() throws {
    let adds: [(TaskList.UserAction, Bool)] = [
        (.addTaskButtonTapped, true), (.addTaskRowTapped(in: .own(nil)), true), (.addListTapped, false),
    ]
    for (add, addsATask) in adds {
        let store = try makeStore()
        let parent = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
        let id = try store.createTask(NewTask(title: "Buy milk"))
        let kept = try store.createTask(NewTask(title: "Call the bank"))
        let module = try list(parent, in: store)
        module.tap(.rowTapped(id))
        module.tap(.titleFieldChanged("Typed"))
        try store.delete(task: id)
        module.tap(add)
        #expect(module.model.problem == "The change could not be saved, so nothing was written.", "\(add)")
        #expect(try store.allTasks().map(\.id) == [kept], "\(add)")
        #expect(try store.children(ofView: parent).isEmpty, "\(add)")
        module.tap(add)
        #expect(module.model.problem == nil, "\(add)")
        #expect(try store.allTasks().count == (addsATask ? 2 : 1), "\(add)")
        #expect(try store.children(ofView: parent).count == (addsATask ? 0 : 1), "\(add)")
    }
}

/// A write the store refuses says so with the module's sentence, and the rows are read back, since what it refused can
/// be a peer's change the module has not heard of yet; the next write that holds takes the sentence away.
@Test func whatTheStoreRefusesBecomesTheSentence() throws {
    let store = try makeStore()
    let gone = try store.createTask(NewTask(title: "Buy milk"))
    let kept = try store.createTask(NewTask(title: "Call the bank"))
    let module = try list(inbox, in: store)
    try store.delete(task: gone)
    module.tap(.checkTapped(gone))
    #expect(module.model.problem == "The change could not be saved, so nothing was written.")
    #expect(rows(of: module.model).map(\.id) == [kept], "the row went with the read back")
    module.tap(.checkTapped(kept))
    #expect(module.model.problem == nil)
}

/// A drop stopped by a refusal is several writes, some of which may have held, and it says so.
@Test func aDropTheStoreRefusesSaysItMayHaveMovedInPart() throws {
    let store = try makeStore()
    let source = try store.createTag(title: "source")
    let parent = try store.createView(NewTaskView(title: "Projects", filter: .status([.open])))
    let from = try store.createView(NewTaskView(title: "From", parent: parent, filter: .hasTag(source)))
    let manual = try store.createManualList("Errands", in: parent, color: nil)
    let id = try store.createTask(NewTask(title: "Buy milk", tags: [source]))
    let module = try list(parent, in: store)
    try store.delete(view: manual)
    module.tap(.rowDropped(id, from: .list(from), in: .list(manual), after: nil))
    #expect(module.model.problem == "The task could not be moved, so it may have moved only in part.")
}

/// A tap that opens a card on a task a peer has deleted says why and opens nothing (spec section 3).
@Test func aCardOnATaskThatIsGoneSaysSo() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let module = try list(inbox, in: store)
    try store.delete(task: id)
    module.tap(.rowTapped(id))
    #expect(openCard(in: module.model) == nil)
    #expect(module.model.problem == "The task is gone.")
}
