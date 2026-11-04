import SQLiteKit

/// How one kind of statement weighs the drivers whose worth depends on what the store holds, for `DriverChooser`:
/// a count weighs them against the open tasks the status index holds (`CountCompiler`, #153), a view's read against
/// the rows it walks without a driver of its own (`ReadCompiler`, #155). Everything else about a driver, which
/// conditions can be one, which is best and how each is written, is the chooser's, and the same for both.
protocol DriverWeighing {
    /// What the statement knows of the rows around a conjunction while a driver is chosen for it.
    associatedtype Walk
    /// The walk of the conditions the statement asks for all of, at its top.
    func walk(ofStatement conditions: [Filter]) -> Walk
    /// The walk of one rule of a folder past the conditions every rule of it asks for, `shared`, while the rules are
    /// grouped by the condition that drives each.
    func walk(ofRule conditions: [Filter], sharing shared: [Filter]) -> Walk
    /// The walk of a branch of a disjunction, inside the walk around the disjunction.
    func walk(ofBranch conditions: [Filter], within around: Walk) -> Walk
    /// Whether any condition of the conjunction may drive it at all.
    func admitsADriver(_ conditions: [Filter]) -> Bool
    /// Whether a tag drives in this walk.
    func tagDrives(_ tag: TagID, in walk: Walk) -> Bool
    /// Whether a range of days that a day's index can search, but that is too wide to drive by itself, an empty day
    /// among them, drives in this walk.
    func rangeDrives(_ condition: Filter, in walk: Walk) -> Bool
    /// Whether a disjunction drives, given the condition that drives each of its branches and each branch's walk.
    func disjunctionDrives(_ branches: [(driver: Filter, walk: Walk)], in walk: Walk) -> Bool
    /// Whether a disjunction that a project drives in every branch is written with the projects' parents compared
    /// plainly, rather than each as the list of its children.
    var writesProjectsPlainly: Bool { get }
}

/// Chooses which condition of a rule drives a statement over it, and writes the statement's condition so that
/// SQLite takes that condition's index and no other (#153, #155).
///
/// SQLite has no statistics of this store, because the store never runs `ANALYZE`, so it chooses between its
/// default estimates, often by a tie. The choice is made here instead, by the shape of the rule. Among the conditions
/// the rule asks for all of, one drives, the first of the best `Driver`, and is written in the form its index serves;
/// every other condition is written off its index (`FilterCompiler.Form.unindexed`), so the planner has one index to
/// take and no tie between its estimates to settle. A count and a view's read share all of it, and each weighs the
/// drivers whose worth depends on the store by its own `Weighing`.
///
/// Every walk here recurses over one filter, as `FilterCompiler.compile` does, and the bound on a stored filter's
/// depth (`maximumDepth`) holds it; a folder's rules come in flat, so none recurses over the tree of views.
struct DriverChooser<Weighing: DriverWeighing> {
    private let today: Day
    private let weighing: Weighing

    init(today: Day, weighing: Weighing) {
        self.today = today
        self.weighing = weighing
    }

    /// What a condition can drive a statement by, best first: the fewer tasks its index gives for any store, the
    /// earlier. A manual list holds the tasks a person placed by hand, a project its own, a day one day's, a short
    /// range a few days', a tag and a wider range are only offered when the statement's weighing finds them small
    /// enough, and a disjunction is read through each branch's.
    private enum Driver: Int, Comparable {
        case pins, project, day, days, tag, range, disjunction

        static func < (lhs: Driver, rhs: Driver) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// The conditions a statement over any of `rules` asks for all of: a list's rule, or the rules of the lists under a
    /// folder, each split into the branches it asks for any of, and regrouped into one conjunction that selects the
    /// same tasks, so that a driver can be found for it (`union`).
    func conditions(ofAnyOf rules: [Filter]) -> [Filter] {
        union(rules.flatMap(\.disjuncts)).conjuncts
    }

