// Sources/Features/TaskList/TaskList+PaneMetrics.swift
import DesignSystem
import DesignSystemComponents

/// The Mac pane's numbers (list screen plan, Task 9's table; `Mac.dc.html`, which the table has already read), for a
/// wide window: the pane's list and the pane's board, the same shapes as the phone's two (`TaskList+Metrics.swift`) at
/// the Mac's sizes, with the glass "+" in the capsule where the phone has the floating one. The canvas predates the
/// brainstorm's boards, so what it does not draw, the swipe, the lift, "+ Add list" and the row's menu, takes the
/// phone's look at the pane's scale. The fonts are the phone's: a font of the look is a text style, which the Mac
/// draws smaller by itself.
extension TaskList.Metrics {
    private typealias Tile = DesignSystem.Color.Components.Tile

    /// The pane's list: the content 780 wide at most, centred, 62 under the top, 48 in at its sides and 140 above its
    /// foot, under a fade of the paper 60 high, solid to 33; the row of buttons 52 high, 14 in at its sides, 8 apart,
    /// the back button a 34 circle with its chevron 19 set 1 left of centre, and the capsule 34 high, rounded as far as
    /// it goes, padded 3, with its "+" 17 and its "…" 18 in 30 by 28 items on either side of a 1 by 16 divider; the
    /// header's tile 40 across, rounded 11, its glyph 24, the title 12 after it and the subtitle 6 under it and 52 in;
    /// the tag bar 10 under it, 40 in and 12 past the content's end, its chips 6 apart in a row padded 12 with 12 more
    /// after the last, fading in over 12 and out over 24, a chip 26 high, a capsule, padded 8 and 10, its hash 12 and 5
    /// before its title, in a 32 tap area; a block's header 34 high, 14 under what stands above, 2 above its rows and 4
    /// in, padded 9 6 0, rounded 7, 8 between its title and its date, over the line's 1 pt rule, its chevron 15 in a 30
    /// hit; "+ Add task" 32 high, rounded 8, padded 4 and 12, its plus 15 in a 32 cell; the Done strip's capsule 30
    /// high and 22 under what stands above, 6 in, its glyph 16 and 9 in, its chevron 13 and 12 short of its end, 7 on
    /// either side of its label, its rows 6 under it, coming in from nothing, .94 of their size about an eighth along
    /// their top and 6 above where they rest (`Mac.dc.html`, `popIn`); the empty state's tile 60 across, rounded 17,
    /// its glyph 30, the title 16 under it and the line 6 under that, 90 from the top, 40 in and 300 wide at most. The
    /// table gives "+ Add list" no numbers: the row 36 high with the line's 1 pt rule, its plus 15 in a 32 cell,
    /// rounded 9, 10 under what stands above and 4 in, the phone's at the pane's scale.
    static let pane = TaskList.Metrics(
        style: paneStyle(contentHorizontalPadding: 48, contentMaxWidth: 780), glass: paneGlass,
        header: paneHeader(horizontalPadding: 0, bottomMargin: 8), tagBar: paneTagBar, empty: paneEmpty,
        blocks: .list(
            header: .init(
                titleToSubtitle: 8, rule: LineStyle(color: .line, width: 1, dash: []), height: 34, topMargin: 14,
                trailingMargin: 0, bottomMargin: 2, leadingMargin: 4, topPadding: 9, horizontalPadding: 6,
                bottomPadding: 0, cornerRadius: 7, foldHitSide: 30
            ),
            chevronSize: 15, row: paneRow, card: paneCard,
            addTask: TaskList.Metrics.AddRow(
                style: .init(
                    iconCellWidth: 32, spacing: 0, height: 32, width: nil, cornerRadius: 8, topPadding: 0,
                    leadingPadding: 4, trailingPadding: 12, dash: nil, rule: nil, topMargin: 0, leadingMargin: 0,
                    trailingMargin: 0
                ),
                iconSize: 15, font: .addRow
            ),
            doneStrip: TaskList.Metrics.DoneStrip(
                style: .init(
                    height: 30, cornerRadius: 15, spacing: 7, leadingPadding: 9, trailingPadding: 12, topMargin: 22,
                    leadingMargin: 6, trailingMargin: 0, background: .fill, capsuleToRows: 6,
                    rowsEntrance: EntranceStyle(
                        opacity: 0, scale: 0.94, offset: -6, anchorX: 0.12, anchorY: 0, animation: .popover
                    ),
                    bump: .init(scale: 1.22, peakAt: 0.4, animation: .check)
                ),
                iconSize: 16, chevronSize: 13
            )
        ),
        addList: TaskList.Metrics.AddRow(
            style: .init(
                iconCellWidth: 32, spacing: 0, height: 36, width: nil, cornerRadius: 9, topPadding: 4,
                leadingPadding: 0, trailingPadding: 12, dash: nil, rule: LineStyle(color: .line, width: 1, dash: []),
                topMargin: 10, leadingMargin: 4, trailingMargin: 0
            ),
            iconSize: 15, font: .barLabel
        ),
        floatingButton: nil
    )

