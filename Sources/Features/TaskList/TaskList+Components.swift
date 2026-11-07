// Sources/Features/TaskList/TaskList+Components.swift
import DesignSystem
import DesignSystemComponents
import TodoCore

/// The models of the list screen's components, built from the blocks and this person's session with the canvas's
/// numbers for the layout the list is shown as: the phone's (`Phone.dc.html`, 2026-11-01), as Task 8's table gives
/// them, the list's and the board's; the Mac's arrive with its pane (Task 9). Every size, gap, radius and line is in
/// points, every colour, font, icon, animation and shadow a token of the design system, every word finished, in English
/// until the formatting service arrives, and every control's action a value (ADR-0007, amendment of 2026-10-30). The
/// numbers are one value per layout (`Metrics`), picked once where the model is built, so that no builder branches on
/// the layout, as the sidebar's are one value per width (`TaskViewList+Components.swift`); a component's are its style,
/// `CheckStyle` for `CheckModel` and so on, which also holds its colours and motions, and which a builder hands over
/// whole; what stays in `Metrics` beside the styles is a number a nested model takes, such as a glyph's size, and a
/// font. The open card is in `TaskList+Card.swift`, and the rows that add, the floating "+", the Done strip and Delete
/// in `TaskList+Controls.swift`.
extension TaskList {
    /// What the rows and the headers of a model are built from beside their own tasks: the device's day, the tags'
    /// names, the open card, the list being named and the task just dropped.
    struct RowContext {
        let today: Day
        let tags: TagNames
        let card: OpenCard?
        let naming: ListNaming?
        let fresh: TaskID?
    }

    /// The screen's header (Task 8's table, Header): the list's tile, the title in the large title, and the subtitle,
    /// where it has one, in the count's font and ink 2.
    static func header(
        _ heading: Heading, color: Tile, icon: DesignSystem.Icon, _ metrics: Metrics.Header
    ) -> ScreenHeaderModel {
        ScreenHeaderModel(
            tile: TileModel(
                icon: icon,
                style: TileStyle(
                    color: color, side: metrics.tile.side, cornerRadius: metrics.tile.cornerRadius,
                    glyphSize: metrics.tile.glyphSize, glyphWeight: .medium
                )
            ),
            title: TextModel(text: heading.title, style: TextStyle(font: .largeTitle, color: .ink)),
            subtitle: heading.subtitle.map { TextModel(text: $0, style: TextStyle(font: .count, color: .ink2)) },
            style: metrics.style
        )
    }

    /// The tag bar, nil when no chip would show (spec section 7; Task 8's table, Tag bar): each chip the tag's bare
    /// name in the pill's font after the hash glyph, lit, while its tag is picked, on the list's check fill with both
    /// in its mark's colour, and unlit on the fill with the title in ink and the glyph in ink 2 (the controller's
    /// ruling on #175, 2026-11-04).
    static func tagBar(
        _ chips: [Chip], picked: Set<TagID>, color: Tile, _ metrics: Metrics.TagBar
    ) -> TagBarModel<UserAction>? {
        guard !chips.isEmpty else { return nil }
        let colors = color.check
        return TagBarModel(
            chips: chips.map { chip in
                let isLit = picked.contains(chip.id)
                return TagChipModel(
                    icon: IconModel(
                        icon: .hash,
                        style: IconStyle(size: metrics.hashSize, weight: .semibold, color: isLit ? colors.mark : .ink2)
                    ),
                    title: TextModel(
                        text: chip.title, style: TextStyle(font: .pill, color: isLit ? colors.mark : .ink)
                    ),
                    style: metrics.chip(color, isLit), isLit: isLit, action: .tagChipTapped(chip.id)
                )
            },
            style: metrics.style
        )
    }

