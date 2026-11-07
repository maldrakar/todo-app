import Testing
import TestSupport
import DesignSystem
import DesignSystemComponents
import TaskListFeature
import TodoCore

private typealias Action = TaskList.UserAction
private typealias Tile = DesignSystem.Color.Components.Tile

/// How a check pops as it is checked (`Phone.dc.html`, `cbPop`): down to .8 by 35 % of its motion, up to 1.14 by 70 %.
private let checkPop = CheckStyle.Pop(dipScale: 0.8, dipAt: 0.35, peakScale: 1.14, peakAt: 0.7)

/// The canvas's tick, `M6.5 12.5l3.5 3.5 7.5-8` in its 24-unit box, its ends and its corner round (`Phone.dc.html`,
/// `.cb`).
private let checkMark = CheckStyle.Mark(
    box: 24, points: [.init(x: 6.5, y: 12.5), .init(x: 10, y: 16), .init(x: 17.5, y: 8)], isRound: true
)

/// How a row or a card leaves as its task is completed (`Phone.dc.html`, `.tt-done` and `.row-leave`): its title in ink
/// 2 and struck in ink 3, sinking 12 as it goes on the row's motion.
private let taskLeaving = TaskLeavingStyle(
    titleColor: .ink2, strike: .ink3, offset: 12, animation: .rowLeaves, deleteAnimation: .rowDeleted
)

/// The board a model draws in columns, nil in the list.
private func board(of model: TaskList.Model) -> TaskList.Model.Board? {
    switch model.layout {
    case .list: nil
    case .columns(let board): board
    }
}

/// The phone's row, as Task 8's table gives it: 8 in and 12 short of the edges, the check 24 across with a 1.75 ring
/// and the 15 pt mark stroked 1.75 in a 44 pt hit, popping on the check's motion; the title in the row title, 11 above
/// and below, 2 after the check's hit and 4 short of the end; the meta 3 under it, its items 10 apart and its lines 3;
/// at least 44 high and rounded 12; dragged 40 leftward it stays moved 88 over its Delete, 78 wide, 3 and 10 in from
/// its edges, rounded 12, reading "Delete" and its title aloud, and its menu holds Delete; it lifts to 1.03 on the
/// surface rounded 14 with the lifted shadow, dimming to .35 where it is dragged from (Task 8's table, Lift and slot;
/// the controller's ruling on #177, 2026-11-07), and is fresh where it is the task just dropped; it stands on the
/// paper. A row of the strip has neither a menu nor a lift, and no meta line.
private func phoneRow(
    _ title: String, id: TaskID, colors: DesignSystem.Color.Components.Check, isOpen: Bool = true,
    meta: [MetaItemModel] = [], deletes: Bool = true, isFresh: Bool = false
) -> TaskRowModel<Action> {
    TaskRowModel(
        check: CheckModel(
            style: .init(
                diameter: 24, ringWidth: 1.75, markSize: 15, markStrokeWidth: 1.75, hitWidth: 44, hitHeight: 44,
                animation: .check, fillAnimation: .checkFills, markAnimation: .checkMarkDraws, pop: checkPop,
                mark: checkMark, colors: colors
            ),
            isChecked: !isOpen,
            accessibilityLabel: (isOpen ? "Complete: " : "Mark as not done: ") + title, action: .checkTapped(id)
        ),
        title: TextModel(text: title, style: TextStyle(font: .rowTitle, color: isOpen ? .ink : .ink2)),
        meta: meta,
        style: .init(
            titleToMeta: 3, metaSpacing: 10, metaLineSpacing: 3, verticalPadding: 11, titleLeading: 2,
            titleTrailing: 4, leading: 8, trailing: 12, minimumHeight: 44, cornerRadius: 12, freshAnimation: .fresh,
            strike: isOpen ? nil : .ink3, lift: deletes ? rowLift : nil, fresh: isFresh ? .fresh : nil,
            landingScale: nil, landingAnimation: .drop, titleAnimation: .titleFades, leaving: taskLeaving,
            ground: .paper
        ),
        swipe: deletes ? SwipeModel(
            style: .init(
                threshold: 40, shift: -88, buttonWidth: 78, buttonVerticalInset: 3, buttonTrailingInset: 10,
                buttonCornerRadius: 12, background: .red, animation: .swipe
            ),
            button: TextModel(
                text: "Delete",
                style: TextStyle(font: .barLabel, color: .onAccent)
            ), accessibilityLabel: "Delete \(title)", action: .deleteSwiped(id)
        ) : nil,
        tap: .rowTapped(id), menu: deletes ? deleteMenu(id) : nil
    )
}

/// A row lifted: grown to 1.03, rounded 14 on the surface with the lifted shadow, and dimmed to .35 where it is dragged
/// from.
private let rowLift = TaskLiftStyle(
    scale: 1.03, opacity: 0.35, cornerRadius: 14, background: .surface, shadow: .lifted, dimAnimation: .dropHighlights
)

/// A column's card lifted: the row's, but rounded as the card is, 13.
private let cardLift = TaskLiftStyle(
    scale: 1.03, opacity: 0.35, cornerRadius: 13, background: .surface, shadow: .lifted, dimAnimation: .dropHighlights
)

/// The mark of a drop's place among a block's rows, in the check fill of the block's list, 10 high: the circle 8 across
/// 52 in, ringed 2 and filled with the paper, the line 2 thick and rounded 1 from 62 in to 20 short of the right edge
/// (Task 8's table, Lift and slot).
private func dropMark(_ colors: DesignSystem.Color.Components.Check) -> DropIndicatorStyle {
    DropIndicatorStyle(
        height: 10, line: LineStyle(color: colors.fill, width: 2, dash: []), lineOffset: 62, lineCornerRadius: 1,
        trailingGap: 20, circleDiameter: 8, circleOffset: 52,
        circleRing: LineStyle(color: colors.fill, width: 2, dash: []), circleFill: .paper
    )
}

