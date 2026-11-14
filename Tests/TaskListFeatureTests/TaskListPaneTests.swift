import Testing
import TestSupport
import DesignSystem
import DesignSystemComponents
import FeatureModule
import TaskListFeature
import TodoCore

// The Mac pane's numbers, row by row of Task 9's table, read through the models a wide list gives (the controller's
// ruling R192). The phone's are held by `TaskListComponentsTests`.

private typealias Action = TaskList.UserAction
private typealias Tile = DesignSystem.Color.Components.Tile

private let hairline = LineStyle(color: .glassLine, width: 0.5, dash: [])
private let rule = LineStyle(color: .line, width: 1, dash: [])
private let taskLeaving = TaskLeavingStyle(
    titleColor: .ink2, strike: .ink3, offset: 12, animation: .rowLeaves,
    reducedAnimation: .rowLeavesWithNoMotion, deleteAnimation: .rowDeleted
)
private let cardEntrance = EntranceStyle(
    opacity: 0.3, scale: 0.98, offset: -3, anchorX: 0.5, anchorY: 0.5, animation: .cardOpens
)
private let tagCapsule = MetaItemStyle.Capsule(
    background: .fill, height: 20, cornerRadius: 10, leadingPadding: 8, trailingPadding: 8
)

/// The pane's tint under a control the pointer is over, within corners of the radius given: the canvas's `--hover`
/// over 0.12 s (`Mac.dc.html`, `.mc-tap`, `.mc-trow`, `.mc-ib`, `.mc-gi` and `.tchip`; the controller's rulings R209
/// and R213).
private func hoverTint(_ cornerRadius: Double) -> HoverStyle {
    HoverStyle(color: .hover, cornerRadius: cornerRadius, animation: .hoverTints)
}

/// A list "Projects" with a list inside it, "House", a task in both with a tag, notes, a subtask and a deadline, and a
/// task done today, on a wide window.
private struct Scene {
    let store: Store
    let module: TaskList
    let projects: ViewID
    let house: ViewID
    let milk: TaskID
    let tag: TagID

    init() throws {
        store = try makeStore()
        tag = try store.createTag(title: "home")
        projects = try store.createView(NewTaskView(title: "Projects", color: .rose, filter: .trashed(false)))
        house = try store.createView(
            NewTaskView(title: "House", parent: projects, color: .teal, filter: .hasTag(tag))
        )
        milk = try store.createTask(NewTask(title: "Buy milk", notes: "two", deadline: day(3), tags: [tag]))
        try store.createTask(NewTask(title: "Wipe", parent: milk))
        let filed = try store.createTask(NewTask(title: "Filed"))
        try store.update(task: filed, [.status(.done)])
        module = try list(projects, in: store, width: .wide)
    }

    var model: TaskList.Model { module.model }

    func block(_ id: TaskList.Model.BlockID) throws -> TaskList.Model.Block {
        try #require(blocks(of: model).first { $0.id == id })
    }
}

private func taskRowStyle(
    isOpen: Bool = true, lift: TaskLiftStyle?, fresh: Bool = false
) -> TaskRowStyle {
    TaskRowStyle(
        titleToMeta: 12, metaSpacing: 8, metaLineSpacing: 0, verticalPadding: 9, titleLeading: 4, titleTrailing: 0,
        leading: 4, trailing: 10, minimumHeight: 36, cornerRadius: 9, strike: isOpen ? nil : .ink3, lift: lift,
        fresh: fresh ? .fresh : nil, landingScale: nil, landingAnimation: .fresh, titleAnimation: .titleFades,
        leaving: taskLeaving, ground: .paper, metaTrailing: true, hover: hoverTint(9)
    )
}

private func lift(_ radius: Double) -> TaskLiftStyle {
    TaskLiftStyle(
        scale: 1.03, opacity: 0.35, cornerRadius: radius, background: .surface, shadow: .lifted,
        dimAnimation: .dropHighlights, slotAnimation: .slotMoves, impact: .light
    )
}