    /// The blocks in the layout the metrics are for. In the list, each block under its header, which folds it, its rows
    /// gone while it is folded; a block with no header folds by nothing. In columns, each block a column headed as the
    /// block is, the own block of a list that groups by nothing titled with the list's own title, its cards drawn
    /// whatever the folds, since columns do not fold, and the block itself with no header, so that it has one and not
    /// two (spec section 5; the controller's ruling on #175, 2026-11-04). "+ Add task" ends every block whose rule
    /// reads as an edit, the folded ones but in the list (canvas); the board ends with `addList`.
    static func layout(
        _ blocks: [PageBlock], title: String, folded: Set<String>, addList: AddRowModel<UserAction>?,
        _ context: RowContext, _ metrics: Metrics.Blocks
    ) -> Model.Layout {
        switch metrics {
        case .list(let headerMetrics, let chevronSize, let rowMetrics, let cardMetrics, let addTaskMetrics, _):
            return .list(blocks.map { block in
                let isFolded = block.heading != nil && foldKey(of: block.id).map(folded.contains) == true
                return Model.Block(
                    id: block.id,
                    header: block.heading.map {
                        blockHeader($0, of: block, isFolded: isFolded, context, headerMetrics, chevronSize: chevronSize)
                    },
                    rows: isFolded ? [] : block.tasks.map {
                        row($0, block.color, context, rowMetrics, card: cardMetrics)
                    },
                    isFolded: isFolded, column: nil,
                    addTask: isFolded ? nil : addTaskRow(for: block, addTaskMetrics), takesDrop: block.edit != nil
                )
            })
        case .columns(let board):
            return .columns(Model.Board(
                columns: blocks.map { block in
                    Model.Block(
                        id: block.id, header: nil,
                        rows: block.tasks.map { row($0, block.color, context, board.card, card: board.openCard) },
                        isFolded: false,
                        column: column(
                            block.heading ?? Heading(title: title, subtitle: nil), of: block, context, board
                        ),
                        addTask: addTaskRow(for: block, board.addTask), takesDrop: block.edit != nil
                    )
                },
                spacing: board.spacing, horizontalPadding: board.horizontalPadding, bottomPadding: board.bottomPadding,
                snaps: board.snaps, addList: addList
            ))
        }
    }

    /// A block's header in the list (Task 8's table, Block header): the title in the section title in the colour of the
    /// block's list's glyph, the date after it in ink 2, the rule of the line under it, and the chevron, down while the
    /// block is open and turned a quarter left while it is folded, saying what a tap will do (the controller's ruling
    /// on #175, 2026-11-04: the canvas keeps "Fold" and carries the state in `aria-expanded`, which the model has no
    /// field for).
    private static func blockHeader(
        _ heading: Heading, of block: PageBlock, isFolded: Bool, _ context: RowContext,
        _ style: BlockHeaderStyle, chevronSize: Double
    ) -> BlockHeaderModel<UserAction> {
        let fold = AccessoryModel<UserAction>.Chevron(
            icon: IconModel(icon: .chevron, style: IconStyle(size: chevronSize, weight: .semibold, color: .ink3)),
            accessibilityLabel: (isFolded ? "Unfold " : "Fold ") + heading.title,
            action: .blockChevronTapped(block.id), style: ChevronStyle(rotation: isFolded ? -90 : 0, animation: .fold)
        )
        return blockHeader(heading, of: block, fold: fold, background: .paper, context, style)
    }

    /// A block's column (Task 8's table, Board): its header as a block's but with no rule and no chevron, since columns
    /// do not fold; the column on the fill, rounded; its cards on the surface, rounded, ringed with the glass line and
    /// casting the resting shadow; the drop's tint and ring in the block's list's colours, where the block's rule reads
    /// as an edit (spec section 6).
    private static func column(
        _ heading: Heading, of block: PageBlock, _ context: RowContext, _ metrics: Metrics.Board
    ) -> ColumnModel<UserAction> {
        ColumnModel(
            header: blockHeader(heading, of: block, fold: nil, background: .fill, context, metrics.header),
            style: metrics.column(block.color), isDropTarget: block.edit != nil
        )
    }