/// A row's menu: Delete with the trash's glyph, drawn as what destroys something (spec section 6).
private func deleteMenu(_ id: TaskID) -> MenuModel<Action> {
    MenuModel(sections: [
        .init(items: [
            .init(title: "Delete", icon: .trash, isDestructive: true, shortcut: nil, action: .deleteMenuItemChosen(id)),
        ]),
    ])
}

/// A row's check is in the colour of the list its block belongs to: the open list's for its own blocks and a list
/// inside's own for its block (spec section 3; canvas, `rowOf`).
@Test func theChecksColoursFollowTheBlocksList() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let projects = try store.createView(NewTaskView(title: "Projects", color: .indigo, filter: .status([.open])))
    try store.createView(NewTaskView(title: "House", parent: projects, color: .teal, filter: .hasTag(home)))
    try store.createTask(NewTask(title: "Write the plan"))
    try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    let model = try list(projects, in: store).model
    let colors = blocks(of: model).map { $0.rows.map { row($0).check.style.colors } }
    #expect(colors == [[Tile.indigo.check], [Tile.teal.check]])
}

/// A task that is not open has its check filled and its title struck in ink 3 over ink 2, and its check says it marks
/// the task not done; an open one says it completes it (canvas, `.tt-done` and `cbLabel`).
@Test func aTaskThatIsNotOpenIsStruckAndItsCheckSaysSo() throws {
    let store = try makeStore()
    let done = try store.createTask(NewTask(title: "Filed"))
    try store.update(task: done, [.status(.done)])
    let open = try store.createTask(NewTask(title: "Buy milk"))
    let logbook = try #require(blocks(of: try list(BuiltInTaskViews.logbook, in: store).model).first)
    #expect(logbook.rows.map(row) == [phoneRow("Filed", id: done, colors: Tile.green.check, isOpen: false)])
    let inbox = try #require(blocks(of: try list(BuiltInTaskViews.inbox, in: store).model).first)
    #expect(inbox.rows.map(row) == [phoneRow("Buy milk", id: open, colors: Tile.blue.check)])
    #expect(inbox.rows.map(\.id) == [open])
}

/// The meta line's items carry the phone's numbers: 13 pt glyphs 3 before their text in the meta font, ink 2, red
/// for a deadline that is due; the notes' item is its glyph alone, with no text.
@Test func aRowsMetaItemsCarryThePhonesNumbers() throws {
    let store = try makeStore()
    let errand = try store.createTag(title: "errand")
    let id = try store.createTask(NewTask(title: "Buy milk", notes: "two", deadline: day(0), tags: [errand]))
    let model = try list(BuiltInTaskViews.inbox, in: store).model
    let meta = [
        MetaItemModel(
            icon: IconModel(icon: .flag, style: IconStyle(size: 13, weight: .regular, color: .red)),
            text: TextModel(text: "Due today", style: TextStyle(font: .meta, color: .red)),
            style: MetaItemStyle(spacing: 3, capsule: nil)
        ),
        MetaItemModel(
            icon: nil, text: TextModel(text: "#errand", style: TextStyle(font: .meta, color: .ink2)),
            style: MetaItemStyle(spacing: 3, capsule: nil)
        ),
        MetaItemModel(
            icon: IconModel(icon: .note, style: IconStyle(size: 13, weight: .regular, color: .ink2)), text: nil,
            style: MetaItemStyle(spacing: 3, capsule: nil)
        ),
    ]
    #expect(blocks(of: model).first?.rows.map(row) == [phoneRow("Buy milk", id: id, colors: Tile.blue.check, meta: meta)])
}

/// A chip unlit stands on the fill with its title in ink and its hash in ink 2; lit, on the list's check fill with
/// both in its mark's colour (canvas, the tag chip; Task 8's table).
@Test func aLitChipTakesTheListsCheckColours() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    try store.createTask(NewTask(title: "Fix the door", tags: [home]))
    try store.createTask(NewTask(title: "Buy milk"))
    let today = try store.createView(NewTaskView(title: "Mine", color: .amber, filter: .status([.open])))
    let module = try list(today, in: store)
    func chip(isLit: Bool) -> TagChipModel<Action> {
        TagChipModel(
            icon: IconModel(
                icon: .hash,
                style: IconStyle(size: 13, weight: .regular, color: isLit ? Tile.amber.check.mark : .ink2)
            ),
            title: TextModel(text: "home", style: TextStyle(font: .pill, color: isLit ? Tile.amber.check.mark : .ink)),
            style: .init(
                height: 30, cornerRadius: 15, leadingPadding: 10, trailingPadding: 12, spacing: 5, hitHeight: 44,
                background: isLit ? Tile.amber.check.fill : .fill, animation: .chipToggles
            ),
            isLit: isLit, action: .tagChipTapped(home)
        )
    }
    let bar = { (chips: [TagChipModel<Action>]) in
        TagBarModel(
            chips: chips,
            style: .init(
                topMargin: 7, spacing: 6, padding: 20, endRoom: 20, fadeIn: 16, fadeOut: 28, leadingMargin: -20,
                trailingMargin: -20
            )
        )
    }
    #expect(module.model.tagBar == bar([chip(isLit: false)]))
    _ = module.send(.action(.tagChipTapped(home)))
    #expect(module.model.tagBar == bar([chip(isLit: true)]))
}

