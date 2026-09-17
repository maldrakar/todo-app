import SQLiteKit

struct SQLFragment: Equatable {
    let sql: String
    let params: [Value]
}

/// Turns a filter tree into one WHERE fragment over `tasks t JOIN task_tree tt`.
enum FilterCompiler {
    /// The fragment a view uses: the filter, plus `tt.trashed = 0` unless the filter mentions trash itself.
    static func whereClause(_ filter: Filter, today: Day) -> SQLFragment {
        let fragment = compile(filter, today: today)
        guard !mentionsTrashed(filter) else { return fragment }
        return SQLFragment(sql: "(\(fragment.sql)) AND tt.trashed = 0", params: fragment.params)
    }

    static func compile(_ filter: Filter, today: Day) -> SQLFragment {
        switch filter {
        case .status(let statuses):
            // No status matches nothing. An empty `IN ()` is not SQL, and a filter that names no status is
            // one a person emptied rather than one that means "any".
            guard !statuses.isEmpty else { return SQLFragment(sql: "0", params: []) }
            let marks = Array(repeating: "?", count: statuses.count).joined(separator: ", ")
            return SQLFragment(sql: "t.status IN (\(marks))", params: statuses.map { .integer($0.rawValue) })
        case .when(let condition):
            return day("t.when_day", condition, today)
        case .deadline(let condition):
            return day("t.deadline_day", condition, today)
        case .hasTag(let tag):
            return SQLFragment(
                sql: "EXISTS (SELECT 1 FROM task_tags x JOIN tags g ON g.id = x.tag_id AND g.deleted = 0 WHERE x.task_id = t.id AND x.tag_id = ? AND x.present = 1)",
                params: [.text(tag.rawValue)]
            )
        case .parent(let parent):
            guard let parent else { return SQLFragment(sql: "tt.parent IS NULL", params: []) }
            return SQLFragment(sql: "tt.parent = ?", params: [.text(parent.rawValue)])
        case .listedIn(let view):
            return SQLFragment(sql: "EXISTS (SELECT 1 FROM view_items v WHERE v.view_id = ? AND v.task_id = t.id AND v.present = 1)", params: [.text(view.rawValue)])
        case .trashed(let flag):
            return SQLFragment(sql: "tt.trashed = ?", params: [Value(flag)])
        // An empty group is the identity of its own operator, the way an empty sum is zero: nothing to
        // require matches everything, nothing to choose from matches nothing. Unlike the empty status list
        // above, neither is a list a person emptied \u2014 a view with no filter is `nil` and not `and([])`.
        case .and(let parts):
            return combine(parts, separator: " AND ", empty: "1", today: today)
        case .or(let parts):
            return combine(parts, separator: " OR ", empty: "0", today: today)
        case .not(let inner):
            // `when_day`, `deadline_day` and `tt.parent` are nullable, and in SQL `NOT (NULL = ?)` is NULL,
            // which drops the row: a negation would lose exactly the tasks with no day and no parent, which
            // are the ones it is there to return. Reading an unknown as false first makes it a complement,
            // and it changes nothing for the conditions that cannot be NULL.
            let fragment = compile(inner, today: today)
            return SQLFragment(sql: "NOT COALESCE((\(fragment.sql)), 0)", params: fragment.params)
        }
    }

    static func mentionsTrashed(_ filter: Filter) -> Bool {
        switch filter {
        case .trashed: return true
        case .and(let parts), .or(let parts): return parts.contains(where: mentionsTrashed)
        case .not(let inner): return mentionsTrashed(inner)
        default: return false
        }
    }

    /// ORDER BY for a view: the requested keys, empty days last, then rank and id for a stable order.
    static func orderBy(_ sort: [SortKey]) -> String {
        var parts: [String] = []
        for key in sort {
            let direction = key.descending ? "DESC" : "ASC"
            // A task with no day belongs at the end of a list sorted by that day, in both directions: the
            // extra key sorts the absent ones after the present ones before the day itself is compared.
            switch key.field {
            case .when: parts += ["(t.when_day IS NULL)", "t.when_day \(direction)"]
            case .deadline: parts += ["(t.deadline_day IS NULL)", "t.deadline_day \(direction)"]
            case .completed: parts += ["(t.completed_at IS NULL)", "t.completed_at \(direction)"]
            // NOCASE folds ASCII and nothing else, which is all a build without ICU can do (ADR-0001): an
            // English list ignores case, a Russian one still sorts the capitals first.
            case .title: parts.append("t.title COLLATE NOCASE \(direction)")
            case .created: parts.append("t.created_at \(direction)")
            case .updated: parts.append("t.updated_at \(direction)")
            case .rank: parts.append("t.rank \(direction)")
            }
        }
        // The tail that makes the order total: two tasks with the same day still come out in a fixed order,
        // and two ranks that two offline devices computed alike are separated by the id. A sort that already
        // names the rank has it once.
        if !sort.contains(where: { $0.field == .rank }) { parts.append("t.rank") }
        parts.append("t.id")
        return parts.joined(separator: ", ")
    }

    private static func day(_ column: String, _ condition: DayCondition, _ today: Day) -> SQLFragment {
        // The bound as the column holds it. An offset comes out of a stored filter, so it is as arbitrary as
        // anything else another device wrote: `Day.advanced(by:)` narrows it to `Int32` and would trap on
        // every read of the view (#34), while a bound computed in `Int64` saturates at a day no column
        // holds, which is the side of today the offset asked for and so still compares the way it read.
        func at(_ offset: Int64) -> Value {
            let (bound, overflow) = Int64(today.daysSinceEpoch).addingReportingOverflow(offset)
            return .integer(overflow ? (offset > 0 ? Int64.max : Int64.min) : bound)
        }
        switch condition {
        case .empty: return SQLFragment(sql: "\(column) IS NULL", params: [])
        case .on(let n): return SQLFragment(sql: "\(column) = ?", params: [at(n)])
        case .onOrBefore(let n): return SQLFragment(sql: "\(column) <= ?", params: [at(n)])
        case .onOrAfter(let n): return SQLFragment(sql: "\(column) >= ?", params: [at(n)])
        case .between(let a, let b): return SQLFragment(sql: "\(column) BETWEEN ? AND ?", params: [at(a), at(b)])
        }
    }

    private static func combine(_ parts: [Filter], separator: String, empty: String, today: Day) -> SQLFragment {
        guard !parts.isEmpty else { return SQLFragment(sql: empty, params: []) }
        let compiled = parts.map { compile($0, today: today) }
        return SQLFragment(sql: "(" + compiled.map(\.sql).joined(separator: separator) + ")", params: compiled.flatMap(\.params))
    }
}
