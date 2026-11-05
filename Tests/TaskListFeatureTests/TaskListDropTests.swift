import Testing
import TestSupport
import DesignSystemComponents
import TaskListFeature
import TodoCore

// A drop (spec section 6; the controller's rulings R76, R77, R90, R91): inside its own block a task takes its place by the
// manual list; into another block it takes what that block's rule asks and leaves the list inside it came from.

private let inbox = BuiltInTaskViews.inbox

/// A list with a tag and a week's days for a rule, grouped by its days.
private func thisWeek(_ store: Store, tag: TagID) throws -> ViewID {
    try store.createView(NewTaskView(
        title: "This week", color: .indigo, filter: .and([.status([.open]), .hasTag(tag), .when(.between(0, 6))]),
        sort: [SortKey(.when)], groupBy: .whenDay
    ))
}

/// A list of open tasks to hold lists inside, on whose screen a test drops.
private func projects(_ store: Store) throws -> ViewID {
    try store.createView(NewTaskView(title: "Projects", color: .indigo, filter: .status([.open]), sort: [SortKey(.rank)]))
}

/// Several tasks, in the order of their ranks, in the Inbox.
private func tasks(_ titles: String..., in store: Store) throws -> [TaskID] {
    try titles.map { try store.createTask(NewTask(title: $0)) }
}

// MARK: - The reorder

/// A task dropped below the pinned tasks lands where it was let go: it and the unpinned tasks above it are pinned in one
/// transaction, in the order they stood.
@Test func aReorderPinsTheTaskAndTheUnpinnedAbove() throws {
    let store = try makeStore()
    let ids = try tasks("a", "b", "c", "d", "e", in: store)
    try store.pin(task: ids[0], in: inbox)
    let module = try list(inbox, in: store)
    let block = TaskList.Model.BlockID.own(nil)
    #expect(try commits(of: store) { module.tap(.rowDropped(ids[4], from: block, in: block, after: ids[1])) } == 1)
    #expect(try store.manualList(of: inbox) == [ids[0], ids[1], ids[4]])
    #expect(rowIDs(of: block, in: module.model) == [ids[0], ids[1], ids[4], ids[2], ids[3]])
    module.tap(.rowDropped(ids[3], from: block, in: block, after: nil))
    #expect(rowIDs(of: block, in: module.model) == [ids[3], ids[0], ids[1], ids[4], ids[2]])
    module.tap(.rowDropped(ids[3], from: block, in: block, after: ids[4]))
    #expect(rowIDs(of: block, in: module.model) == [ids[0], ids[1], ids[4], ids[3], ids[2]], "a pinned task moves too")
    #expect(try list(inbox, in: store).model == module.model, "and keeps it")
}

/// In a day block the manual list is the list's and the order is kept within the day: a drop moves no other day and no day
/// its task is on (spec section 6).
@Test func aReorderInADayBlockStaysInTheDay() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let week = try thisWeek(store, tag: work)
    let first = try store.createTask(NewTask(title: "First", when: day(1), tags: [work]))
    let a = try store.createTask(NewTask(title: "a", when: day(2), tags: [work]))
    let b = try store.createTask(NewTask(title: "b", when: day(2), tags: [work]))
    let c = try store.createTask(NewTask(title: "c", when: day(2), tags: [work]))
    let module = try list(week, in: store)
    let block = TaskList.Model.BlockID.own(.day(day(2)))
    module.tap(.rowDropped(c, from: block, in: block, after: a))
    #expect(try store.manualList(of: week) == [a, c])
    #expect(rowIDs(of: block, in: module.model) == [a, c, b])
    #expect(rowIDs(of: .own(.day(day(1))), in: module.model) == [first])
    #expect(try stored(c, in: store).when == day(2))
    let group = try list(TaskList.Route(head: .init(view: week, group: .day(2))), in: store)
    #expect(rowIDs(of: block, in: group.model) == [a, c, b], "the order is one on both screens")
    group.tap(.rowDropped(b, from: block, in: block, after: nil))
    #expect(try store.manualList(of: week) == [b, a, c], "a group's reorder pins in the list")
}

