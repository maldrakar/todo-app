import SQLiteKit

/// Writes what a view reads so that the most selective index its rule has drives the statement, by the chooser its
/// count is driven by (`DriverChooser`, #155).
///
/// A read left the choice of its driver to SQLite, which has no statistics of this store because the store never runs
/// `ANALYZE`, and decides between its default estimates, often by a tie: in #153's measurement at 50,000 tasks every
/// tag list's read walked every task and answered a correlated `EXISTS` on each, 14 to 31 ms, and a manual list's read
/// walked every task in 5 ms. A read takes the count's chooser, adapted where a read differs from a count: it has no
/// status of its own, so a driver is weighed against the walk SQLite would make for the rule without one (`Weighing`);
/// the exclusion of the Trash that each rule not naming it carries becomes a condition of the rule's own; and a
/// disjunction of projects is written plainly. A read nothing drives is written as before, but for its tags, which
/// become lists written last (`FilterCompiler.Form.tagListsLast`) while they are small against the rows they are tested
/// on; it is otherwise the statement it was, byte for byte, the built-ins' among them.
///
/// The sort plays no part in the choice: in #155's measurement every read's plan sorted its rows in a temporary B-tree,
/// whatever drove it, since every sort begins with an expression or with a column no index leads with.
struct ReadCompiler {
    /// One of the sizes the choice of a read's driver weighs: the tasks of the store, of a status, of a tag or of a
    /// condition, as an index holds them, trashed and deleted ones among them.
    enum Size: Equatable {
        case tasks
        case status(TaskStatus)
        case tag(TagID)
        case condition(Filter)
    }

    /// The sizes one call read, each from an index alone (`Store.readSizes(for:today:)`). A size that is not among them
    /// was not asked for, and nothing is weighed by it.
    struct Sizes {
        private let read: [(size: Size, tasks: Int64)]

        init(_ read: [(size: Size, tasks: Int64)]) {
            self.read = read
        }

        fileprivate subscript(_ size: Size) -> Int64? {
            read.first { $0.size == size }?.tasks
        }
    }

    private let today: Day
    private let weighing: Weighing

    init(today: Day, sizes: Sizes) {
        self.today = today
        weighing = Weighing(sizes: sizes)
    }

    /// How many tasks the tags of a read nothing drives may hold, added up, against the rows SQLite tests them on, for
    /// them to be written as lists: under four times as many. The list is built whole however few rows reach it, so it
    /// loses to the correlated `EXISTS` once it is many times those rows: in #155's sweeps at 50,000 tasks it was a
    /// tenth or more slower from 6.6 times (7,305 tasks of a tag beside the 1,111 canceled ones) and from 8 times (3,946
    /// beside the 487 deadlines more than 20 days past), and from 4.5 to 5 times still within a twentieth either way.
    /// Below that it is faster: Untagged, two negated tags, read in 64.6 ms listed where it read in 91.2 before.
    private static let listedShare = 4.0

    /// The condition of what a view reads, over `tasks t JOIN task_tree tt`: any of `rules`, a list's rule or the rules
    /// of the lists under a folder, each with its own exclusion of the Trash unless it names the Trash
    /// (`FilterCompiler.whereClause(anyOf:today:)`).
    ///
    /// The exclusion becomes `.trashed(false)` among the conditions of each branch of each rule that does not name the
    /// Trash, before the rules are regrouped (`DriverChooser.conditions(ofAnyOf:)`), so that a folder whose rules all
    /// exclude it has it in front. It never drives, and it is written as it is, `tt.trashed = 0`, which no index serves.
    func compile(_ rules: [Filter]) -> SQLFragment {
        let chooser = DriverChooser(today: today, weighing: weighing)
        let conditions = chooser.conditions(ofAnyOf: rules.flatMap(Self.excludingTheTrash))
        if let driven = chooser.driven(conditions) { return driven }
        let held = rules.flatMap(FilterCompiler.tags(of:)).reduce(0.0) { $0 + Double(weighing.sizes[.tag($1)] ?? 0) }
        let listed = held > 0 && held < Self.listedShare * max(weighing.walk(ofStatement: conditions).tested(besides: nil), 1)
        return FilterCompiler.whereClause(anyOf: rules, today: today, form: listed ? .tagListsLast : .plain)
    }

