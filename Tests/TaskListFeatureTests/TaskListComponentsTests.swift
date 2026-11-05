import Testing
import TestSupport
import DesignSystem
import DesignSystemComponents
import TaskListFeature
import TodoCore

private typealias Action = TaskList.UserAction
private typealias Tile = DesignSystem.Color.Components.Tile

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
/// its edges, rounded 12, and its menu holds Delete; no lift yet (Task 8). A row of the strip has neither, and no meta
/// line.
private func phoneRow(
    _ title: String, id: TaskID, colors: DesignSystem.Color.Components.Check, isOpen: Bool = true,
    meta: [MetaItemModel] = [], deletes: Bool = true
) -> TaskRowModel<Action> {
    TaskRowModel(
        check: CheckModel(
            diameter: 24, ringWidth: 1.75, markSize: 15, markStrokeWidth: 1.75, hitWidth: 44, hitHeight: 44,
            colors: colors, isChecked: !isOpen, animation: .check,
            accessibilityLabel: (isOpen ? "Complete: " : "Mark as not done: ") + title, action: .checkTapped(id)
        ),
        title: TextModel(text: title, font: .rowTitle, color: isOpen ? .ink : .ink2), strike: isOpen ? nil : .ink3,
        meta: meta, titleToMeta: 3, metaSpacing: 10, metaLineSpacing: 3, verticalPadding: 11, titleLeading: 2,
        titleTrailing: 4, leading: 8, trailing: 12, minimumHeight: 44, cornerRadius: 12,
        swipe: deletes ? SwipeModel(
            threshold: 40, shift: -88, buttonWidth: 78, buttonVerticalInset: 3, buttonTrailingInset: 10,
            buttonCornerRadius: 12, button: TextModel(text: "Delete", font: .barLabel, color: .onAccent),
            background: .red, animation: .swipe, action: .deleteSwiped(id)
        ) : nil,
        lift: nil, fresh: nil, freshAnimation: .fresh, tap: .rowTapped(id), menu: deletes ? deleteMenu(id) : nil
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
    #expect(blocks(of: model).map { $0.rows.map { row($0).check.colors } } == [[Tile.indigo.check], [Tile.teal.check]])
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
            icon: IconModel(icon: .flag, size: 13, weight: .regular, color: .red),
            text: TextModel(text: "Due today", font: .meta, color: .red), spacing: 3, capsule: nil
        ),
        MetaItemModel(icon: nil, text: TextModel(text: "#errand", font: .meta, color: .ink2), spacing: 3, capsule: nil),
        MetaItemModel(
            icon: IconModel(icon: .note, size: 13, weight: .regular, color: .ink2), text: nil, spacing: 3, capsule: nil
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
            icon: IconModel(icon: .hash, size: 13, weight: .semibold, color: isLit ? Tile.amber.check.mark : .ink2),
            title: TextModel(text: "home", font: .pill, color: isLit ? Tile.amber.check.mark : .ink),
            background: isLit ? Tile.amber.check.fill : .fill, height: 30, cornerRadius: 15, leadingPadding: 10,
            trailingPadding: 12, spacing: 5, hitHeight: 44, isLit: isLit, action: .tagChipTapped(home)
        )
    }
    let bar = { (chips: [TagChipModel<Action>]) in
        TagBarModel(chips: chips, spacing: 6, padding: 20, fadeIn: 16, fadeOut: 28, leadingMargin: -20, trailingMargin: -20)
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
            title: TextModel(text: "Tomorrow", font: .sectionTitle, color: Tile.rose.glyph),
            subtitle: TextModel(text: "Thu, Sep 11", font: .areaLabel, color: .ink2), titleToSubtitle: 8, field: nil,
            fold: BlockHeaderModel.Fold(
                chevron: AccessoryModel.Chevron(
                    icon: IconModel(icon: .chevron, size: 18, weight: .semibold, color: .ink3),
                    rotation: isFolded ? -90 : 0, animation: .fold,
                    accessibilityLabel: isFolded ? "Unfold Tomorrow" : "Fold Tomorrow", action: .blockChevronTapped(id)
                ),
                hitSide: 44
            ),
            rule: StrokeModel(color: .line, width: 1, dash: []), height: 44, topMargin: 6,
            trailingMargin: 6, bottomMargin: 2, leadingMargin: 12, topPadding: 13, horizontalPadding: 8,
            bottomPadding: 0, cornerRadius: 0, titleTapped: .blockTitleTapped(id)
        )
    }
    #expect(blocks(of: module.model).first?.header == header(isFolded: false))
    _ = module.send(.action(.blockChevronTapped(id)))
    #expect(blocks(of: module.model).first?.header == header(isFolded: true))
}