/// A list inside keeps its order in its own manual list, not its parent's (spec section 6).
@Test func aReorderInAListInsidePinsInThatList() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let parent = try projects(store)
    let house = try store.createView(NewTaskView(title: "House", parent: parent, filter: .hasTag(home), sort: [SortKey(.rank)]))
    let a = try store.createTask(NewTask(title: "a", tags: [home]))
    let b = try store.createTask(NewTask(title: "b", tags: [home]))
    let module = try list(parent, in: store)
    module.tap(.rowDropped(b, from: .list(house), in: .list(house), after: nil))
    #expect(try store.manualList(of: house) == [b])
    #expect(try store.manualList(of: parent).isEmpty)
    #expect(rowIDs(of: .list(house), in: module.model) == [b, a])
}

/// The reorder reads the block's order before the tag bar's filter: the tasks the pick hides keep their places (the
/// controller's ruling R90).
@Test func aReorderUnderAPickKeepsTheHiddenTasksPlaces() throws {
    let store = try makeStore()
    let shown = try store.createTag(title: "shown")
    let a = try store.createTask(NewTask(title: "a", tags: [shown]))
    let hidden = try store.createTask(NewTask(title: "hidden"))
    let b = try store.createTask(NewTask(title: "b", tags: [shown]))
    let c = try store.createTask(NewTask(title: "c", tags: [shown]))
    let d = try store.createTask(NewTask(title: "d", tags: [shown]))
    let module = try list(inbox, in: store)
    module.tap(.tagChipTapped(shown))
    let block = TaskList.Model.BlockID.own(nil)
    #expect(rowIDs(of: block, in: module.model) == [a, b, c, d])
    module.tap(.rowDropped(d, from: block, in: block, after: b))
    #expect(rowIDs(of: block, in: module.model) == [a, b, d, c])
    #expect(try list(inbox, in: store).model.layout != module.model.layout, "the pick is session state; this is the setup")
    #expect(rowIDs(of: block, in: try list(inbox, in: store).model) == [a, hidden, b, d, c])
}

/// A task let go where it stands moves nothing, so it writes nothing (the controller's ruling R91).
@Test func aReorderToItsOwnPlaceWritesNothing() throws {
    let store = try makeStore()
    let ids = try tasks("a", "b", "c", in: store)
    let module = try list(inbox, in: store)
    let block = TaskList.Model.BlockID.own(nil)
    #expect(try commits(of: store) { module.tap(.rowDropped(ids[1], from: block, in: block, after: ids[0])) } == 0)
    #expect(try commits(of: store) { module.tap(.rowDropped(ids[0], from: block, in: block, after: nil)) } == 0)
}

@Test func aDropAfterARowNotInTheBlockWritesNothing() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let parent = try projects(store)
    let house = try store.createView(NewTaskView(title: "House", parent: parent, filter: .hasTag(home)))
    let inside = try store.createTask(NewTask(title: "Inside", tags: [home]))
    let a = try store.createTask(NewTask(title: "a"))
    let b = try store.createTask(NewTask(title: "b"))
    let module = try list(parent, in: store)
    #expect(try commits(of: store) { module.tap(.rowDropped(b, from: .own(nil), in: .own(nil), after: inside)) } == 0)
    #expect(try commits(of: store) { module.tap(.rowDropped(a, from: .own(nil), in: .list(house), after: b)) } == 0)
    #expect(try commits(of: store) { module.tap(.rowDropped(b, from: .list(house), in: .own(nil), after: nil)) } == 0, "not its row")
    let gone = TaskList.Model.BlockID.list(ViewID("gone"))
    #expect(try commits(of: store) { module.tap(.rowDropped(a, from: .own(nil), in: gone, after: nil)) } == 0)
    #expect(try commits(of: store) { module.tap(.rowDropped(a, from: gone, in: .own(nil), after: nil)) } == 0)
}

@Test func aDropAfterItselfWritesNothing() throws {
    let store = try makeStore()
    let ids = try tasks("a", "b", "c", in: store)
    let module = try list(inbox, in: store)
    let block = TaskList.Model.BlockID.own(nil)
    #expect(try commits(of: store) { module.tap(.rowDropped(ids[1], from: block, in: block, after: ids[1])) } == 0)
}

// MARK: - The move