/// A block's header carries the phone's numbers, and its chevron turns a quarter left when the block folds, saying what
/// a tap will do (Task 8's table; the controller's ruling on #175, 2026-11-04).
@Test func aBlocksChevronTurnsAndSaysWhatATapDoes() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let module = try list(BuiltInTaskViews.upcoming, in: store)
    let id = TaskList.Model.BlockID.own(.day(day(1)))
    func header(isFolded: Bool) -> BlockHeaderModel<Action> {
        BlockHeaderModel(
            title: TextModel(text: "Tomorrow", style: TextStyle(font: .sectionTitle, color: Tile.rose.glyph)),
            subtitle: TextModel(text: "Thu, Sep 11", style: TextStyle(font: .areaLabel, color: .ink2)), field: nil,
            fold: AccessoryModel.Chevron(
                icon: IconModel(icon: .chevron, style: IconStyle(size: 18, weight: .regular, color: .ink2)),
                accessibilityLabel: isFolded ? "Unfold Tomorrow" : "Fold Tomorrow", action: .blockChevronTapped(id),
                style: ChevronStyle(rotation: isFolded ? -90 : 0, animation: .fold)
            ),
            style: .init(
                titleToSubtitle: 8, rule: LineStyle(color: .line, width: 1, dash: []), height: 44, topMargin: 6,
                trailingMargin: 6, bottomMargin: 2, leadingMargin: 12, topPadding: 13, horizontalPadding: 8,
                bottomPadding: 0, cornerRadius: 0, foldHitSide: 44
            ),
            titleTapped: .blockTitleTapped(id)
        )
    }
    #expect(blocks(of: module.model).first?.header == header(isFolded: false))
    _ = module.send(.action(.blockChevronTapped(id)))
    #expect(blocks(of: module.model).first?.header == header(isFolded: true))
}

/// The screen's header carries the phone's numbers: the list's tile 38 across, rounded 11, its glyph 23, 12 before the
/// large title, the subtitle in ink 2 6 under it and 50 in, the header 20 in from the screen's sides (Task 8's table).
@Test func theHeaderCarriesThePhonesNumbers() throws {
    let store = try makeStore()
    let header = try list(BuiltInTaskViews.today, in: store).model.header
    #expect(header == ScreenHeaderModel(
        tile: TileModel(
            icon: .sun,
            style: TileStyle(color: .amber, side: 38, cornerRadius: 11, glyphSize: 23, glyphWeight: .medium)
        ),
        title: TextModel(text: "Today", style: TextStyle(font: .largeTitle, color: .ink)),
        subtitle: TextModel(text: "Wednesday, September 10", style: TextStyle(font: .count, color: .ink2)),
        style: .init(horizontalPadding: 20, bottomMargin: 10, spacing: 12, titleToSubtitle: 6, subtitleLeading: 50)
    ))
    let board = try list(BuiltInTaskViews.upcoming, in: store)
    board.tap(.showAsChosen(.columns))
    #expect(board.model.header.style.bottomMargin == 12, "the canvas's board stands 12 under it, the list's 10")
}

/// The empty state carries the phone's numbers: the list's tile 64 across, rounded 18, its glyph 32, the title 18
/// under it and the line 6 under that, 84 from the top, 40 in and 270 wide at most (Task 8's table).
@Test func theEmptyStateCarriesThePhonesNumbers() throws {
    let store = try makeStore()
    #expect(try list(BuiltInTaskViews.inbox, in: store).model.empty == EmptyScreenModel(
        tile: TileModel(
            icon: .tray,
            style: TileStyle(color: .blue, side: 64, cornerRadius: 18, glyphSize: 32, glyphWeight: .medium)
        ),
        title: TextModel(text: "Nothing here yet", style: TextStyle(font: .emptyScreenTitle, color: .ink)),
        text: TextModel(
            text: "Tasks that match this list’s rule will show up here.",
            style: TextStyle(font: .notes, color: .ink2)
        ),
        style: .init(tileToTitle: 18, titleToText: 6, topPadding: 84, horizontalPadding: 40, maxWidth: 270)
    ))
}

/// The glass buttons are 44 circles on the glass edged with its 0.5 hairline and casting the raised shadow: the back
/// chevron 24 across set 2 left of centre, reading "Back", and "…" 22 across, reading "More"; they stand 14 in from the
/// screen's sides at the safe area's top, over a fade of the paper 54 under it, solid to 15.12 under it, with the
/// content 56 under it (Task 8's table, Glass buttons; the controller's ruling on #177, 2026-11-07: the canvas's 108
/// fade less its 54 status bar, solid to 64 % of the 108).
@Test func theGlassButtonsCarryThePhonesNumbers() throws {
    let store = try makeStore()
    func button(_ icon: DesignSystem.Icon, size: Double, offset: Double, _ label: String) -> GlassButtonModel {
        GlassButtonModel(
            icon: IconModel(icon: icon, style: IconStyle(size: size, weight: .regular, color: .ink)),
            style: GlassControlStyle(
                iconOffset: offset, diameter: 44, surface: .glass,
                line: LineStyle(color: .glassLine, width: 0.5, dash: []), shadow: .raised
            ),
            accessibilityLabel: label
        )
    }
    let fade = ListScreenStyle.Fade(color: .paper, height: 54, solidDepth: 15.12)
    for layout in [TaskList.Model.Layout.Kind.list, .columns] {
        let module = try list(BuiltInTaskViews.upcoming, in: store)
        module.tap(.showAsChosen(layout))
        let model = module.model
        #expect(model.back == button(.chevronLeft, size: 24, offset: -2, "Back"))
        #expect(model.more == button(.ellipsis, size: 22, offset: 0, "More"))
        let style = ListScreenStyle(
            edgeInset: 14, fade: layout == .list ? fade : nil, contentTop: 56, contentBottom: 116, background: .paper
        )
        #expect(model.style == style, "the fade is the list's alone; the board's circles stand in the flow")
    }
}

