import SQLiteKit

/// Writes what one view counts so that a single index drives its statement: the index of a condition of the
/// rule's own where the rule has one (#153).
///
/// Every count carries its own `t.status = 0`, and SQLite, which has no statistics of this store because the store
/// never runs `ANALYZE`, takes the status index for it as readily as any other: so every count walked every open
/// task and tested its rule on each, a project's five tasks as dearly as the Inbox's thousands. The choice is made
/// here instead, by the shape of the rule. Among the conditions the rule asks for all of, one drives, the first of
/// the best `Driver`, and is written in the form its index serves; every other condition of the statement, the
/// count's own status among them, is written off its index (`FilterCompiler.Form.unindexed`), so the planner has
/// one index to take and no tie between its default estimates to settle. A rule with no such condition is written
/// as #144 wrote it, and the status index drives it, as it drives every built-in's count.
///
/// Every walk here recurses over one filter, as `FilterCompiler.compile` does, and the bound on a stored filter's
/// depth (`maximumDepth`) holds it; a folder's rules come in flat, so none recurses over the tree of views.
struct CountCompiler {
    let today: Day
    /// The tags that hold few enough tasks to drive a count, as `Store` measured them for this call. Any other tag is
    /// no driver: its index would walk more tasks, done ones among them, than the walk of the open ones it replaces.
    let smallTags: Set<TagID>

    /// What a condition can drive a count by, best first: the fewer tasks its index gives for any store, the
    /// earlier. A manual list holds the tasks a person placed by hand, a project its own, a day one day's, a short
    /// range a few days', and a tag is only offered when it is small; a disjunction is read through each branch's.
    private enum Driver: Int, Comparable {
        case pins, project, day, days, tag, disjunction

        static func < (lhs: Driver, rhs: Driver) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// A range of days drives only when it spans fewer days than this. A wide range holds most dated tasks, and its
    /// index then walks them all: in #153's measurement at 50,000 tasks, `when` from a year ago to two months ahead
    /// counted 2.8 times slower driven by the day index than by the walk of the open tasks, while every range it
    /// measured up to 29 days long was faster driven. A month is a judgement between the two, not a crossover.
    private static let widestDrivingRange: Int64 = 31

    /// The condition of what a view counts, over `tasks t JOIN task_tree tt`, and whether a condition of the rule's
    /// own drives it, which is when the count's own status condition has to be kept off its index.
    ///
    /// `rules` are what the view counts any of: a list's rule, or the rules of the lists under a folder. They are
    /// regrouped before a driver is chosen (`union`), and a count with none is written as the rules are, as a
    /// folder's disjunction of them when there are several. Its tags and its pins are then written as the lists
    /// of their tasks, which SQLite builds once per statement where the correlated `EXISTS` probes once per open
    /// task, unless a day or a parent is among the conditions the rule asks for all of: SQLite tests those first,
    /// and the probes then run on the few rows left, which costs less than the list (Untagged 21.5 to 15.3 ms
    /// listed in #153's measurement, while a rule narrowed by a day was slower listed).
    func compile(_ rules: [Filter]) -> (condition: SQLFragment, driven: Bool) {
        if let condition = driven(Self.conjuncts(union(rules.flatMap(Self.disjuncts))), inDisjunction: false) {
            return (condition, true)
        }
        let rule = rules.count == 1 ? rules[0] : Filter.or(rules)
        let narrowed = Self.conjuncts(rule).contains { condition in
            switch condition {
            case .when, .deadline, .parent: return true
            case .status, .hasTag, .listedIn, .trashed, .and, .or, .not: return false
            }
        }
        return (FilterCompiler.compile(rule, today: today, form: narrowed ? .plain : .lists), false)
    }