/// A day block asks for its day and the rest of what the rule asks; the task leaves the list inside it was dragged from
/// (spec section 6's table).
@Test func aDropIntoADayBlockSetsTheDayAndTheRulesTag() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let home = try store.createTag(title: "home")
    let week = try thisWeek(store, tag: work)
    let house = try store.createView(NewTaskView(title: "House", parent: week, filter: .hasTag(home)))
    let there = try store.createTask(NewTask(title: "There", when: day(2), tags: [work]))
    let id = try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    let module = try list(week, in: store)
    let block = TaskList.Model.BlockID.own(.day(day(2)))
    module.tap(.rowDropped(id, from: .list(house), in: block, after: there))
    let task = try stored(id, in: store)
    #expect(task.when == day(2) && task.tags == [work])
    #expect(rowIDs(of: block, in: module.model) == [there, id])
    #expect(rowIDs(of: .list(house), in: module.model).isEmpty)
}

/// A manual list takes the task last, and it leaves the manual list it came from (spec section 6's table). `after` is
/// unused by a move, and the drop writes through the rows the module read: nothing asks the task to be anywhere else.
@Test func aDropIntoAManualListPinsLastAndLeavesTheSourcesPin() throws {
    let store = try makeStore()
    let parent = try projects(store)
    let from = try store.createManualList("From", in: parent, color: nil)
    let to = try store.createManualList("To", in: parent, color: nil)
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let first = try store.createTask(NewTask(title: "First"))
    let second = try store.createTask(NewTask(title: "Second"))
    try store.pin(task: id, in: from)
    try store.pin(task: first, in: to)
    try store.pin(task: second, in: to)
    let module = try list(parent, in: store)
    module.tap(.rowDropped(id, from: .list(from), in: .list(to), after: first))
    #expect(try store.manualList(of: to) == [first, second, id])
    #expect(try store.manualList(of: from).isEmpty)
    #expect(rowIDs(of: .list(to), in: module.model) == [first, second, id])
    #expect(rowIDs(of: .list(from), in: module.model).isEmpty)
}

@Test func aDropIntoATagListSwapsTheTags() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let work = try store.createTag(title: "work")
    let other = try store.createTag(title: "other")
    let parent = try projects(store)
    let house = try store.createView(NewTaskView(title: "House", parent: parent, filter: .hasTag(home)))
    let office = try store.createView(NewTaskView(title: "Office", parent: parent, filter: .hasTag(work)))
    let id = try store.createTask(NewTask(title: "Fix the door", tags: [home, other]))
    let module = try list(parent, in: store)
    module.tap(.rowDropped(id, from: .list(house), in: .list(office), after: nil))
    #expect(try stored(id, in: store).tags == [work, other], "and keeps what no block asked")
    #expect(rowIDs(of: .list(office), in: module.model) == [id])
    #expect(rowIDs(of: .list(house), in: module.model).isEmpty)
}

@Test func aDropIntoAFolderAsksItsFirstList() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let first = try store.createTag(title: "first")
    let parent = try projects(store)
    let house = try store.createView(NewTaskView(title: "House", parent: parent, filter: .hasTag(home)))
    let folder = try store.createView(NewTaskView(title: "Folder", parent: parent))
    try store.createView(NewTaskView(title: "First", parent: folder, filter: .hasTag(first)))
    let id = try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    let module = try list(parent, in: store)
    module.tap(.rowDropped(id, from: .list(house), in: .list(folder), after: nil))
    #expect(try stored(id, in: store).tags == [first])
    #expect(rowIDs(of: .list(folder), in: module.model) == [id])
}

@Test func aDropIntoTheOwnBlockLeavesTheListInside() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let parent = try projects(store)
    let house = try store.createView(NewTaskView(title: "House", parent: parent, filter: .hasTag(home)))
    let id = try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    let module = try list(parent, in: store)
    module.tap(.rowDropped(id, from: .list(house), in: .own(nil), after: nil))
    #expect(try stored(id, in: store).tags == [])
    #expect(rowIDs(of: .own(nil), in: module.model) == [id])
}