/// Show as, the menu "…" opens, is headed "Show as" and holds List and Columns with the layout the list is shown as
/// checked, Columns disabled with its reason where there is nothing to show as columns (canvas, section 2; spec section
/// 5; the plan's rule for the menu's heading and check).
@Test func showAsIsHeadedAndChecksTheLayoutWithColumnsDisabledWithItsReason() throws {
    let store = try makeStore()
    func showAs(current: TaskList.Model.Layout.Kind, canBoard: Bool) -> MenuModel<Action> {
        MenuModel(
            heading: "Show as",
            sections: [
                .init(items: [
                    .init(
                        title: "List", icon: .list, isDestructive: false, isChecked: current == .list, shortcut: nil,
                        action: .showAsChosen(.list)
                    ),
                    .init(
                        title: "Columns", subtitle: canBoard ? nil : "Group the list in its settings to get columns",
                        icon: .columns, isDestructive: false, isDisabled: !canBoard, isChecked: current == .columns,
                        shortcut: nil, action: .showAsChosen(.columns)
                    ),
                ]),
            ]
        )
    }
    #expect(try list(BuiltInTaskViews.inbox, in: store).model.showAs == showAs(current: .list, canBoard: false))
    let upcoming = try list(BuiltInTaskViews.upcoming, in: store)
    #expect(upcoming.model.showAs == showAs(current: .list, canBoard: true))
    upcoming.tap(.showAsChosen(.columns))
    #expect(upcoming.model.showAs == showAs(current: .columns, canBoard: true), "the choice moves the check")
}

/// A column and its cards carry the board's numbers: the board 10 between columns, 16 in at its sides and 24 at its
/// bottom, snapping; a column 296 wide, rounded 18 on the fill, its cards 8 apart and 8 in, each rounded 13 on the
/// surface with a 0.5 hairline of the glass line and the resting shadow; its header 44 high, padded 13 14 9, with no
/// rule and no chevron; a card's check 22 across in a 42 by 44 hit and its title callout-sized (Task 8's table; the
/// controller's ruling on #175, 2026-11-04). A card has the row's menu and no swipe (canvas), and the column takes a
/// drop where the block's rule reads as an edit.
@Test func aColumnCarriesTheBoardsNumbers() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let module = try list(BuiltInTaskViews.upcoming, in: store)
    _ = module.send(.action(.showAsChosen(.columns)))
    let model = module.model
    let board = try #require(board(of: model))
    #expect([board.spacing, board.horizontalPadding, board.endRoom, board.bottomPadding] == [10, 16, 16, 24])
    #expect(board.snaps)
    let block = try #require(board.columns.first)
    let blockID = TaskList.Model.BlockID.own(.day(day(1)))
    #expect(block.column == ColumnModel(
        header: BlockHeaderModel(
            title: TextModel(text: "Tomorrow", style: TextStyle(font: .sectionTitle, color: Tile.rose.glyph)),
            subtitle: TextModel(text: "Thu, Sep 11", style: TextStyle(font: .areaLabel, color: .ink2)), field: nil,
            fold: nil,
            style: .init(
                titleToSubtitle: 8, rule: nil, height: 44, topMargin: 0, trailingMargin: 0, bottomMargin: 0,
                leadingMargin: 0, topPadding: 13, horizontalPadding: 14, bottomPadding: 9, cornerRadius: 0,
                foldHitSide: nil
            ),
            titleTapped: .blockTitleTapped(blockID)
        ),
        style: .init(
            width: 296, cornerRadius: 18, cardSpacing: 8, padding: 8, cardCornerRadius: 13,
            cardRing: LineStyle(color: .glassLine, width: 0.5, dash: []), fill: .fill, cardBackground: .surface,
            cardShadow: .resting, dropRingWidth: 2, dropTint: Tile.rose.dropTint,
            dropRing: Tile.rose.check.fill, dropAnimation: .dropHighlights
        ),
        isDropTarget: true
    ))
    #expect(block.rows.map(row) == [TaskRowModel(
        check: CheckModel(
            style: .init(
                diameter: 22, ringWidth: 1.75, markSize: 15, markStrokeWidth: 1.75, hitWidth: 42, hitHeight: 44,
                animation: .check, fillAnimation: .checkFills, markAnimation: .checkMarkDraws, pop: checkPop,
                mark: checkMark, colors: Tile.rose.check
            ),
            isChecked: false, accessibilityLabel: "Complete: Buy milk",
            action: .checkTapped(id)
        ),
        title: TextModel(text: "Buy milk", style: TextStyle(font: .nestedRowTitle, color: .ink)), meta: [],
        style: .init(
            titleToMeta: 3, metaSpacing: 10, metaLineSpacing: 3, verticalPadding: 11, titleLeading: 2, titleTrailing: 4,
            leading: 0, trailing: 12, minimumHeight: 44, cornerRadius: 13, freshAnimation: .fresh,
            strike: nil, lift: cardLift, fresh: nil, landingScale: nil, landingAnimation: .drop,
            titleAnimation: .titleFades, leaving: taskLeaving, ground: nil
        ),
        swipe: nil,
        tap: .rowTapped(id), menu: deleteMenu(id)
    )])
}