    /// The tags whose size the choice of a driver for `rule` may ask about: the tags it asks for all of, and those
    /// each branch of a disjunction among them asks for all of. A conjunction that asks for a status other than
    /// open has no driver, so its tags are not asked about. A folder's rules are its lists', so the tags of every
    /// list's rule are all the tags any count asks about.
    static func candidateTags(of rule: Filter) -> [TagID] {
        let conditions = conjuncts(rule)
        guard !conditions.contains(where: excludesOpen) else { return [] }
        return conditions.flatMap { condition -> [TagID] in
            switch condition {
            case .hasTag(let tag): [tag]
            case .or: disjuncts(condition).flatMap(candidateTags(of:))
            case .status, .when, .deadline, .parent, .listedIn, .trashed, .and, .not: []
            }
        }
    }

    /// A disjunction of rules regrouped into one that selects the same tasks, so that a driver can be found for it.
    /// The conditions every rule asks for are taken out in front, `(a AND x) OR (a AND y)` as `a AND (x OR y)`, and
    /// when a rule asks for nothing more than those it absorbs the others, `a OR (a AND y)` as `a`; then the rules
    /// driven by the same condition are grouped under it (`grouped`). Both hold in SQL's logic of three values,
    /// where AND and OR distribute over each other and absorb as they do over two.
    private func union(_ rules: [Filter]) -> Filter {
        guard rules.count > 1 else { return rules.first ?? .or([]) }
        let lists = rules.map(Self.conjuncts)
        var shared: [Filter] = []
        for condition in lists[0] where !shared.contains(condition) && lists.allSatisfy({ $0.contains(condition) }) {
            shared.append(condition)
        }
        let rests = lists.map { $0.filter { !shared.contains($0) } }
        guard !rests.contains(where: \.isEmpty) else { return Self.and(shared) }
        return Self.and(shared + [grouped(rests)])
    }

    /// `(a AND x) OR (a AND y) OR (b AND z)` as `(a AND (x OR y)) OR (b AND z)`: the rules whose driver is the same
    /// condition become one branch driven by it, so that its index is read once and not once per rule. A rule with
    /// no driver is a branch of its own, and so is a rule no other shares its driver with.
    private func grouped(_ lists: [[Filter]]) -> Filter {
        var drivers: [Filter?] = []
        var members: [[[Filter]]] = []
        for list in lists {
            let driver = driverPosition(in: list, inDisjunction: true).map { list[$0] }
            if let driver, let group = drivers.firstIndex(of: driver) {
                members[group].append(list)
            } else {
                drivers.append(driver)
                members.append([list])
            }
        }
        return Self.or(zip(drivers, members).map { driver, lists in
            guard let driver, lists.count > 1 else { return Self.or(lists.map(Self.and)) }
            let rests = lists.map { $0.filter { $0 != driver } }
            guard !rests.contains(where: \.isEmpty) else { return driver }
            return .and([driver, Self.or(rests.map(Self.and))])
        })
    }

    /// A conjunction written with its driver in the form its index serves and every other condition off its index,
    /// or nil when it has no driver. `inDisjunction` says that it is a branch of a disjunction that drives.
    private func driven(_ conditions: [Filter], inDisjunction: Bool) -> SQLFragment? {
        guard let chosen = driverPosition(in: conditions, inDisjunction: inDisjunction) else { return nil }
        var written: [SQLFragment] = []
        for (position, condition) in conditions.enumerated() {
            guard position == chosen else {
                written.append(FilterCompiler.compile(condition, today: today, form: .unindexed))
                continue
            }
            guard let driving = driving(condition, inDisjunction: inDisjunction) else { return nil }
            written.append(driving)
        }
        return FilterCompiler.joined(written, separator: " AND ", empty: "1")
    }

