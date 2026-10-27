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
    private let today: Day
    /// The tasks each tag a rule could be driven by holds, done, trashed and deleted ones among them, as `Store`
    /// counted them for this call. A tag that is not in it is no driver.
    private let tagSizes: [TagID: Int64]
    /// The open tasks the status index holds, trashed and deleted ones among them, counted for this call too.
    private let openTasks: Int64

    init(today: Day, tagSizes: [TagID: Int64], openTasks: Int64) {
        self.today = today
        self.tagSizes = tagSizes
        self.openTasks = openTasks
    }

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

    /// How many tasks one tag that drives a count may hold, against the open tasks the status index holds: under two
    /// fifths of them. A tag's driver walks every task the tag holds, done ones too, where the walk of the open tasks
    /// it replaces reads the tag's list once and each open task once. In #153's sweeps at 50,000 tasks a tag's list
    /// crossed that walk between 0.36 and 0.40 of the open tasks with about a quarter of the store open, and past 0.5
    /// with every task open or beside the open status. Under the share every count measured was 1.6 to 12 times
    /// faster than #144's, for a tag alone, beside the open status, an empty day, the root, the root negated or a range
    /// negated, and at most a twentieth slower than the walk, just under the share.
    private static let tagShare = 0.4

    /// How many tasks the tags that drive a disjunction's branches may hold, added up, since its driver walks them
    /// all: under half of the open tasks, each tag also under `tagShare`. In #153's sweeps a disjunction of two to ten
    /// tags crossed the walk of the open tasks between 0.5 and 0.8 of them, summed, two tags of 0.2 each still faster
    /// at 0.4 and two of 0.3 slower at 0.6, and against #144's count it stayed faster up to 1.6 in both stores. Under
    /// the share it was 1.7 to 10 times faster than #144's, and at most an eighth slower than the walk.
    private static let disjunctionShare = 0.5

    /// The share, for one tag or added up over a disjunction's, where #144 rejects most open tasks before it probes a
    /// tag (`narrows`), beside a day only a dated task meets or in a disjunction whose every branch it can reject
    /// that way: three hundredths of the open tasks. #144's count then costs little more than the walk of the open
    /// tasks itself, the least any count costs it, which a tag's driver beats only while the tag is small. Against
    /// a deadline no task has, where #144 does nothing but that walk, one tag crossed it between 0.10 and 0.15 of the
    /// open tasks with a quarter of the store open and between 0.05 and 0.06 with every task open, and a disjunction
    /// of two or three tags between 0.06 and 0.10, and between 0.03 and 0.04, summed; against Electrical's
    /// `deadline <= 30` one tag crossed between 0.15 and 0.20, and between 0.10 and 0.15. SQLite tests a day before a
    /// tag in a disjunction's branch too, whichever is written first. The share is under the least of them, so that
    /// no day a rule names makes a count slower than #144's.
    private static let narrowedShare = 0.03

    /// The condition of what a view counts, over `tasks t JOIN task_tree tt`, and whether a condition of the rule's
    /// own drives it, which is when the count's own status condition has to be kept off its index.
    ///
    /// `rules` are what the view counts any of: a list's rule, or the rules of the lists under a folder. They are
    /// regrouped before a driver is chosen (`union`), and a count with none is written as the rules are, as a
    /// folder's disjunction of them when there are several. Its tags and its pins are then written as the lists
    /// of their tasks, which SQLite builds once per statement where the correlated `EXISTS` probes once per open
    /// task, unless a day or a parent is among the conditions the rule asks for all of, or another condition that
    /// `narrows` it: SQLite tests those first, and the probes then run on the rows left, which can cost less than the
    /// list (Untagged 21.5 to 15.3 ms listed in #153's measurement, while a rule narrowed by a day, or by having a
    /// deadline, was slower listed than as #144 wrote it).
    func compile(_ rules: [Filter]) -> (condition: SQLFragment, driven: Bool) {
        let conditions = Self.conjuncts(union(rules.flatMap(Self.disjuncts)))
        if let condition = driven(conditions, inDisjunction: false, narrowed: conditions.contains(where: Self.narrows)) {
            return (condition, true)
        }
        let rule = rules.count == 1 ? rules[0] : Filter.or(rules)
        let narrowed = Self.conjuncts(rule).contains { condition in
            switch condition {
            case .when, .deadline, .parent: return true
            case .status, .hasTag, .listedIn, .trashed, .and, .or, .not: return Self.narrows(condition)
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
    /// no driver is a branch of its own, and so is a rule no other shares its driver with. A rule's driver here is the
    /// one it would have where no day narrows it: whether the regrouped disjunction drives is decided on the whole, and
    /// a tag that two rules share is walked once in a group where it would be walked twice apart.
    private func grouped(_ lists: [[Filter]]) -> Filter {
        var drivers: [Filter?] = []
        var members: [[[Filter]]] = []
        for list in lists {
            let driver = driverPosition(in: list, inDisjunction: true, narrowed: false).map { list[$0] }
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
    /// or nil when it has no driver. `inDisjunction` says that it is a branch of a disjunction that drives, and
    /// `narrowed` that #144 rejects most open tasks before it probes a tag here.
    private func driven(_ conditions: [Filter], inDisjunction: Bool, narrowed: Bool) -> SQLFragment? {
        guard let chosen = driverPosition(in: conditions, inDisjunction: inDisjunction, narrowed: narrowed) else { return nil }
        var written: [SQLFragment] = []
        for (position, condition) in conditions.enumerated() {
            guard position == chosen else {
                written.append(FilterCompiler.compile(condition, today: today, form: .unindexed))
                continue
            }
            guard let driving = driving(condition, inDisjunction: inDisjunction, narrowed: narrowed) else { return nil }
            written.append(driving)
        }
        return FilterCompiler.joined(written, separator: " AND ", empty: "1")
    }

    /// A driver in the form its index serves: a day and a range as the compiler writes them, a tag and a pin as the
    /// list of their tasks, which SQLite looks the tasks up from by id, and a project as its tree's parent. A
    /// disjunction is each branch driven in its turn; SQLite reads it by several indexes (`MULTI-INDEX OR`) only
    /// when every branch searches the same table, and every other driver searches `tasks t`, so inside one a
    /// project is the list of its tasks too. Nil for a condition that is no driver.
    private func driving(_ condition: Filter, inDisjunction: Bool, narrowed: Bool) -> SQLFragment? {
        switch condition {
        case .listedIn, .hasTag:
            return FilterCompiler.compile(condition, today: today, form: .lists)
        case .when, .deadline:
            return FilterCompiler.compile(condition, today: today)
        case .parent(let parent?):
            guard inDisjunction else { return FilterCompiler.compile(condition, today: today) }
            return SQLFragment(sql: "t.id IN (SELECT p.id FROM task_tree p WHERE p.parent = ?)", params: [.text(parent.rawValue)])
        case .or:
            var written: [SQLFragment] = []
            for branch in Self.disjuncts(condition) {
                guard let fragment = driven(Self.conjuncts(branch), inDisjunction: true, narrowed: narrowed) else { return nil }
                written.append(fragment)
            }
            return FilterCompiler.joined(written, separator: " OR ", empty: "0")
        case .status, .parent, .trashed, .and, .not:
            return nil
        }
    }

    /// Which of the conditions a conjunction asks for all of drives it: the first of the best driver, or none. A
    /// conjunction that asks for a status other than open has none, whatever else it asks for: it counts nothing,
    /// and with the count's own status condition left on its index SQLite compares the two constants before the
    /// loop and reads no row, which no driver could beat. `inDisjunction` says that the conjunction is a branch of
    /// a disjunction that drives, and `narrowed` that #144 rejects most open tasks before it probes a tag here.
    private func driverPosition(in conditions: [Filter], inDisjunction: Bool, narrowed: Bool) -> Int? {
        guard !conditions.contains(where: Self.excludesOpen) else { return nil }
        var best: (position: Int, driver: Driver)?
        for (position, condition) in conditions.enumerated() {
            guard let driver = driver(condition, inDisjunction: inDisjunction, narrowed: narrowed) else { continue }
            if best.map({ driver < $0.driver }) ?? true { best = (position, driver) }
        }
        return best?.position
    }

    /// What a condition can drive a count by, if anything. An empty day and the root are each an equality to
    /// SQLite, and select most of a store; a range open at one end, a status, a negation and the trash select too
    /// much of it to be worth an index; a range of days drives only while it is shorter than a month. A disjunction
    /// drives only at the top of a count: SQLite reads a disjunction by its branches' indexes one level deep, and a
    /// disjunction inside a branch of another one would leave the planner no index but a scan of every task. A tag
    /// drives while it holds fewer tasks than its share of the open ones, and a disjunction while the tags that
    /// drive its branches do, their tasks added up, since its driver walks them all.
    private func driver(_ condition: Filter, inDisjunction: Bool, narrowed: Bool) -> Driver? {
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
            return holdFewerTasks(than: narrowed ? Self.narrowedShare : Self.tagShare, [tag]) ? .tag : nil
        case .or:
            guard !inDisjunction else { return nil }
            let branches = Self.disjuncts(condition)
            guard !branches.isEmpty else { return nil }
            var tags: [TagID] = []
            for branch in branches {
                let conditions = Self.conjuncts(branch)
                guard let position = driverPosition(in: conditions, inDisjunction: true, narrowed: narrowed) else { return nil }
                if case .hasTag(let tag) = conditions[position] { tags.append(tag) }
            }
            return holdFewerTasks(than: narrowed ? Self.narrowedShare : Self.disjunctionShare, tags) ? .disjunction : nil
        case .status, .when, .deadline, .trashed, .and, .not:
            return nil
        }
    }

    /// Whether the tags hold fewer tasks, added up, than `share` of the open ones. Summed and compared as `Double`, so
    /// that counts a store could hold never overflow on the way; a tag whose size was not read is no driver. No tags
    /// hold no tasks under any share, whatever the open count: a disjunction of projects, pins and days walks none,
    /// and in a store where no rule names a tag the open tasks are never counted at all.
    private func holdFewerTasks(than share: Double, _ tags: [TagID]) -> Bool {
        guard !tags.isEmpty else { return true }
        var held = 0.0
        for tag in tags {
            guard let size = tagSizes[tag] else { return false }
            held += Double(size)
        }
        return held < share * Double(openTasks)
    }

    /// Whether a condition is one SQLite tests before a tag's or a pin's subquery and that rejects most tasks of a
    /// store: a range of days, closed or open at one end, a day that is not empty, or a project; a conjunction with
    /// one of them; and a disjunction of them, in whose every branch SQLite tests it first, whichever is written
    /// first. In a store most tasks have no deadline, many no day at all and most belong to no project, so #144
    /// rejects most open tasks by such a condition before it probes a tag (`narrowedShare`); a disjunction with one
    /// branch it cannot reject that way makes it probe that branch's tag for every open task. One day and a short
    /// range drive the count themselves; an empty day, the root and the negation of anything else admit the tasks
    /// with no day, which in #153's sweeps never made a tag's driver lose to #144 under `tagShare`.
    private static func narrows(_ condition: Filter) -> Bool {
        switch condition {
        case .when(let day), .deadline(let day): return day != .empty
        case .not(.when(.empty)), .not(.deadline(.empty)): return true
        case .parent(let parent): return parent != nil
        case .and(let parts): return parts.contains(where: narrows)
        case .or(let parts): return !parts.isEmpty && parts.allSatisfy(narrows)
        case .status, .hasTag, .listedIn, .trashed, .not: return false
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
