import SQLiteKit

struct SQLFragment: Equatable {
    let sql: String
    let params: [Value]
}

/// Turns a filter tree into one WHERE fragment over `tasks t JOIN task_tree tt`.
enum FilterCompiler {
    /// How `compile` writes a condition that SQLite could drive a statement from. A count and a view's read choose the
    /// one condition they are driven by themselves (`DriverChooser`, #153, #155) and write the others so that the
    /// planner cannot take them; a statement with no such condition writes every one plainly and leaves the choice of
    /// an index to the planner.
    enum Form {
        /// As a view's read writes them: a column compared as it is, and a tag and a pin as a correlated `EXISTS`,
        /// which SQLite answers once per row it reaches.
        case plain
        /// As `plain`, but a tag and a pin as the list of the tasks it holds, `t.id IN (SELECT …)`: SQLite builds
        /// the list once per statement, and can look the tasks up by id from it.
        case lists
        /// Off every index: a column behind a unary `+`, which SQLite compares as it is but cannot search an index
        /// by, and a tag and a pin as the correlated `EXISTS`, which it answers for each row it reaches. The trash is
        /// left as it is. Where a rule asks for the trash among the conditions it asks for all of, the count's own
        /// `tt.trashed = 0` beside it makes the two a comparison of constants, which SQLite makes once before the
        /// loop, so the count reads no row whichever index the planner opened, as the Trash's count does
        /// (`EXPLAIN`, SQLite 3.53.4); anywhere else in a rule no index serves it.
        case unindexed
        /// As `plain`, but a tag as the list of the tasks it holds kept off every index, `+t.id IN (SELECT …)`, and
        /// written after every condition of its conjunction and every branch of its disjunction that names no tag. A
        /// read with no driver of its own writes its tags so (`ReadCompiler`, #155): SQLite builds the list once per
        /// statement where it answers the correlated `EXISTS` once per row, and no plan can take the list for a driver.
        /// It tests an uncorrelated list in the place it is written, while it moves a correlated `EXISTS` behind the
        /// other conditions, so the list goes last for SQLite to test the cheaper conditions first: in #155's
        /// measurement at 50,000 tasks a rule asking for open tasks, a tag and a deadline within a month read in 3.49
        /// ms with the list written first and 1.99 with it last, where the `EXISTS` took 2.49.
        case tagListsLast
    }

    /// The fragment a view uses: the filter, plus `tt.trashed = 0` unless the filter mentions trash itself.
    static func whereClause(_ filter: Filter, today: Day, form: Form = .plain) -> SQLFragment {
        let fragment = compile(filter, today: today, form: form)
        guard !mentionsTrashed(filter) else { return fragment }
        return SQLFragment(sql: "(\(fragment.sql)) AND tt.trashed = 0", params: fragment.params)
    }

    /// The fragment of a union of views' reads: each rule as `whereClause` writes it, with its own exclusion of the
    /// Trash and in parentheses of its own, and the reads joined by `or`. One rule is that rule's read. A folder
    /// holds what its lists hold, so a list whose rule names the Trash reads it there and a list whose rule does not
    /// still leaves it out: an exclusion written once over a disjunction would be dropped for every rule as soon as
    /// one named the Trash.
    static func whereClause(anyOf rules: [Filter], today: Day, form: Form = .plain) -> SQLFragment {
        let reads = rules.map { rule in
            let read = whereClause(rule, today: today, form: form)
            return SQLFragment(sql: "(\(read.sql))", params: read.params)
        }
        return joined(reads, separator: " OR ", empty: "0")
    }