    /// A driver in the form its index serves: a day and a range as the compiler writes them, a tag and a pin as the
    /// list of their tasks, which SQLite looks the tasks up from by id, and a project as its tree's parent. A
    /// disjunction is each branch driven in its turn; SQLite reads it by several indexes (`MULTI-INDEX OR`) only
    /// when every branch searches the same table, and every other driver searches `tasks t`, so inside one a
    /// project is the list of its tasks too. Nil for a condition that is no driver.
    private func driving(_ condition: Filter, inDisjunction: Bool) -> SQLFragment? {
        switch condition {
        case .listedIn, .hasTag:
            return FilterCompiler.compile(condition, today: today, form: .lists)
        case .when, .deadline:
            return FilterCompiler.compile(condition, today: today)
        case .parent(let parent?):
            guard inDisjunction else { return FilterCompiler.compile(condition, today: today) }
            return SQLFragment(sql: "t.id IN (SELECT p.id FROM task_tree p WHERE p.parent = ?)", params: [.text(parent.rawValue)])
        case .or:
            var branches: [SQLFragment] = []
            for branch in Self.disjuncts(condition) {
                guard let fragment = driven(Self.conjuncts(branch), inDisjunction: true) else { return nil }
                branches.append(fragment)
            }
            return FilterCompiler.joined(branches, separator: " OR ", empty: "0")
        case .status, .parent, .trashed, .and, .not:
            return nil
        }
    }

    /// Which of the conditions a conjunction asks for all of drives it: the first of the best driver, or none. A
    /// conjunction that asks for a status other than open has none, whatever else it asks for: it counts nothing,
    /// and with the count's own status condition left on its index SQLite compares the two constants before the
    /// loop and reads no row, which no driver could beat. `inDisjunction` says that the conjunction is a branch of
    /// a disjunction that drives.
    private func driverPosition(in conditions: [Filter], inDisjunction: Bool) -> Int? {
        guard !conditions.contains(where: Self.excludesOpen) else { return nil }
        var best: (position: Int, driver: Driver)?
        for (position, condition) in conditions.enumerated() {
            guard let driver = driver(condition, inDisjunction: inDisjunction) else { continue }
            if best.map({ driver < $0.driver }) ?? true { best = (position, driver) }
        }
        return best?.position
    }

    /// What a condition can drive a count by, if anything. An empty day and the root are each an equality to
    /// SQLite, and select most of a store; a range open at one end, a status, a negation and the trash select too
    /// much of it to be worth an index; a range of days drives only while it is shorter than a month. A disjunction
    /// drives only at the top of a count: SQLite reads a disjunction by its branches' indexes one level deep, and a
    /// disjunction inside a branch of another one would leave the planner no index but a scan of every task.
    private func driver(_ condition: Filter, inDisjunction: Bool) -> Driver? {
        switch condition {
        case .listedIn:
            return .pins
        case .parent(let parent):
            return parent == nil ? nil : .project
        case .when(.on), .deadline(.on):
            return .day
        case .when(.between(let from, let to)), .deadline(.between(let from, let to)):
            let (span, overflow) = to.subtractingReportingOverflow(from)
            return !overflow && span < Self.widestDrivingRange ? .days : nil
        case .hasTag(let tag):
            return smallTags.contains(tag) ? .tag : nil
        case .or:
            guard !inDisjunction else { return nil }
            let branches = Self.disjuncts(condition)
            return !branches.isEmpty && branches.allSatisfy({ driverPosition(in: Self.conjuncts($0), inDisjunction: true) != nil }) ? .disjunction : nil
        case .status, .when, .deadline, .trashed, .and, .not:
            return nil
        }
    }

    private static func excludesOpen(_ condition: Filter) -> Bool {
        guard case .status(let statuses) = condition else { return false }
        return !statuses.contains(.open)
    }

    /// The conditions a filter asks for all of, its nested conjunctions flattened: none for an empty one.
    private static func conjuncts(_ filter: Filter) -> [Filter] {
        guard case .and(let parts) = filter else { return [filter] }
        return parts.flatMap(conjuncts)
    }

    /// The conditions a filter asks for any of, its nested disjunctions flattened: none for an empty one.
    private static func disjuncts(_ filter: Filter) -> [Filter] {
        guard case .or(let parts) = filter else { return [filter] }
        return parts.flatMap(disjuncts)
    }

    /// A conjunction of conditions, and a single condition as itself.
    private static func and(_ conditions: [Filter]) -> Filter {
        conditions.count == 1 ? conditions[0] : .and(conditions)
    }

    /// A disjunction of conditions, and a single condition as itself.
    private static func or(_ conditions: [Filter]) -> Filter {
        conditions.count == 1 ? conditions[0] : .or(conditions)
    }
}