    /// The header of a block or a column, with the fold it is given or none: what both share. While the block's list is
    /// being named its name's field stands in its title's place, in what is left of the header's height under and over
    /// its paddings, on what the header stands on (`Phone.dc.html`, the block's and the column's name field; the
    /// controller's ruling on #176, 2026-11-05: no placeholder).
    private static func blockHeader(
        _ heading: Heading, of block: PageBlock, fold: AccessoryModel<UserAction>.Chevron?,
        background: DesignSystem.Color, _ context: RowContext, _ style: BlockHeaderStyle
    ) -> BlockHeaderModel<UserAction> {
        let field: TextFieldModel<UserAction>? = if let naming = context.naming, block.id == .list(naming.id) {
            plainField(
                naming.draft, placeholder: "", font: .sectionTitle, color: block.color.glyph, background: background,
                height: style.height - style.topPadding - style.bottomPadding, padding: 0,
                submitted: .listNameFieldSubmitted, cancelled: .listNameFieldCancelled,
                focusLost: .listNameFieldLostFocus
            )
        } else {
            nil
        }
        return BlockHeaderModel(
            title: TextModel(text: heading.title, style: TextStyle(font: .sectionTitle, color: block.color.glyph)),
            subtitle: heading.subtitle.map { TextModel(text: $0, style: TextStyle(font: .areaLabel, color: .ink2)) },
            field: field, fold: fold, style: style, titleTapped: .blockTitleTapped(block.id)
        )
    }

    /// A task of a block: the open card where its row stood, or its row with its meta line, and its swipe and its menu,
    /// which a task in the Trash has neither of (spec section 6; the controller's ruling on #176, 2026-11-05). A
    /// column's card has the menu and no swipe, its metrics having none.
    private static func row(
        _ task: TodoTask, _ color: Tile, _ context: RowContext, _ metrics: Metrics.Row, card cardMetrics: Metrics.Card
    ) -> Model.Row {
        cardRow(of: task, color, context, cardMetrics) ?? .task(task.id, taskRow(
            task, color, meta: meta(of: task, today: context.today, tags: context.tags, metrics),
            swipe: task.trashed ? nil : metrics.swipe.map { swipe(of: task.id, title: drawnTitle(of: task), $0) },
            menu: task.trashed ? nil : deleteMenu(of: task.id), isFresh: context.fresh == task.id, metrics
        ))
    }

    /// The open card where its row stood, and nil for any other task: a block's rows and the strip's alike.
    private static func cardRow(
        of task: TodoTask, _ color: Tile, _ context: RowContext, _ metrics: Metrics.Card
    ) -> Model.Row? {
        guard let card = context.card, card.id == task.id else { return nil }
        return .card(task.id, self.card(of: task, card, color, context, metrics))
    }

    /// The Done strip and what stands under it while it is open, in the layout that has one (canvas: the board has
    /// none): its capsule, nil with no task to hold, and each task the open card where it stood, or its check and its
    /// struck title, with no meta line, no swipe and no menu (spec section 3; canvas; the controller's ruling on #176,
    /// 2026-11-05).
    static func doneStrip(
        _ tasks: [TodoTask], isOpen: Bool, color: Tile, _ context: RowContext, _ metrics: Metrics.Blocks
    ) -> (strip: DoneStripModel<UserAction>?, rows: [Model.Row]) {
        guard case .list(_, _, let rowMetrics, let cardMetrics, _, let stripMetrics) = metrics, !tasks.isEmpty else {
            return (nil, [])
        }
        let rows: [Model.Row] = isOpen ? tasks.map { task in
            cardRow(of: task, color, context, cardMetrics)
                ?? .task(
                    task.id,
                    taskRow(
                        task, color, meta: [], swipe: nil, menu: nil, isFresh: context.fresh == task.id, rowMetrics
                    )
                )
        } : []
        return (doneStrip(count: tasks.count, isOpen: isOpen, color: color, stripMetrics), rows)
    }