    /// The conjunction `conditions`, written with one of them driving it and every other condition off its index, or
    /// nil when none drives.
    func driven(_ conditions: [Filter]) -> SQLFragment? {
        driven(conditions, inDisjunction: false, walk: weighing.walk(ofStatement: conditions))
    }

    /// A disjunction of rules regrouped into one that selects the same tasks, so that a driver can be found for it.
    /// The conditions every rule asks for are taken out in front, `(a AND x) OR (a AND y)` as `a AND (x OR y)`, and
    /// when a rule asks for nothing more than those it absorbs the others, `a OR (a AND y)` as `a`; then the rules
    /// driven by the same condition are grouped under it (`grouped`). Both hold in SQL's logic of three values,
    /// where AND and OR distribute over each other and absorb as they do over two.
    private func union(_ rules: [Filter]) -> Filter {
        guard rules.count > 1 else { return rules.first ?? .or([]) }
        let lists = rules.map(\.conjuncts)
        var shared: [Filter] = []
        for condition in lists[0] where !shared.contains(condition) && lists.allSatisfy({ $0.contains(condition) }) {
            shared.append(condition)
        }
        let rests = lists.map { $0.filter { !shared.contains($0) } }
        guard !rests.contains(where: \.isEmpty) else { return .conjunction(of: shared) }
        return .conjunction(of: shared + [grouped(rests, sharing: shared)])
    }

    /// `(a AND x) OR (a AND y) OR (b AND z)` as `(a AND (x OR y)) OR (b AND z)`: the rules whose driver is the same
    /// condition become one branch driven by it, so that its index is read once and not once per rule. A rule with
    /// no driver is a branch of its own, and so is a rule no other shares its driver with. A rule's driver here is the
    /// one it has in its own walk past the conditions every rule shares (`DriverWeighing.walk(ofRule:sharing:)`):
    /// whether the regrouped disjunction drives is decided on the whole, and a tag that two rules share is walked
    /// once in a group where it would be walked twice apart.
    private func grouped(_ lists: [[Filter]], sharing shared: [Filter]) -> Filter {
        var drivers: [Filter?] = []
        var members: [[[Filter]]] = []
        for list in lists {
            let driver = driverPosition(in: list, inDisjunction: true, walk: weighing.walk(ofRule: list, sharing: shared)).map { list[$0] }
            if let driver, let group = drivers.firstIndex(of: driver) {
                members[group].append(list)
            } else {
                drivers.append(driver)
                members.append([list])
            }
        }
        return .disjunction(of: zip(drivers, members).map { driver, lists in
            guard let driver, lists.count > 1 else { return .disjunction(of: lists.map(Filter.conjunction(of:))) }
            let rests = lists.map { $0.filter { $0 != driver } }
            guard !rests.contains(where: \.isEmpty) else { return driver }
            return .and([driver, .disjunction(of: rests.map(Filter.conjunction(of:)))])
        })
    }

    /// A conjunction written with its driver in the form its index serves and every other condition off its index,
    /// or nil when it has no driver. `inDisjunction` says that it is a branch of a disjunction that drives, in which
    /// a project is written plainly where `projectsPlainly` says so.
    private func driven(_ conditions: [Filter], inDisjunction: Bool, walk: Weighing.Walk, projectsPlainly: Bool = false) -> SQLFragment? {
        guard let chosen = driverPosition(in: conditions, inDisjunction: inDisjunction, walk: walk) else { return nil }
        var written: [SQLFragment] = []
        for (position, condition) in conditions.enumerated() {
            guard position == chosen else {
                written.append(FilterCompiler.compile(condition, today: today, form: .unindexed))
                continue
            }
            guard let driving = driving(condition, inDisjunction: inDisjunction, walk: walk, projectsPlainly: projectsPlainly) else { return nil }
            written.append(driving)
        }
        return FilterCompiler.joined(written, separator: " AND ", empty: "1")
    }

