import Testing
@testable import TodoCore
@testable import SQLiteKit

private let today = Day(year: 2026, month: 9, day: 11)

@Test func filterRoundTripsThroughJSON() throws {
    let filter: Filter = .and([
        .status([.open, .done]),
        .or([.when(.between(-1, 7)), .deadline(.empty), .not(.hasTag(TagID("g1")))]),
        .parent(nil), .parent(TaskID("p1")), .listedIn(ViewID("v1")), .trashed(false),
        .when(.on(0)), .when(.onOrBefore(0)), .when(.onOrAfter(1)),
    ])
    let json = try filter.json()
    #expect(json.hasPrefix("{\"filters\":[{\"kind\":\"status\",\"statuses\":[0,1]}"))
    #expect(try Filter(json: json) == filter)
    #expect(try Filter.parent(nil).json() == "{\"kind\":\"parent\",\"task\":null}")
    #expect(try Filter.when(.on(0)).json() == "{\"day\":{\"kind\":\"on\",\"offset\":0},\"kind\":\"when\"}")
}

@Test func unknownKindsAreReportedByName() {
    var caught: FilterError?
    do { _ = try Filter(json: "{\"kind\":\"reminder_soon\",\"minutes\":30}") } catch { caught = error }
    #expect(caught == .unsupported(kind: "reminder_soon"))
    do { _ = try Filter(json: "{\"kind\":\"and\",\"filters\":[{\"kind\":\"day\",\"day\":{\"kind\":\"next_week\"}}]}") } catch { caught = error }
    #expect(caught == .unsupported(kind: "day"))
    do { _ = try Filter(json: "{\"kind\":\"when\",\"day\":{\"kind\":\"next_week\"}}") } catch { caught = error }
    #expect(caught == .unsupported(kind: "next_week"))
    do { _ = try Filter(json: "not json") } catch { caught = error }
    if case .malformed = caught {} else { Issue.record("expected malformed, got \(String(describing: caught))") }
}

/// A status a newer app wrote is a condition this one cannot evaluate: dropping it would quietly turn
/// `status IN (open, 7)` into a list that is missing rows, and the spec asks for "needs a newer app"
/// rather than a wrong list.
@Test func anUnknownStatusIsReportedRatherThanDropped() {
    var caught: FilterError?
    do { _ = try Filter(json: "{\"kind\":\"status\",\"statuses\":[0,7]}") } catch { caught = error }
    #expect(caught == .unsupported(kind: "status 7"))
}

/// A newer app that extends a kind it shares with this one writes keys this one does not read. Ignoring
/// them would turn "the tasks under p1 and p2" into "the tasks at the root" \u2014 a full list of the wrong
/// tasks, which is worse than a view that says it needs a newer app.
@Test func aKindMissingTheKeyThatSelectsIsNotReadAsSomethingElse() {
    var caught: FilterError?
    do { _ = try Filter(json: "{\"kind\":\"parent\",\"tasks\":[\"p1\",\"p2\"]}") } catch { caught = error }
    #expect(caught == .unsupported(kind: "parent"))
    #expect((try? Filter(json: "{\"kind\":\"parent\",\"task\":null}")) == Filter.parent(nil))
}

@Test func sortKeysRoundTripAndRejectUnknownFields() throws {
    let keys = [SortKey(.when), SortKey(.completed, descending: true)]
    let json = try SortKey.json(keys)
    #expect(json == "[{\"descending\":false,\"field\":\"when\"},{\"descending\":true,\"field\":\"completed\"}]")
    #expect(try SortKey.parse(json: json) == keys)
    var caught: FilterError?
    do { _ = try SortKey.parse(json: "[{\"field\":\"priority\",\"descending\":false}]") } catch { caught = error }
    #expect(caught == .unsupported(kind: "sort priority"))
    do { _ = try SortKey.parse(json: "not json") } catch { caught = error }
    if case .malformed = caught {} else { Issue.record("expected malformed, got \(String(describing: caught))") }
}