/// The screen's header carries the phone's numbers: the list's tile 38 across, rounded 11, its glyph 23, 12 before the
/// large title, the subtitle in ink 2 6 under it and 50 in (Task 8's table).
@Test func theHeaderCarriesThePhonesNumbers() throws {
    let store = try makeStore()
    let header = try list(BuiltInTaskViews.today, in: store).model.header
    #expect(header == ScreenHeaderModel(
        tile: TileModel(color: .amber, icon: .sun, side: 38, cornerRadius: 11, glyphSize: 23),
        title: TextModel(text: "Today", font: .largeTitle, color: .ink),
        subtitle: TextModel(text: "Wednesday, September 10", font: .count, color: .ink2), spacing: 12,
        titleToSubtitle: 6, subtitleLeading: 50
    ))
}

/// The empty state carries the phone's numbers: the list's tile 64 across, rounded 18, its glyph 32, the title 18
/// under it and the line 6 under that, 84 from the top, 40 in and 270 wide at most (Task 8's table).
@Test func theEmptyStateCarriesThePhonesNumbers() throws {
    let store = try makeStore()
    #expect(try list(BuiltInTaskViews.inbox, in: store).model.empty == EmptyScreenModel(
        tile: TileModel(color: .blue, icon: .tray, side: 64, cornerRadius: 18, glyphSize: 32),
        title: TextModel(text: "Nothing here yet", font: .emptyScreenTitle, color: .ink),
        text: TextModel(text: "Tasks that match this list’s rule will show up here.", font: .notes, color: .ink2),
        tileToTitle: 18, titleToText: 6, topPadding: 84, horizontalPadding: 40, maxWidth: 270
    ))
}

/// Show as is "…" on the platform's container, reading "More", with List and Columns, Columns disabled with its reason
/// where there is nothing to show as columns (canvas, section 2; spec section 5).
@Test func showAsIsMoreWithListAndAColumnsItemDisabledWithItsReason() throws {
    let store = try makeStore()
    func showAs(canBoard: Bool) -> MenuButtonModel<Action> {
        MenuButtonModel(
            label: ButtonLabelModel(
                icon: IconModel(icon: .ellipsis, size: 22, weight: .semibold, color: .ink), title: nil,
                accessibilityLabel: "More", fill: .container
            ),
            menu: MenuModel(sections: [
                .init(items: [
                    .init(title: "List", icon: .list, isDestructive: false, shortcut: nil, action: .showAsChosen(.list)),
                    .init(
                        title: "Columns", subtitle: canBoard ? nil : "Group the list in its settings to get columns",
                        icon: .columns, isDestructive: false, isDisabled: !canBoard, shortcut: nil,
                        action: .showAsChosen(.columns)
                    ),
                ]),
            ])
        )
    }
    #expect(try list(BuiltInTaskViews.inbox, in: store).model.showAs == showAs(canBoard: false))
    #expect(try list(BuiltInTaskViews.upcoming, in: store).model.showAs == showAs(canBoard: true))
}