    /// A driver in the form its index serves: a day and a range as the compiler writes them, a tag and a pin as the
    /// list of their tasks, which SQLite looks the tasks up from by id, and a project as its tree's parent. A
    /// disjunction is each branch driven in its turn; SQLite reads it by several indexes (`MULTI-INDEX OR`) only
    /// when every branch searches the same table, and every other driver searches `tasks t`, so inside one a
    /// project is the list of its tasks too, unless every branch is a project's and the weighing writes those
    /// plainly (`DriverWeighing.writesProjectsPlainly`). Nil for a condition that is no driver.
    private func driving(_ condition: Filter, inDisjunction: Bool, walk: Weighing.Walk, projectsPlainly: Bool) -> SQLFragment? {
        switch condition {
        case .listedIn, .hasTag:
            return FilterCompiler.compile(condition, today: today, form: .lists)
        case .when, .deadline:
            return FilterCompiler.compile(condition, today: today)
        case .parent(let parent?):
            guard inDisjunction, !projectsPlainly else { return FilterCompiler.compile(condition, today: today) }
            return SQLFragment(sql: "t.id IN (SELECT p.id FROM task_tree p WHERE p.parent = ?)", params: [.text(parent.rawValue)])
        case .or:
            let branches = condition.disjuncts.map { branch in
                (conditions: branch.conjuncts, walk: weighing.walk(ofBranch: branch.conjuncts, within: walk))
            }
            let projectsPlainly = weighing.writesProjectsPlainly && branches.allSatisfy { branch in
                guard let position = driverPosition(in: branch.conditions, inDisjunction: true, walk: branch.walk),
                      case .parent(_?) = branch.conditions[position] else { return false }
                return true
            }
            var written: [SQLFragment] = []
            for branch in branches {
                guard let fragment = driven(branch.conditions, inDisjunction: true, walk: branch.walk, projectsPlainly: projectsPlainly) else { return nil }
                written.append(fragment)
            }
            return FilterCompiler.joined(written, separator: " OR ", empty: "0")
        case .status, .parent, .trashed, .and, .not:
            return nil
        }
    }

    /// Which of the conditions a conjunction asks for all of drives it: the first of the best driver, or none.
    /// `inDisjunction` says that the conjunction is a branch of a disjunction that drives.
    private func driverPosition(in conditions: [Filter], inDisjunction: Bool, walk: Weighing.Walk) -> Int? {
        guard weighing.admitsADriver(conditions) else { return nil }
        var best: (position: Int, driver: Driver)?
        for (position, condition) in conditions.enumerated() {
            guard let driver = driver(condition, inDisjunction: inDisjunction, walk: walk) else { continue }
            if best.map({ driver < $0.driver }) ?? true { best = (position, driver) }
        }
        return best?.position
    }

    /// What a condition can drive a statement by, if anything. The root is an equality to SQLite and selects most of a
    /// store, and a status, a negation and the trash select too much of it to be worth an index; a range of days drives
    /// by itself while it is shorter than a month, and a wider one, one open at one end and an empty day only where the
    /// weighing finds them small enough. A disjunction drives only at the top of a statement: SQLite reads a
    /// disjunction by its branches' indexes one level deep, and a disjunction inside a branch of another one would
    /// leave the planner no index but a scan of every task. Whether a tag drives, and a disjunction once every branch
    /// has a driver, is the weighing's.
    private func driver(_ condition: Filter, inDisjunction: Bool, walk: Weighing.Walk) -> Driver? {
        switch condition {
        case .listedIn:
            return .pins
        case .parent(let parent):
            return parent == nil ? nil : .project
        case .when(.on), .deadline(.on):
            return .day
        case .when, .deadline:
            if condition.isAShortRangeOfDays { return .days }
            return weighing.rangeDrives(condition, in: walk) ? .range : nil
        case .hasTag(let tag):
            return weighing.tagDrives(tag, in: walk) ? .tag : nil
        case .or:
            guard !inDisjunction else { return nil }
            let branches = condition.disjuncts
            guard !branches.isEmpty else { return nil }
            var drivers: [(driver: Filter, walk: Weighing.Walk)] = []
            for branch in branches {
                let conditions = branch.conjuncts
                let branchWalk = weighing.walk(ofBranch: conditions, within: walk)
                guard let position = driverPosition(in: conditions, inDisjunction: true, walk: branchWalk) else { return nil }
                drivers.append((conditions[position], branchWalk))
            }
            return weighing.disjunctionDrives(drivers, in: walk) ? .disjunction : nil
        case .status, .trashed, .and, .not:
            return nil
        }
    }
}

/// The shape of a rule as the choice of a driver walks it.
extension Filter {
    /// The conditions a filter asks for all of, its nested conjunctions flattened: none for an empty one.
    var conjuncts: [Filter] {
        guard case .and(let parts) = self else { return [self] }
        return parts.flatMap(\.conjuncts)
    }