    /// A task's row, or a column's card in the card look (spec section 3; Task 8's table, Row and Board): the check in
    /// the block's list's colour, filled for a task that is not open and saying what a tap will do (the controller's
    /// ruling on #175, 2026-11-04); the title, struck in ink 3 over ink 2 for a task that is not open, and "New task"
    /// for a task with no title or a blank one, in the title and in what the check reads aloud (spec, "Risks"; the
    /// controller's ruling on #176, 2026-11-05); what stands under it and what it slides off and holds; and the row's
    /// tap. It can be lifted exactly where it has a menu, a task in the Trash and a row of the Done strip having
    /// neither (the controller's ruling on #177, 2026-11-07), and it is fresh where it is the task just dropped.
    private static func taskRow(
        _ task: TodoTask, _ color: Tile, meta: [MetaItemModel], swipe: SwipeModel<UserAction>?,
        menu: MenuModel<UserAction>?, isFresh: Bool, _ metrics: Metrics.Row
    ) -> TaskRowModel<UserAction> {
        let isOpen = task.status == .open
        let title = drawnTitle(of: task)
        return TaskRowModel(
            check: check(title: title, isOpen: isOpen, action: .checkTapped(task.id), metrics.check(color)),
            title: TextModel(text: title, style: TextStyle(font: metrics.title, color: isOpen ? .ink : .ink2)),
            meta: meta, style: metrics.style(color, isOpen, menu != nil, isFresh), swipe: swipe,
            tap: .rowTapped(task.id), menu: menu
        )
    }

    /// A check, a row's, a card's or a subtask's: in the colour of the block's list, filled for a task that is not
    /// open, saying what a tap will do (canvas, `cbLabel`).
    static func check(
        title: String, isOpen: Bool, action: UserAction, _ style: CheckStyle
    ) -> CheckModel<UserAction> {
        CheckModel(
            style: style, isChecked: !isOpen,
            accessibilityLabel: (isOpen ? "Complete: " : "Mark as not done: ") + title, action: action
        )
    }

    /// A field with no ring of its own, on what it stands on, drawn by the line of what it stands in: a card's three
    /// and a list's name's.
    static func plainField(
        _ text: String, placeholder: String, font: DesignSystem.Font, color: DesignSystem.Color,
        background: DesignSystem.Color, height: Double, padding: Double, submitted: UserAction, cancelled: UserAction,
        focusLost: UserAction
    ) -> TextFieldModel<UserAction> {
        TextFieldModel(
            text: text, placeholder: placeholder,
            style: FieldStyle(
                font: font, color: color, background: background, minimumWidth: 0, height: height, padding: padding,
                cornerRadius: 0, ring: LineStyle(color: background, width: 0, dash: [])
            ),
            submitted: submitted, cancelled: cancelled, focusLost: focusLost
        )
    }

    /// A row's meta line, in the spec's order (spec section 3; canvas, section 5; the controller's ruling on #175,
    /// 2026-11-04): the deadline of an open task after the flag, red from the day it is due; each tag as "#name" in the
    /// tags' order; the subtasks done over all after the subtasks' glyph; and the notes' glyph alone, with no text.
    /// Every item carries the meta line's gap between a glyph and a text, which stands only where it has both.
    private static func meta(of task: TodoTask, today: Day, tags: TagNames, _ metrics: Metrics.Row) -> [MetaItemModel] {
        func item(_ icon: DesignSystem.Icon?, _ text: String?, color: DesignSystem.Color = .ink2) -> MetaItemModel {
            MetaItemModel(
                icon: icon.map {
                    IconModel(icon: $0, style: IconStyle(size: metrics.metaIconSize, weight: .regular, color: color))
                },
                text: text.map { TextModel(text: $0, style: TextStyle(font: .meta, color: color)) },
                style: MetaItemStyle(spacing: metrics.metaIconSpacing, capsule: nil)
            )
        }
        var items: [MetaItemModel] = []
        if task.status == .open, let deadline = task.deadline {
            let color: DesignSystem.Color = isDue(deadline, today: today) ? .red : .ink2
            items.append(item(.flag, dueText(deadline, today: today), color: color))
        }
        items += tags.titles(of: task.tags).map { item(nil, "#\($0)") }
        if task.subtasks > 0 { items.append(item(.list, "\(task.subtasksDone)/\(task.subtasks)")) }
        if task.hasNotes { items.append(item(.note, nil)) }
        return items
    }