/// The list's header, tag bar, block header, rows, add rows and Done strip: the tile 40, the title 12 after it, the
/// subtitle 6 under it and 52 in; the tag bar and its chips; a block's header 34 high; a row 36 high with its meta on
/// the title's line, a tag on a 20 high capsule; "+ Add task" 32 high; "+ Add list"; the Done strip 30 high with its
/// rows below it (Task 9's table, Header, Tag bar, Block header, Row, Add task, Done strip).
@Test func thePanesListCarriesTheMacsHeaderBarBlocksRowsAndStrip() throws {
    let scene = try Scene()
    let model = scene.model
    #expect(model.header.style == ScreenHeaderStyle(
        horizontalPadding: 0, bottomMargin: 8, spacing: 12, titleToSubtitle: 6, subtitleLeading: 52
    ))
    #expect(model.header.tile.style.side == 40)
    #expect(model.header.tile.style.cornerRadius == 11)
    #expect(model.header.tile.style.glyphSize == 24)
    let bar = try #require(model.tagBar)
    #expect(bar.style == TagBarStyle(
        topMargin: 10, spacing: 6, padding: 12, endRoom: 12, fadeIn: 12, fadeOut: 24, leadingMargin: 40,
        trailingMargin: -12
    ))
    let chip = try #require(bar.chips.first)
    #expect(chip.style == TagChipStyle(
        height: 26, cornerRadius: 13, leadingPadding: 8, trailingPadding: 10, spacing: 5, hitHeight: 32,
        background: .fill, animation: .chipToggles, hover: hoverTint(13)
    ))
    #expect(chip.icon.style.size == 12)

    let house = try scene.block(.list(scene.house))
    let header = try #require(house.header)
    #expect(header.style == BlockHeaderStyle(
        titleToSubtitle: 8, rule: rule, height: 34, topMargin: 14, trailingMargin: 0, bottomMargin: 2, leadingMargin: 4,
        topPadding: 9, horizontalPadding: 6, bottomPadding: 0, cornerRadius: 7, foldHitSide: 30, titleFills: true,
        hover: hoverTint(7)
    ))
    #expect(header.fold?.icon.style.size == 15)
    let addTask = try #require(house.addTask)
    #expect(addTask.style == AddRowStyle(
        iconCellWidth: 32, spacing: 0, height: 32, width: nil, fills: false, cornerRadius: 8, topPadding: 0,
        leadingPadding: 4, trailingPadding: 12, dash: nil, rule: nil, topMargin: 0, leadingMargin: 0, trailingMargin: 0,
        hover: hoverTint(8)
    ))
    #expect(addTask.icon.style.size == 15)
    #expect(house.indicator == DropIndicatorStyle(
        height: 10, line: LineStyle(color: Tile.teal.check.fill, width: 2, dash: []), lineOffset: 46,
        lineCornerRadius: 1, trailingGap: 10, circleDiameter: 8, circleOffset: 36,
        circleRing: LineStyle(color: Tile.teal.check.fill, width: 2, dash: []), circleFill: .paper
    ))

    let addList = try #require(model.addList)
    #expect(addList.style == AddRowStyle(
        iconCellWidth: 32, spacing: 0, height: 36, width: nil, fills: false, cornerRadius: 9, topPadding: 4,
        leadingPadding: 0, trailingPadding: 12, dash: nil, rule: rule, topMargin: 10, leadingMargin: 4,
        trailingMargin: 0, hover: nil
    ))
    #expect(addList.icon.style.size == 15)

    guard case .task(_, let milk)? = house.rows.first else {
        Issue.record("the first row of House is a task's row")
        return
    }
    #expect(milk.style == taskRowStyle(lift: lift(11)))
    #expect(milk.title.style.font == .rowTitle)
    #expect(milk.check.style.diameter == 18)
    #expect(milk.check.style.ringWidth == 1.5)
    #expect(milk.check.style.markSize == 12)
    #expect(milk.check.style.hitWidth == 32)
    #expect(milk.check.style.hitHeight == 36)
    #expect(milk.swipe?.style.buttonWidth == 78, "the iPad's swipe is the phone's")
    let tag = try #require(milk.meta.first { $0.text?.text == "home" })
    #expect(tag.style.capsule == tagCapsule, "a tag on a 20 high capsule, without its hash")
    let due = try #require(milk.meta.first { $0.icon?.icon == .flag })
    #expect(due.style.capsule == nil)
    #expect(due.icon?.style.size == 13)
    #expect(due.style.spacing == 3)

    let done = try #require(model.done)
    #expect(done.style == DoneStripStyle(
        height: 30, cornerRadius: 15, spacing: 7, leadingPadding: 9, trailingPadding: 12, topMargin: 22,
        leadingMargin: 6, trailingMargin: 0, background: .fill, capsuleToRows: 6,
        rowsEntrance: EntranceStyle(
            opacity: 0, scale: 0.94, offset: -6, anchorX: 0.12, anchorY: 0, animation: .popover
        ),
        bump: .init(scale: 1.22, peakAt: 0.4, animation: .check), hover: hoverTint(15)
    ))
    #expect(done.icon.style.size == 16)
    #expect(done.chevron.icon.style.size == 13)
    scene.module.tap(.doneStripTapped)
    guard case .task(_, let filed)? = scene.model.doneRows.first else {
        Issue.record("the strip holds the task done")
        return
    }
    #expect(filed.style == taskRowStyle(isOpen: false, lift: nil))
    #expect(filed.style.minimumHeight == 36, "the strip's rows are 36 high")
}