/// A task with no title is drawn as "New task" in its row, a blank title too, wherever a row is drawn: a block's, a
/// column's card and the strip's, its title and what its check reads aloud alike, since a row with nothing to read is
/// no row to find (spec, "Risks"; the controller's ruling on #176, 2026-11-05). The store keeps what it holds, and the
/// open card's field shows that with its placeholder, as it does for a task just added.
@Test func aTaskWithNoTitleIsDrawnAsNewTaskInItsRow() throws {
    let store = try makeStore()
    let empty = try store.createTask(NewTask(title: "", when: day(1)))
    let blank = try store.createTask(NewTask(title: "   ", when: day(1)))
    let finished = try store.createTask(NewTask(title: "", notes: "Call at 5", when: day(2)))
    try store.update(task: finished, [.status(.done)])
    let module = try list(BuiltInTaskViews.upcoming, in: store)
    func expectNewTask(_ row: TaskRowModel<Action>, check: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(row.title.text == "New task", sourceLocation: sourceLocation)
        #expect(row.check.accessibilityLabel == check, sourceLocation: sourceLocation)
    }
    let id = TaskList.Model.BlockID.own(.day(day(1)))
    let rows = try #require(block(id, of: module.model)?.rows)
    #expect(rows.map(\.id) == [empty, blank])
    for listRow in rows { expectNewTask(row(listRow), check: "Complete: New task") }
    module.tap(.doneStripTapped)
    expectNewTask(row(try #require(module.model.doneRows.first)), check: "Mark as not done: New task")
    module.tap(.showAsChosen(.columns))
    let cards = try #require(block(id, of: module.model)?.rows)
    #expect(cards.map(\.id) == [empty, blank])
    for card in cards { expectNewTask(row(card), check: "Complete: New task") }
    #expect(try store.task(empty)?.title == "", "the store keeps what it holds")
    #expect(try store.task(blank)?.title == "   ")
    module.tap(.showAsChosen(.list))
    module.tap(.rowTapped(blank))
    let opened = try #require(openCard(in: module.model))
    #expect(opened.card.title.text == "   ", "the field shows what the store keeps")
    #expect(opened.card.title.placeholder == "New task")
    #expect(opened.card.check.accessibilityLabel == "Complete: New task", "the name VoiceOver hears on its row")
    module.tap(.titleFieldChanged("Typed"))
    #expect(openCard(in: module.model)?.card.title.text == "Typed")
    #expect(openCard(in: module.model)?.card.check.accessibilityLabel == "Complete: New task", "the stored title's, none")
    let titled = try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let onTitled = try list(BuiltInTaskViews.upcoming, in: store)
    onTitled.tap(.rowTapped(titled))
    #expect(openCard(in: onTitled.model)?.card.check.accessibilityLabel == "Complete: Buy milk")
}

/// A row that adds a task carries the phone's numbers in the list, 40 high with its plus 18 in a 44 cell, and in a
/// column, 44 high with the plus 6 before its title; the row that adds a list stands after the blocks over a rule and
/// as the board's dashed last column (Task 8's table, Add rows and Board).
@Test func theAddRowsCarryThePhonesNumbers() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let module = try list(BuiltInTaskViews.upcoming, in: store)
    let id = TaskList.Model.BlockID.own(.day(day(1)))
    func plus(_ size: Double) -> IconModel {
        IconModel(icon: .plus, style: IconStyle(size: size, weight: .regular, color: .ink2))
    }
    #expect(block(id, of: module.model)?.addTask == AddRowModel(
        icon: plus(18), title: TextModel(text: "Add task", style: TextStyle(font: .addRow, color: .ink2)),
        style: .init(
            iconCellWidth: 44, spacing: 0, height: 40, width: nil, cornerRadius: 12, topPadding: 0, leadingPadding: 0,
            trailingPadding: 12, dash: nil, rule: nil, topMargin: 0, leadingMargin: 8, trailingMargin: 12
        ),
        action: .addTaskRowTapped(in: id)
    ))
    #expect(module.model.addList == AddRowModel(
        icon: plus(18), title: TextModel(text: "Add list", style: TextStyle(font: .barLabel, color: .ink2)),
        style: .init(
            iconCellWidth: 40, spacing: 0, height: 44, width: nil, cornerRadius: 12, topPadding: 4, leadingPadding: 0,
            trailingPadding: 12, dash: nil, rule: LineStyle(color: .line, width: 1, dash: []), topMargin: 10,
            leadingMargin: 12, trailingMargin: 6
        ),
        action: .addListTapped
    ))
    module.tap(.showAsChosen(.columns))
    #expect(block(id, of: module.model)?.addTask == AddRowModel(
        icon: plus(18), title: TextModel(text: "Add task", style: TextStyle(font: .addRow, color: .ink2)),
        style: .init(
            iconCellWidth: 18, spacing: 6, height: 44, width: nil, cornerRadius: 13, topPadding: 0, leadingPadding: 11,
            trailingPadding: 12, dash: nil, rule: nil, topMargin: 0, leadingMargin: 0, trailingMargin: 0
        ),
        action: .addTaskRowTapped(in: id)
    ))
    #expect(module.model.addList == nil, "the board holds it")
    #expect(board(of: module.model)?.addList == AddRowModel(
        icon: plus(18), title: TextModel(text: "Add list", style: TextStyle(font: .barLabel, color: .ink2)),
        style: .init(
            iconCellWidth: 18, spacing: 8, height: 52, width: 200, cornerRadius: 18, topPadding: 0, leadingPadding: 16,
            trailingPadding: 16, dash: LineStyle(color: .line, width: 1.5, dash: [5, 4]), rule: nil, topMargin: 0,
            leadingMargin: 0, trailingMargin: 0
        ),
        action: .addListTapped
    ))
}