/// A rule of alternatives, a condition no edit satisfies, takes no drop: the model says so for the view, and one sent all
/// the same writes nothing (spec section 6).
@Test func aBlockWhoseRuleRefusesTakesNoDrop() throws {
    let store = try makeStore()
    let parent = try projects(store)
    let either = try store.createView(NewTaskView(title: "Either", parent: parent, filter: .or([.when(.on(0)), .when(.on(1))])))
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let module = try list(parent, in: store)
    #expect(block(.list(either), of: module.model)?.takesDrop == false)
    #expect(block(.own(nil), of: module.model)?.takesDrop == true)
    #expect(try commits(of: store) { module.tap(.rowDropped(id, from: .own(nil), in: .list(either), after: nil)) } == 0)
    module.tap(.showAsChosen(.columns))
    #expect(block(.list(either), of: module.model)?.column?.isDropTarget == false)
    #expect(block(.own(nil), of: module.model)?.column?.isDropTarget == true)
    #expect(try commits(of: store) { module.tap(.rowDropped(id, from: .own(nil), in: .list(either), after: nil)) } == 0)
}

/// A task two blocks draw leaves only the one it was dragged from (the controller's ruling R76).
@Test func aTaskTwoBlocksDrawLeavesOnlyTheOneItWasDraggedFrom() throws {
    let store = try makeStore()
    let a = try store.createTag(title: "a")
    let b = try store.createTag(title: "b")
    let c = try store.createTag(title: "c")
    let parent = try projects(store)
    let listA = try store.createView(NewTaskView(title: "A", parent: parent, filter: .hasTag(a)))
    let listB = try store.createView(NewTaskView(title: "B", parent: parent, filter: .hasTag(b)))
    let listC = try store.createView(NewTaskView(title: "C", parent: parent, filter: .hasTag(c)))
    let id = try store.createTask(NewTask(title: "Both", tags: [a, b]))
    let module = try list(parent, in: store)
    #expect(rowIDs(of: .list(listA), in: module.model) == [id])
    #expect(rowIDs(of: .list(listB), in: module.model) == [id])
    module.tap(.rowDropped(id, from: .list(listA), in: .list(listC), after: nil))
    #expect(try stored(id, in: store).tags == [b, c])
    #expect(rowIDs(of: .list(listA), in: module.model).isEmpty)
    #expect(rowIDs(of: .list(listB), in: module.model) == [id], "it stays where it was not dragged from")
    #expect(rowIDs(of: .list(listC), in: module.model) == [id])
}

/// An own block reverses nothing: reversing the list's own rule would strip a tag or a pin the spec's table never lists as
/// left, and the task leaves it by being claimed (the controller's ruling R77).
@Test func aDropOutOfAnOwnBlockKeepsTheListsTag() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let home = try store.createTag(title: "home")
    let parent = try store.createView(NewTaskView(title: "Projects", filter: .and([.status([.open]), .hasTag(work)])))
    let house = try store.createView(NewTaskView(title: "House", parent: parent, filter: .hasTag(home)))
    let id = try store.createTask(NewTask(title: "Fix the door", tags: [work]))
    let module = try list(parent, in: store)
    module.tap(.rowDropped(id, from: .own(nil), in: .list(house), after: nil))
    #expect(try stored(id, in: store).tags == [work, home])
    #expect(rowIDs(of: .own(nil), in: module.model).isEmpty)
    #expect(rowIDs(of: .list(house), in: module.model) == [id])
}

/// What the target asks is taken out of what the source gave back: a shared tag and the same manual list stay (the
/// controller's ruling R77).
@Test func theReversalKeepsWhatTheTargetAsks() throws {
    let store = try makeStore()
    let shared = try store.createTag(title: "shared")
    let a = try store.createTag(title: "a")
    let b = try store.createTag(title: "b")
    let parent = try projects(store)
    let manual = try store.createManualList("Manual", in: parent, color: nil)
    let fromList = try store.createView(NewTaskView(
        title: "From", parent: parent, filter: .and([.hasTag(shared), .hasTag(a), .listedIn(manual)])
    ))
    let toList = try store.createView(NewTaskView(
        title: "To", parent: parent, filter: .and([.hasTag(shared), .hasTag(b), .listedIn(manual)])
    ))
    let id = try store.createTask(NewTask(title: "Buy milk", tags: [shared, a]))
    try store.pin(task: id, in: manual)
    let module = try list(parent, in: store)
    module.tap(.rowDropped(id, from: .list(fromList), in: .list(toList), after: nil))
    #expect(try stored(id, in: store).tags == [shared, b])
    #expect(try store.manualList(of: manual) == [id])
}