/// An empty list's state: the tile 60 across, the title 16 under it and the line 6 under that, 90 from the top, 40 in
/// and 300 wide at most (Task 9's table, Empty state).
@Test func thePanesEmptyStateCarriesTheMacsNumbers() throws {
    let store = try makeStore()
    let model = try list(BuiltInTaskViews.inbox, in: store, width: .wide).model
    let empty = try #require(model.empty)
    #expect(empty.style == EmptyScreenStyle(
        tileToTitle: 16, titleToText: 6, topPadding: 90, horizontalPadding: 40, maxWidth: 300, bottomMargin: 12
    ))
    #expect(empty.tile.style.side == 60)
    #expect(empty.tile.style.cornerRadius == 17)
    #expect(empty.tile.style.glyphSize == 30)
}

/// The open card in the list: 6 above, 10 below, rounded 14 on the raised shadow; the title field 40 high, the body
/// 38 in and 14 short of its end and bottom, the notes, a subtask's check 15 across in a 30 hit and its title row 30
/// high, "Add subtask" 30 high, the pills 26 high with their glyphs (Task 9's table, Card).
@Test func thePanesOpenCardCarriesTheMacsNumbers() throws {
    let scene = try Scene()
    scene.module.tap(.rowTapped(scene.milk))
    scene.module.tap(.addSubtaskTapped)
    let card = try #require(openCard(in: scene.model)).card
    let style = card.style
    #expect(style.expandHitSide == 30)
    #expect(style.cornerRadius == 14)
    #expect([style.topMargin, style.horizontalMargin, style.bottomMargin] == [6, 0, 10])
    #expect([style.bodyLeading, style.bodyTrailing, style.bodyBottom] == [38, 14, 14])
    #expect([style.subtasksToPills, style.pillSpacing] == [8, 6])
    #expect(style.shadow == .raised)
    #expect(style.entrance == cardEntrance)
    #expect([style.subtasksOutdent, style.titleToNotes, style.notesToSubtasks] == [8, 2, 4])
    #expect(style.subtaskDraftCircle.diameter == 15)
    #expect(style.leaving == taskLeaving)
    #expect(card.check.style.diameter == 18)
    #expect([card.check.style.hitWidth, card.check.style.hitHeight] == [32, 40])
    #expect([card.title.style.height, card.title.style.padding] == [40, 2])
    #expect(card.notes.style.height == 20)
    #expect(card.subtaskField?.style.height == 30)
    #expect(card.expand.label.icon.style.size == 16)
    let subtask = try #require(card.subtasks.first)
    #expect(subtask.style == SubtaskRowStyle(height: 30, strike: nil, titleAnimation: .titleFades))
    let check = subtask.check.style
    #expect([check.diameter, check.ringWidth, check.markSize, check.hitWidth, check.hitHeight] == [15, 1.5, 10, 30, 30])
    #expect(card.addSubtask.style == AddRowStyle(
        iconCellWidth: 30, spacing: 0, height: 30, width: nil, fills: false, cornerRadius: 7, topPadding: 0,
        leadingPadding: 0, trailingPadding: 10, dash: nil, rule: nil, topMargin: 0, leadingMargin: -8,
        trailingMargin: 0, hover: hoverTint(7)
    ))
    #expect(card.addSubtask.icon.style.size == 14)
    let pill = try #require(card.pills.first)
    #expect(pill.style == PillStyle(
        height: 26, cornerRadius: 13, leadingPadding: 8, trailingPadding: 10, spacing: 5, background: .fill
    ))
    let sizes = card.pills.map(\.icon.style.size)
    #expect(sizes.first == 14, "the sun")
    #expect(sizes.dropFirst().first == 13, "the flag")
    #expect(sizes.last == 12, "the hash")
}