/// The floating "+" is the accent's 48 circle with a white plus 22 across, casting the raised shadow and reading "New
/// task" (Task 8's table, Floating "+"; the controller's ruling on #176, 2026-11-05).
@Test func theFloatingPlusCarriesThePhonesNumbers() throws {
    let store = try makeStore()
    #expect(try list(BuiltInTaskViews.inbox, in: store).model.addTask == FloatingButtonModel(
        icon: IconModel(icon: .plus, style: IconStyle(size: 22, weight: .medium, color: .onAccent)),
        style: .init(diameter: 48, fill: .accent, shadow: .raised, trailingMargin: 16, bottomMargin: 30),
        accessibilityLabel: "New task", action: .addTaskButtonTapped
    ))
}

/// The Done strip is a 36 capsule on the fill, its check in a circle 18 in the list's glyph colour, "Done today · N" in
/// the bar's label and ink 2, its chevron 15, turned half round while it is open and saying what a tap will do; a row
/// under it is struck, with no meta line, no swipe and no menu (Task 8's table, Done strip; the controller's ruling on
/// #176, 2026-11-05).
@Test func theDoneStripCarriesThePhonesNumbers() throws {
    let store = try makeStore()
    let errand = try store.createTag(title: "errand")
    let done = try store.createTask(NewTask(title: "Filed", deadline: day(0), tags: [errand]))
    try store.update(task: done, [.status(.done)])
    let inbox = try store.createView(NewTaskView(title: "Mine", color: .amber, filter: .trashed(false)))
    let module = try list(inbox, in: store)
    func strip(isOpen: Bool) -> DoneStripModel<Action> {
        DoneStripModel(
            icon: IconModel(icon: .checkCircle, style: IconStyle(size: 18, weight: .regular, color: Tile.amber.glyph)),
            label: TextModel(text: "Done today · 1", style: TextStyle(font: .barLabel, color: .ink2)),
            chevron: AccessoryModel.Chevron(
                icon: IconModel(icon: .chevron, style: IconStyle(size: 15, weight: .regular, color: .ink2)),
                accessibilityLabel: isOpen ? "Hide done tasks" : "Show done tasks", action: .doneStripTapped,
                style: ChevronStyle(rotation: isOpen ? 180 : 0, animation: .fold)
            ),
            style: .init(
                height: 36, cornerRadius: 18, spacing: 8, leadingPadding: 10, trailingPadding: 14, topMargin: 20,
                leadingMargin: 14, trailingMargin: 16, background: .fill, capsuleToRows: 6,
                rowsEntrance: EntranceStyle(
                    opacity: 0, scale: 0.92, offset: -8, anchorX: 0.2, anchorY: 0, animation: .popover
                ),
                bump: .init(scale: 1.22, peakAt: 0.4, animation: .check)
            ),
            isOpen: isOpen, action: .doneStripTapped
        )
    }
    #expect(module.model.done == strip(isOpen: false))
    #expect(module.model.doneRows.isEmpty, "none while it is closed")
    module.tap(.doneStripTapped)
    #expect(module.model.done == strip(isOpen: true))
    #expect(module.model.doneRows == [
        .task(done, phoneRow("Filed", id: done, colors: Tile.amber.check, isOpen: false, deletes: false)),
    ])
}

/// A task in the Trash has no swipe and no menu (spec section 6): its row is the row's, its check the mark of whether
/// it is open.
@Test func aTrashRowHasNoSwipeAndNoMenu() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Binned"))
    try store.trash(task: id)
    let rows = blocks(of: try list(BuiltInTaskViews.trash, in: store).model).flatMap(\.rows).map(row)
    #expect(rows == [phoneRow("Binned", id: id, colors: Tile.stone.check, deletes: false)])
}

/// A block carries the mark of a drop's place among its rows, in the colour of its list, whichever rows it holds: one
/// with none has it too. A column has none, its tint marking the drop.
@Test func aBlockCarriesTheMarkOfADropInItsListsColour() throws {
    let store = try makeStore()
    let home = try store.createTag(title: "home")
    let parent = try store.createView(NewTaskView(title: "Projects", color: .rose, filter: .status([.open])))
    let house = try store.createView(NewTaskView(title: "House", parent: parent, color: .teal, filter: .hasTag(home)))
    let module = try list(parent, in: store)
    #expect(block(.own(nil), of: module.model)?.rows.isEmpty == true)
    #expect(block(.own(nil), of: module.model)?.indicator == dropMark(Tile.rose.check))
    #expect(block(.list(house), of: module.model)?.indicator == dropMark(Tile.teal.check))
    module.tap(.showAsChosen(.columns))
    #expect(blocks(of: module.model).allSatisfy { $0.column != nil && $0.indicator == nil })
}

/// A row answers its lift and its swipe whatever its kind: a task's row those of its model, and an open card, which is
/// neither lifted nor swiped, none.
@Test func aRowAnswersItsLiftAndItsSwipeWhateverItsKind() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk"))
    let module = try list(BuiltInTaskViews.inbox, in: store)
    let drawn = try #require(blocks(of: module.model).first?.rows.first)
    #expect(drawn.lift == row(drawn).style.lift && drawn.lift != nil)
    #expect(drawn.swipe == row(drawn).swipe && drawn.swipe != nil)
    module.tap(.rowTapped(id))
    let card = try #require(blocks(of: module.model).first?.rows.first)
    #expect(card.lift == nil)
    #expect(card.swipe == nil)
}