@Test func conditionsCompileToParameterisedSQL() {
    let day = Int64(today.daysSinceEpoch)
    #expect(FilterCompiler.compile(.status([.open, .done]), today: today) == SQLFragment(sql: "t.status IN (?, ?)", params: [.integer(0), .integer(1)]))
    #expect(FilterCompiler.compile(.status([]), today: today) == SQLFragment(sql: "0", params: []))
    #expect(FilterCompiler.compile(.when(.empty), today: today) == SQLFragment(sql: "t.when_day IS NULL", params: []))
    #expect(FilterCompiler.compile(.when(.on(2)), today: today) == SQLFragment(sql: "t.when_day = ?", params: [.integer(day + 2)]))
    #expect(FilterCompiler.compile(.deadline(.onOrBefore(0)), today: today) == SQLFragment(sql: "t.deadline_day <= ?", params: [.integer(day)]))
    #expect(FilterCompiler.compile(.when(.onOrAfter(1)), today: today) == SQLFragment(sql: "t.when_day >= ?", params: [.integer(day + 1)]))
    #expect(FilterCompiler.compile(.when(.between(-1, 7)), today: today) == SQLFragment(sql: "t.when_day BETWEEN ? AND ?", params: [.integer(day - 1), .integer(day + 7)]))
    #expect(FilterCompiler.compile(.hasTag(TagID("g")), today: today) == SQLFragment(
        sql: "EXISTS (SELECT 1 FROM task_tags x JOIN tags g ON g.id = x.tag_id AND g.deleted = 0 WHERE x.task_id = t.id AND x.tag_id = ? AND x.present = 1)",
        params: [.text("g")]))
    #expect(FilterCompiler.compile(.parent(nil), today: today) == SQLFragment(sql: "tt.parent IS NULL", params: []))
    #expect(FilterCompiler.compile(.parent(TaskID("p")), today: today) == SQLFragment(sql: "tt.parent = ?", params: [.text("p")]))
    #expect(FilterCompiler.compile(.listedIn(ViewID("v")), today: today) == SQLFragment(
        sql: "EXISTS (SELECT 1 FROM view_items v WHERE v.view_id = ? AND v.task_id = t.id AND v.present = 1)",
        params: [.text("v")]))
    #expect(FilterCompiler.compile(.trashed(true), today: today) == SQLFragment(sql: "tt.trashed = ?", params: [.integer(1)]))
    #expect(FilterCompiler.compile(.and([]), today: today).sql == "1")
    #expect(FilterCompiler.compile(.or([]), today: today).sql == "0")
    #expect(FilterCompiler.compile(.not(.trashed(true)), today: today) == SQLFragment(sql: "NOT COALESCE((tt.trashed = ?), 0)", params: [.integer(1)]))
    let combined = FilterCompiler.compile(.and([.status([.open]), .or([.when(.empty), .deadline(.empty)])]), today: today)
    #expect(combined == SQLFragment(sql: "(t.status IN (?) AND (t.when_day IS NULL OR t.deadline_day IS NULL))", params: [.integer(0)]))
}

/// An offset is a number out of a stored filter, so it is as arbitrary as anything else another device
/// wrote (#34): the bound saturates instead of trapping, and it stays on the side of today the offset
/// asked for, which is what makes the comparison still mean what the filter said.
@Test func anOffsetPastTheCalendarSaturatesInsteadOfTrapping() throws {
    // A bound past every day a column can hold, on the side of today the offset asked for, is what keeps
    // `<=` and `>=` meaning what the filter said once the arithmetic can no longer reach the day itself.
    #expect(FilterCompiler.compile(.when(.onOrBefore(.max)), today: today) == SQLFragment(sql: "t.when_day <= ?", params: [.integer(.max)]))
    // Backwards the sum does not overflow at all \u2014 today is a positive day count, so `Int64.min` plus it
    // still fits \u2014 and what the bound has to be is past every day a column can hold, not the type's floor.
    let back = FilterCompiler.compile(.when(.onOrAfter(.min)), today: today)
    #expect(back.sql == "t.when_day >= ?" && (back.params.first?.int64 ?? 0) < Int64(Int32.min))
    #expect(FilterCompiler.compile(.deadline(.between(.min, .max)), today: today).params.last == .integer(.max))
    #expect(try Filter(json: "{\"day\":{\"kind\":\"on\",\"offset\":5000000000},\"kind\":\"when\"}") == .when(.on(5_000_000_000)))
}

@Test func trashIsExcludedUnlessTheFilterMentionsIt() {
    #expect(FilterCompiler.mentionsTrashed(.and([.status([.open]), .not(.trashed(false))])))
    #expect(!FilterCompiler.mentionsTrashed(.or([.status([.open]), .when(.empty)])))
    #expect(FilterCompiler.whereClause(.status([.open]), today: today) == SQLFragment(sql: "(t.status IN (?)) AND tt.trashed = 0", params: [.integer(0)]))
    #expect(FilterCompiler.whereClause(.trashed(true), today: today) == SQLFragment(sql: "tt.trashed = ?", params: [.integer(1)]))
}

@Test func orderByPutsEmptyDaysLastAndEndsWithRankAndID() {
    #expect(FilterCompiler.orderBy([]) == "t.rank, t.id")
    #expect(FilterCompiler.orderBy([SortKey(.when)]) == "(t.when_day IS NULL), t.when_day ASC, t.rank, t.id")
    #expect(FilterCompiler.orderBy([SortKey(.completed, descending: true), SortKey(.title)]) == "(t.completed_at IS NULL), t.completed_at DESC, t.title COLLATE NOCASE ASC, t.rank, t.id")
    #expect(FilterCompiler.orderBy([SortKey(.rank, descending: true)]) == "t.rank DESC, t.id")
}