    /// The conditions a filter asks for any of, its nested disjunctions flattened: none for an empty one.
    var disjuncts: [Filter] {
        guard case .or(let parts) = self else { return [self] }
        return parts.flatMap(\.disjuncts)
    }

    /// A conjunction of conditions, and a single condition as itself.
    static func conjunction(of conditions: [Filter]) -> Filter {
        conditions.count == 1 ? conditions[0] : .and(conditions)
    }

    /// A disjunction of conditions, and a single condition as itself.
    static func disjunction(of conditions: [Filter]) -> Filter {
        conditions.count == 1 ? conditions[0] : .or(conditions)
    }

    /// A range of days drives by itself only when it spans fewer days than this. A wide range holds most dated tasks,
    /// and its index then walks them all: in #153's measurement at 50,000 tasks, `when` from a year ago to two months
    /// ahead counted 2.8 times slower driven by the day index than by the walk of the open tasks, while every range it
    /// measured up to 29 days long was faster driven. A month is a judgement between the two, not a crossover.
    static let widestDrivingRange: Int64 = 31

    /// Whether the filter is a range of days that drives a statement by itself, one shorter than `widestDrivingRange`. A
    /// range over more days than an `Int64` counts is as wide as a range gets.
    var isAShortRangeOfDays: Bool {
        switch self {
        case .when(.between(let from, let to)), .deadline(.between(let from, let to)):
            let (span, overflow) = to.subtractingReportingOverflow(from)
            return !overflow && span < Filter.widestDrivingRange
        case .status, .when, .deadline, .hasTag, .parent, .listedIn, .trashed, .and, .or, .not:
            return false
        }
    }

    /// Whether a condition is one SQLite tests before a tag's or a pin's subquery and that rejects most tasks of a
    /// store: a range of days, closed or open at one end, a day that is not empty, or a project; a conjunction with
    /// one of them; and a disjunction of them, in whose every branch SQLite tests it first, whichever is written
    /// first. In a store most tasks have no deadline, many no day at all and most belong to no project, so #144
    /// rejects most open tasks by such a condition before it probes a tag (`CountCompiler`'s narrowed share); a
    /// disjunction with one branch it cannot reject that way makes it probe that branch's tag for every open task. One
    /// day and a short range drive a statement themselves; an empty day, the root and the negation of anything else
    /// admit the tasks with no day, which in #153's sweeps never made a tag's driver lose to #144 under its share.
    var narrows: Bool {
        switch self {
        case .when(let day), .deadline(let day): return day != .empty
        case .not(.when(.empty)), .not(.deadline(.empty)): return true
        case .parent(let parent): return parent != nil
        case .and(let parts): return parts.contains(where: \.narrows)
        case .or(let parts): return !parts.isEmpty && parts.allSatisfy(\.narrows)
        case .status, .hasTag, .listedIn, .trashed, .not: return false
        }
    }
}
