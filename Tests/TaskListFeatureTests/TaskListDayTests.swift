import Testing
import TestSupport
import DesignSystem
import DesignSystemComponents
import SQLiteKit
import TaskListFeature
import TodoCore

/// Today's subtitle is its date written long, the weekday's and the month's names in full, on any day of any month
/// (spec section 8); the canvas's "Saturday, October 24".
@Test func theLongDateNamesTheWeekdayTheMonthAndTheDay() throws {
    let store = try makeStore()
    let cases: [(Day, String)] = [
        (Day(year: 2026, month: 10, day: 24), "Saturday, October 24"),
        (Day(year: 2025, month: 9, day: 10), "Wednesday, September 10"),
        (Day(year: 2026, month: 1, day: 1), "Thursday, January 1"),
        (Day(year: 2026, month: 2, day: 2), "Monday, February 2"),
        (Day(year: 2026, month: 3, day: 3), "Tuesday, March 3"),
        (Day(year: 2026, month: 4, day: 5), "Sunday, April 5"),
        (Day(year: 2026, month: 5, day: 8), "Friday, May 8"),
        (Day(year: 2026, month: 6, day: 30), "Tuesday, June 30"),
        (Day(year: 2026, month: 7, day: 4), "Saturday, July 4"),
        (Day(year: 2026, month: 8, day: 31), "Monday, August 31"),
        (Day(year: 2026, month: 11, day: 4), "Wednesday, November 4"),
        (Day(year: 2026, month: 12, day: 25), "Friday, December 25"),
    ]
    for (today, long) in cases {
        let model = try TaskList(
            store: store, route: .init(head: .init(view: BuiltInTaskViews.today)), day: deviceDay(today)
        ).model
        #expect(model.header.subtitle?.text == long)
    }
}

/// A day's block is titled "Today", "Tomorrow", or the weekday's full name for every other day, past or future, at any
/// distance, with the date under it short with its weekday for today and tomorrow and without it for every other day; a
/// day in another year needs no year (canvas, `dayTitle` and `dayDate`; the controller's ruling on #175, 2026-11-04).
@Test func aDaysBlockIsTitledTodayTomorrowOrItsWeekdayAtAnyDistance() throws {
    let store = try makeStore()
    let byDay = try store.createView(NewTaskView(title: "By day", filter: .status([.open]), sort: [SortKey(.when)], groupBy: .whenDay))
    let offsets = [-8, -1, 0, 1, 2, 3, 4, 5, 6, 7, 30, 120]
    for offset in offsets { try store.createTask(NewTask(title: "On \(offset)", when: day(offset))) }
    let headings = blocks(of: try TaskList(store: store, route: .init(head: .init(view: byDay)), day: testDay).model)
        .map { [$0.header?.title.text, $0.header?.subtitle?.text] }
    #expect(headings == [
        ["Tuesday", "Sep 2"], ["Tuesday", "Sep 9"], ["Today", "Wed, Sep 10"], ["Tomorrow", "Thu, Sep 11"],
        ["Friday", "Sep 12"], ["Saturday", "Sep 13"], ["Sunday", "Sep 14"], ["Monday", "Sep 15"],
        ["Tuesday", "Sep 16"], ["Wednesday", "Sep 17"], ["Friday", "Oct 10"], ["Thursday", "Jan 8"],
    ])
}

/// The due text at every distance: "Overdue 1 day" in the singular and "Overdue N days", "Due today", the weekday's
/// short name through six days ahead with no "Due tomorrow", and the month and the day from seven days on (canvas,
/// `dueText`; the controller's ruling on #175, 2026-11-04).
@Test func theDueTextAtEveryDistance() throws {
    let store = try makeStore()
    let cases: [(Int, String)] = [
        (-400, "Overdue 400 days"), (-2, "Overdue 2 days"), (-1, "Overdue 1 day"), (0, "Due today"), (1, "Due Thu"),
        (2, "Due Fri"), (3, "Due Sat"), (4, "Due Sun"), (5, "Due Mon"), (6, "Due Tue"), (7, "Due Sep 17"),
        (21, "Due Oct 1"), (113, "Due Jan 1"),
    ]
    for (offset, _) in cases { try store.createTask(NewTask(title: "Due \(offset)", deadline: day(offset))) }
    let rows = try #require(blocks(of: try TaskList(store: store, route: .init(head: .init(view: BuiltInTaskViews.inbox)), day: testDay).model).first).rows
    #expect(rows.map { row($0).meta.first?.text?.text } == cases.map(\.1))
}

