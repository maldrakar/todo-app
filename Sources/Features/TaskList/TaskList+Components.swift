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
/// the layout, as the sidebar's are one value per width (`TaskViewList+Components.swift`).
extension TaskList {
    /// The screen's header (Task 8's table, Header): the list's tile, the title in the large title, and the subtitle,
    /// where it has one, in the count's font and ink 2.
    static func header(
        _ heading: Heading, color: Tile, icon: DesignSystem.Icon, _ metrics: Metrics.Header
    ) -> ScreenHeaderModel {
        ScreenHeaderModel(
            tile: TileModel(
                color: color, icon: icon, side: metrics.tileSide, cornerRadius: metrics.tileCornerRadius,
                glyphSize: metrics.glyphSize
            ),
            title: TextModel(text: heading.title, font: .largeTitle, color: .ink),
            subtitle: heading.subtitle.map { TextModel(text: $0, font: .count, color: .ink2) },
            spacing: metrics.spacing, titleToSubtitle: metrics.titleToSubtitle, subtitleLeading: metrics.subtitleLeading
        )
    }

    /// The tag bar, nil when no chip would show (spec section 7; Task 8's table, Tag bar): each chip the tag's bare
    /// name in the pill's font after the hash glyph, lit, while its tag is picked, on the list's check fill with both
    /// in its mark's colour, and unlit on the fill with the title in ink and the glyph in ink 2 (the controller's
    /// ruling on #175, 2026-11-04).
    static func tagBar(
        _ chips: [Chip], picked: Set<TagID>, colors: DesignSystem.Color.Components.Check, _ metrics: Metrics.TagBar
    ) -> TagBarModel<UserAction>? {
        guard !chips.isEmpty else { return nil }
        return TagBarModel(
            chips: chips.map { chip in
                let isLit = picked.contains(chip.id)
                return TagChipModel(
                    icon: IconModel(
                        icon: .hash, size: metrics.hashSize, weight: .semibold, color: isLit ? colors.mark : .ink2
                    ),
                    title: TextModel(text: chip.title, font: .pill, color: isLit ? colors.mark : .ink),
                    background: isLit ? colors.fill : .fill, height: metrics.chipHeight,
                    cornerRadius: metrics.chipHeight / 2, leadingPadding: metrics.chipLeadingPadding,
                    trailingPadding: metrics.chipTrailingPadding, spacing: metrics.chipSpacing,
                    hitHeight: metrics.chipHitHeight, isLit: isLit, action: .tagChipTapped(chip.id)
                )
            },
            spacing: metrics.spacing, padding: metrics.padding, fadeIn: metrics.fadeIn, fadeOut: metrics.fadeOut,
            leadingMargin: metrics.margin, trailingMargin: metrics.margin
        )
    }

    /// The blocks in the layout the metrics are for. In the list, each block under its header, which folds it, its rows
    /// gone while it is folded; a block with no header folds by nothing. In columns, each block a column headed as the
    /// block is, the own block of a list that groups by nothing titled with the list's own title, its cards drawn
    /// whatever the folds, since columns do not fold, and the block itself with no header, so that it has one and not
    /// two (spec section 5; the controller's ruling on #175, 2026-11-04).
    static func layout(
        _ blocks: [PageBlock], title: String, folded: Set<String>, today: Day, tags: TagNames, _ metrics: Metrics.Blocks
    ) -> Model.Layout {
        switch metrics {
        case .list(let headerMetrics, let chevronMetrics, let rowMetrics):
            return .list(blocks.map { block in
                let isFolded = block.heading != nil && foldKey(of: block.id).map(folded.contains) == true
                return Model.Block(
                    id: block.id,
                    header: block.heading.map {
                        blockHeader($0, of: block, isFolded: isFolded, headerMetrics, chevron: chevronMetrics)
                    },
                    rows: isFolded ? [] : block.tasks.map {
                        .task($0.id, row($0, block.color, today: today, tags: tags, rowMetrics))
                    },
                    isFolded: isFolded, column: nil
                )
            })
        case .columns(let board):
            return .columns(Model.Board(
                columns: blocks.map { block in
                    Model.Block(
                        id: block.id, header: nil,
                        rows: block.tasks.map {
                            .task($0.id, row($0, block.color, today: today, tags: tags, board.card))
                        },
                        isFolded: false,
                        column: column(block.heading ?? Heading(title: title, subtitle: nil), of: block, board)
                    )
                },
                spacing: board.spacing, horizontalPadding: board.horizontalPadding, bottomPadding: board.bottomPadding,
                snaps: board.snaps
            ))
        }
    }