    /// The branches of a rule, each asking for what is not in the Trash as well, or the rule as it is when it names the
    /// Trash itself.
    private static func excludingTheTrash(_ rule: Filter) -> [Filter] {
        guard !FilterCompiler.mentionsTrashed(rule) else { return [rule] }
        return rule.disjuncts.map { .conjunction(of: $0.conjuncts + [.trashed(false)]) }
    }

    /// The sizes the choice of a driver for a read of `rules` weighs, each once, in the order they are read: none when
    /// no rule offers a candidate whose worth depends on the store, a tag, or a range of days in a branch of a
    /// disjunction; otherwise every task, each status, each tag, and each condition SQLite searches an index for
    /// (`searchable`), with an empty day for a day that is not empty, that the conditions of any conjunction a walk is
    /// taken of name. A read whose drivers are a project, a manual list, a day or a short range reads none, and is
    /// driven all the same.
    static func sizes(wantedBy rules: [Filter]) -> [Size] {
        let tags = rules.flatMap(FilterCompiler.tags(of:))
        let conditions = rules.flatMap(walkedConditions(of:))
        let inDisjunctions = rules.count > 1 ? conditions : rules.flatMap { rule in
            rule.conjuncts.flatMap { condition -> [Filter] in
                guard case .or = condition else { return [] }
                return walkedConditions(of: condition)
            }
        }
        let offersARange = inDisjunctions.contains { condition in
            switch condition {
            case .when(let day), .deadline(let day): return day != .empty && searchable(condition)
            case .status, .hasTag, .parent, .listedIn, .trashed, .and, .or, .not: return false
            }
        }
        guard !tags.isEmpty || offersARange else { return [] }
        var statuses: Set<TaskStatus> = []
        var sizes: [Size] = [.tasks]
        var searched: [Size] = []
        for condition in conditions {
            switch condition {
            case .status(let named):
                statuses.formUnion(named)
            case .not(let inner) where inner == .when(.empty) || inner == .deadline(.empty):
                searched.append(.condition(inner))
            case .when, .deadline, .hasTag, .parent, .listedIn, .trashed, .and, .or, .not:
                if searchable(condition) { searched.append(.condition(condition)) }
            }
        }
        for size in statuses.sorted(by: { $0.rawValue < $1.rawValue }).map(Size.status) + tags.map(Size.tag) + searched where !sizes.contains(size) {
            sizes.append(size)
        }
        return sizes
    }

    /// The conditions of every conjunction of a rule the choice of its driver takes a walk of: the rule's own and,
    /// through each disjunction among them, its branches', at any depth.
    private static func walkedConditions(of rule: Filter) -> [Filter] {
        rule.conjuncts.flatMap { condition -> [Filter] in
            guard case .or = condition else { return [condition] }
            return condition.disjuncts.flatMap(walkedConditions(of:))
        }
    }

    /// Whether SQLite searches a condition's index for a read when nothing better serves it: a day's condition but one
    /// day and a short range, which drive by themselves, an empty day among them, which is an equality to it, and the
    /// root. In #155's measurement every read with one of them and no status walked its index first, a narrow range's
    /// as readily as an empty day's.
    private static func searchable(_ condition: Filter) -> Bool {
        switch condition {
        case .when(.on), .deadline(.on): return false
        case .when, .deadline: return !condition.isAShortRangeOfDays
        case .parent(let parent): return parent == nil
        case .status, .hasTag, .listedIn, .trashed, .and, .or, .not: return false
        }
    }