    /// The pane's board, which the pane shares the header, the tag bar, the empty state and the glass buttons with the
    /// list for, the header padded 28 in and 14 above the columns, and the buttons standing over it: 12 between
    /// columns, 24 in at its sides and at its bottom, 12 more after its last column, scrolling freely; a column 288
    /// wide and rounded 14, its header padded 11 12 7 (the column's own 6 stand under the 1 left to the header's
    /// bottom), its cards 6 apart and 6 in, each rounded 10 with a 0.5 hairline and the resting shadow, a hover shadow
    /// of 8 % with a blur of 10 dropped 3; a card's check 18 across with a 1.5 ring and the 12 pt mark in a 34 by 36
    /// hit, its title callout-sized, 9 above and below it and 10 short of its end, the meta 3 under it, its items 9
    /// apart and its lines 2, its glyphs 12 and 3 before their text, at least 36 high; its open card in the card, its
    /// check in a 34 by 40 hit, its body 36 in and 12 short of its end and bottom; "+ Add task" 32 high, rounded 9,
    /// padded 10, the plus 15 and 6 before its title. The table gives "+ Add list" nothing: a column 200 wide edged in
    /// a 1.5 dashed line, as rounded as a column, 44 high, padded 14, the plus 15 and 8 before its title, the phone's
    /// at the pane's scale. The table gives the column's header no height: 36, its padding and a line of its title.
    static let paneColumns = TaskList.Metrics(
        style: paneStyle(contentHorizontalPadding: 0, contentMaxWidth: nil), glass: paneGlass,
        header: paneHeader(horizontalPadding: 28, bottomMargin: 14), tagBar: paneTagBar, empty: paneEmpty,
        blocks: .columns(TaskList.Metrics.Board(
            spacing: 12, horizontalPadding: 24, endRoom: 12, bottomPadding: 24, snaps: false,
            column: { color in
                .init(
                    width: 288, cornerRadius: 14, cardSpacing: 6, padding: 6, cardCornerRadius: 10,
                    cardRing: LineStyle(color: .glassLine, width: 0.5, dash: []), fill: .fill,
                    cardBackground: .surface, cardShadow: .resting, cardHoverShadow: .hovered, dropRingWidth: 2,
                    dropTint: color.dropTint, dropRing: color.check.fill, dropAnimation: .dropHighlights
                )
            },
            header: .init(
                titleToSubtitle: 8, rule: nil, height: 36, topMargin: 0, trailingMargin: 0, bottomMargin: 0,
                leadingMargin: 0, topPadding: 11, horizontalPadding: 12, bottomPadding: 1, cornerRadius: 0,
                foldHitSide: nil
            ),
            card: TaskList.Metrics.Row(
                style: { isOpen, lifts, isFresh in
                    .init(
                        titleToMeta: 3, metaSpacing: 9, metaLineSpacing: 2, verticalPadding: 9, titleLeading: 0,
                        titleTrailing: 10, leading: 0, trailing: 0, minimumHeight: 36, cornerRadius: 10,
                        strike: isOpen ? nil : .ink3, lift: lifts ? taskLift(cornerRadius: 10) : nil, fresh: nil,
                        landingScale: isFresh ? 1.05 : nil, landingAnimation: .drop, titleAnimation: .titleFades,
                        leaving: taskLeaving, ground: nil, metaTrailing: false, hover: nil
                    )
                },
                check: { color in paneRowCheck(color, hitWidth: 34, hitHeight: 36) },
                title: .nestedRowTitle, metaIconSize: 12, metaIconSpacing: 3, tagCapsule: paneTagCapsule, swipe: nil,
                indicator: nil, dropStyle: nil
            ),
            openCard: paneOpenCard(
                cornerRadius: 10, margins: (top: 0, horizontal: 0, bottom: 0), shadow: .resting, bodyLeading: 36,
                bodyTrailing: 12, bodyBottom: 12, checkHitWidth: 34
            ),
            addTask: TaskList.Metrics.AddRow(
                style: .init(
                    iconCellWidth: 15, spacing: 6, height: 32, width: nil, cornerRadius: 9, topPadding: 0,
                    leadingPadding: 10, trailingPadding: 10, dash: nil, rule: nil, topMargin: 0, leadingMargin: 0,
                    trailingMargin: 0
                ),
                iconSize: 15, font: .addRow
            )
        )),
        addList: TaskList.Metrics.AddRow(
            style: .init(
                iconCellWidth: 15, spacing: 8, height: 44, width: 200, cornerRadius: 14, topPadding: 0,
                leadingPadding: 14, trailingPadding: 14, dash: LineStyle(color: .line, width: 1.5, dash: [5, 4]),
                rule: nil, topMargin: 0, leadingMargin: 0, trailingMargin: 0
            ),
            iconSize: 15, font: .barLabel
        ),
        floatingButton: nil
    )

