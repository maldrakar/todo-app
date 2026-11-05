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
/// at least 44 high and rounded 12; no swipe, lift or menu yet (Tasks 7 and 8).
private func phoneRow(
    _ title: String, id: TaskID, colors: DesignSystem.Color.Components.Check, isOpen: Bool = true,
    meta: [MetaItemModel] = []
) -> TaskRowModel<Action> {
    TaskRowModel(
        check: CheckModel(
            diameter: 24, ringWidth: 1.75, markSize: 15, markStrokeWidth: 1.75, hitWidth: 44, hitHeight: 44,
            colors: colors, isChecked: !isOpen, animation: .check,
            accessibilityLabel: (isOpen ? "Complete: " : "Mark as not done: ") + title, action: .rowTapped(id)
        ),
        title: TextModel(text: title, font: .rowTitle, color: isOpen ? .ink : .ink2), strike: isOpen ? nil : .ink3,
        meta: meta, titleToMeta: 3, metaSpacing: 10, metaLineSpacing: 3, verticalPadding: 11, titleLeading: 2,
        titleTrailing: 4, leading: 8, trailing: 12, minimumHeight: 44, cornerRadius: 12, swipe: nil, lift: nil,
        fresh: nil, freshAnimation: .fresh, tap: .rowTapped(id), menu: nil
    )
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
/// the task not done; an open one says it completes it (canvas, `.tt-done` and `cbLabel`). Until #176 gives the check
/// its own action, it sends the row's tap.
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
/// controller's ruling on #175, 2026-11-04). A column does not take a drop until Task 7 reads a block's rule.
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
        isDropTarget: false, dropRing: StrokeModel(color: Tile.rose.check.fill, width: 2, dash: []), cardCornerRadius: 13,
        cardBackground: .surface, cardRing: StrokeModel(color: .glassLine, width: 0.5, dash: []), cardShadow: .resting
    ))
    #expect(block.rows.map(row) == [TaskRowModel(
        check: CheckModel(
            diameter: 22, ringWidth: 1.75, markSize: 15, markStrokeWidth: 1.75, hitWidth: 42, hitHeight: 44,
            colors: Tile.rose.check, isChecked: false, animation: .check, accessibilityLabel: "Complete: Buy milk",
            action: .rowTapped(id)
        ),
        title: TextModel(text: "Buy milk", font: .nestedRowTitle, color: .ink), strike: nil, meta: [], titleToMeta: 3,
        metaSpacing: 10, metaLineSpacing: 3, verticalPadding: 11, titleLeading: 2, titleTrailing: 4, leading: 0,
        trailing: 12, minimumHeight: 44, cornerRadius: 13, swipe: nil, lift: nil, fresh: nil, freshAnimation: .fresh,
        tap: .rowTapped(id), menu: nil
    )])
}