/// The board: a column 288 wide rounded 14 with its header padded 11 12 7 and tinted under the pointer within corners
/// of 7, its cards 6 apart and 6 in, each rounded 10 with the resting shadow and the hover shadow over 0.15 s, its
/// check 18 across in a 34 by 36 hit, its title callout-sized and its meta 12 with a tag as "#name", its open card 36
/// in and 12 short of its end, "+ Add task" 32 high and tinted under the pointer (Task 9's table, Board;
/// `Mac.dc.html`, the card's markup, :460-463, and `.card:hover`; the controller's rulings R209 and R210).
@Test func thePanesBoardCarriesTheMacsNumbers() throws {
    let scene = try Scene()
    scene.module.tap(.showAsChosen(.columns))
    let column = try #require(blocks(of: scene.model).first { $0.id == .list(scene.house) }?.column)
    let style = column.style
    #expect(
        [style.width, style.cornerRadius, style.cardSpacing, style.padding, style.cardCornerRadius]
            == [288, 14, 6, 6, 10]
    )
    #expect(style.cardRing == hairline)
    #expect(style.fill == .fill)
    #expect(style.cardBackground == .surface)
    #expect(style.cardShadow == .resting)
    #expect(style.cardHover == CardHoverStyle(shadow: .hovered, animation: .hoverShadows))
    #expect(style.dropRingWidth == 2)
    #expect(column.header.style == BlockHeaderStyle(
        titleToSubtitle: 8, rule: nil, height: 31, topMargin: 5, trailingMargin: 0, bottomMargin: 0, leadingMargin: 6,
        topPadding: 6, horizontalPadding: 6, bottomPadding: 4, cornerRadius: 0, foldHitSide: nil, titleFills: false,
        hover: hoverTint(7)
    ), "its title fits its words, padded 6 6 4, 5 under the column's top and 6 in: the words 11 down and 12 in")
    let block = try scene.block(.list(scene.house))
    guard case .task(_, let card)? = block.rows.first else {
        Issue.record("the column's first card is a task's")
        return
    }
    #expect(card.style == TaskRowStyle(
        titleToMeta: 3, metaSpacing: 9, metaLineSpacing: 2, verticalPadding: 9, titleLeading: 0, titleTrailing: 10,
        leading: 0, trailing: 0, minimumHeight: 36, cornerRadius: 10, strike: nil, lift: lift(10), fresh: nil,
        landingScale: nil, landingAnimation: .drop, titleAnimation: .titleFades, leaving: taskLeaving, ground: nil,
        metaTrailing: false, hover: nil
    ))
    #expect(card.title.style.font == .nestedRowTitle)
    #expect([card.check.style.diameter, card.check.style.hitWidth, card.check.style.hitHeight] == [18, 34, 36])
    #expect(card.swipe == nil)
    let tag = try #require(card.meta.first { $0.text?.text == "#home" }, "a card writes a tag out, on no capsule")
    #expect(tag.style.capsule == nil)
    #expect(card.meta.compactMap(\.icon).allSatisfy { $0.style.size == 12 })
    let addTask = try #require(block.addTask)
    #expect(addTask.style == AddRowStyle(
        iconCellWidth: 15, spacing: 6, height: 32, width: nil, fills: true, cornerRadius: 9, topPadding: 0,
        leadingPadding: 10, trailingPadding: 10, dash: nil, rule: nil, topMargin: 0, leadingMargin: 0,
        trailingMargin: 0, hover: hoverTint(9)
    ), "a column's \"+ Add task\" fills its column")
    #expect(addTask.icon.style.size == 15)

    scene.module.tap(.rowTapped(scene.milk))
    let open = try #require(openCard(in: scene.model)).card.style
    #expect(open.cornerRadius == 10)
    #expect([open.topMargin, open.horizontalMargin, open.bottomMargin] == [0, 0, 0])
    #expect([open.bodyLeading, open.bodyTrailing, open.bodyBottom] == [36, 12, 12])
    #expect(open.shadow == .resting)
    #expect(try #require(openCard(in: scene.model)).card.check.style.hitWidth == 34)
}