    /// The pane's screen (Task 9's table, Pane; `Mac.dc.html`, the nav row and the scroller): the buttons' row 52 high
    /// and 14 in from the pane's sides, 8 apart, under a fade (`paneFade`), the content 62 under the top and ending
    /// 140 above the foot, all of it on the paper; the list's content is `contentMaxWidth` at most and
    /// `contentHorizontalPadding` in, and the board's the pane's width, its own paddings standing instead.
    private static func paneStyle(contentHorizontalPadding: Double, contentMaxWidth: Double?) -> ListScreenStyle {
        ListScreenStyle(
            edgeInset: 14, fade: paneFade, contentTop: 62, contentBottom: 140, background: .paper,
            contentHorizontalPadding: contentHorizontalPadding, contentMaxWidth: contentMaxWidth, barHeight: 52,
            barSpacing: 8,
            capsule: GlassCapsuleStyle(
                height: 34, cornerRadius: 99, horizontalPadding: 3, glass: paneGlassUnder,
                divider: LineStyle(color: .line, width: 1, dash: []), dividerHeight: 16
            )
        )
    }

    /// The pane's fade under the buttons' row, in both layouts (`Mac.dc.html`, the div at the pane's level above the
    /// list and the board; the controller's ruling R204): 60 high, the paper solid down to 55 % of it, 33, then clear.
    /// The pane has no safe area, so the depth is measured from its top.
    private static let paneFade = ListScreenStyle.Fade(color: .paper, height: 60, solidDepth: 33)

    /// The pane's glass buttons (Task 9's table, Pane): the back button a 34 circle on the glass with its chevron 19
    /// set 1 left of centre and stroked a little heavier than the phone's, and in the capsule the "+" 17, stroked
    /// heavier too, and the "…" 18, each in a 30 by 28 item. The back button stands on glass of its own; the items
    /// stand on the capsule's (`paneStyle`) and have none.
    private static let paneGlass = TaskList.Metrics.Glass(
        back: GlassControlStyle(
            iconOffset: -1, diameter: 34, height: 34, glass: paneGlassUnder
        ),
        backGlyphSize: 19, backGlyphWeight: .medium,
        more: paneCapsuleItem,
        moreGlyphSize: 18,
        add: TaskList.Metrics.GlassAdd(style: paneCapsuleItem, glyphSize: 17, glyphWeight: .medium)
    )

    private static let paneCapsuleItem = GlassControlStyle(iconOffset: 0, diameter: 30, height: 28, glass: nil)

    /// The glass of the pane: the canvas's `.glass`, its surface edged with a 0.5 hairline and casting the raised
    /// shadow (`Mac.dc.html`, the back button's and the capsule's), the back button's and the capsule's.
    private static let paneGlassUnder = GlassControlStyle.Glass(
        surface: .glass, line: LineStyle(color: .glassLine, width: 0.5, dash: []), shadow: .raised
    )

    /// The pane's header (Task 9's table, Header): the tile 40 across, rounded 11, its glyph 24, 12 before the title,
    /// the subtitle 6 under it and 52 in; padded as the list or the board says, and the first block or the board that
    /// far under it.
    private static func paneHeader(horizontalPadding: Double, bottomMargin: Double) -> TaskList.Metrics.Header {
        TaskList.Metrics.Header(
            style: .init(
                horizontalPadding: horizontalPadding, bottomMargin: bottomMargin, spacing: 12, titleToSubtitle: 6,
                subtitleLeading: 52
            ),
            tile: TaskList.Metrics.TileSize(side: 40, cornerRadius: 11, glyphSize: 24)
        )
    }