@Test func everyConditionKindProducesValidSQL() throws {
    let store = try makeStore()
    let kinds: [Filter] = [
        .status([.open]), .when(.empty), .when(.on(0)), .deadline(.onOrBefore(1)), .when(.onOrAfter(-1)), .when(.between(0, 3)),
        .hasTag(TagID("g")), .parent(nil), .parent(TaskID("p")), .listedIn(ViewID("v")), .trashed(true),
        .and([.status([.open]), .not(.when(.empty))]), .or([]), .not(.and([])),
    ]
    for filter in kinds {
        let clause = FilterCompiler.whereClause(filter, today: today)
        let rows = try store.sql { () throws(SQLiteError) in
            try store.db.rows("SELECT count(*) FROM tasks t JOIN task_tree tt ON tt.id = t.id WHERE t.deleted = 0 AND (\(clause.sql))", clause.params)
        }
        #expect(rows == [[.integer(0)]], "\(filter)")
    }
}

/// The compiler names a column per sort field, and a name the schema does not have fails when the
/// statement is prepared rather than when a list is drawn.
@Test func everySortFieldProducesValidSQL() throws {
    let store = try makeStore()
    for field in SortField.allCases {
        let order = FilterCompiler.orderBy([SortKey(field, descending: true)])
        let rows = try store.sql { () throws(SQLiteError) in
            try store.db.rows("SELECT t.id FROM tasks t JOIN task_tree tt ON tt.id = t.id ORDER BY \(order)", [])
        }
        #expect(rows.isEmpty, "\(field)")
    }
}

/// A filter is an `indirect enum` whose depth is whatever a peer wrote into the view row, and both
/// Foundation's JSON scanner and its decoder walk it recursively: on wasm32, where the stack is 64 KiB,
/// a filter 68 levels deep traps inside the decoder and a document a few hundred levels deep traps inside
/// the scanner, before any type of this module is reached. A trap is not catchable and the view is read on
/// every open, so the depth is counted before the decoder sees the bytes (#34).
@Test func aFilterNestedDeeperThanTheBoundIsRefusedInsteadOfExhaustingTheStack() throws {
    func nested(_ depth: Int) -> String {
        var json = "{\"kind\":\"trashed\",\"value\":true}"
        for _ in 0..<depth { json = "{\"filter\":\(json),\"kind\":\"not\"}" }
        return json
    }
    // At the bound everything the core does with a filter still works on both platforms.
    let deepest = try Filter(json: nested(31))
    #expect(try deepest.json() == nested(31))
    #expect(FilterCompiler.whereClause(deepest, today: today).params == [.integer(1)])
    for json in [nested(32), nested(500), String(repeating: "[", count: 500)] {
        var caught: FilterError?
        do { _ = try Filter(json: json) } catch { caught = error }
        if case .malformed = caught {} else { Issue.record("expected malformed, got \(String(describing: caught))") }
    }
    // A filter the app itself builds is held to the same bound, because a filter that is written and then
    // refused on every read is a view the person cannot open and cannot fix. A group costs two levels.
    var groups: Filter = .trashed(true)
    for _ in 0..<15 { groups = .and([groups]) }
    #expect(try Filter(json: groups.json()) == groups)
    #expect(throws: FilterError.malformed("nested deeper than 32 levels")) { try Filter.and([groups]).json() }
    // A brace inside a string is text and not nesting, which is the whole reason the count is written by
    // hand: an id or a title that holds one must not read as a document the core refuses.
    let braces = Filter.hasTag(TagID("{[\"\\"))
    #expect(try Filter(json: braces.json()) == braces)
    var caught: FilterError?
    do { _ = try SortKey.parse(json: String(repeating: "[", count: 500)) } catch { caught = error }
    if case .malformed = caught {} else { Issue.record("expected malformed, got \(String(describing: caught))") }
}

/// The fragments above are strings until something runs them over rows. This is the test that does, through
/// the loader Task 9 hands them to, and it pins the two rules a wrong fragment breaks silently: what a
/// negation answers for a task whose column is empty, and that trash stays out unless the filter asks.
@Test func filtersSelectRowsThroughTheLoader() throws {
    let store = try makeStore()
    let tag = try store.createTag(title: "home")
    let dated = try store.createTask(NewTask(title: "dated", when: today, tags: [tag]))
    _ = try store.createTask(NewTask(title: "undated"))
    _ = try store.createTask(NewTask(title: "child", parent: dated))
    let gone = try store.createTask(NewTask(title: "gone"))
    try store.trash(task: gone)

    func titles(_ filter: Filter) throws -> [String] {
        let clause = FilterCompiler.whereClause(filter, today: today)
        return try store.loadTasks(where: clause.sql, clause.params, orderBy: "t.created_at, t.id").map(\.title)
    }
    #expect(try titles(.when(.on(0))) == ["dated"])
    // A task with no `when` is not one that is due today, so the negation has to return it: in SQL
    // `NOT (NULL = ?)` is NULL and a NULL condition drops the row instead.
    #expect(try titles(.not(.when(.on(0)))) == ["undated", "child"])
    #expect(try titles(.not(.parent(dated))) == ["dated", "undated"])
    #expect(try titles(.and([])) == ["dated", "undated", "child"])
    #expect(try titles(.trashed(true)) == ["gone"])
    #expect(try titles(.hasTag(tag)) == ["dated"])
    // A deleted tag takes the tasks it carried out of the filter by the reading rule, not by a write.
    try store.delete(tag: tag)
    #expect(try titles(.hasTag(tag)) == [])
}