/// A group's screen is titled by its group: the day the distance falls on today, with the list's title and that
/// day's date under it, and the other groups by their names with the list's title alone (spec section 2; canvas).
@Test func aGroupsScreenIsTitledByItsGroup() throws {
    let store = try makeStore()
    let errand = try store.createTag(title: "errand")
    let plan = try store.createTask(NewTask(title: "The plan"))
    let week = try store.createView(NewTaskView(title: "This week", filter: .status([.open]), groupBy: .whenDay))
    let byTag = try store.createView(NewTaskView(title: "By tag", filter: .status([.open]), groupBy: .tag))
    let byParent = try store.createView(NewTaskView(title: "By parent", filter: .status([.open]), groupBy: .parent))
    let byStatus = try store.createView(NewTaskView(title: "By status", filter: .status([.open]), groupBy: .status))
    let byDeadline = try store.createView(NewTaskView(title: "Due", filter: .status([.open]), groupBy: .deadlineDay))
    let cases: [(ViewID, TaskList.Route.Group, String, String)] = [
        (week, .day(0), "Today", "This week · Wed, Sep 10"),
        (week, .day(1), "Tomorrow", "This week · Thu, Sep 11"),
        (week, .day(2), "Friday", "This week · Sep 12"),
        (week, .day(-1), "Tuesday", "This week · Sep 9"),
        (week, .day(14), "Wednesday", "This week · Sep 24"),
        (week, .day(nil), "No date", "This week"),
        (byDeadline, .deadline(3), "Saturday", "Due · Sep 13"),
        (byTag, .tag(errand), "errand", "By tag"),
        (byTag, .tag(nil), "No tag", "By tag"),
        (byParent, .parent(plan), "The plan", "By parent"),
        (byParent, .parent(nil), "No parent", "By parent"),
        (byStatus, .status(.open), "Open", "By status"),
        (byStatus, .status(.done), "Done", "By status"),
        (byStatus, .status(.canceled), "Canceled", "By status"),
    ]
    for (view, group, title, subtitle) in cases {
        let header = try TaskList(store: store, route: .init(head: .init(view: view, group: group)), day: testDay).model.header
        #expect([header.title.text, header.subtitle?.text] == [title, subtitle], "\(group)")
    }
}

/// A day a peer wrote can lie at either end of what a day holds, where measuring it from today or naming its date
/// would leave the 32-bit integer on wasm32: such a day is named, measured and keyed as the nearest day the module can
/// name, and nothing traps (`docs/style.md`, "A trap is a bug").
@Test func aDayAtEitherEndOfTheCountIsNamedWithoutATrap() throws {
    let store = try makeStore()
    let byDay = try store.createView(NewTaskView(title: "By day", filter: .status([.open]), sort: [SortKey(.when)], groupBy: .whenDay))
    let past = try store.createTask(NewTask(title: "Long ago"))
    let future = try store.createTask(NewTask(title: "Far ahead"))
    let peer = Store.newDeviceID()
    var counter: Int32 = 0
    func write(_ task: TaskID, _ field: String, _ count: Int32) -> JournalOperation {
        counter += 1
        return JournalOperation(
            entity: .task, entityID: task.rawValue, field: field, value: .integer(Int64(count)),
            clock: HLC(millis: 1_800_000_000_000, counter: counter), device: peer
        )
    }
    _ = try store.apply([
        write(past, "when_day", .min), write(past, "deadline_day", .min),
        write(future, "when_day", .max), write(future, "deadline_day", .max),
    ])
    let module = try TaskList(store: store, route: .init(head: .init(view: byDay)), day: testDay)
    let model = module.model
    #expect(blocks(of: model).compactMap(\.header).count == 2)
    #expect(blocks(of: model).flatMap(\.rows).map { row($0).meta.first?.text?.text.hasPrefix("Overdue") } == [true, false])
    for block in blocks(of: model) { _ = module.send(.action(.blockChevronTapped(block.id))) }
    #expect(try store.deviceState("taskList.folded.\(byDay)", as: [String].self)?.count == 2)
    for block in blocks(of: model) { _ = module.send(.action(.blockTitleTapped(block.id))) }
    #expect(module.destination.pushed != nil)
}

/// The When pill names today and tomorrow, a past day by its date and a later one by its weekday and date; unset it
/// reads "When" in ink 2, and the sun is amber only while it is set (canvas, `whenLabel`; the controller's ruling on
/// #176, 2026-11-05).
@Test func theWhenPillNamesTodayTomorrowAPastDayAndALaterOne() throws {
    let store = try makeStore()
    let cases: [(Int?, String)] = [
        (0, "Today"), (1, "Tomorrow"), (-2, "Sep 8"), (2, "Fri, Sep 12"), (16, "Fri, Sep 26"), (nil, "When"),
    ]
    let view = try store.createView(NewTaskView(title: "All", filter: .status([.open])))
    for (offset, text) in cases {
        let id = try store.createTask(NewTask(title: "\(text)", when: offset.map(day)))
        let module = try list(view, in: store)
        module.tap(.rowTapped(id))
        let pill = try #require(openCard(in: module.model)?.card.pills.first)
        #expect(pill.text.text == text)
        #expect(pill.text.style.color == (offset == nil ? .ink2 : .ink))
        #expect(pill.icon.style.color == (offset == nil ? .ink2 : DesignSystem.Color.Components.Tile.amber.glyph))
    }
}

/// The Deadline pill always names its weekday and date, in ink, and red from the day it is due; its flag is red while
/// it is set, a future deadline's too; unset it reads "Deadline" in ink 2 (canvas, `dayShort`; the controller's ruling
/// on #176, 2026-11-05).
@Test func theDeadlinePillAlwaysNamesItsWeekdayAndDate() throws {
    let store = try makeStore()
    let cases: [(Int?, String, DesignSystem.Color)] = [
        (-1, "Tue, Sep 9", .red), (0, "Wed, Sep 10", .red), (1, "Thu, Sep 11", .ink), (nil, "Deadline", .ink2),
    ]
    let view = try store.createView(NewTaskView(title: "All", filter: .status([.open])))
    for (offset, text, color) in cases {
        let id = try store.createTask(NewTask(title: text, deadline: offset.map(day)))
        let module = try list(view, in: store)
        module.tap(.rowTapped(id))
        let pills = try #require(openCard(in: module.model)?.card.pills)
        #expect(pills[1].text.text == text)
        #expect(pills[1].text.style.color == color)
        #expect(pills[1].icon.style.color == (offset == nil ? .ink2 : .red))
    }
}