    /// The pane's tag bar (Task 9's table, Tag bar): 10 under the header and 40 in, so that its chips stand under the
    /// title, 12 past the content's end, its chips 6 apart in a row padded 12 with 12 more after the last, fading in
    /// over 12 and out over 24; a chip 26 high, a capsule, padded 8 and 10, its hash 12 and 5 before its title, in a 32
    /// tap area.
    private static let paneTagBar = TaskList.Metrics.TagBar(
        style: .init(
            topMargin: 10, spacing: 6, padding: 12, endRoom: 12, fadeIn: 12, fadeOut: 24, leadingMargin: 40,
            trailingMargin: -12
        ),
        chip: { color, isLit in
            .init(
                height: 26, cornerRadius: 13, leadingPadding: 8, trailingPadding: 10, spacing: 5, hitHeight: 32,
                background: isLit ? color.check.fill : .fill, animation: .chipToggles
            )
        },
        hashSize: 12
    )

    /// The pane's empty state (Task 9's table, Empty state): the tile 60 across, rounded 17, its glyph 30, the title 16
    /// under it and the line 6 under that, 90 from the top, 40 in, and 300 wide at most; 12 above a board's columns.
    private static let paneEmpty = TaskList.Metrics.Empty(
        style: .init(
            tileToTitle: 16, titleToText: 6, topPadding: 90, horizontalPadding: 40, maxWidth: 300, bottomMargin: 12
        ),
        tile: TaskList.Metrics.TileSize(side: 60, cornerRadius: 17, glyphSize: 30)
    )

    /// A tag in a row's or a card's meta line (Task 9's table, Row): a 20 high capsule of the fill, padded 8, with the
    /// tag's name and no hash.
    private static let paneTagCapsule = MetaItemStyle.Capsule(
        background: .fill, height: 20, cornerRadius: 10, leadingPadding: 8, trailingPadding: 8
    )

    /// A check of the pane's row, a column's card and the open card: 18 across with a 1.5 ring and the 12 pt mark in a
    /// hit as wide and as high as it says (Task 9's table, Row and Board).
    private static func paneRowCheck(_ color: Tile, hitWidth: Double, hitHeight: Double) -> CheckStyle {
        checkStyle(
            diameter: 18, ringWidth: 1.5, markSize: 12, markStrokeWidth: 1.4, hitWidth: hitWidth,
            hitHeight: hitHeight, color: color
        )
    }

    /// A subtask's check in the pane's open card: 15 across with a 1.5 ring and the 10 pt mark in a 30 hit (Task 9's
    /// table, Card), the canvas's 2.8 in its 24-unit box stroked 1.17 at that size.
    private static func paneSubtaskCheck(_ color: Tile) -> CheckStyle {
        checkStyle(
            diameter: 15, ringWidth: 1.5, markSize: 10, markStrokeWidth: 1.17, hitWidth: 30, hitHeight: 30,
            color: color
        )
    }

    /// The pane's row (Task 9's table, Row): 36 high, padded 0 10 0 4, rounded 9, tinted under the pointer, its check
    /// `paneRowCheck` in a 32 by 36 hit, its title 4 after the hit and one line, with the meta line on it 12 after the
    /// title, its items 8 apart, its glyphs 13 and 3 before their text, a tag on a 20 high capsule. The title is
    /// padded 9 above and below; the swipe is the phone's, which the iPad keeps, and the lift is the phone's at the
    /// row's scale, rounded 2 more than the row. The mark of a drop's place and the look of the block a task from
    /// another block would land in are the phone's at the pane's scale: the mark's circle at 36 across from the row's
    /// edge, after the check, its line from 46 to 10 short of the right edge; the block's ring rounded 14 and 4 in.
    private static let paneRow = TaskList.Metrics.Row(
        style: { isOpen, lifts, isFresh in
            .init(
                titleToMeta: 12, metaSpacing: 8, metaLineSpacing: 0, verticalPadding: 9, titleLeading: 4,
                titleTrailing: 0, leading: 4, trailing: 10, minimumHeight: 36, cornerRadius: 9,
                strike: isOpen ? nil : .ink3, lift: lifts ? taskLift(cornerRadius: 11) : nil,
                fresh: isFresh ? .fresh : nil, landingScale: nil, landingAnimation: .fresh,
                titleAnimation: .titleFades, leaving: taskLeaving, ground: .paper, metaTrailing: true,
                hover: .hover
            )
        },
        check: { color in paneRowCheck(color, hitWidth: 32, hitHeight: 36) },
        title: .rowTitle, metaIconSize: 13, metaIconSpacing: 3, tagCapsule: paneTagCapsule, swipe: swipe,
        indicator: paneDropMark, dropStyle: paneBlockDrop
    )