/// A row or a column's card lifts exactly where it has a menu: not a row of the Done strip, not a task in the Trash
/// (the controller's ruling on #177, 2026-11-07). Its swipe reads Delete and the title the row draws aloud, "New task"
/// for a task with none.
@Test func aRowLiftsExactlyWhereItHasAMenu() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    try store.createTask(NewTask(title: " ", when: day(1)))
    let finished = try store.createTask(NewTask(title: "Filed", when: day(2)))
    try store.update(task: finished, [.status(.done)])
    let binned = try store.createTask(NewTask(title: "Binned"))
    try store.trash(task: binned)
    func lifts(_ model: TaskList.Model) -> [Bool] {
        (blocks(of: model).flatMap(\.rows) + model.doneRows).map { row($0).style.lift != nil }
    }
    func menus(_ model: TaskList.Model) -> [Bool] {
        (blocks(of: model).flatMap(\.rows) + model.doneRows).map { row($0).menu != nil }
    }
    let upcoming = try list(BuiltInTaskViews.upcoming, in: store)
    upcoming.tap(.doneStripTapped)
    #expect(lifts(upcoming.model) == menus(upcoming.model))
    #expect(lifts(upcoming.model) == [true, true, false])
    let rows = blocks(of: upcoming.model).flatMap(\.rows).map(row)
    #expect(rows.compactMap { $0.swipe?.accessibilityLabel } == ["Delete Buy milk", "Delete New task"])
    upcoming.tap(.showAsChosen(.columns))
    #expect(lifts(upcoming.model) == [true, true])
    let trash = try list(BuiltInTaskViews.trash, in: store)
    #expect(lifts(trash.model) == [false] && menus(trash.model) == [false])
}

/// The open card carries the phone's numbers, in the list and in a column; its pills, its fields and its subtasks read
/// what the task holds (Task 8's table, Card; `Phone.dc.html`, the open card; the controller's ruling on #176,
/// 2026-11-05).
@Test func theCardCarriesThePhonesNumbers() throws {
    let store = try makeStore()
    let errand = try store.createTag(title: "errand")
    let id = try store.createTask(
        NewTask(title: "Buy milk", notes: "two", when: day(1), deadline: day(2), tags: [errand])
    )
    let sub = try store.createTask(NewTask(title: "Find the coupon", parent: id))
    let module = try list(BuiltInTaskViews.upcoming, in: store)
    module.tap(.rowTapped(id))
    let colors = Tile.rose.check
    func check(_ title: String, _ action: Action, side: Double = 24) -> CheckModel<Action> {
        side == 24
            ? CheckModel(
                style: .init(
                    diameter: 24, ringWidth: 1.75, markSize: 15, markStrokeWidth: 1.75, hitWidth: 44, hitHeight: 44,
                    animation: .check, fillAnimation: .checkFills, markAnimation: .checkMarkDraws, pop: checkPop,
                    mark: checkMark, colors: colors
                ),
                isChecked: false, accessibilityLabel: "Complete: \(title)",
                action: action
            )
            : CheckModel(
                style: .init(
                    diameter: 18, ringWidth: 1.5, markSize: 12, markStrokeWidth: 1.4, hitWidth: 40, hitHeight: 44,
                    animation: .check, fillAnimation: .checkFills, markAnimation: .checkMarkDraws, pop: checkPop,
                    mark: checkMark, colors: colors
                ),
                isChecked: false, accessibilityLabel: "Complete: \(title)",
                action: action
            )
    }
    func field(
        _ text: String, _ placeholder: String, _ font: DesignSystem.Font, _ color: DesignSystem.Color, height: Double,
        padding: Double, submitted: Action, cancelled: Action, focusLost: Action
    ) -> TextFieldModel<Action> {
        TextFieldModel(
            text: text, placeholder: placeholder,
            style: FieldStyle(
                font: font, color: color, placeholder: .placeholder, background: .surface, minimumWidth: 0,
                height: height, padding: padding, cornerRadius: 0, ring: LineStyle(color: .surface, width: 0, dash: [])
            ),
            submitted: submitted, cancelled: cancelled, focusLost: focusLost
        )
    }
    func pill(_ icon: DesignSystem.Icon, size: Double, iconColor: DesignSystem.Color, _ text: String, font: DesignSystem.Font = .pill) -> PillModel {
        PillModel(
            icon: IconModel(icon: icon, style: IconStyle(size: size, weight: .regular, color: iconColor)),
            text: TextModel(text: text, style: TextStyle(font: font, color: .ink)),
            style: .init(
                height: 32, cornerRadius: 16, leadingPadding: 10, trailingPadding: 12, spacing: 6, background: .fill
            )
        )
    }
    func card(
        topMargin: Double, horizontalMargin: Double, bottomMargin: Double, cornerRadius: Double,
        shadow: DesignSystem.Shadow, bodyLeading: Double, bodyTrailing: Double, bodyBottom: Double
    ) -> CardModel<Action> {
        let subtaskCircle = CheckStyle(
            diameter: 18, ringWidth: 1.5, markSize: 12, markStrokeWidth: 1.4, hitWidth: 40, hitHeight: 44,
            animation: .check, fillAnimation: .checkFills, markAnimation: .checkMarkDraws, pop: checkPop,
            mark: checkMark, colors: colors
        )
        return CardModel(
            check: check("Buy milk", .checkTapped(id)),
            title: field(
                "Buy milk", "New task", .rowTitleEmphasized, .ink, height: 44, padding: 2, submitted: .titleFieldSubmitted,
                cancelled: .titleFieldCancelled, focusLost: .titleFieldLostFocus
            ),
            notes: field(
                "two", "Notes", .notes, .ink2, height: 22, padding: 0, submitted: .notesFieldLostFocus,
                cancelled: .escapeKeyPressed, focusLost: .notesFieldLostFocus
            ),
            subtasks: [
                SubtaskRowModel(
                    check: check("Find the coupon", .subtaskCheckTapped(sub), side: 18),
                    title: TextModel(text: "Find the coupon", style: TextStyle(font: .notes, color: .ink)),
                    style: .init(height: 44, strike: nil, titleAnimation: .titleFades)
                ),
            ],
            subtaskField: nil,
            addSubtask: AddRowModel(
                icon: IconModel(icon: .plus, style: IconStyle(size: 17, weight: .regular, color: .ink2)),
                title: TextModel(text: "Add subtask", style: TextStyle(font: .notes, color: .ink2)),
                style: .init(
                    iconCellWidth: 40, spacing: 0, height: 44, width: nil, cornerRadius: 12, topPadding: 0,
                    leadingPadding: 0, trailingPadding: 12, dash: nil, rule: nil, topMargin: 0, leadingMargin: -12,
                    trailingMargin: 0
                ),
                action: .addSubtaskTapped
            ),
            pills: [
                pill(.sun, size: 16, iconColor: Tile.amber.glyph, "Tomorrow"),
                pill(.flag, size: 15, iconColor: .red, "Fri, Sep 12"),
                pill(.hash, size: 14, iconColor: .ink2, "errand", font: .areaLabel),
            ],
            expand: ButtonModel(
                label: ButtonLabelModel(
                    icon: IconModel(icon: .expand, style: IconStyle(size: 19, weight: .regular, color: .ink2)),
                    title: nil, accessibilityLabel: "Open full screen",
                    style: ButtonLabelStyle(fill: .color(.surface))
                ),
                action: .openFullScreenTapped
            ),
            style: .init(
                expandHitSide: 44, cornerRadius: cornerRadius, topMargin: topMargin, horizontalMargin: horizontalMargin,
                bottomMargin: bottomMargin, bodyLeading: bodyLeading, bodyTrailing: bodyTrailing,
                bodyBottom: bodyBottom, subtasksToPills: 10, pillSpacing: 6, shadow: shadow, background: .surface,
                entrance: EntranceStyle(
                    opacity: 0.3, scale: 0.97, offset: -4, anchorX: 0.5, anchorY: 0.5, animation: .cardOpens
                ),
                subtasksOutdent: 12, titleToNotes: 2, notesToSubtasks: 4, subtaskDraftCircle: subtaskCircle,
                leaving: taskLeaving, titleStrike: nil
            ),
            backgroundTapped: .backgroundTapped
        )
    }
    #expect(openCard(in: module.model)?.card == card(
        topMargin: 6, horizontalMargin: 10, bottomMargin: 10, cornerRadius: 18, shadow: .raised, bodyLeading: 46,
        bodyTrailing: 14, bodyBottom: 14
    ))
    module.tap(.showAsChosen(.columns))
    #expect(openCard(in: module.model)?.card == card(
        topMargin: 0, horizontalMargin: 0, bottomMargin: 0, cornerRadius: 13, shadow: .resting, bodyLeading: 44,
        bodyTrailing: 12, bodyBottom: 12
    ))
    module.tap(.addSubtaskTapped)
    module.tap(.subtaskFieldChanged("A note"))
    #expect(openCard(in: module.model)?.card.subtaskField == field(
        "A note", "Subtask", .notes, .ink, height: 40, padding: 0, submitted: .subtaskFieldSubmitted,
        cancelled: .subtaskFieldCancelled, focusLost: .subtaskFieldLostFocus
    ))
}