    /// How a read weighs the drivers that depend on the store: against the rows SQLite walks for the rule without a
    /// driver of the read's own, and those of them it tests a tag on. A read has no status of its own, so #153's share of
    /// the open tasks has no meaning for it; and every conjunction admits a driver, a closed status among its
    /// conditions too, whose rows can be as many as a tag beats (a done task and a tag, 23.74 ms walking the done
    /// tasks and 5.32 driven by the tag).
    private struct Weighing: DriverWeighing {
        /// What a read's choice knows of the rows around a conjunction.
        struct Walk {
            /// W, the rows SQLite walks for the conjunction with no driver of the read's own, as it plans the statement
            /// it was: the rows of the statuses it names, by the status index one status at a time; else the rows of
            /// its smallest condition SQLite searches an index for (`searchable`), as that index holds them; else every
            /// task; and never more than the walk around it. A driver beats this walk or nothing: weighed against every
            /// task, a tag of 1,488 tasks beside the 487 deadlines more than 20 days past drove the read in 2.09 ms where
            /// the walk of the range took 0.57, in #155's measurement.
            let rows: Double
            /// S, the rows of the walk SQLite tests a tag on, but for `disjunctions`: the walk around it scaled by the rows
            /// the conjunction walks, and by the share of the store each other condition keeps, as its index holds them, a
            /// day SQLite searches by its own and a day that is not empty as all but the empty ones; none where a
            /// condition rejects most rows (`Filter.narrows`) and no index says how many. Beside a condition that keeps
            /// a third of the store or more, a share of the walk alone left a read 3 to 7 times slower than driven:
            /// Articles, a tag and a day that is not empty, 14.23 ms where the tag drives it in 4.92.
            private let tested: Double
            /// The disjunctions of the conjunction that reject most rows, every branch of each by a condition SQLite tests
            /// before a tag (`Filter.narrows`), and whose share no index gives. Each leaves no rows to test the conditions
            /// beside it on, a tag or another disjunction, which a choice of projects or of days would otherwise let a tag
            /// of thousands of tasks drive in their place; but not itself, nor its own branches, which are weighed against
            /// the walk around it, as #155's sweeps measured them.
            private let disjunctions: [Filter]
            /// Whether the conjunction is a branch of a disjunction, or one of a folder's rules, around which SQLite
            /// walks every task. A range a day's index can search then drives a branch that has no better driver.
            let aroundEveryTask: Bool

            init(rows: Double, tested: Double, disjunctions: [Filter], aroundEveryTask: Bool) {
                self.rows = rows
                self.tested = tested
                self.disjunctions = disjunctions
                self.aroundEveryTask = aroundEveryTask
            }

            /// S for a condition of the conjunction, `disjunction` or, for any other, nil: none beside a disjunction of
            /// `disjunctions` other than it.
            func tested(besides disjunction: Filter?) -> Double {
                disjunctions.contains { $0 != disjunction } ? 0 : tested
            }
        }

        let sizes: Sizes

        /// The share of the walk a tag's list may hold whatever it is tested on: three hundredths, #153's floor, which
        /// #155's sweeps at 50,000 tasks held to. Where the walk tests a tag on next to none of its rows, beside a deadline
        /// no task has, a tag's driver crossed the walk between 0.05 and 0.08 of it with every task open and between
        /// 0.11 and 0.18 with a quarter of them open.
        static let walkShare = 0.03

        /// How many tasks one tag that drives a read may hold, beyond `walkShare`, against the rows SQLite tests it on:
        /// two fifths. In #155's sweeps a tag alone crossed the read it replaces between 0.47 and 2.28 of those rows, the
        /// least beside the 1,111 canceled tasks, two fifths of which are 444 tasks, where the crossover lay between 518
        /// and 1,006; over the 600 single-tag points of the sweeps no read the share drove was slower than before.
        static let tagShare = 0.4

        /// How many tasks the tags and the ranges that drive a disjunction's branches may hold, added up, beyond
        /// `walkShare`, against the rows SQLite tests them on, the branches' walks added up and never more than the walk
        /// around them: half. In #155's sweeps a disjunction of two to ten tags crossed the read it replaces at 1.08 of
        /// those rows or more, and the best undriven form between 0.6 and 0.86 of them.
        static let disjunctionShare = 0.5

        func walk(ofStatement conditions: [Filter]) -> Walk {
            let tasks = Double(sizes[.tasks] ?? 0)
            return walk(of: conditions, rows: tasks, tested: tasks, branch: false)
        }

        func walk(ofRule conditions: [Filter], sharing shared: [Filter]) -> Walk {
            let around = walk(ofStatement: shared)
            return walk(of: conditions, rows: around.rows, tested: around.tested(besides: nil), branch: true)
        }

        func walk(ofBranch conditions: [Filter], of disjunction: Filter, within around: Walk) -> Walk {
            walk(of: conditions, rows: around.rows, tested: around.tested(besides: disjunction), branch: true)
        }

        func admitsADriver(_ conditions: [Filter]) -> Bool {
            true
        }

