import Testing
import TestSupport
@testable import TaskListFeature
import TodoCore

// A rule read as an edit, one test per condition and per refusal (spec section 4): the same reading decides what "+"
// and "+ Add task" give a new task and what a drop into a block does (spec section 6).

private typealias TaskEdit = TaskList.TaskEdit

private let today = testDay.day
private let work = TagID("work")
private let home = TagID("home")
private let errands = ViewID("errands")
private let chores = ViewID("chores")

/// What a rule asks outside a day block, as a list with no grouping or a list inside reads it.
private func read(_ filter: Filter) -> TaskEdit? {
    TaskEdit.of(filter, today: today, day: nil)
}

@Test func aWhenOnGivesThatDay() {
    #expect(read(.when(.on(3))) == TaskEdit(when: .on(day(3))))
    #expect(read(.when(.on(-2))) == TaskEdit(when: .on(day(-2))))
    #expect(read(.deadline(.on(3))) == TaskEdit(deadline: .on(day(3))))
}

@Test func aWhenOnOrBeforeGivesTodayAtTheLatest() {
    #expect(read(.when(.onOrBefore(0))) == TaskEdit(when: .on(today)))
    #expect(read(.when(.onOrBefore(5))) == TaskEdit(when: .on(today)), "today is nearer than the last day it allows")
    #expect(read(.when(.onOrBefore(-3))) == TaskEdit(when: .on(day(-3))))
    #expect(read(.deadline(.onOrBefore(5))) == TaskEdit(deadline: .on(today)))
}

@Test func aWhenOnOrAfterGivesTodayAtTheEarliest() {
    #expect(read(.when(.onOrAfter(1))) == TaskEdit(when: .on(day(1))))
    #expect(read(.when(.onOrAfter(-5))) == TaskEdit(when: .on(today)), "today is nearer than the first day it allows")
    #expect(read(.deadline(.onOrAfter(2))) == TaskEdit(deadline: .on(day(2))))
}

@Test func aBetweenClampsToday() {
    #expect(read(.when(.between(-2, 2))) == TaskEdit(when: .on(today)))
    #expect(read(.when(.between(1, 5))) == TaskEdit(when: .on(day(1))))
    #expect(read(.when(.between(-5, -1))) == TaskEdit(when: .on(day(-1))))
    #expect(read(.deadline(.between(1, 5))) == TaskEdit(deadline: .on(day(1))))
}

/// A range with no day in it selects nothing and no day satisfies it: a condition no edit satisfies refuses (spec
/// section 4).
@Test func aRangeWithNoDayInItRefuses() {
    #expect(read(.when(.between(5, 1))) == nil)
    #expect(read(.deadline(.between(5, 1))) == nil)
}

@Test func aWhenEmptyGivesNoDay() {
    #expect(read(.when(.empty)) == TaskEdit(when: .noDay))
    #expect(read(.deadline(.empty)) == TaskEdit(deadline: .noDay))
}

@Test func aDayBlockGivesItsOwnDay() {
    #expect(TaskEdit.of(.when(.onOrAfter(1)), today: today, day: .on(day(4))) == TaskEdit(when: .on(day(4))))
    #expect(TaskEdit.of(.when(.onOrAfter(1)), today: today, day: .noDay) == TaskEdit(when: .noDay))
}

/// The block's day replaces what the rule's When gives, and it stands where the rule has none: a day block of a list
/// whose rule is a tag and a day of its own grouping (the controller's ruling on #176, 2026-11-05).
@Test func aRuleWithNoWhenInADayBlockTakesTheDay() {
    #expect(
        TaskEdit.of(.hasTag(work), today: today, day: .on(day(2))) == TaskEdit(when: .on(day(2)), addTags: [work])
    )
    #expect(
        TaskEdit.of(.or([.hasTag(work)]), today: today, day: .on(day(2))) == nil, "a rule that refuses still refuses"
    )
}

@Test func aTagGivesTheTag() {
    #expect(read(.hasTag(work)) == TaskEdit(addTags: [work]))
}

@Test func aManualListPins() {
    #expect(read(.listedIn(errands)) == TaskEdit(pinIn: errands))
}

@Test func aNegatedTagRemovesIt() {
    #expect(read(.not(.hasTag(work))) == TaskEdit(removeTags: [work]))
}

@Test func aNegatedManualListUnpins() {
    #expect(read(.not(.listedIn(errands))) == TaskEdit(unpinFrom: [errands]))
}

@Test func anOpenStatusARootAndNotTrashedAskNothing() {
    #expect(read(.status([.open])) == TaskEdit())
    #expect(read(.parent(nil)) == TaskEdit())
    #expect(read(.trashed(false)) == TaskEdit())
    #expect(read(.and([])) == TaskEdit())
}

@Test func aConjunctionGivesEach() {
    let rule = Filter.and([
        .status([.open]), .when(.onOrBefore(0)), .deadline(.on(2)), .hasTag(work), .hasTag(home), .listedIn(errands),
        .not(.hasTag(TagID("old"))), .not(.listedIn(chores)), .and([.parent(nil), .trashed(false)]),
    ])
    #expect(read(rule) == TaskEdit(
        when: .on(today), deadline: .on(day(2)), addTags: [work, home], removeTags: [TagID("old")], pinIn: errands,
        unpinFrom: [chores]
    ))
}