/// A done task's card strikes its title in ink 3 over ink 2, as a done row's title is, and an open task's has no line
/// through it (`Phone.dc.html`, the card's `t.titleClass` and `.tt-done`; the controller's ruling on #177, 2026-11-07).
@Test func aDoneTasksCardStrikesItsTitle() throws {
    let store = try makeStore()
    let done = try store.createTask(NewTask(title: "Filed"))
    try store.update(task: done, [.status(.done)])
    let open = try store.createTask(NewTask(title: "Open"))
    let mine = try store.createView(NewTaskView(title: "Mine", color: .amber, filter: .trashed(false)))
    let module = try list(mine, in: store)
    module.tap(.rowTapped(open))
    #expect(openCard(in: module.model)?.card.style.titleStrike == nil)
    #expect(openCard(in: module.model)?.card.title.style.color == .ink)
    module.tap(.backgroundTapped)
    module.tap(.doneStripTapped)
    module.tap(.rowTapped(done))
    #expect(openCard(in: module.model)?.id == done)
    #expect(openCard(in: module.model)?.card.style.titleStrike == .ink3)
    #expect(openCard(in: module.model)?.card.title.style.color == .ink2)
}

/// A list being named has the field in its header's place, in the list's glyph colour in the section title, with no
/// placeholder, in a list and in a column (`Phone.dc.html`, the block's and the column's name field).
@Test func theNameFieldStandsInTheHeadersPlace() throws {
    let store = try makeStore()
    let parent = try store.createView(NewTaskView(title: "Projects", color: .indigo, filter: .status([.open])))
    let module = try list(parent, in: store)
    module.tap(.addListTapped)
    let made = try #require(try store.children(ofView: parent).last?.id)
    func field(background: DesignSystem.Color, height: Double) -> TextFieldModel<Action> {
        TextFieldModel(
            text: "New list", placeholder: "",
            style: FieldStyle(
                font: .sectionTitle, color: Tile.indigo.glyph, placeholder: .placeholder, background: background,
                minimumWidth: 0, height: height, padding: 0, cornerRadius: 0,
                ring: LineStyle(color: background, width: 0, dash: [])
            ),
            submitted: .listNameFieldSubmitted, cancelled: .listNameFieldCancelled, focusLost: .listNameFieldLostFocus
        )
    }
    #expect(block(.list(made), of: module.model)?.header?.field == field(background: .paper, height: 31))
    module.tap(.showAsChosen(.columns))
    #expect(block(.list(made), of: module.model)?.column?.header.field == field(background: .fill, height: 22))
}