    private static let paneDropMark: @Sendable (Tile) -> DropIndicatorStyle = { color in
        DropIndicatorStyle(
            height: 10, line: LineStyle(color: color.check.fill, width: 2, dash: []), lineOffset: 46,
            lineCornerRadius: 1, trailingGap: 10, circleDiameter: 8, circleOffset: 36,
            circleRing: LineStyle(color: color.check.fill, width: 2, dash: []), circleFill: .paper
        )
    }

    private static let paneBlockDrop: @Sendable (Tile) -> BlockDropStyle = { color in
        BlockDropStyle(
            tint: color.dropTint, ring: color.check.fill, ringWidth: 2, cornerRadius: 14, inset: 4,
            animation: .dropHighlights
        )
    }

    /// The pane's open card in the list (Task 9's table, Card; `Mac.dc.html`, the open card): 6 above, 10 below,
    /// rounded 14 and casting the raised shadow.
    private static let paneCard = paneOpenCard(
        cornerRadius: 14, margins: (top: 6, horizontal: 0, bottom: 10), shadow: .raised, bodyLeading: 38,
        bodyTrailing: 14, bodyBottom: 14, checkHitWidth: 32
    )

    /// The open card of the pane, in the list or in a column (Task 9's table, Card and Board): its check 18 across in a
    /// hit of the width given and 40 high, its title field 40 high and padded 2, Open full screen 16 in a 30 hit, the
    /// notes 20 high, the subtasks 4 under them and 8 outside the body's leading edge, one 30 high with its check 15
    /// across and its field 30 high, "Add subtask" 30 high, rounded 7, its plus 14 in a 30 cell, 10 short of its end,
    /// the pills 6 apart and 8 under the subtasks, each 26 high, a capsule, padded 8 and 10, its glyph 5 before its
    /// text, the sun 14, the flag 13, the hash 12. The card comes in from .3 opaque, .98 of its size and 3 above where
    /// it rests (`Mac.dc.html`, `xIn`), over the card's motion.
    private static func paneOpenCard(
        cornerRadius: Double, margins: (top: Double, horizontal: Double, bottom: Double), shadow: DesignSystem.Shadow,
        bodyLeading: Double, bodyTrailing: Double, bodyBottom: Double, checkHitWidth: Double
    ) -> TaskList.Metrics.Card {
        TaskList.Metrics.Card(
            style: { color, isOpen in
                .init(
                    expandHitSide: 30, cornerRadius: cornerRadius, topMargin: margins.top,
                    horizontalMargin: margins.horizontal, bottomMargin: margins.bottom, bodyLeading: bodyLeading,
                    bodyTrailing: bodyTrailing, bodyBottom: bodyBottom, subtasksToPills: 8, pillSpacing: 6,
                    shadow: shadow, background: .surface,
                    entrance: EntranceStyle(
                        opacity: 0.3, scale: 0.98, offset: -3, anchorX: 0.5, anchorY: 0.5, animation: .cardOpens
                    ),
                    subtasksOutdent: 8, titleToNotes: 2, notesToSubtasks: 4,
                    subtaskDraftCircle: paneSubtaskCheck(color),
                    leaving: taskLeaving, titleStrike: isOpen ? nil : .ink3
                )
            },
            check: { color in paneRowCheck(color, hitWidth: checkHitWidth, hitHeight: 40) },
            subtaskCheck: paneSubtaskCheck,
            subtask: { isOpen in
                SubtaskRowStyle(height: 30, strike: isOpen ? nil : .ink3, titleAnimation: .titleFades)
            },
            titleHeight: 40, titlePadding: 2, expandSize: 16, notesHeight: 20, subtaskFieldHeight: 30,
            addSubtask: TaskList.Metrics.AddRow(
                style: .init(
                    iconCellWidth: 30, spacing: 0, height: 30, width: nil, cornerRadius: 7, topPadding: 0,
                    leadingPadding: 0, trailingPadding: 10, dash: nil, rule: nil, topMargin: 0, leadingMargin: -8,
                    trailingMargin: 0
                ),
                iconSize: 14, font: .notes
            ),
            pill: TaskList.Metrics.Pill(
                style: .init(
                    height: 26, cornerRadius: 13, leadingPadding: 8, trailingPadding: 10, spacing: 5,
                    background: .fill
                ),
                sunSize: 14, flagSize: 13, hashSize: 12
            )
        )
    }
}