    /// A block's header in the list (Task 8's table, Block header): the title in the section title in the colour of the
    /// block's list's glyph, the date after it in ink 2, the rule of the line under it, and the chevron, down while the
    /// block is open and turned a quarter left while it is folded, saying what a tap will do (the controller's ruling
    /// on #175, 2026-11-04: the canvas keeps "Fold" and carries the state in `aria-expanded`, which the model has no
    /// field for).
    private static func blockHeader(
        _ heading: Heading, of block: PageBlock, isFolded: Bool, _ metrics: Metrics.BlockHeader,
        chevron: Metrics.Chevron
    ) -> BlockHeaderModel<UserAction> {
        let fold = BlockHeaderModel<UserAction>.Fold(
            chevron: AccessoryModel.Chevron(
                icon: IconModel(icon: .chevron, size: chevron.size, weight: .semibold, color: .ink3),
                rotation: isFolded ? -90 : 0, animation: .fold,
                accessibilityLabel: (isFolded ? "Unfold " : "Fold ") + heading.title,
                action: .blockChevronTapped(block.id)
            ),
            hitSide: chevron.hitSide
        )
        return blockHeader(heading, of: block, fold: fold, metrics)
    }

    /// A block's column (Task 8's table, Board): its header as a block's but with no rule and no chevron, since columns
    /// do not fold; the column on the fill, rounded; its cards on the surface, rounded, ringed with the glass line and
    /// casting the resting shadow; the drop's tint and ring in the block's list's colours, which no column shows until
    /// a block's rule is read for a drop (Task 7).
    private static func column(
        _ heading: Heading, of block: PageBlock, _ metrics: Metrics.Board
    ) -> ColumnModel<UserAction> {
        ColumnModel(
            header: blockHeader(heading, of: block, fold: nil, metrics.header), width: metrics.columnWidth,
            cornerRadius: metrics.columnCornerRadius, cardSpacing: metrics.cardSpacing, padding: metrics.columnPadding,
            fill: .fill, dropTint: block.color.dropTint, isDropTarget: false,
            dropRing: StrokeModel(color: block.color.check.fill, width: metrics.dropRingWidth, dash: []),
            cardCornerRadius: metrics.cardCornerRadius, cardBackground: .surface,
            cardRing: StrokeModel(color: .glassLine, width: metrics.cardRingWidth, dash: []), cardShadow: .resting
        )
    }

    /// The header of a block or a column, with the fold it is given or none: what both share.
    private static func blockHeader(
        _ heading: Heading, of block: PageBlock, fold: BlockHeaderModel<UserAction>.Fold?, _ metrics: Metrics.BlockHeader
    ) -> BlockHeaderModel<UserAction> {
        BlockHeaderModel(
            title: TextModel(text: heading.title, font: .sectionTitle, color: block.color.glyph),
            subtitle: heading.subtitle.map { TextModel(text: $0, font: .areaLabel, color: .ink2) },
            titleToSubtitle: metrics.titleToSubtitle, field: nil, fold: fold, rule: metrics.rule, height: metrics.height,
            topMargin: metrics.topMargin, trailingMargin: metrics.trailingMargin, bottomMargin: metrics.bottomMargin,
            leadingMargin: metrics.leadingMargin, topPadding: metrics.topPadding,
            horizontalPadding: metrics.horizontalPadding, bottomPadding: metrics.bottomPadding, cornerRadius: 0,
            titleTapped: .blockTitleTapped(block.id)
        )
    }

