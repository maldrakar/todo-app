// Sources/Features/TaskList/TaskList+Rule.swift
import TodoCore

extension TaskList {
    /// What a rule asks of a task for it to match, one edit per condition (spec sections 4 and 6): what "+" and "+ Add
    /// task" give a new task, and what a drop into a block writes on the task it takes. `when` and `deadline` are nil
    /// for no edit, `.some(nil)` for no day and `.some(day)` for that day.
    struct TaskEdit: Equatable {
        let when: Day??
        let deadline: Day??
        let addTags: Set<TagID>
        let removeTags: Set<TagID>
        let pinIn: ViewID?
        let unpinFrom: Set<ViewID>

        /// TaskEdit ask nothing but what they are given, which is what an open status, the root and being out of the
        /// Trash ask of a task the screen adds or drags, which is open, at the root and out of the Trash, and what a
        /// conjunction starts from.
        init(
            when: Day?? = nil, deadline: Day?? = nil, addTags: Set<TagID> = [], removeTags: Set<TagID> = [],
            pinIn: ViewID? = nil, unpinFrom: Set<ViewID> = []
        ) {
            self.when = when
            self.deadline = deadline
            self.addTags = addTags
            self.removeTags = removeTags
            self.pinIn = pinIn
            self.unpinFrom = unpinFrom
        }

        /// The edit a rule asks of a task, or nil for a rule the module cannot read as an edit (spec section 4). `day`
        /// is the When of the day block it is for, which replaces what the rule's When gives and stands where the
        /// rule has none, and nil outside a day block; a rule that refuses refuses there too (the controller's ruling
        /// on #176, 2026-11-05).
        static func of(_ filter: Filter, today: Day, day: Day??) -> TaskEdit? {
            guard let edit = read(filter, today: today) else { return nil }
            guard let day else { return edit }
            return TaskEdit(
                when: day, deadline: edit.deadline, addTags: edit.addTags, removeTags: edit.removeTags,
                pinIn: edit.pinIn, unpinFrom: edit.unpinFrom
            )
        }

        /// This edit with the day of a day block of a list grouped by deadline, which is the task's deadline (the
        /// controller's ruling on #176, 2026-11-05).
        func settingDeadline(_ day: Day?) -> TaskEdit {
            TaskEdit(
                when: when, deadline: .some(day), addTags: addTags, removeTags: removeTags, pinIn: pinIn,
                unpinFrom: unpinFrom
            )
        }

        /// What a drop writes through `update(task:)`: the days this edit asks that the task does not hold. A day
        /// condition of `rule` the task already meets asks nothing of it, so an overdue task dropped into Today keeps
        /// its day; `ownDay` says which day the block's own day is, for a day block, which always writes it (the
        /// controller's ruling on #176, 2026-11-05).
        func dayChanges(of task: TodoTask, rule: Filter?, ownDay: GroupBy?, today: Day) -> [TaskChange] {
            var changes: [TaskChange] = []
            let whenHolds = TaskEdit.holds(rule, on: task.when, today: today) {
                if case .when(let condition) = $0 { condition } else { nil }
            }
            let deadlineHolds = TaskEdit.holds(rule, on: task.deadline, today: today) {
                if case .deadline(let condition) = $0 { condition } else { nil }
            }
            if let when, when != task.when, ownDay == .whenDay || !whenHolds { changes.append(.when(when)) }
            if let deadline, deadline != task.deadline, ownDay == .deadlineDay || !deadlineHolds {
                changes.append(.deadline(deadline))
            }
            return changes
        }

        /// The walk over the rule, which may recurse, since the store refuses a filter deeper than `maximumDepth`
        /// (global constraints): a condition its edit, a conjunction each of its parts, and nil for what no edit
        /// satisfies.
        private static func read(_ filter: Filter, today: Day) -> TaskEdit? {
            switch filter {
            case .when(let condition):
                guard let day = day(condition, today: today) else { return nil }
                return TaskEdit(when: day)
            case .deadline(let condition):
                guard let day = day(condition, today: today) else { return nil }
                return TaskEdit(deadline: day)
            case .hasTag(let tag):
                return TaskEdit(addTags: [tag])
            case .listedIn(let view):
                return TaskEdit(pinIn: view)
            case .not(.hasTag(let tag)):
                return TaskEdit(removeTags: [tag])
            case .not(.listedIn(let view)):
                return TaskEdit(unpinFrom: [view])
            case .status(let statuses) where !statuses.isEmpty && statuses.allSatisfy({ $0 == .open }):
                return TaskEdit()
            case .parent(nil), .trashed(false):
                return TaskEdit()
            case .and(let parts):
                var edit = TaskEdit()
                for part in parts {
                    guard let asked = read(part, today: today), let merged = edit.merged(with: asked) else {
                        return nil
                    }
                    edit = merged
                }
                return edit
            case .or, .status, .parent, .trashed, .not:
                return nil
            }
        }