    /// The empty state (Task 8's table, Empty state): the list's own tile at the state's size, the title in the empty
    /// screen's title, and the line under it in the notes' font and ink 2.
    static func empty(
        _ words: EmptyWords, color: Tile, icon: DesignSystem.Icon, _ metrics: Metrics.Empty
    ) -> EmptyScreenModel {
        EmptyScreenModel(
            tile: TileModel(
                icon: icon,
                style: TileStyle(
                    color: color, side: metrics.tile.side, cornerRadius: metrics.tile.cornerRadius,
                    glyphSize: metrics.tile.glyphSize, glyphWeight: .medium
                )
            ),
            title: TextModel(text: words.title, style: TextStyle(font: .emptyScreenTitle, color: .ink)),
            text: TextModel(text: words.text, style: TextStyle(font: .notes, color: .ink2)), style: metrics.style
        )
    }

    /// The back button over the content (spec section 1; Task 8's table, Glass buttons): the chevron, reading "Back".
    /// The canvas reads "Back to <title>" of the screen under this one, which the window's stack knows and this module
    /// does not (the controller's ruling on #177, 2026-11-07).
    static func back(_ metrics: Metrics.Glass) -> GlassButtonModel {
        GlassButtonModel(
            icon: IconModel(
                icon: .chevronLeft, style: IconStyle(size: metrics.backGlyphSize, weight: .semibold, color: .ink)
            ),
            style: metrics.back, accessibilityLabel: "Back"
        )
    }

    /// "…" over the content (spec section 5; Task 8's table, Glass buttons), reading "More": the menu it opens is
    /// `showAs`.
    static func more(_ metrics: Metrics.Glass) -> GlassButtonModel {
        GlassButtonModel(
            icon: IconModel(
                icon: .ellipsis, style: IconStyle(size: metrics.moreGlyphSize, weight: .semibold, color: .ink)
            ),
            style: metrics.more, accessibilityLabel: "More"
        )
    }

    /// Show as (spec section 5; canvas, section 2), the menu "…" opens, headed "Show as": List and Columns with their
    /// glyphs, the layout the list is shown as checked, Columns disabled with the reason the canvas gives where there
    /// are no columns to show.
    static func showAs(current: Model.Layout.Kind, canBoard: Bool) -> MenuModel<UserAction> {
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

    /// A list's tile colour, the store's name read as the design system's by its raw value, and stone for a list with
    /// none or with one the design system does not know, so that a platform draws every value it is given, as the
    /// sidebar reads it (`TaskViewList.ReadRow.tileColor`; ADR-0007, amendment of 2026-10-26). A feature cannot import
    /// its sibling (ADR-0007), so the reading is written here too.
    static func tileColor(_ color: TaskViewColor?) -> Tile {
        color.flatMap { Tile(rawValue: $0.rawValue) } ?? .stone
    }

    /// A list's tile glyph, the store's name of the icon read as the design system's, and the default glyph, bullets,
    /// for a list with none or with a name this app does not know, as the sidebar reads it (`TaskViewList.ReadRow`).
    static func tileIcon(_ icon: String?) -> DesignSystem.Icon {
        icon.flatMap(DesignSystem.Icon.init(rawValue:)) ?? .bullets
    }

    typealias Tile = DesignSystem.Color.Components.Tile
}