    /// A task's row, or a column's card in the card look (spec section 3; Task 8's table, Row and Board): the check in
    /// the block's list's colour, filled for a task that is not open and saying what a tap will do (the controller's
    /// ruling on #175, 2026-11-04); the title, struck in ink 3 over ink 2 for a task that is not open; the meta line;
    /// and the row's tap. The check sends the row's tap until #176 gives it its own action (the controller's ruling on
    /// #175, 2026-11-04).
    private static func row(
        _ task: TodoTask, _ color: Tile, today: Day, tags: TagNames, _ metrics: Metrics.Row
    ) -> TaskRowModel<UserAction> {
        let isOpen = task.status == .open
        return TaskRowModel(
            check: CheckModel(
                diameter: metrics.checkDiameter, ringWidth: metrics.checkRingWidth, markSize: metrics.markSize,
                markStrokeWidth: metrics.markStrokeWidth, hitWidth: metrics.checkHitWidth,
                hitHeight: metrics.checkHitHeight, colors: color.check, isChecked: !isOpen, animation: .check,
                accessibilityLabel: (isOpen ? "Complete: " : "Mark as not done: ") + task.title,
                action: .rowTapped(task.id)
            ),
            title: TextModel(text: task.title, font: metrics.title, color: isOpen ? .ink : .ink2),
            strike: isOpen ? nil : .ink3, meta: meta(of: task, today: today, tags: tags, metrics),
            titleToMeta: metrics.titleToMeta, metaSpacing: metrics.metaSpacing,
            metaLineSpacing: metrics.metaLineSpacing,
            verticalPadding: metrics.verticalPadding, titleLeading: metrics.titleLeading,
            titleTrailing: metrics.titleTrailing, leading: metrics.leading, trailing: metrics.trailing,
            minimumHeight: metrics.minimumHeight, cornerRadius: metrics.cornerRadius, swipe: nil, lift: nil, fresh: nil,
            freshAnimation: .fresh, tap: .rowTapped(task.id), menu: nil
        )
    }

    /// A row's meta line, in the spec's order (spec section 3; canvas, section 5; the controller's ruling on #175,
    /// 2026-11-04): the deadline of an open task after the flag, red from the day it is due; each tag as "#name" in the
    /// tags' order; the subtasks done over all after the subtasks' glyph; and the notes' glyph alone, with no text.
    /// Every item carries the meta line's gap between a glyph and a text, which stands only where it has both.
    private static func meta(of task: TodoTask, today: Day, tags: TagNames, _ metrics: Metrics.Row) -> [MetaItemModel] {
        func item(_ icon: DesignSystem.Icon?, _ text: String?, color: DesignSystem.Color = .ink2) -> MetaItemModel {
            MetaItemModel(
                icon: icon.map { IconModel(icon: $0, size: metrics.metaIconSize, weight: .regular, color: color) },
                text: text.map { TextModel(text: $0, font: .meta, color: color) }, spacing: metrics.metaIconSpacing,
                capsule: nil
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
                color: color, icon: icon, side: metrics.tileSide, cornerRadius: metrics.tileCornerRadius,
                glyphSize: metrics.glyphSize
            ),
            title: TextModel(text: words.title, font: .emptyScreenTitle, color: .ink),
            text: TextModel(text: words.text, font: .notes, color: .ink2), tileToTitle: metrics.tileToTitle,
            titleToText: metrics.titleToText, topPadding: metrics.topPadding,
            horizontalPadding: metrics.horizontalPadding, maxWidth: metrics.maxWidth
        )
    }

