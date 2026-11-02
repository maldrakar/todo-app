// Sources/TodoCore/Query/Store+Done.swift
import SQLiteKit

extension Store {
    /// The tasks the page's rules select once their status conditions are lifted, no longer open and completed at
    /// or after `since`, the clock's milliseconds; newest first. Empty for a view with no rule and no lists.
    ///
    /// This is the Done strip under a list (spec section 3): the rules are the page's, the view's own and each
    /// child's, a folder inside contributing its lists' as its section does, so a task finished in a list inside is
    /// in the strip of the list around it. A list's rule asks for the open tasks it draws as rows, and the strip is
    /// the tasks that stopped being open, so the status conditions come out of the rules before they are read. `since`
    /// is an instant and not a day, because the core has no time zone (ADR-0001): the platform knows when its day
    /// began.
    ///
    /// A core statement and not a stored rule: no condition of a filter is about the completion time, and a new kind
    /// of condition written into a view would read as `needsNewerApp` on an app older than it (ADR-0004).
    public func done(in viewID: ViewID, since: Int64, today: Day) throws(StoreError) -> [TodoTask] {
        let view = try readableView(viewID)
        let rules = (view.filter.map { [$0] } ?? []) + (try childSections(of: viewID)).flatMap(\.rules)
        guard !rules.isEmpty else { return [] }
        let statement = Store.doneStatement(rules: rules, since: since, today: today)
        return try loadTasks(sql: statement.sql, statement.params)
    }

    /// The statement the done read runs: the rules lifted and joined by `or`, compiled bare, under the read's own
    /// conditions, a status no longer open and a completion at or after `since`, and the Trash left out unless a rule
    /// names it, as a view's read leaves it out (`FilterCompiler.whereClause`). The completion bound drives it from
    /// `tasks_completed` (`Schema.version6`) unless SQLite, which has no statistics of the store, takes a condition of
    /// a rule's own for a narrower one: an equality, such as the Inbox's empty day or a project's parent.
    ///
    /// Assembled here rather than inside the read, so that `theDoneStatementUsesTheCompletedIndex` explains the query
    /// plan of exactly this statement, as `builtInViewsUseIndexes` explains `viewStatement`'s.
    static func doneStatement(rules: [Filter], since: Int64, today: Day) -> (sql: String, params: [Value]) {
        let lifted = Filter.or(rules.map(Store.liftingStatus))
        let condition = FilterCompiler.compile(lifted, today: today)
        let trash = FilterCompiler.mentionsTrashed(lifted) ? "" : " AND tt.trashed = 0"
        let clause = "(\(condition.sql)) AND t.status != 0 AND t.completed_at >= ?\(trash)"
        return (Store.taskQuery(where: clause, orderBy: "t.completed_at DESC, t.id", limit: nil), condition.params + [.integer(since)])
    }

    /// A rule with every status condition lifted out of it: each becomes `and([])`, which is true, so the rule says
    /// what it says of a task but not of its status. Inside a `not` that makes the branch false, so a rule that asks
    /// for what is not cancelled has an empty strip, which is accepted: no rule the app seeds or makes is one.
    /// Recursive, as every walk over a filter is, since the store refuses one deeper than `maximumDepth`.
    private static func liftingStatus(_ rule: Filter) -> Filter {
        switch rule {
        case .status: .and([])
        case .and(let parts): .and(parts.map(liftingStatus))
        case .or(let parts): .or(parts.map(liftingStatus))
        case .not(let inner): .not(liftingStatus(inner))
        case .when, .deadline, .hasTag, .parent, .listedIn, .trashed: rule
        }
    }
}
