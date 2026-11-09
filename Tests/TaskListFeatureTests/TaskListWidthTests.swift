import Testing
import TestSupport
import DesignSystem
import DesignSystemComponents
import FeatureModule
import TaskListFeature
import TodoCore

// The window's width reaches the list as the day does, and the numbers the list's model carries follow it: the phone's
// in a narrow window and the Mac's pane in a wide one (list screen plan, Task 9; the controller's rulings R192 and
// R195).

private let grayLine = LineStyle(color: .glassLine, width: 0.5, dash: [])

private func columns(of model: TaskList.Model) -> TaskList.Model.Board? {
    switch model.layout {
    case .list: nil
    case .columns(let board): board
    }
}

/// The module on a view with two tasks and a tag, in a window of the width, with the first task's card open, a tag
/// picked, the Done strip open and a subtask half typed, which a test then moves. Nothing here writes, so that two
/// modules over the same store read the same page.
private func opened(in store: Store, width: WindowWidth, _ ids: (milk: TaskID, tag: TagID)) throws -> TaskList {
    let module = try list(BuiltInTaskViews.upcoming, in: store, width: width)
    module.tap(.tagChipTapped(ids.tag))
    module.tap(.doneStripTapped)
    module.tap(.rowTapped(ids.milk))
    module.tap(.addSubtaskTapped)
    module.tap(.subtaskFieldChanged("Wipe the shelf"))
    return module
}

private func seeded(_ store: Store) throws -> (milk: TaskID, tag: TagID) {
    let tag = try store.createTag(title: "home")
    let milk = try store.createTask(NewTask(title: "Buy milk", when: day(1), tags: [tag]))
    try store.createTask(NewTask(title: "Water", when: day(2), tags: [tag]))
    return (milk, tag)
}

/// A list made wide carries the pane's numbers, in the list and in columns: the glass "+" in the capsule, no floating
/// one, the content 780 wide at most and the board free (Task 9's table).
@Test func aWideListCarriesThePanesNumbers() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let module = try list(BuiltInTaskViews.upcoming, in: store, width: .wide)
    let model = module.model
    #expect(model.style.contentTop == 62)
    #expect(model.style.contentBottom == 140)
    #expect(model.style.contentHorizontalPadding == 48)
    #expect(model.style.contentMaxWidth == 780)
    #expect(model.style.fade == ListScreenStyle.Fade(color: .paper, height: 60, solidDepth: 33))
    #expect(model.style.barHeight == 52)
    #expect(model.style.barSpacing == 8)
    #expect(model.style.capsule == GlassCapsuleStyle(
        height: 34, cornerRadius: 99, horizontalPadding: 3,
        divider: LineStyle(color: .line, width: 1, dash: []), dividerHeight: 16
    ))
    #expect(model.back.label.style == GlassControlStyle(
        iconOffset: -1, diameter: 34, height: 34, surface: .glass, line: grayLine, shadow: .raised
    ))
    #expect(model.back.label.icon.style == IconStyle(size: 19, weight: .medium, color: .ink))
    #expect(model.more.icon.style == IconStyle(size: 18, weight: .regular, color: .ink))
    #expect(model.more.style.diameter == 30)
    #expect(model.more.style.height == 28)
    #expect(model.glassAddTask == GlassButtonModel(
        label: GlassButtonLabelModel(
            icon: IconModel(icon: .plus, style: IconStyle(size: 17, weight: .medium, color: .ink)),
            style: GlassControlStyle(
                iconOffset: 0, diameter: 30, height: 28, surface: .glass, line: grayLine, shadow: .raised
            ),
            accessibilityLabel: "New task"
        ),
        action: .addTaskButtonTapped
    ))
    #expect(model.addTask == nil, "the pane has no floating \"+\"")
    #expect(model.header.tile.style.side == 40)
    #expect(model.header.style.subtitleLeading == 52)
    guard case .list(let blocks) = model.layout, let row = blocks.first?.rows.first,
          case .task(_, let task) = row
    else {
        Issue.record("the list draws its blocks, and the first holds a row")
        return
    }
    #expect(task.style.minimumHeight == 36)
    #expect(task.style.cornerRadius == 9)
    #expect(task.style.leading == 4)
    #expect(task.style.trailing == 10)
    #expect(task.style.metaTrailing, "the Mac's meta stands on the title's line")
    #expect(task.style.hover != nil)
    #expect(task.check.style.diameter == 18)
    #expect(task.check.style.hitWidth == 32)
    #expect(task.check.style.hitHeight == 36)

    module.tap(.showAsChosen(.columns))
    let board = try #require(columns(of: module.model))
    #expect([board.spacing, board.horizontalPadding, board.endRoom, board.bottomPadding] == [12, 24, 12, 24])
    #expect(!board.snaps, "the Mac's board scrolls freely")
    #expect(try #require(board.columns.first?.column).style.width == 288)
    #expect(module.model.style.contentHorizontalPadding == 0)
    #expect(module.model.style.contentMaxWidth == nil)
    #expect(
        module.model.style.fade == ListScreenStyle.Fade(color: .paper, height: 60, solidDepth: 33),
        "the pane's fade is the pane's, over the board as over the list"
    )
    #expect(module.model.addTask == nil)
    #expect(module.model.glassAddTask != nil)
}