/// A column and its cards carry the board's numbers: the board 10 between columns, 16 in at its sides and 24 at its
/// bottom, snapping; a column 296 wide, rounded 18 on the fill, its cards 8 apart and 8 in, each rounded 13 on the
/// surface with a 0.5 hairline of the glass line and the resting shadow; its header 44 high, padded 13 14 9, with no
/// rule and no chevron; a card's check 22 across in a 42 by 44 hit and its title callout-sized (Task 8's table; the
/// controller's ruling on #175, 2026-11-04). A card has the row's menu and no swipe (canvas), and the column takes a
/// drop where the block's rule reads as edits.
@Test func aColumnCarriesTheBoardsNumbers() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let module = try list(BuiltInTaskViews.upcoming, in: store)
    _ = module.send(.action(.showAsChosen(.columns)))
    let model = module.model
    let board = try #require(board(of: model))
    #expect([board.spacing, board.horizontalPadding, board.bottomPadding] == [10, 16, 24])
    #expect(board.snaps)
    let block = try #require(board.columns.first)
    let blockID = TaskList.Model.BlockID.own(.day(day(1)))
    #expect(block.column == ColumnModel(
        header: BlockHeaderModel(
            title: TextModel(text: "Tomorrow", font: .sectionTitle, color: Tile.rose.glyph),
            subtitle: TextModel(text: "Thu, Sep 11", font: .areaLabel, color: .ink2), titleToSubtitle: 8, field: nil,
            fold: nil, rule: nil, height: 44, topMargin: 0, trailingMargin: 0, bottomMargin: 0,
            leadingMargin: 0, topPadding: 13, horizontalPadding: 14, bottomPadding: 9, cornerRadius: 0,
            titleTapped: .blockTitleTapped(blockID)
        ),
        width: 296, cornerRadius: 18, cardSpacing: 8, padding: 8, fill: .fill, dropTint: Tile.rose.dropTint,
        isDropTarget: true, dropRing: StrokeModel(color: Tile.rose.check.fill, width: 2, dash: []), cardCornerRadius: 13,
        cardBackground: .surface, cardRing: StrokeModel(color: .glassLine, width: 0.5, dash: []), cardShadow: .resting
    ))
    #expect(block.rows.map(row) == [TaskRowModel(
        check: CheckModel(
            diameter: 22, ringWidth: 1.75, markSize: 15, markStrokeWidth: 1.75, hitWidth: 42, hitHeight: 44,
            colors: Tile.rose.check, isChecked: false, animation: .check, accessibilityLabel: "Complete: Buy milk",
            action: .checkTapped(id)
        ),
        title: TextModel(text: "Buy milk", font: .nestedRowTitle, color: .ink), strike: nil, meta: [], titleToMeta: 3,
        metaSpacing: 10, metaLineSpacing: 3, verticalPadding: 11, titleLeading: 2, titleTrailing: 4, leading: 0,
        trailing: 12, minimumHeight: 44, cornerRadius: 13, swipe: nil, lift: nil, fresh: nil, freshAnimation: .fresh,
        tap: .rowTapped(id), menu: deleteMenu(id)
    )])
}

/// A task with no title is drawn as "New task" in its row, a blank title too, wherever a row is drawn: a block's, a column's
/// card and the strip's, its title and what its check reads aloud alike, since a row with nothing to read is no row to find
/// (spec, "Risks"; the controller's ruling on #176, 2026-11-05). The store keeps what it holds, and the open card's field
/// shows that with its placeholder, as it does for a task just added.
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
    module.tap(.titleFieldChanged("Typed"))
    #expect(openCard(in: module.model)?.card.title.text == "Typed")
}

