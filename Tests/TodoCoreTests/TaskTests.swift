import Testing
import TestSupport
@testable import TodoCore
@testable import SQLiteKit

@Test func createTaskStoresEveryFieldAndDefaults() throws {
    let clock = TestClock()
    let store = try makeStore(clock: clock)
    let id = try store.createTask(NewTask(title: "Write spec"))
    let task = try #require(try store.task(id))
    #expect(task.title == "Write spec")
    #expect(task.status == .open)
    #expect(task.when == nil && task.deadline == nil && task.parent == nil)
    #expect(task.rank == Rank.initial)
    #expect(task.tags.isEmpty && !task.trashed && task.completedAt == nil)
    #expect(task.createdAt > 1_757_500_000_000)
    #expect(try store.notes(of: id) == "")
    #expect(try store.task(TaskID("missing")) == nil)
}

@Test func updateChangesFieldsAndCompletionTracksStatus() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "a"))
    let when = Day(year: 2026, month: 9, day: 12)
    try store.update(task: id, [.title("b"), .notes("# md"), .when(when), .deadline(when.advanced(by: 3)), .status(.done)])
    let task = try #require(try store.task(id))
    #expect(task.title == "b" && task.when == when && task.deadline == when.advanced(by: 3))
    #expect(task.status == .done && task.completedAt != nil)
    #expect(try store.notes(of: id) == "# md")
    try store.update(task: id, [.status(.open), .when(nil)])
    let reopened = try #require(try store.task(id))
    #expect(reopened.status == .open && reopened.completedAt == nil && reopened.when == nil)
}

@Test func childrenAreOrderedByRankAndPlacementWorks() throws {
    let store = try makeStore()
    let project = try store.createTask(NewTask(title: "Project"))
    let first = try store.createTask(NewTask(title: "1", parent: project))
    let third = try store.createTask(NewTask(title: "3", parent: project))
    let second = try store.createTask(NewTask(title: "2", parent: project), at: .after(first))
    let zero = try store.createTask(NewTask(title: "0", parent: project), at: .start)
    #expect(try store.children(of: project).map(\.title) == ["0", "1", "2", "3"])
    #expect(try store.children(of: nil).map(\.id) == [project])
    try store.move(task: third, to: project, at: .start)
    #expect(try store.children(of: project).map(\.title) == ["3", "0", "1", "2"])
    try store.move(task: zero, to: nil, at: .end)
    #expect(try store.children(of: nil).map(\.title) == ["Project", "0"])
    #expect(try store.task(second)?.parent == project)
}

@Test func moveRejectsSelfAndMissingParents() throws {
    let store = try makeStore()
    let a = try store.createTask(NewTask(title: "a"))
    var caught: StoreError?
    do { try store.move(task: a, to: a, at: .end) } catch { caught = error }
    #expect(caught == .invalid("a task cannot be its own parent"))
    do { try store.move(task: a, to: TaskID("nope"), at: .end) } catch { caught = error }
    #expect(caught == .notFound(TaskID("nope")))
}

@Test func trashRestoreAndDeleteFollowTheTree() throws {
    let store = try makeStore()
    let p = try store.createTask(NewTask(title: "p"))
    let child = try store.createTask(NewTask(title: "c", parent: p))
    try store.trash(task: p)
    #expect(try store.task(child)?.trashed == true)
    #expect(try store.children(of: p).isEmpty)
    #expect(try store.allTasks().isEmpty && store.allTasks(includeTrashed: true).count == 2)
    #expect(try store.children(of: p, includeTrashed: true).count == 1)
    try store.restore(task: p)
    #expect(try store.task(child)?.trashed == false)
    try store.delete(task: p)
    #expect(try store.task(p) == nil)
    #expect(try store.task(child)?.parent == nil, "children of a deleted parent show at the root")
}

@Test func tagsAttachDetachAndHideDeletedTags() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let home = try store.createTag(title: "home")
    let id = try store.createTask(NewTask(title: "t", tags: [work]))
    try store.add(tag: home, to: id)
    #expect(try store.task(id)?.tags == [work, home])
    try store.remove(tag: work, from: id)
    #expect(try store.task(id)?.tags == [home])
    try store.delete(tag: home)
    #expect(try store.task(id)?.tags == [])
}

@Test func writesReportChangeSetsAndReachTheJournal() throws {
    let store = try makeStore()
    var seen: [ChangeSet] = []
    store.onChange = { seen.append($0) }
    func journalled() throws -> Int64 {
        try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM ops WHERE device != 'seed'").first?.first?.int64 ?? 0 }
    }
    let tag = try store.createTag(title: "work")
    let id = try store.createTask(NewTask(title: "t"))
    let created = try journalled()
    #expect(created == 15, "five fields for the tag and ten for the task, each one an operation and nothing written beside them")
    try store.update(task: id, [])
    #expect(try journalled() == created, "an edit that changes nothing writes nothing")
    try store.add(tag: tag, to: id)
    try store.move(task: id, to: nil, at: .start)
    try store.trash(task: id)
    #expect(try journalled() == created + 4, "one operation for the tag, two for the move, one for the trash")
    #expect(seen.count == 5)
    #expect(seen[0].tags == [tag] && seen[0].tasks.isEmpty)
    #expect(seen.dropFirst().allSatisfy { $0.tasks == [id] && $0.tags.isEmpty })
}