/// A list made narrow carries the phone's numbers as before, with the floating "+" and no glass one, and with each
/// field the pane's tables added the phone's own value.
@Test func aNarrowListCarriesThePhonesNumbersAndTheFloatingPlus() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let module = try list(BuiltInTaskViews.upcoming, in: store, width: .narrow)
    let model = module.model
    #expect(model.style == ListScreenStyle(
        edgeInset: 14, fade: ListScreenStyle.Fade(color: .paper, height: 54, solidDepth: 15.12), contentTop: 56,
        contentBottom: 116, background: .paper, contentHorizontalPadding: 0, contentMaxWidth: nil, barHeight: 44,
        barSpacing: 0, capsule: nil
    ))
    #expect(model.addTask != nil)
    #expect(model.glassAddTask == nil)
    #expect(model.back.label.icon.style == IconStyle(size: 24, weight: .regular, color: .ink))
    #expect(model.back.label.style.height == 44)
    #expect(model.more.style.height == 44)
    module.tap(.showAsChosen(.columns))
    #expect(try #require(columns(of: module.model)).snaps)
    #expect(module.model.addTask != nil)
    #expect(module.model.glassAddTask == nil)
}

/// A list that takes no task has neither "+", wide or narrow.
@Test func aListThatTakesNoTaskHasNeitherPlus() throws {
    let store = try makeStore()
    for width in [WindowWidth.narrow, .wide] {
        let model = try list(BuiltInTaskViews.logbook, in: store, width: width).model
        #expect(model.addTask == nil)
        #expect(model.glassAddTask == nil)
    }
}

/// The glass "+" does what the floating one does: the same action, answered by the same write.
@Test func theGlassPlusAddsATaskAsTheFloatingOneDoes() throws {
    let store = try makeStore()
    let module = try list(BuiltInTaskViews.inbox, in: store, width: .wide)
    let plus = try #require(module.model.glassAddTask)
    module.tap(plus.action)
    #expect(openCard(in: module.model) != nil)
}

/// The width moves the numbers and nothing else: what a person has open or typed stays, so the model after the move is
/// the model of a list that was made at the new width and given the same events.
@Test func aWidthChangeMovesTheNumbersAndNothingElse() throws {
    let store = try makeStore()
    let ids = try seeded(store)
    let narrow = try opened(in: store, width: .narrow, ids)
    let wide = try opened(in: store, width: .wide, ids)
    #expect(narrow.model != wide.model, "the two widths draw different numbers")
    #expect(narrow.send(.widthChanged(.wide)) == nil)
    #expect(narrow.model == wide.model)
    #expect(wide.send(.widthChanged(.narrow)) == nil)
    #expect(narrow.send(.widthChanged(.narrow)) == nil)
    #expect(narrow.model == wide.model)
    #expect(openCard(in: narrow.model)?.card.subtaskField?.text == "Wipe the shelf", "the open card and its draft stay")
}

/// A width reads nothing from the store, the one it has and a new one alike: the page is state, and the numbers are
/// computed from the width on every read of the model. A task renamed behind the module's back, with no change handed
/// to it, shows on screen only if the page was read again, so the old title standing proves no read (a day's change
/// is the control: it rereads and the new title shows). The guard on the width it already has is the sibling of the
/// day's and moves nothing a test could see beyond that.
@Test func aWidthRereadsNothingFromTheStore() throws {
    let store = try makeStore()
    let ids = try seeded(store)
    for (first, second) in [(WindowWidth.narrow, WindowWidth.wide), (.wide, .narrow)] {
        let module = try opened(in: store, width: first, ids)
        func titles() -> [String] { rows(of: module.model).map(\.title) }
        let before = titles()
        try store.update(task: ids.milk, [.title("Renamed behind its back")])
        #expect(module.send(.widthChanged(first)) == nil)
        #expect(titles() == before, "the width it has")
        #expect(module.send(.widthChanged(second)) == nil)
        #expect(titles() == before, "a new width")
        let tomorrow = deviceDay(day(1))
        #expect(module.send(.dayChanged(tomorrow)) == nil)
        #expect(titles() != before, "control: a new day rereads, so the test can tell")
        try store.update(task: ids.milk, [.title("Buy milk")])
    }
}

/// A list made on a route with a list over it hands the width to nothing itself: the window's stack makes what it
/// declared, so the module only keeps its own width, and a move leaves what it declared and its route alone.
@Test func aWidthChangeLeavesTheRouteAndTheDestination() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", parent: BuiltInTaskViews.upcoming))
    let route = TaskList.Route(
        head: .init(view: BuiltInTaskViews.upcoming), tail: .list(.init(head: .init(view: work)))
    )
    let module = try list(route, in: store)
    let destination = module.destination
    #expect(module.send(.widthChanged(.wide)) == nil)
    #expect(module.route == route)
    #expect(module.destination.pushed == destination.pushed)
}