/// The meta line's order is the layout's: the pane's row reads notes, subtasks, tags and the deadline, the Mac canvas's
/// row's (`Mac.dc.html`, :349-352), and the pane's card the deadline, tags, subtasks and notes, its own canvas's
/// (:460-463), as the phone's row and card keep theirs (`Phone.dc.html`, :349-352) (the controller's ruling R210).
@Test func theMetaLineFollowsItsLayoutsOrder() throws {
    let scene = try Scene()
    func line(_ model: TaskList.Model) throws -> (icons: [DesignSystem.Icon?], words: [String?]) {
        let house = try #require(blocks(of: model).first { $0.id == .list(scene.house) })
        guard case .task(_, let milk)? = house.rows.first else {
            Issue.record("the first row of House is Buy milk's")
            return ([], [])
        }
        return (milk.meta.map { $0.icon?.icon }, milk.meta.map { $0.text?.text })
    }
    let pane = try line(scene.model)
    #expect(pane.icons == [.note, .list, nil, .flag])
    #expect(Array(pane.words.prefix(3)) == [nil, "0/1", "home"])
    scene.module.tap(.showAsChosen(.columns))
    let card = try line(scene.model)
    #expect(card.icons == [.flag, nil, .list, .note])
    #expect(Array(card.words.dropFirst()) == ["#home", "0/1", nil])

    // The device keeps the layout per list, so the phone's module opens on the board the pane chose.
    let phone = try list(scene.projects, in: scene.store)
    let phoneCard = try line(phone.model)
    #expect(phoneCard.icons == [.flag, nil, .list, .note])
    #expect(Array(phoneCard.words.dropFirst()) == ["#home", "0/1", nil])
    phone.tap(.showAsChosen(.list))
    let phoneRow = try line(phone.model)
    #expect(phoneRow.icons == [.flag, nil, .list, .note])
    #expect(Array(phoneRow.words.dropFirst()) == ["#home", "0/1", nil])
}