        func tagDrives(_ tag: TagID, in walk: Walk) -> Bool {
            guard let held = sizes[.tag(tag)] else { return false }
            return Self.drives(Double(held), share: Self.tagShare, rows: walk.rows, tested: walk.tested(besides: nil))
        }

        /// A range a day's index can search drives a branch under a walk of every task, by its index: Urgent, a tag or
        /// a deadline that has passed, read in 33.31 ms walking every task and in 9.15 driven by both, in #155's
        /// measurement. An empty day is no range, and holds most of a store.
        func rangeDrives(_ condition: Filter, in walk: Walk) -> Bool {
            guard walk.aroundEveryTask, condition != .when(.empty), condition != .deadline(.empty) else { return false }
            return sizes[.condition(condition)] != nil
        }

        /// A disjunction whose branches no tag and no range drives walks nothing a share could weigh, and drives.
        func disjunctionDrives(_ disjunction: Filter, branches: [(driver: Filter, walk: Walk)], in walk: Walk) -> Bool {
            var held = 0.0
            var rows = 0.0
            var tested = 0.0
            for branch in branches {
                rows += branch.walk.rows
                tested += branch.walk.tested(besides: nil)
                switch branch.driver {
                case .hasTag(let tag): held += Double(sizes[.tag(tag)] ?? 0)
                case .when, .deadline: held += Double(sizes[.condition(branch.driver)] ?? 0)
                case .status, .parent, .listedIn, .trashed, .and, .or, .not: break
                }
            }
            guard held > 0 else { return true }
            return Self.drives(held, share: Self.disjunctionShare, rows: min(rows, walk.rows), tested: min(tested, walk.tested(besides: disjunction)))
        }

        /// A read has no status of its own to compete with a disjunction of parents, and SQLite reads them compared
        /// plainly as one search of the parent index: the Projects folder in 0.120 ms, against 0.196 with each project
        /// as the list of its children and 0.143 before #155, in #155's measurement.
        var writesProjectsPlainly: Bool { true }

        /// Whether tasks held by a driver drive a walk of `rows`, `tested` of which it tests: while they are fewer than
        /// `walkShare` of the rows and `share` of those tested, added up.
        private static func drives(_ held: Double, share: Double, rows: Double, tested: Double) -> Bool {
            held < walkShare * rows + share * tested
        }

        /// The walk of a conjunction inside a walk around it of `aroundRows`, `aroundTested` of which are tested; `branch`
        /// says that it is a branch of a disjunction or a folder's rule.
        private func walk(of conditions: [Filter], rows aroundRows: Double, tested aroundTested: Double, branch: Bool) -> Walk {
            var rows = aroundRows
            var source: [Filter] = conditions.filter { if case .status = $0 { true } else { false } }
            for case .status(let named) in source {
                rows = min(rows, Set(named).reduce(0.0) { $0 + Double(sizes[.status($1)] ?? 0) })
            }
            if source.isEmpty {
                for condition in conditions where ReadCompiler.searchable(condition) {
                    guard let held = sizes[.condition(condition)].map(Double.init), held < rows else { continue }
                    rows = held
                    source = [condition]
                }
            }
            var tested = aroundRows > 0 ? aroundTested * rows / aroundRows : 0
            var disjunctions: [Filter] = []
            for condition in conditions where !source.contains(condition) {
                switch condition {
                case .hasTag, .listedIn, .trashed, .and:
                    continue
                case .or:
                    if condition.narrows { disjunctions.append(condition) }
                case .status, .when, .deadline, .parent, .not:
                    if let kept = share(keptBy: condition) { tested *= kept } else if condition.narrows { tested = 0 }
                }
            }
            return Walk(rows: rows, tested: tested, disjunctions: disjunctions, aroundEveryTask: branch && aroundRows >= Double(sizes[.tasks] ?? 0))
        }

        /// The share of the store a condition keeps, as its index holds it: a condition SQLite searches by its own rows,
        /// and a day that is not empty by all but the empty ones; nil for any other.
        private func share(keptBy condition: Filter) -> Double? {
            let tasks = Double(max(sizes[.tasks] ?? 0, 1))
            if case .not(let inner) = condition, inner == .when(.empty) || inner == .deadline(.empty) {
                return sizes[.condition(inner)].map { 1 - Double($0) / tasks }
            }
            return sizes[.condition(condition)].map { Double($0) / tasks }
        }
    }
}