    static func compile(_ filter: Filter, today: Day, form: Form = .plain) -> SQLFragment {
        switch filter {
        case .status(let statuses):
            // No status matches nothing. An empty `IN ()` is not SQL, and a filter that names no status is
            // one a person emptied rather than one that means "any".
            guard !statuses.isEmpty else { return SQLFragment(sql: "0", params: []) }
            let marks = Array(repeating: "?", count: statuses.count).joined(separator: ", ")
            return SQLFragment(sql: "\(column("t.status", form)) IN (\(marks))", params: statuses.map { .integer($0.rawValue) })
        case .when(let condition):
            return day(column("t.when_day", form), condition, today)
        case .deadline(let condition):
            return day(column("t.deadline_day", form), condition, today)
        case .hasTag(let tag):
            let list = "t.id IN (SELECT x.task_id FROM task_tags x JOIN tags g ON g.id = x.tag_id AND g.deleted = 0 WHERE x.tag_id = ? AND x.present = 1)"
            switch form {
            case .plain, .unindexed:
                return SQLFragment(
                    sql: "EXISTS (SELECT 1 FROM task_tags x JOIN tags g ON g.id = x.tag_id AND g.deleted = 0 WHERE x.task_id = t.id AND x.tag_id = ? AND x.present = 1)",
                    params: [.text(tag.rawValue)]
                )
            case .lists:
                return SQLFragment(sql: list, params: [.text(tag.rawValue)])
            case .tagListsLast:
                return SQLFragment(sql: "+" + list, params: [.text(tag.rawValue)])
            }
        case .parent(let parent):
            guard let parent else { return SQLFragment(sql: "\(column("tt.parent", form)) IS NULL", params: []) }
            return SQLFragment(sql: "\(column("tt.parent", form)) = ?", params: [.text(parent.rawValue)])
        case .listedIn(let view):
            guard form == .lists else {
                return SQLFragment(sql: "EXISTS (SELECT 1 FROM view_items v WHERE v.view_id = ? AND v.task_id = t.id AND v.present = 1)", params: [.text(view.rawValue)])
            }
            return SQLFragment(sql: "t.id IN (SELECT v.task_id FROM view_items v WHERE v.view_id = ? AND v.present = 1)", params: [.text(view.rawValue)])
        case .trashed(let flag):
            // The flag is written into the SQL instead of bound, the way `whereClause` writes the implicit
            // exclusion one screen above. It is a `Bool`, so there is nothing to inject, and it is what lets
            // `task_tree`'s index be a partial one over the trashed rows alone: SQLite can see that a literal
            // `1` implies the index's `WHERE trashed = 1`, while it cannot prove it of a parameter. A plain
            // index over the whole column would be usable by the implicit `tt.trashed = 0` of every other
            // view, and the planner takes it — driving the join from the 49,980 rows that are not trashed
            // instead of from the status index, which cost the Logbook 1.8 ms against 15.8 ms at 50,000 tasks.
            return SQLFragment(sql: "tt.trashed = \(flag ? 1 : 0)", params: [])
        // An empty group is the identity of its own operator, the way an empty sum is zero: nothing to
        // require matches everything, nothing to choose from matches nothing. Unlike the empty status list
        // above, neither is a list a person emptied \u2014 a view with no filter is `nil` and not `and([])`.
        case .and(let parts):
            return combine(parts, separator: " AND ", empty: "1", today: today, form: form)
        case .or(let parts):
            return combine(parts, separator: " OR ", empty: "0", today: today, form: form)
        case .not(let inner):
            // `when_day`, `deadline_day` and `tt.parent` are nullable, and in SQL `NOT (NULL = ?)` is NULL,
            // which drops the row: a negation would lose exactly the tasks with no day and no parent, which
            // are the ones it is there to return. Reading an unknown as false first makes it a complement,
            // and it changes nothing for the conditions that cannot be NULL.
            let fragment = compile(inner, today: today, form: form)
            return SQLFragment(sql: "NOT COALESCE((\(fragment.sql)), 0)", params: fragment.params)
        }
    }

    /// A column as `form` compares it: behind a unary `+`, which leaves the value as it is and the index unused.
    private static func column(_ name: String, _ form: Form) -> String {
        form == .unindexed ? "+" + name : name
    }

    /// Every tag a filter names, negated or not, at any depth, once for each time it names it.
    static func tags(of filter: Filter) -> [TagID] {
        switch filter {
        case .hasTag(let tag): return [tag]
        case .and(let parts), .or(let parts): return parts.flatMap(tags(of:))
        case .not(let inner): return tags(of: inner)
        case .status, .when, .deadline, .parent, .listedIn, .trashed: return []
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

    /// A group's parts compiled and joined, in the order written, or with the parts that name a tag last where `form`
    /// writes its tags last.
    private static func combine(_ parts: [Filter], separator: String, empty: String, today: Day, form: Form) -> SQLFragment {
        var ordered = parts
        if form == .tagListsLast {
            var untagged: [Filter] = []
            var tagged: [Filter] = []
            for part in parts {
                if tags(of: part).isEmpty { untagged.append(part) } else { tagged.append(part) }
            }
            ordered = untagged + tagged
        }
        return joined(ordered.map { compile($0, today: today, form: form) }, separator: separator, empty: empty)
    }

    /// Fragments joined by an operator, in parentheses of their own; none is the operator's identity, `empty`.
    static func joined(_ parts: [SQLFragment], separator: String, empty: String) -> SQLFragment {
        guard !parts.isEmpty else { return SQLFragment(sql: empty, params: []) }
        return SQLFragment(sql: "(" + parts.map(\.sql).joined(separator: separator) + ")", params: parts.flatMap(\.params))
    }
}