/// A day condition the task already meets asks nothing of it, so an overdue task dropped into a list of what is due keeps
/// its day, where a day block always writes its own (the controller's ruling R91).
@Test func aDropIntoARuleTheTaskAlreadyMatchesKeepsItsDay() throws {
    let store = try makeStore()
    let a = try store.createTag(title: "a")
    let parent = try projects(store)
    let tagged = try store.createView(NewTaskView(title: "Tagged", parent: parent, filter: .hasTag(a)))
    let due = try store.createView(NewTaskView(title: "Due", parent: parent, filter: .when(.onOrBefore(0))))
    let late = try store.createTask(NewTask(title: "Late", when: day(-3), tags: [a]))
    let bare = try store.createTask(NewTask(title: "Bare", tags: [a]))
    let future = try store.createTask(NewTask(title: "Future", when: day(5), tags: [a]))
    let module = try list(parent, in: store)
    module.tap(.rowDropped(late, from: .list(tagged), in: .list(due), after: nil))
    #expect(try stored(late, in: store).when == day(-3))
    module.tap(.rowDropped(bare, from: .list(tagged), in: .list(due), after: nil))
    #expect(try stored(bare, in: store).when == day(0), "the nearest day the rule allows")
    module.tap(.rowDropped(future, from: .list(tagged), in: .list(due), after: nil))
    #expect(try stored(future, in: store).when == day(0))
    #expect(try stored(future, in: store).tags == [])
}

/// A move writes only what changes: a tag the task holds, the day it is on and a pin it does not have cost no write, which
/// is what keeps the rereads few (the controller's ruling R91).
@Test func aMoveWritesOnlyWhatChanges() throws {
    let store = try makeStore()
    let a = try store.createTag(title: "a")
    let shared = try store.createTag(title: "shared")
    let parent = try projects(store)
    let manual = try store.createManualList("Manual", in: parent, color: nil)
    let from = try store.createView(NewTaskView(title: "From", parent: parent, filter: .hasTag(a)))
    let to = try store.createView(NewTaskView(
        title: "To", parent: parent, filter: .and([.hasTag(shared), .when(.on(1)), .not(.listedIn(manual))])
    ))
    let id = try store.createTask(NewTask(title: "Buy milk", when: day(1), tags: [a, shared]))
    let module = try list(parent, in: store)
    #expect(try commits(of: store) { module.tap(.rowDropped(id, from: .list(from), in: .list(to), after: nil)) } == 1)
    #expect(try stored(id, in: store).tags == [shared], "the one write: the tag it left")
    #expect(try stored(id, in: store).when == day(1))
}

/// A move into a folded block leaves it folded (the controller's ruling R90).
@Test func aMoveIntoAFoldedBlockLeavesItFolded() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let parent = try projects(store)
    let house = try store.createView(NewTaskView(title: "House", parent: parent, filter: .hasTag(home)))
    let id = try store.createTask(NewTask(title: "Fix the door"))
    let module = try list(parent, in: store)
    module.tap(.blockChevronTapped(.list(house)))
    #expect(block(.list(house), of: module.model)?.takesDrop == true)
    module.tap(.rowDropped(id, from: .own(nil), in: .list(house), after: nil))
    #expect(try stored(id, in: store).tags == [home])
    #expect(block(.list(house), of: module.model)?.isFolded == true)
    #expect(rowIDs(of: .list(house), in: module.model).isEmpty)
}

/// Every drop answers a person's action and rereads at once, so the model after it is what a list made now would draw.
@Test func aDropLeavesTheModelAListMadeNowDraws() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let parent = try projects(store)
    let house = try store.createView(NewTaskView(title: "House", parent: parent, filter: .hasTag(home)))
    let id = try store.createTask(NewTask(title: "Fix the door"))
    let module = try list(parent, in: store)
    module.tap(.rowDropped(id, from: .own(nil), in: .list(house), after: nil))
    #expect(module.model == (try list(parent, in: store).model))
}
