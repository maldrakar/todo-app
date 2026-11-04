import SQLiteKit

/// Writes what one view counts so that a single index drives its statement: the index of a condition of the
/// rule's own where the rule has one (#153).
///
/// Every count carries its own `t.status = 0`, and SQLite, which has no statistics of this store because the store
/// never runs `ANALYZE`, takes the status index for it as readily as any other: so every count walked every open
/// task and tested its rule on each, a project's five tasks as dearly as the Inbox's thousands. The choice is made
/// by `DriverChooser` instead, by the shape of the rule, with a tag weighed against the open tasks (`Weighing`); the
/// count's own status is then one of the conditions written off its index. A rule with no such condition is written
/// as #144 wrote it, and the status index drives it, as it drives every built-in's count.
struct CountCompiler {
    private let today: Day
    private let weighing: Weighing

    init(today: Day, tagSizes: [TagID: Int64], openTasks: Int64) {
        self.today = today
        weighing = Weighing(tagSizes: tagSizes, openTasks: openTasks)
    }

    /// The condition of what a view counts, over `tasks t JOIN task_tree tt`, and whether a condition of the rule's
    /// own drives it, which is when the count's own status condition has to be kept off its index.
    ///
    /// `rules` are what the view counts any of: a list's rule, or the rules of the lists under a folder. They are
    /// regrouped before a driver is chosen (`DriverChooser.conditions(ofAnyOf:)`), and a count with none is written as
    /// the rules are, as a folder's disjunction of them when there are several. Its tags and its pins are then written
    /// as the lists of their tasks, which SQLite builds once per statement where the correlated `EXISTS` probes once
    /// per open task, unless a day or a parent is among the conditions the rule asks for all of, or another condition
    /// that `narrows` it: SQLite tests those first, and the probes then run on the rows left, which can cost less than
    /// the list (Untagged 21.5 to 15.3 ms listed in #153's measurement, while a rule narrowed by a day, or by having a
    /// deadline, was slower listed than as #144 wrote it).
    func compile(_ rules: [Filter]) -> (condition: SQLFragment, driven: Bool) {
        let chooser = DriverChooser(today: today, weighing: weighing)
        if let condition = chooser.driven(chooser.conditions(ofAnyOf: rules)) {
            return (condition, true)
        }
        let rule = rules.count == 1 ? rules[0] : Filter.or(rules)
        let narrowed = rule.conjuncts.contains { condition in
            switch condition {
            case .when, .deadline, .parent: return true
            case .status, .hasTag, .listedIn, .trashed, .and, .or, .not: return condition.narrows
            }
        }
        return (FilterCompiler.compile(rule, today: today, form: narrowed ? .plain : .lists), false)
    }

    /// The tags whose size the choice of a driver for `rule` may ask about: the tags it asks for all of, and those
    /// each branch of a disjunction among them asks for all of. A conjunction that asks for a status other than
    /// open has no driver, so its tags are not asked about. A folder's rules are its lists', so the tags of every
    /// list's rule are all the tags any count asks about.
    static func candidateTags(of rule: Filter) -> [TagID] {
        let conditions = rule.conjuncts
        guard !conditions.contains(where: excludesOpen) else { return [] }
        return conditions.flatMap { condition -> [TagID] in
            switch condition {
            case .hasTag(let tag): [tag]
            case .or: condition.disjuncts.flatMap(candidateTags(of:))
            case .status, .when, .deadline, .parent, .listedIn, .trashed, .and, .not: []
            }
        }
    }

    private static func excludesOpen(_ condition: Filter) -> Bool {
        guard case .status(let statuses) = condition else { return false }
        return !statuses.contains(.open)
    }

    /// How a count weighs the drivers that depend on the store: a tag, and the tags of a disjunction's branches, against
    /// the open tasks the status index holds, which is what #144's count walked. A conjunction that asks for a status
    /// other than open has no driver, whatever else it asks for: it counts nothing, and with the count's own status
    /// condition left on its index SQLite compares the two constants before the loop and reads no row, which no
    /// driver could beat. A range of days wider than a month, or open at one end, never drives a count.
    private struct Weighing: DriverWeighing {
        /// What a count knows of the walk around a conjunction.
        struct Walk {
            /// Whether #144 rejects most open tasks before it probes a tag in the conjunction (`Filter.narrows`), which
            /// lowers a tag's share to `narrowedShare`. A rule of a folder is weighed as though nothing narrowed it while
            /// the rules are grouped, and a branch of a disjunction as the conjunction around it, the disjunction's own
            /// narrowing among it.
            let narrowed: Bool
        }

        /// The tasks each tag a rule could be driven by holds, done, trashed and deleted ones among them, as `Store`
        /// counted them for this call. A tag that is not in it is no driver.
        let tagSizes: [TagID: Int64]
        /// The open tasks the status index holds, trashed and deleted ones among them, counted for this call too.
        let openTasks: Int64