    /// Show as (spec section 5; canvas, section 2): "…", 22 pt semibold in ink on the platform's container, reading
    /// "More", its menu List and Columns with their glyphs, Columns disabled with the reason the canvas gives where
    /// there are no columns to show. The menu's "Show as" heading and the current item's check arrive with their
    /// drawing (Task 8; the controller's ruling on #175, 2026-11-04).
    static func showAs(canBoard: Bool) -> MenuButtonModel<UserAction> {
        MenuButtonModel(
            label: ButtonLabelModel(
                icon: IconModel(icon: .ellipsis, size: 22, weight: .semibold, color: .ink), title: nil,
                accessibilityLabel: "More", fill: .container
            ),
            menu: MenuModel(sections: [
                .init(items: [
                    .init(
                        title: "List", icon: .list, isDestructive: false, shortcut: nil, action: .showAsChosen(.list)
                    ),
                    .init(
                        title: "Columns", subtitle: canBoard ? nil : "Group the list in its settings to get columns",
                        icon: .columns, isDestructive: false, isDisabled: !canBoard, shortcut: nil,
                        action: .showAsChosen(.columns)
                    ),
                ]),
            ])
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

    /// The numbers the screen's components are drawn with in one layout, in points, picked once by the layout
    /// (`of(_:)`), so that no builder branches on it: the phone's list (`phone`) and the phone's board
    /// (`phoneColumns`), which share the header, the tag bar and the empty state and differ in their blocks.
    struct Metrics {
        /// The screen's header: the tile's side, corners and glyph, the gap to the title, and the subtitle's distance
        /// under the title and in from the header's leading edge.
        struct Header {
            let tileSide: Double
            let tileCornerRadius: Double
            let glyphSize: Double
            let spacing: Double
            let titleToSubtitle: Double
            let subtitleLeading: Double
        }

        /// The tag bar and its chips: the chips' gap, the row's padding, the fades and the bar's margin past the
        /// content's sides, negative; a chip's height, a capsule's, its paddings, the glyph's size and gap, and its tap
        /// area's height.
        struct TagBar {
            let spacing: Double
            let padding: Double
            let fadeIn: Double
            let fadeOut: Double
            let margin: Double
            let chipHeight: Double
            let chipLeadingPadding: Double
            let chipTrailingPadding: Double
            let chipSpacing: Double
            let chipHitHeight: Double
            let hashSize: Double
        }

        /// A block's header or a column's: its height, margins and paddings, the gap between its title and its date,
        /// and its rule, nil for none.
        struct BlockHeader {
            let height: Double
            let topMargin: Double
            let trailingMargin: Double
            let bottomMargin: Double
            let leadingMargin: Double
            let topPadding: Double
            let horizontalPadding: Double
            let bottomPadding: Double
            let titleToSubtitle: Double
            let rule: StrokeModel?
        }

        /// The chevron that folds a block in the list: its glyph's size and its square hit's side. A column's header has
        /// none, so the board carries none.
        struct Chevron {
            let size: Double
            let hitSide: Double
        }

        /// A task's row, or a column's card: its insets, the check's sizes and hit, the title's font and paddings, the
        /// meta line's gaps and glyphs, its least height and its corners.
        struct Row {
            let leading: Double
            let trailing: Double
            let checkDiameter: Double
            let checkRingWidth: Double
            let markSize: Double
            let markStrokeWidth: Double
            let checkHitWidth: Double
            let checkHitHeight: Double
            let title: DesignSystem.Font
            let verticalPadding: Double
            let titleLeading: Double
            let titleTrailing: Double
            let titleToMeta: Double
            let metaSpacing: Double
            let metaLineSpacing: Double
            let metaIconSize: Double
            let metaIconSpacing: Double
            let minimumHeight: Double
            let cornerRadius: Double
        }

        /// The empty state: the tile's side, corners and glyph, the gaps under the tile and the title, its distance
        /// from the top and the sides, and the line's widest.
        struct Empty {
            let tileSide: Double
            let tileCornerRadius: Double
            let glyphSize: Double
            let tileToTitle: Double
            let titleToText: Double
            let topPadding: Double
            let horizontalPadding: Double
            let maxWidth: Double
        }

        /// The board: the gap between columns, its paddings, and whether it snaps; a column's width, corners, padding,
        /// cards' gap, header and drop ring; a card's corners, ring and row.
        struct Board {
            let spacing: Double
            let horizontalPadding: Double
            let bottomPadding: Double
            let snaps: Bool
            let columnWidth: Double
            let columnCornerRadius: Double
            let columnPadding: Double
            let cardSpacing: Double
            let dropRingWidth: Double
            let header: BlockHeader
            let cardCornerRadius: Double
            let cardRingWidth: Double
            let card: Row
        }

        /// The blocks' numbers in the layout: the list's header, its chevron and its row, or the board's.
        enum Blocks {
            case list(header: BlockHeader, chevron: Chevron, row: Row)
            case columns(Board)
        }

        let header: Header
        let tagBar: TagBar
        let empty: Empty
        let blocks: Blocks

        /// The numbers of the layout.
        static func of(_ layout: Model.Layout.Kind) -> Metrics {
            switch layout {
            case .list: phone
            case .columns: phoneColumns
            }
        }

        /// The phone's list (Task 8's table): the header, the tag bar and the empty state the board shares; a block's
        /// header 44 high, 6 6 2 12 from what stands round it, padded 13 8 0, its date 8 after its title, over the
        /// line's 1 pt rule, its chevron 18 in a 44 hit; a row 8 in and 12 short of the edges, its check 24 across with
        /// a 1.75 ring and the 15 pt mark stroked 1.75 in a 44 hit, its title the row title padded 11 above and below,
        /// 2 after the check's hit and 4 short of the end, the meta 3 under it, its items 10 apart and its lines 3, its
        /// glyphs 13 and 3 before their text, at least 44 high. The table gives the row no radius: 12, the add row's
        /// under it, until Task 8's hand check tunes it.
        static let phone = Metrics(
            header: phoneHeader, tagBar: phoneTagBar, empty: phoneEmpty,
            blocks: .list(
                header: BlockHeader(
                    height: 44, topMargin: 6, trailingMargin: 6, bottomMargin: 2, leadingMargin: 12, topPadding: 13,
                    horizontalPadding: 8, bottomPadding: 0, titleToSubtitle: 8,
                    rule: StrokeModel(color: .line, width: 1, dash: [])
                ),
                chevron: Chevron(size: 18, hitSide: 44),
                row: Row(
                    leading: 8, trailing: 12, checkDiameter: 24, checkRingWidth: 1.75, markSize: 15,
                    markStrokeWidth: 1.75, checkHitWidth: 44, checkHitHeight: 44, title: .rowTitle, verticalPadding: 11,
                    titleLeading: 2, titleTrailing: 4, titleToMeta: 3, metaSpacing: 10, metaLineSpacing: 3,
                    metaIconSize: 13, metaIconSpacing: 3, minimumHeight: 44, cornerRadius: 12
                )
            )
        )

        /// The phone's board (Task 8's table, Board; the controller's ruling on #175, 2026-11-04): 10 between columns,
        /// 16 in at its sides and 24 at its bottom, snapping; a column 296 wide and rounded 18, its header padded 13 14
        /// 9 with no rule and no chevron, its drop ring 2; a card rounded 13 with a 0.5 hairline, its check 22 across
        /// in a 42 by 44 hit, its title callout-sized. The table gives a column's padding and cards' gap neither: the
        /// cards are 8 apart (`task-4-canvas.md`, "column body gap 8") and 8 in; a column's header no height: a block's
        /// 44; a card's row the row's numbers but its check, its title and its edges: 0 in, the check's hit at its
        /// edge, 12 short of its end, rounded as the card. The card's check keeps the row's ring and mark, the canvas
        /// resizing only its circle.
        static let phoneColumns = Metrics(
            header: phoneHeader, tagBar: phoneTagBar, empty: phoneEmpty,
            blocks: .columns(Board(
                spacing: 10, horizontalPadding: 16, bottomPadding: 24, snaps: true, columnWidth: 296,
                columnCornerRadius: 18, columnPadding: 8, cardSpacing: 8, dropRingWidth: 2,
                header: BlockHeader(
                    height: 44, topMargin: 0, trailingMargin: 0, bottomMargin: 0, leadingMargin: 0, topPadding: 13,
                    horizontalPadding: 14, bottomPadding: 9, titleToSubtitle: 8, rule: nil
                ),
                cardCornerRadius: 13, cardRingWidth: 0.5,
                card: Row(
                    leading: 0, trailing: 12, checkDiameter: 22, checkRingWidth: 1.75, markSize: 15,
                    markStrokeWidth: 1.75, checkHitWidth: 42, checkHitHeight: 44, title: .nestedRowTitle,
                    verticalPadding: 11, titleLeading: 2, titleTrailing: 4, titleToMeta: 3, metaSpacing: 10,
                    metaLineSpacing: 3, metaIconSize: 13, metaIconSpacing: 3, minimumHeight: 44, cornerRadius: 13
                )
            ))
        )

        /// The phone's header (Task 8's table, Header): the tile 38 across, rounded 11, its glyph 23, 12 before the
        /// title (`task-4-canvas.md`, "gap 12"), the subtitle 6 under it and 50 in.
        private static let phoneHeader = Header(
            tileSide: 38, tileCornerRadius: 11, glyphSize: 23, spacing: 12, titleToSubtitle: 6, subtitleLeading: 50
        )

        /// The phone's tag bar (Task 8's table, Tag bar): chips 6 apart in a row padded 20, the bar 20 past the
        /// content's sides, fading in over 16 and out over 28; a chip 30 high, a capsule, padded 10 and 12, its hash 13
        /// and 5 before its title, in a 44 tap area.
        private static let phoneTagBar = TagBar(
            spacing: 6, padding: 20, fadeIn: 16, fadeOut: 28, margin: -20, chipHeight: 30, chipLeadingPadding: 10,
            chipTrailingPadding: 12, chipSpacing: 5, chipHitHeight: 44, hashSize: 13
        )

        /// The phone's empty state (Task 8's table, Empty state): the tile 64 across, rounded 18, its glyph 32, the
        /// title 18 under it and the line 6 under that, 84 from the top, 40 in, and 270 wide at most.
        private static let phoneEmpty = Empty(
            tileSide: 64, tileCornerRadius: 18, glyphSize: 32, tileToTitle: 18, titleToText: 6, topPadding: 84,
            horizontalPadding: 40, maxWidth: 270
        )
    }
}
