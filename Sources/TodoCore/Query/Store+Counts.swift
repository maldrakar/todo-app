// Sources/TodoCore/Query/Store+Counts.swift
import SQLiteKit

extension Store {
    /// The number of open tasks each view selects, which its row draws beside its title (spec section 4).
    /// A count for every view that has one; absent for an area, a view this app cannot read, and a folder with
    /// nothing to count. A zero is a count like any other and is present.
    ///
    /// Every view with a count costs one statement, a folder too: a list with no rule counts the union of its
    /// children, each task once, so its statement asks for any of their conditions, and no ids travel from one
    /// statement to the next. Each statement is driven by one index, its rule's own where the rule has one
    /// (`CountCompiler`, #153).
    public func taskCounts(today: Day) throws(StoreError) -> [ViewID: Int] {
        var counts: [ViewID: Int] = [:]
        for count in try countStatements(today: today) {
            let rows = try sql { () throws(SQLiteError) in try db.rows(count.sql, count.params) }
            // SQLite counts in 64 bits and `Int` is 32 bits wide on wasm32, so a number the type cannot hold reads
            // as no count rather than a trap, the way a stored day the type cannot hold reads as no day.
            counts[count.view] = rows.first?.first?.int64.flatMap { Int(exactly: $0) }
        }
        return counts
    }

    /// The statement of every count `taskCounts` runs, by view, in the order it runs them.
    ///
    /// What each view counts is gathered from the leaves up in one pass over the tree order reversed, where every
    /// child comes before its parent: a list with a rule counts its rule, and a folder the rules of the lists
    /// under it, which each view hands up as one flat list, so the walk here never recurses and a folder's
    /// condition is as deep as its deepest rule and not as deep as the tree. SQLite's code generation still
    /// recurses over a wide disjunction (#152). Then the sizes of the tags any rule could be driven by are read,
    /// once for the call, and each statement is written.
    ///
    /// Assembled here, beside `viewStatement` and for its reason: `theCountStatementUsesTheIndexes` and
    /// `aCountIsDrivenByItsRulesOwnIndex` explain the query plans of exactly these statements, and a guard that
    /// explained a copy would pass while a count itself degraded into a scan.
    func countStatements(today: Day) throws(StoreError) -> [(view: ViewID, sql: String, params: [Value])] {
        var counted: [(view: ViewID, rules: [Filter])] = []
        var childRules: [ViewID: [Filter]] = [:]
        var candidates: Set<TagID> = []
        for view in try views().reversed() {
            guard let rules = Store.countedRules(of: view, children: childRules[view.id] ?? []) else { continue }
            counted.append((view.id, rules))
            if let filter = view.filter { candidates.formUnion(CountCompiler.candidateTags(of: filter)) }
            if let parent = view.parent { childRules[parent, default: []] += rules }
        }
        let sizes = try tagSizes(among: candidates)
        let compiler = CountCompiler(today: today, tagSizes: sizes.tags, openTasks: sizes.open)
        return counted.map { view, rules in
            let count = compiler.compile(rules)
            return (view, Store.countStatement(over: count.condition.sql, driven: count.driven), count.condition.params)
        }
    }

    /// The open tasks the status index holds, the trashed and the deleted among them, counted on the index alone.
    static let openTaskCountQuery = "SELECT count(*) FROM tasks WHERE status = 0"

    /// The tasks a tag holds, done, trashed and deleted ones among them, counted on the tag's partial index alone.
    static let tagSizeQuery = "SELECT count(*) FROM task_tags WHERE tag_id = ? AND present = 1"

    /// The sizes the choice of a tag's driver is made by (`CountCompiler`): the open tasks, and the tasks each of
    /// `candidates` holds. Read only when a rule offers a tag at all, each once, from an index and no table row: at
    /// 50,000 tasks a tag of 1,500 tasks in 0.02 ms and one of 25,000 in 0.3 ms, the open tasks in 0.13 to 0.58 ms.
    /// A read that fails fails the call, as any of its statements would; `count(*)` always answers one row, and a
    /// tag whose answer had none would be left out, which costs speed and never a count.
    private func tagSizes(among candidates: Set<TagID>) throws(StoreError) -> (open: Int64, tags: [TagID: Int64]) {
        guard !candidates.isEmpty else { return (0, [:]) }
        return try sql { () throws(SQLiteError) in
            let open = try db.rows(Store.openTaskCountQuery).first?.first?.int64 ?? 0
            var tags: [TagID: Int64] = [:]
            for tag in candidates {
                tags[tag] = try db.rows(Store.tagSizeQuery, [.text(tag.rawValue)]).first?.first?.int64
            }
            return (open, tags)
        }
    }

    /// The statement one view's count runs, over the condition of what the view counts: the open tasks that
    /// are neither deleted nor in the trash, by conditions of the count's own. A view's read takes the trash's
    /// exclusion from `FilterCompiler.whereClause`, which leaves it out of a rule that names the trash, so a
    /// count built on the read would count the Trash's tasks; the condition here is compiled bare, and the
    /// statement excludes the trash itself. By its two conditions the Logbook and the Trash count nothing,
    /// since nothing in either is open (spec section 4). When a condition of the rule's own drives the count,
    /// the count's own status condition is kept off the status index by a unary `+`, so that it cannot drive.
    private static func countStatement(over condition: String, driven: Bool) -> String {
        "SELECT count(*) FROM tasks t JOIN task_tree tt ON tt.id = t.id WHERE t.deleted = 0 AND \(driven ? "+" : "")t.status = 0 AND tt.trashed = 0 AND (\(condition))"
    }

    /// The rules one view counts any of, out of those its children count. A list with a rule counts its rule;
    /// a list with none counts the rules of its children, a child with nothing to count adding nothing, and has
    /// nothing to count when none of them has; an area, which selects nothing, and a view this app cannot read,
    /// whose rule is unknown, have no count and add nothing to the view above them.
    private static func countedRules(of view: TaskView, children: [Filter]) -> [Filter]? {
        guard view.kind == .list, view.needsNewerApp == nil else { return nil }
        if let filter = view.filter { return [filter] }
        return children.isEmpty ? nil : children
    }
}