        /// How many tasks one tag that drives a count may hold, against the open tasks the status index holds: under
        /// two fifths of them. A tag's driver walks every task the tag holds, done ones too, where the walk of the open
        /// tasks it replaces reads the tag's list once and each open task once. In #153's sweeps at 50,000 tasks a tag's
        /// list crossed that walk between 0.36 and 0.40 of the open tasks with about a quarter of the store open, and
        /// past 0.5 with every task open or beside the open status. Under the share every count measured was 1.6 to 12
        /// times faster than #144's, for a tag alone, beside the open status, an empty day, the root, the root negated
        /// or a range negated, and at most a twentieth slower than the walk, just under the share.
        static let tagShare = 0.4

        /// How many tasks the tags that drive a disjunction's branches may hold, added up, since its driver walks them
        /// all: under half of the open tasks, each tag also under `tagShare`. In #153's sweeps a disjunction of two to
        /// ten tags crossed the walk of the open tasks between 0.5 and 0.8 of them, summed, two tags of 0.2 each still
        /// faster at 0.4 and two of 0.3 slower at 0.6, and against #144's count it stayed faster up to 1.6 in both
        /// stores. Under the share it was 1.7 to 10 times faster than #144's, and at most an eighth slower than the walk.
        static let disjunctionShare = 0.5

        /// The share, for one tag or added up over a disjunction's, where #144 rejects most open tasks before it probes
        /// a tag (`narrows`), beside a day only a dated task meets or in a disjunction whose every branch it can reject
        /// that way: three hundredths of the open tasks. #144's count then costs little more than the walk of the open
        /// tasks itself, the least any count costs it, which a tag's driver beats only while the tag is small. Against
        /// a deadline no task has, where #144 does nothing but that walk, one tag crossed it between 0.10 and 0.15 of
        /// the open tasks with a quarter of the store open and between 0.05 and 0.06 with every task open, and a
        /// disjunction of two or three tags between 0.06 and 0.10, and between 0.03 and 0.04, summed; against
        /// Electrical's `deadline <= 30` one tag crossed between 0.15 and 0.20, and between 0.10 and 0.15. SQLite tests
        /// a day before a tag in a disjunction's branch too, whichever is written first. The share is under the least
        /// of them, so that no day a rule names makes a count slower than #144's.
        static let narrowedShare = 0.03

        func walk(ofStatement conditions: [Filter]) -> Walk {
            Walk(narrowed: conditions.contains(where: \.narrows))
        }

        func walk(ofRule conditions: [Filter], sharing shared: [Filter]) -> Walk {
            Walk(narrowed: false)
        }

        func walk(ofBranch conditions: [Filter], of disjunction: Filter, within around: Walk) -> Walk {
            around
        }

        func admitsADriver(_ conditions: [Filter]) -> Bool {
            !conditions.contains(where: CountCompiler.excludesOpen)
        }

        func tagDrives(_ tag: TagID, in walk: Walk) -> Bool {
            holdFewerTasks(than: walk.narrowed ? Self.narrowedShare : Self.tagShare, [tag])
        }

        func rangeDrives(_ condition: Filter, in walk: Walk) -> Bool {
            false
        }

        func disjunctionDrives(_ disjunction: Filter, branches: [(driver: Filter, walk: Walk)], in walk: Walk) -> Bool {
            let tags = branches.compactMap { branch -> TagID? in
                guard case .hasTag(let tag) = branch.driver else { return nil }
                return tag
            }
            return holdFewerTasks(than: walk.narrowed ? Self.narrowedShare : Self.disjunctionShare, tags)
        }

        /// A count's own `t.status` competes for the plan with a disjunction of parents, so a project in a disjunction
        /// is the list of its children there, which SQLite looks up by id beside every other branch's list (#153).
        var writesProjectsPlainly: Bool { false }

        /// A count weighs every disjunction after a tag, in the order #153 measured, and keeps the statements it measured.
        var disjunctionsThatNeedNoSizeOutrankTags: Bool { false }

        /// Whether the tags hold fewer tasks, added up, than `share` of the open ones. Summed and compared as `Double`,
        /// so that counts a store could hold never overflow on the way; a tag whose size was not read is no driver. No
        /// tags hold no tasks under any share, whatever the open count: a disjunction of projects, pins and days walks
        /// none, and in a store where no rule names a tag the open tasks are never counted at all.
        private func holdFewerTasks(than share: Double, _ tags: [TagID]) -> Bool {
            guard !tags.isEmpty else { return true }
            var held = 0.0
            for tag in tags {
                guard let size = tagSizes[tag] else { return false }
                held += Double(size)
            }
            return held < share * Double(openTasks)
        }
    }
}
