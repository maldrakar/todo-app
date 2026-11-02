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

/// Whether a task has notes is read with it, by every reader through the one loader, so a row can draw its note
/// glyph with no read of its own (spec section 3); the notes themselves stay where they are and are read by
/// `notes(of:)`. A note cleared to nothing is no note, and a note is one by its bytes, so one that starts with a NUL,
/// which a write binds with its length and so keeps whole, is a note: `length()` would stop at the NUL and read none.
@Test func aTaskSaysWhetherItHasNotes() throws {
    let store = try makeStore()
    let project = try store.createTask(NewTask(title: "Project"))
    let with = try store.createTask(NewTask(title: "with", notes: "# md", parent: project))
    let without = try store.createTask(NewTask(title: "without", parent: project))
    let view = try store.createView(NewTaskView(title: "Project", filter: .parent(project)))

    #expect(try store.task(with)?.hasNotes == true)
    #expect(try store.task(without)?.hasNotes == false)
    #expect(try store.children(of: project).map(\.hasNotes) == [true, false])
    #expect(try store.page(of: view, today: Day(year: 2026, month: 11, day: 2)).sections.flatMap(\.groups).flatMap(\.tasks).map(\.hasNotes) == [true, false])
    try store.update(task: with, [.notes("")])
    #expect(try store.task(with)?.hasNotes == false, "a note cleared to nothing is no note")
    try store.update(task: with, [.notes("\u{0}after a NUL")])
    #expect(try store.notes(of: with) == "\u{0}after a NUL", "the write keeps the NUL")
    #expect(try store.task(with)?.hasNotes == true, "a note that starts with a NUL is a note")
}

/// A task counts its children done over all, as its row's "2/4" reads (spec section 3): a cancelled child is no
/// longer open, so it is done here as it is in the Logbook; a child in the Trash and a deleted one are not the
/// task's any more and are not counted; a grandchild is its own parent's, not the task's.
@Test func aTaskCountsItsSubtasksDoneOverAll() throws {
    let store = try makeStore()
    let project = try store.createTask(NewTask(title: "Project"))
    let open = try store.createTask(NewTask(title: "open", parent: project))
    let done = try store.createTask(NewTask(title: "done", parent: project))
    try store.update(task: done, [.status(.done)])
    let canceled = try store.createTask(NewTask(title: "canceled", parent: project))
    try store.update(task: canceled, [.status(.canceled)])
    let binned = try store.createTask(NewTask(title: "binned", parent: project))
    try store.trash(task: binned)
    let gone = try store.createTask(NewTask(title: "gone", parent: project))
    try store.update(task: gone, [.status(.done)])
    try store.delete(task: gone)
    try store.createTask(NewTask(title: "grandchild", parent: open))

    let task = try #require(try store.task(project))
    #expect(task.subtasks == 3 && task.subtasksDone == 2)
    let row = try #require(try store.children(of: nil).first { $0.id == project })
    #expect(row.subtasks == 3 && row.subtasksDone == 2, "a list reads the counts as the task itself does")
    #expect(try store.task(open)?.subtasks == 1, "the grandchild is its own parent's")
}

@Test func aTaskWithNoChildrenReadsZeroOverZero() throws {
    let store = try makeStore()
    let leaf = try store.createTask(NewTask(title: "leaf"))
    let task = try #require(try store.task(leaf))
    #expect(task.subtasks == 0 && task.subtasksDone == 0)
}

/// The notes flag is the size of the notes in bytes, `octet_length`, which SQLite reads from the record's header
/// without loading the text from its overflow pages, so a list still reads no notes (ADR-0002). `EXPLAIN` shows it on
/// the `Column` opcode that reads the notes: P5 carries `OPFLAG_BYTELENARG`, 0xc0. That value and no other skips the
/// overflow pages of a text: `OP_Column` uses the content it has not loaded only for `typeof()` (0x80), for
/// `length()` (0x40) of a blob, and for `octet_length()` (0xc0) of anything (`Sources/CSQLite/sqlite3.c`, the branch
/// "This branch happens only when content is on overflow pages"); `length()` of a text counts its characters and
/// loads it, as a comparison with the text, `notes != ''`, would. Every read of the notes column by the loader's
/// statement has to carry it, and there has to be one, or the flag is read some other way and this proves nothing.
@Test func theNotesFlagLoadsNoNotes() throws {
    let store = try makeStore()
    let byteLengthOnly: Int64 = 0xc0
    let program = try store.sql { () throws(SQLiteError) in
        try store.db.rows("EXPLAIN " + Store.taskQuery(where: "t.id = ?", orderBy: "t.rank", limit: nil), [.text("t")])
    }
    let tasksRoot = try store.sql { () throws(SQLiteError) in
        try store.db.rows("SELECT rootpage FROM sqlite_master WHERE type = 'table' AND name = 'tasks'").first?.first?.int64
    }
    let notesColumn = try store.sql { () throws(SQLiteError) in
        try store.db.rows("SELECT cid FROM pragma_table_info('tasks') WHERE name = 'notes'").first?.first?.int64
    }
    // EXPLAIN's columns: addr, opcode, p1, p2, p3, p4, p5, comment. The cursor the tasks table is opened on is the
    // `OpenRead` of its root page.
    let cursors = Set(program.filter { $0[1].string == "OpenRead" && $0[3].int64 == tasksRoot }.compactMap { $0[2].int64 })
    let notesReads = program.filter { $0[1].string == "Column" && cursors.contains($0[2].int64 ?? -1) && $0[3].int64 == notesColumn }
    #expect(!cursors.isEmpty, "the statement opens the tasks table: \(program)")
    #expect(!notesReads.isEmpty, "the statement reads the notes column for the flag: \(program)")
    #expect(notesReads.allSatisfy { ($0[6].int64 ?? 0) & byteLengthOnly == byteLengthOnly }, "every read of the notes is of their size in bytes alone: \(notesReads)")
}