/// A row that adds a task carries the phone's numbers in the list, 40 high with its plus 18 in a 44 cell, and in a
/// column, 44 high with the plus 6 before its title; the row that adds a list stands after the blocks over a rule and
/// as the board's dashed last column (Task 8's table, Add rows and Board).
@Test func theAddRowsCarryThePhonesNumbers() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk", when: day(1)))
    let module = try list(BuiltInTaskViews.upcoming, in: store)
    let id = TaskList.Model.BlockID.own(.day(day(1)))
    func plus(_ size: Double) -> IconModel { IconModel(icon: .plus, size: size, weight: .regular, color: .ink2) }
    #expect(block(id, of: module.model)?.addTask == AddRowModel(
        icon: plus(18), iconCellWidth: 44, spacing: 0, title: TextModel(text: "Add task", font: .addRow, color: .ink2),
        height: 40, width: nil, cornerRadius: 12, topPadding: 0, leadingPadding: 0, trailingPadding: 12, dash: nil,
        rule: nil, topMargin: 0, leadingMargin: 8, trailingMargin: 12, action: .addTaskRowTapped(in: id)
    ))
    #expect(module.model.addList == AddRowModel(
        icon: plus(18), iconCellWidth: 40, spacing: 0, title: TextModel(text: "Add list", font: .barLabel, color: .ink2),
        height: 44, width: nil, cornerRadius: 12, topPadding: 4, leadingPadding: 0, trailingPadding: 12, dash: nil,
        rule: StrokeModel(color: .line, width: 1, dash: []), topMargin: 10, leadingMargin: 12, trailingMargin: 6,
        action: .addListTapped
    ))
    module.tap(.showAsChosen(.columns))
    #expect(block(id, of: module.model)?.addTask == AddRowModel(
        icon: plus(18), iconCellWidth: 18, spacing: 6, title: TextModel(text: "Add task", font: .addRow, color: .ink2),
        height: 44, width: nil, cornerRadius: 13, topPadding: 0, leadingPadding: 11, trailingPadding: 12, dash: nil,
        rule: nil, topMargin: 0, leadingMargin: 0, trailingMargin: 0, action: .addTaskRowTapped(in: id)
    ))
    #expect(module.model.addList == nil, "the board holds it")
    #expect(board(of: module.model)?.addList == AddRowModel(
        icon: plus(18), iconCellWidth: 18, spacing: 8, title: TextModel(text: "Add list", font: .barLabel, color: .ink2),
        height: 52, width: 200, cornerRadius: 18, topPadding: 0, leadingPadding: 16, trailingPadding: 16,
        dash: StrokeModel(color: .line, width: 1.5, dash: [5, 4]), rule: nil, topMargin: 0, leadingMargin: 0,
        trailingMargin: 0, action: .addListTapped
    ))
}

