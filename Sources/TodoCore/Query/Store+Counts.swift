// Sources/TodoCore/Query/Store+Counts.swift
import SQLiteKit

extension Store {
    /// The number of open tasks each view selects, which its row draws beside its title (spec section 4).
    /// A count for every view that has one; absent for an area, a view this app cannot read, and a folder with
    /// nothing to count. A zero is a count like any other and is present.
    ///
    /// Every view with a count costs one statement, a folder too: a list with no rule counts the union of its
    /// children, each task once, so its statement asks for any of their conditions, and no ids travel from one
    /// statement to the next. The conditions are built from the leaves up in one pass over the tree order
    /// reversed, where every child comes before its parent, and each is text made of its children's text: the
    /// walk here never recurses, while the expression is as deep as the tree, and SQLite's code generation
    /// recurses over it (#152).
    public func taskCounts(today: Day) throws(StoreError) -> [ViewID: Int] {
        var counts: [ViewID: Int] = [:]
        var childFragments: [ViewID: [SQLFragment]] = [:]
        for view in try views().reversed() {
            guard let fragment = Store.countFragment(of: view, children: childFragments[view.id] ?? [], today: today) else { continue }
            let rows = try sql { () throws(SQLiteError) in try db.rows(Store.countStatement(where: fragment.sql), fragment.params) }
            // SQLite counts in 64 bits and `Int` is 32 bits wide on wasm32, so a number the type cannot hold reads
            // as no count rather than a trap, the way a stored day the type cannot hold reads as no day.
            counts[view.id] = rows.first?.first?.int64.flatMap { Int(exactly: $0) }
            if let parent = view.parent { childFragments[parent, default: []].append(fragment) }
        }
        return counts
    }

    /// The statement one view's count runs, over the condition of what the view counts: the open tasks that
    /// are neither deleted nor in the trash, by conditions of the count's own. A view's read takes the trash's
    /// exclusion from `FilterCompiler.whereClause`, which leaves it out of a rule that names the trash, so a
    /// count built on the read would count the Trash's tasks; the condition here is `compile`'s, bare, and the
    /// statement excludes the trash itself. By its two conditions the Logbook and the Trash count nothing,
    /// since nothing in either is open (spec section 4).
    ///
    /// Assembled here, beside `viewStatement` and for its reason: `theCountStatementUsesTheIndexes` explains
    /// the query plan of exactly this statement, and a guard that explained a copy would pass while the count
    /// itself degraded into a scan.
    static func countStatement(where fragment: String) -> String {
        "SELECT count(*) FROM tasks t JOIN task_tree tt ON tt.id = t.id WHERE t.deleted = 0 AND t.status = 0 AND tt.trashed = 0 AND (\(fragment))"
    }

    /// What one view counts, as a condition over `tasks t JOIN task_tree tt`, out of what its children count.
    /// A list with a rule counts what the rule selects; a list with none counts what any of its children
    /// counts, a child with nothing to count adding nothing, and has nothing to count when none of them has;
    /// an area, which selects nothing, and a view this app cannot read, whose rule is unknown, have no count
    /// and add nothing to the view above them.
    private static func countFragment(of view: TaskView, children: [SQLFragment], today: Day) -> SQLFragment? {
        guard view.kind == .list, view.needsNewerApp == nil else { return nil }
        if let filter = view.filter { return FilterCompiler.compile(filter, today: today) }
        guard !children.isEmpty else { return nil }
        return SQLFragment(sql: children.map { "(\($0.sql))" }.joined(separator: " OR "), params: children.flatMap(\.params))
    }
}