@Test func twoDaysThatDisagreeRefuse() {
    #expect(read(.and([.when(.on(1)), .when(.on(2))])) == nil)
    #expect(read(.and([.when(.empty), .when(.on(2))])) == nil)
    #expect(read(.and([.deadline(.on(1)), .deadline(.on(2))])) == nil)
    #expect(
        read(.and([.when(.onOrAfter(0)), .when(.onOrBefore(7))])) == TaskEdit(when: .on(today)), "both ask for today"
    )
}

/// A rule that asks a thing and its negation, or for two manual lists where a task is pinned by one edit, reads as no
/// one edit to one task: a condition no edit satisfies refuses (spec section 4).
@Test func aRuleAtOddsWithItselfRefuses() {
    #expect(read(.and([.hasTag(work), .not(.hasTag(work))])) == nil)
    #expect(read(.and([.listedIn(errands), .not(.listedIn(errands))])) == nil)
    #expect(read(.and([.listedIn(errands), .listedIn(chores)])) == nil)
}

@Test func alternativesRefuse() {
    #expect(read(.or([.hasTag(work), .hasTag(home)])) == nil)
    #expect(read(.or([.hasTag(work)])) == nil)
    #expect(read(.and([.hasTag(work), .or([.when(.on(1))])])) == nil, "inside a conjunction too")
}

@Test func aDoneStatusAParentAndTheTrashRefuse() {
    #expect(read(.status([.done])) == nil)
    #expect(read(.status([.open, .done])) == nil)
    #expect(read(.status([])) == nil)
    #expect(read(.parent(TaskID("parent"))) == nil)
    #expect(read(.trashed(true)) == nil)
    #expect(read(.not(.status([.done]))) == nil, "any other negation")
    #expect(read(.not(.not(.hasTag(work)))) == nil)
}

/// An offset comes from a filter another device wrote and may lie past what a day holds: it lands on the nearest day
/// the module names and nothing traps (global constraints).
@Test func anOffsetOutsideInt32IsClamped() {
    let latest = Day(year: 2_000_000, month: 1, day: 1)
    let earliest = Day(year: -2_000_000, month: 1, day: 1)
    #expect(read(.when(.on(.max))) == TaskEdit(when: .on(latest)))
    #expect(read(.when(.on(.min))) == TaskEdit(when: .on(earliest)))
    #expect(read(.when(.onOrAfter(.max))) == TaskEdit(when: .on(latest)))
    #expect(read(.when(.onOrBefore(.min))) == TaskEdit(when: .on(earliest)))
    #expect(read(.deadline(.between(.max - 1, .max))) == TaskEdit(deadline: .on(latest)))
    #expect(read(.deadline(.between(.min, .min + 1))) == TaskEdit(deadline: .on(earliest)))
}

@Test func theInboxAsksNoDayTodayAsksTodayUpcomingAsksTomorrow() throws {
    let store = try makeStore()
    func rule(_ view: ViewID) throws -> Filter { try #require(try store.view(view)?.filter) }
    #expect(read(try rule(BuiltInTaskViews.inbox)) == TaskEdit(when: .noDay))
    #expect(read(try rule(BuiltInTaskViews.today)) == TaskEdit(when: .on(today)))
    #expect(read(try rule(BuiltInTaskViews.upcoming)) == TaskEdit(when: .on(day(1))))
}

@Test func logbookAndTrashRefuse() throws {
    let store = try makeStore()
    #expect(read(try #require(try store.view(BuiltInTaskViews.logbook)?.filter)) == nil)
    #expect(read(try #require(try store.view(BuiltInTaskViews.trash)?.filter)) == nil)
}

/// A rule draws finished tasks as its rows where it asks for no open task: a status without open, the Trash, a
/// conjunction with such a part, alternatives of only such parts (the controller's ruling on #176, 2026-11-05).
@Test func aRuleDrawsFinishedTasksWhereItAsksForNoOpenOne() {
    #expect(TaskList.drawsFinished(.status([.done, .canceled])))
    #expect(TaskList.drawsFinished(.trashed(true)))
    #expect(TaskList.drawsFinished(.and([.hasTag(work), .status([.done])])))
    #expect(TaskList.drawsFinished(.or([.status([.done]), .trashed(true)])))
    #expect(!TaskList.drawsFinished(.status([.open])))
    #expect(!TaskList.drawsFinished(.status([.open, .done])))
    #expect(!TaskList.drawsFinished(.trashed(false)))
    #expect(!TaskList.drawsFinished(.listedIn(errands)))
    #expect(!TaskList.drawsFinished(.hasTag(work)))
    #expect(!TaskList.drawsFinished(.or([.status([.done]), .hasTag(work)])))
    #expect(!TaskList.drawsFinished(.or([])))
    #expect(!TaskList.drawsFinished(.not(.status([.open]))))
}