/// The floating "+" is the accent's 48 circle with a white plus 22 across, casting the raised shadow and reading "New
/// task" (Task 8's table, Floating "+"; the controller's ruling on #176, 2026-11-05).
@Test func theFloatingPlusCarriesThePhonesNumbers() throws {
    let store = try makeStore()
    #expect(try list(BuiltInTaskViews.inbox, in: store).model.addTask == FloatingButtonModel(
        icon: IconModel(icon: .plus, size: 22, weight: .semibold, color: .onAccent), diameter: 48, fill: .accent,
        shadow: .raised, accessibilityLabel: "New task", action: .addTaskButtonTapped
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
            icon: IconModel(icon: .checkCircle, size: 18, weight: .regular, color: Tile.amber.glyph),
            label: TextModel(text: "Done today · 1", font: .barLabel, color: .ink2),
            chevron: AccessoryModel.Chevron(
                icon: IconModel(icon: .chevron, size: 15, weight: .semibold, color: .ink2), rotation: isOpen ? 180 : 0,
                animation: .fold, accessibilityLabel: isOpen ? "Hide done tasks" : "Show done tasks",
                action: .doneStripTapped
            ),
            background: .fill, height: 36, cornerRadius: 18, spacing: 8, leadingPadding: 10, trailingPadding: 14,
            topMargin: 20, leadingMargin: 14, trailingMargin: 16, isOpen: isOpen, action: .doneStripTapped
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
                diameter: 24, ringWidth: 1.75, markSize: 15, markStrokeWidth: 1.75, hitWidth: 44, hitHeight: 44,
                colors: colors, isChecked: false, animation: .check, accessibilityLabel: "Complete: \(title)",
                action: action
            )
            : CheckModel(
                diameter: 18, ringWidth: 1.5, markSize: 12, markStrokeWidth: 1.4, hitWidth: 40, hitHeight: 44,
                colors: colors, isChecked: false, animation: .check, accessibilityLabel: "Complete: \(title)",
                action: action
            )
    }
    func field(
        _ text: String, _ placeholder: String, _ font: DesignSystem.Font, _ color: DesignSystem.Color, height: Double,
        padding: Double, submitted: Action, cancelled: Action, focusLost: Action
    ) -> TextFieldModel<Action> {
        TextFieldModel(
            text: text, placeholder: placeholder, font: font, color: color, background: .surface, minimumWidth: 0,
            height: height, padding: padding, cornerRadius: 0, ring: StrokeModel(color: .surface, width: 0, dash: []),
            submitted: submitted, cancelled: cancelled, focusLost: focusLost
        )
    }
    func pill(_ icon: DesignSystem.Icon, size: Double, iconColor: DesignSystem.Color, _ text: String, font: DesignSystem.Font = .pill) -> PillModel {
        PillModel(
            icon: IconModel(icon: icon, size: size, weight: .regular, color: iconColor),
            text: TextModel(text: text, font: font, color: .ink), background: .fill, height: 32, cornerRadius: 16,
            leadingPadding: 10, trailingPadding: 12, spacing: 6
        )
    }
    func card(
        topMargin: Double, horizontalMargin: Double, bottomMargin: Double, cornerRadius: Double,
        shadow: DesignSystem.Shadow, bodyLeading: Double, bodyTrailing: Double, bodyBottom: Double
    ) -> CardModel<Action> {
        CardModel(
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
                    title: TextModel(text: "Find the coupon", font: .notes, color: .ink), strike: nil, height: 44
                ),
            ],
            subtaskField: nil,
            addSubtask: AddRowModel(
                icon: IconModel(icon: .plus, size: 17, weight: .regular, color: .ink2), iconCellWidth: 40, spacing: 0,
                title: TextModel(text: "Add subtask", font: .notes, color: .ink2), height: 44, width: nil,
                cornerRadius: 12, topPadding: 0, leadingPadding: 0, trailingPadding: 12, dash: nil, rule: nil,
                topMargin: 0, leadingMargin: -12, trailingMargin: 0, action: .addSubtaskTapped
            ),
            pills: [
                pill(.sun, size: 16, iconColor: Tile.amber.glyph, "Tomorrow"),
                pill(.flag, size: 15, iconColor: .red, "Fri, Sep 12"),
                pill(.hash, size: 14, iconColor: .ink2, "errand", font: .areaLabel),
            ],
            expand: ButtonModel(
                label: ButtonLabelModel(
                    icon: IconModel(icon: .expand, size: 19, weight: .regular, color: .ink2), title: nil,
                    accessibilityLabel: "Open full screen", fill: .color(.surface)
                ),
                action: .openFullScreenTapped
            ),
            expandHitSide: 44, background: .surface, cornerRadius: cornerRadius, topMargin: topMargin,
            horizontalMargin: horizontalMargin, bottomMargin: bottomMargin, bodyLeading: bodyLeading,
            bodyTrailing: bodyTrailing, bodyBottom: bodyBottom, subtasksToPills: 10, pillSpacing: 6, shadow: shadow,
            animation: .cardOpens, backgroundTapped: .backgroundTapped
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
            text: "New list", placeholder: "", font: .sectionTitle, color: Tile.indigo.glyph, background: background,
            minimumWidth: 0, height: height, padding: 0, cornerRadius: 0,
            ring: StrokeModel(color: background, width: 0, dash: []), submitted: .listNameFieldSubmitted,
            cancelled: .listNameFieldCancelled, focusLost: .listNameFieldLostFocus
        )
    }
    #expect(block(.list(made), of: module.model)?.header?.field == field(background: .paper, height: 31))
    module.tap(.showAsChosen(.columns))
    #expect(block(.list(made), of: module.model)?.column?.header.field == field(background: .fill, height: 22))
}