        /// The day nearest today a condition allows: `.some(nil)` for no day, and nil where no day satisfies it, a
        /// range with no day in it. The offset is a filter's, an `Int64` a peer wrote, and `TaskList.day(_:from:)`
        /// clamps it.
        private static func day(_ condition: DayCondition, today: Day) -> Day?? {
            switch condition {
            case .empty: return .some(nil)
            case .on(let offset): return TaskList.day(offset, from: today)
            case .onOrBefore(let offset): return TaskList.day(min(offset, 0), from: today)
            case .onOrAfter(let offset): return TaskList.day(max(offset, 0), from: today)
            case .between(let first, let last):
                guard first <= last else { return nil }
                return TaskList.day(min(max(0, first), last), from: today)
            }
        }

        /// Both as one, or nil where they disagree: two days that differ, two manual lists, a tag or a list asked
        /// and taken off.
        private func merged(with other: TaskEdit) -> TaskEdit? {
            if let when, let theirs = other.when, when != theirs { return nil }
            if let deadline, let theirs = other.deadline, deadline != theirs { return nil }
            if let pinIn, let theirs = other.pinIn, pinIn != theirs { return nil }
            let addTags = addTags.union(other.addTags)
            let removeTags = removeTags.union(other.removeTags)
            let pinIn = pinIn ?? other.pinIn
            let unpinFrom = unpinFrom.union(other.unpinFrom)
            guard addTags.isDisjoint(with: removeTags), pinIn.map(unpinFrom.contains) != true else { return nil }
            return TaskEdit(
                when: when ?? other.when, deadline: deadline ?? other.deadline, addTags: addTags,
                removeTags: removeTags, pinIn: pinIn, unpinFrom: unpinFrom
            )
        }

        /// Whether a day meets every condition of the rule that `condition` picks out of it; nothing but a conjunction
        /// can hold one a task must meet, since a rule of any other shape refused.
        private static func holds(
            _ rule: Filter?, on day: Day?, today: Day, _ condition: (Filter) -> DayCondition?
        ) -> Bool {
            guard let rule else { return true }
            if case .and(let parts) = rule {
                return parts.allSatisfy { holds($0, on: day, today: today, condition) }
            }
            return condition(rule).map { holds($0, on: day, today: today) } ?? true
        }

        /// Whether a day meets a condition, as the core's read compares it, a day measured from today in the days the
        /// module names (`TaskList.distance(to:from:)`).
        private static func holds(_ condition: DayCondition, on day: Day?, today: Day) -> Bool {
            guard let day else { return condition == .empty }
            let distance = Int64(TaskList.distance(to: day, from: today))
            switch condition {
            case .empty: return false
            case .on(let offset): return distance == offset
            case .onOrBefore(let offset): return distance <= offset
            case .onOrAfter(let offset): return distance >= offset
            case .between(let first, let last): return first <= distance && distance <= last
            }
        }
    }

    /// Whether a rule draws finished tasks as its rows, which is why it keeps them in its blocks and has no strip and
    /// no list inside: a status without open, the Trash, a conjunction with such a part, alternatives of only such
    /// parts. A rule that names no status, a manual list's, draws its open tasks, as the rows of a list are (spec
    /// section 3; the controller's ruling on #176, 2026-11-05). No built-in is named: this is how Logbook and Trash are
    /// told.
    static func drawsFinished(_ rule: Filter) -> Bool {
        switch rule {
        case .status(let statuses): !statuses.contains(.open)
        case .trashed(let trashed): trashed
        case .and(let parts): parts.contains(where: drawsFinished)
        case .or(let parts): !parts.isEmpty && parts.allSatisfy(drawsFinished)
        case .when, .deadline, .hasTag, .parent, .listedIn, .not: false
        }
    }
}