/// `when_day` is a plain INTEGER column and takes whatever a peer or a newer version of the app writes into
/// it; `Day` holds 32 bits. A read that converts without checking traps, and since the value is stored, it
/// traps again on every later read of every list that holds the task — the shape of #34.
@Test func aDayOutsideTheRangeOfTheColumnReadsAsNoDay() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "t"))
    try store.apply([
        store.op(.task, id.rawValue, "when_day", .integer(5_000_000_000), store.clock.next()),
        store.op(.task, id.rawValue, "deadline_day", .integer(-5_000_000_000), store.clock.next()),
    ])
    let task = try #require(try store.task(id))
    #expect(task.when == nil && task.deadline == nil, "a day the type cannot hold reads as no day, the way an unusable parent link reads as no link")
    #expect(try store.allTasks().count == 1)
}

/// The read rule that puts a cycle at the root belongs to merges, where neither of two concurrent links is
/// the better one. A local move has the whole tree in hand, and scattering the subtree a person dragged is
/// not what they asked for.
@Test func movingATaskUnderItsOwnDescendantIsRefused() throws {
    let store = try makeStore()
    let project = try store.createTask(NewTask(title: "Project"))
    let child = try store.createTask(NewTask(title: "Child", parent: project))
    let grandchild = try store.createTask(NewTask(title: "Grandchild", parent: child))
    var caught: StoreError?
    do { try store.move(task: project, to: grandchild, at: .end) } catch { caught = error }
    #expect(caught == .invalid("a task cannot be moved under its own descendant"))
    #expect(try store.children(of: nil).map(\.id) == [project], "the refused move left the tree as it was")
    #expect(try store.children(of: child).map(\.id) == [grandchild])
}

/// Every operation of one call carries one stamp, so a field named twice would meet itself as an equal in
/// `apply`, the second would lose and its journal row would be dropped as a duplicate: the value would be
/// gone from the state and from sync alike.
@Test func theLastChangeForAFieldWins() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "t"))
    try store.update(task: id, [.title("first"), .status(.done), .title("second")])
    let task = try #require(try store.task(id))
    #expect(task.title == "second" && task.status == .done)
}

@Test func theCompletionTimeMovesOnlyWhenTheTaskCrossesOpen() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "t"))
    try store.update(task: id, [.status(.done)])
    let completed = try #require(try store.task(id)?.completedAt)
    try store.update(task: id, [.status(.done)])
    #expect(try store.task(id)?.completedAt == completed, "marking a done task done again keeps when it was done")
    try store.update(task: id, [.status(.canceled)])
    #expect(try store.task(id)?.completedAt == completed, "a task already out of open did not leave it a second time")
    try store.update(task: id, [.status(.open)])
    #expect(try store.task(id)?.completedAt == nil)
    try store.update(task: id, [.status(.canceled)])
    #expect(try store.task(id)?.completedAt != nil, "canceled leaves open too")
}

/// A write names what it edits, and `apply` inserts the row it does not find, which is what sync needs and
/// what a typo must not reach.
@Test func writesRefuseIdsThatAreNotThere() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "t"))
    let missingTag = TagID("no-such-tag")
    let missingTask = TaskID("no-such-task")
    var caught: StoreError?
    do { try store.add(tag: missingTag, to: id) } catch { caught = error }
    #expect(caught == .notFound(missingTag))
    do { try store.remove(tag: missingTag, from: missingTask) } catch { caught = error }
    #expect(caught == .notFound(missingTask))
    do { _ = try store.createTask(NewTask(title: "x", tags: [missingTag])) } catch { caught = error }
    #expect(caught == .notFound(missingTag))
    do { _ = try store.createTask(NewTask(title: "y"), at: .after(missingTask)) } catch { caught = error }
    #expect(caught == .notFound(missingTask))
    do { _ = try store.notes(of: missingTask) } catch { caught = error }
    #expect(caught == .notFound(missingTask))
    #expect(try store.allTasks().map(\.id) == [id], "nothing a refused write named reached the state")
}

/// A drag inside one list is not a statement about the parent, and `move(task:to:at:)` could only say it by
/// re-asserting the link at a new stamp, which is a peer's concurrent re-parent lost.
@Test func aReorderKeepsTheParentAndWritesTheRankAlone() throws {
    let store = try makeStore()
    func journalled() throws -> Int64 {
        try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM ops WHERE device != 'seed'").first?.first?.int64 ?? 0 }
    }
    let project = try store.createTask(NewTask(title: "Project"))
    let first = try store.createTask(NewTask(title: "1", parent: project))
    try store.createTask(NewTask(title: "2", parent: project))
    let third = try store.createTask(NewTask(title: "3", parent: project))
    let before = try journalled()
    try store.move(task: third, at: .after(first))
    #expect(try store.children(of: project).map(\.title) == ["1", "3", "2"])
    #expect(try store.task(third)?.parent == project)
    #expect(try journalled() == before + 1, "the rank, and no operation naming the parent")
    try store.move(task: first, at: .end)
    #expect(try store.children(of: project).map(\.title) == ["3", "2", "1"])
}