/// Every control the Mac canvas tints under the pointer has the pane's tint, in its own corners, and none of the
/// phone's has one: a row, a block's header and its chevron, "+ Add task", "Add subtask", the Done strip, a tag's chip,
/// the capsule's "+" and "…" and Open full screen in the list; a column's header and its "+ Add task" on the board, a
/// column's card casting its shadow instead. The back circle and "+ Add list", which the canvas does not tint, have
/// none (`Mac.dc.html`, `.mc-tap`, `.mc-trow`, `.mc-ib`, `.mc-gi`, `.tchip`; the controller's rulings R209 and R213).
@Test func everyControlTheCanvasTintsHasThePanesTintAndNoneThePhones() throws {
    let scene = try Scene()
    /// The tints a list draws, its first row's read before that row opens into the card whose own are read after.
    func tints(_ module: TaskList) throws -> [String: HoverStyle?] {
        let firstRow = blocks(of: module.model).flatMap(\.rows).compactMap { row -> TaskRowModel<Action>? in
            if case .task(_, let task) = row { task } else { nil }
        }.first
        let row = try #require(firstRow)
        module.tap(.rowTapped(scene.milk))
        defer { module.tap(.backgroundTapped) }
        let model = module.model
        let house = try #require(blocks(of: model).first { $0.id == .list(scene.house) })
        let card = try #require(openCard(in: model)).card
        return [
            "row": row.style.hover, "header": house.header?.style.hover, "add task": house.addTask?.style.hover,
            "add subtask": card.addSubtask.style.hover, "expand": card.style.expandHover,
            "strip": model.done?.style.hover, "chip": model.tagBar?.chips.first?.style.hover,
            "more": model.showAs.label.style.hover, "back": model.back.label.style.hover,
            "add list": model.addList?.style.hover,
        ]
    }
    func tints(onTheBoardOf model: TaskList.Model) throws -> [String: HoverStyle?] {
        let house = try #require(blocks(of: model).first { $0.id == .list(scene.house) })
        let column = try #require(house.column)
        let card = try #require(house.rows.compactMap { row -> TaskRowModel<Action>? in
            if case .task(_, let task) = row { task } else { nil }
        }.first)
        return [
            "column header": column.header.style.hover, "column add task": house.addTask?.style.hover,
            "card": card.style.hover,
        ]
    }

    var pane = try tints(scene.module)
    #expect(scene.model.glassAddTask?.label.style.hover == hoverTint(14))
    #expect(pane.removeValue(forKey: "row") == hoverTint(9))
    #expect(pane.removeValue(forKey: "header") == hoverTint(7))
    #expect(pane.removeValue(forKey: "add task") == hoverTint(8))
    #expect(pane.removeValue(forKey: "add subtask") == hoverTint(7))
    #expect(pane.removeValue(forKey: "expand") == hoverTint(7))
    #expect(pane.removeValue(forKey: "strip") == hoverTint(15))
    #expect(pane.removeValue(forKey: "chip") == hoverTint(13))
    #expect(pane.removeValue(forKey: "more") == hoverTint(14))
    #expect(pane.compactMapValues { $0 }.isEmpty, "the back circle and \"+ Add list\" are not tinted: \(pane)")
    scene.module.tap(.showAsChosen(.columns))
    let board = try tints(onTheBoardOf: scene.model)
    #expect(board["column header"] == hoverTint(7))
    #expect(board["column add task"] == hoverTint(9))
    #expect(board["card"] == .some(nil), "a column's card casts its shadow instead")
    guard case .columns(let columns) = scene.model.layout else {
        Issue.record("the list stands as columns")
        return
    }
    #expect(columns.addList?.style.hover == nil, "the board's \"+ Add list\" is not tinted")
    scene.module.tap(.showAsChosen(.list))

    let phone = try list(scene.projects, in: scene.store)
    #expect(try tints(phone).compactMapValues { $0 }.isEmpty, "the phone has no pointer")
    #expect(phone.model.addTask != nil && phone.model.glassAddTask == nil)
}

/// A row that adds fits its glyph and its title, as both canvases draw "+ Add task" in a block, "Add subtask" and "+
/// Add list", and fills what it stands in only as a column's "+ Add task", which its column stretches (`Mac.dc.html`,
/// :359, :332 and :471; `Phone.dc.html`, :362, :328, :376 and :488); the phone's fit as they did before the pane, its
/// column's among them; and a block header's title fills its header beside the chevron, a column's fitting its words
/// (`Mac.dc.html`, :301 and :414) (the controller's ruling R215 and the review's minor 1).
@Test func aRowThatAddsFitsItsWordsAndOnlyAColumnsFillsIt() throws {
    let scene = try Scene()
    scene.module.tap(.rowTapped(scene.milk))
    let house = try scene.block(.list(scene.house))
    #expect(house.addTask?.style.fills == false)
    #expect(scene.model.addList?.style.fills == false)
    #expect(try #require(openCard(in: scene.model)).card.addSubtask.style.fills == false)
    #expect(house.header?.style.titleFills == true)
    scene.module.tap(.backgroundTapped)
    scene.module.tap(.showAsChosen(.columns))
    let column = try scene.block(.list(scene.house))
    #expect(column.addTask?.style.fills == true)
    #expect(column.column?.header.style.titleFills == false)
    guard case .columns(let board) = scene.model.layout else {
        Issue.record("the list stands as columns")
        return
    }
    #expect(board.addList?.style.fills == false)

    let phone = try list(scene.projects, in: scene.store)
    let phoneColumn = try #require(blocks(of: phone.model).first { $0.id == .list(scene.house) })
    #expect(phoneColumn.addTask?.style.fills == false, "the phone's tap areas are what they were")
    #expect(phoneColumn.column?.header.style.titleFills == true)
    phone.tap(.showAsChosen(.list))
    phone.tap(.rowTapped(scene.milk))
    let phoneBlock = try #require(blocks(of: phone.model).first { $0.id == .list(scene.house) })
    #expect(phoneBlock.addTask?.style.fills == false)
    #expect(phone.model.addList?.style.fills == false)
    #expect(try #require(openCard(in: phone.model)).card.addSubtask.style.fills == false)
    #expect(phoneBlock.header?.style.titleFills == true)
}
