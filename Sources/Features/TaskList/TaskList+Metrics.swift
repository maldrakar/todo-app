// Sources/Features/TaskList/TaskList+Metrics.swift
import DesignSystem
import DesignSystemComponents

extension TaskList {
    /// The numbers the screen's components are drawn with in one layout, in points, and the colours and motions that go
    /// with them, picked once by the layout (`of(_:)`), so that no builder branches on it: the phone's list (`phone`)
    /// and the phone's board (`phoneColumns`), which share the header, the tag bar, the empty state and the floating
    /// "+" and differ in their blocks, their "+ Add list" and the Done strip, which only the list has. A component's
    /// values are its style, `CheckStyle` for `CheckModel` and so on (`DesignSystemComponents`), declared here once per
    /// layout and handed to its model whole; an entry that depends on the row is a function of what it depends on, the
    /// list's colour or whether the task is open, which a builder calls for that row's instance; a struct of this
    /// type's own stays only for a number that feeds a model nested in a component, such as a glyph's size, which the
    /// component's style cannot hand over.
    struct Metrics {
        /// A tile's side, its corners and the size of its glyph: the tile's own numbers, beside which its colour and
        /// which glyph it draws are the list's.
        struct TileSize {
            let side: Double
            let cornerRadius: Double
            let glyphSize: Double
        }

        /// The screen's header: its own numbers and its tile.
        struct Header {
            let style: ScreenHeaderStyle
            let tile: TileSize
        }

        /// The tag bar and its chips: the bar's style, a chip's for the list's colour and whether it is lit, and the
        /// size of the chip's hash.
        struct TagBar {
            let style: TagBarStyle
            let chip: @Sendable (Tile, _ isLit: Bool) -> TagChipStyle
            let hashSize: Double
        }

        /// A task's row, or a column's card: its style for whether the task is open, whether it can be lifted, which it
        /// can where it has a menu, and whether it is the task just dropped; its check's for the block's colour, the
        /// title's font, the meta line's glyph and its gap to its text; its swipe, nil for a column's card, which has
        /// none (canvas); and the mark of a drop's place among such rows for the block's colour, nil for a column's
        /// card, whose column's tint marks the drop.
        struct Row {
            let style: @Sendable (_ isOpen: Bool, _ lifts: Bool, _ isFresh: Bool) -> TaskRowStyle
            let check: @Sendable (Tile) -> CheckStyle
            let title: DesignSystem.Font
            let metaIconSize: Double
            let metaIconSpacing: Double
            let swipe: SwipeStyle?
            let indicator: (@Sendable (Tile) -> DropIndicatorStyle)?
        }

        /// A pill of the open card: its numbers and the sizes of its glyphs, the sun's, the flag's and the hash's.
        struct Pill {
            let style: PillStyle
            let sunSize: Double
            let flagSize: Double
            let hashSize: Double
        }

        /// A row that adds: its numbers, its glyph's size and its title's font.
        struct AddRow {
            let style: AddRowStyle
            let iconSize: Double
            let font: DesignSystem.Font
        }

        /// The open card: its style, its subtask draft's circle in the block's colour and its title's line where the
        /// task is not open; its check's and its subtasks' for the block's colour, and a subtask row's for whether the
        /// subtask is open; its title field's height and padding, the size of the button that opens it full screen, the
        /// notes' height and the subtask field's; and the row that adds a subtask and its pills.
        struct Card {
            let style: @Sendable (_ color: Tile, _ isOpen: Bool) -> CardStyle
            let check: @Sendable (Tile) -> CheckStyle
            let subtaskCheck: @Sendable (Tile) -> CheckStyle
            let subtask: @Sendable (_ isOpen: Bool) -> SubtaskRowStyle
            let titleHeight: Double
            let titlePadding: Double
            let expandSize: Double
            let notesHeight: Double
            let subtaskFieldHeight: Double
            let addSubtask: AddRow
            let pill: Pill
        }

        /// The Done strip's capsule: its numbers and its glyph's and chevron's sizes. The row and the card drawn under
        /// it are the list's.
        struct DoneStrip {
            let style: DoneStripStyle
            let iconSize: Double
            let chevronSize: Double
        }

        /// The floating "+": the circle's numbers and its glyph's size.
        struct FloatingButton {
            let style: FloatingButtonStyle
            let glyphSize: Double
        }

        /// The glass buttons over the content: the back button's numbers and glyph and "…"'s.
        struct Glass {
            let back: GlassControlStyle
            let backGlyphSize: Double
            let more: GlassControlStyle
            let moreGlyphSize: Double
        }

        /// The empty state: its numbers and its tile.
        struct Empty {
            let style: EmptyScreenStyle
            let tile: TileSize
        }

        /// The board: the gap between columns, its paddings, and whether it snaps, which `Model.Board` holds as they
        /// are, the board being no component; a column's style for the block's colour; a column's header; a card's row,
        /// and the card it opens into; and "+ Add task".
        struct Board {
            let spacing: Double
            let horizontalPadding: Double
            let endRoom: Double
            let bottomPadding: Double
            let snaps: Bool
            let column: @Sendable (Tile) -> ColumnStyle
            let header: BlockHeaderStyle
            let card: Row
            let openCard: Card
            let addTask: AddRow
        }

        /// The blocks' values in the layout: the list's header, its chevron's size, its row, its open card, its "+ Add
        /// task" and its Done strip, or the board's, which has no strip (canvas). Indirect, as the layout's whole
        /// values are some 1,400 to 1,500 bytes on wasm32, which a debug build would put on the stack at every copy of
        /// `Metrics`.
        indirect enum Blocks {
            case list(
                header: BlockHeaderStyle, chevronSize: Double, row: Row, card: Card, addTask: AddRow,
                doneStrip: DoneStrip
            )
            case columns(Board)
        }

        let style: ListScreenStyle
        let glass: Glass
        let header: Header
        let tagBar: TagBar
        let empty: Empty
        let blocks: Blocks
        let addList: AddRow
        let floatingButton: FloatingButton

        /// The numbers of the layout.
        static func of(_ layout: Model.Layout.Kind) -> Metrics {
            switch layout {
            case .list: phone
            case .columns: phoneColumns
            }
        }

        /// The phone's list (Task 8's table): the header, the tag bar, the empty state and the floating "+" the board
        /// shares; a block's header 44 high, 6 6 2 12 from what stands round it, padded 13 8 0, its date 8 after its
        /// title, over the line's 1 pt rule, its chevron 18 in a 44 hit; the row and the open card below; "+ Add task"
        /// 40 high, 8 in and 12 short of the edges, its plus 18 in a 44 cell with its title right after it and 12 short
        /// of its end, rounded 12; "+ Add list" 44 high over the line's 1 pt rule with 4 under it, 10 under what stands
        /// above and 12 in and 6 short of the edges, its plus 18 in a 40 cell; the Done strip's capsule 36 high and 20
        /// under what stands above, 14 in and 16 short of the edges, its glyph 18 and 10 in, its chevron 15 and 14
        /// short of its end, 8 on either side of its label, its rows 6 under it, coming in from nothing, .92 of their
        /// size about a fifth along their top and 8 above where they rest, over the popover's motion (`Phone.dc.html`,
        /// `popIn`); its words growing to 1.22 by 40 % of the check's motion as they change (`bumpA`, on the check's
        /// own curve and .45 s).
        static let phone = Metrics(
            style: phoneStyle(fade: phoneFade), glass: phoneGlass, header: phoneHeader(bottomMargin: 10),
            tagBar: phoneTagBar, empty: phoneEmpty,
            blocks: .list(
                header: .init(
                    titleToSubtitle: 8, rule: LineStyle(color: .line, width: 1, dash: []), height: 44, topMargin: 6,
                    trailingMargin: 6, bottomMargin: 2, leadingMargin: 12, topPadding: 13, horizontalPadding: 8,
                    bottomPadding: 0, cornerRadius: 0, foldHitSide: 44
                ),
                chevronSize: 18, row: phoneRow, card: phoneCard,
                addTask: AddRow(
                    style: .init(
                        iconCellWidth: 44, spacing: 0, height: 40, width: nil, cornerRadius: 12, topPadding: 0,
                        leadingPadding: 0, trailingPadding: 12, dash: nil, rule: nil, topMargin: 0, leadingMargin: 8,
                        trailingMargin: 12
                    ),
                    iconSize: 18, font: .addRow
                ),
                doneStrip: DoneStrip(
                    style: .init(
                        height: 36, cornerRadius: 18, spacing: 8, leadingPadding: 10, trailingPadding: 14,
                        topMargin: 20, leadingMargin: 14, trailingMargin: 16, background: .fill, capsuleToRows: 6,
                        rowsEntrance: EntranceStyle(
                            opacity: 0, scale: 0.92, offset: -8, anchorX: 0.2, anchorY: 0, animation: .popover
                        ),
                        bump: .init(scale: 1.22, peakAt: 0.4, animation: .check)
                    ),
                    iconSize: 18, chevronSize: 15
                )
            ),
            addList: AddRow(
                style: .init(
                    iconCellWidth: 40, spacing: 0, height: 44, width: nil, cornerRadius: 12, topPadding: 4,
                    leadingPadding: 0, trailingPadding: 12, dash: nil,
                    rule: LineStyle(color: .line, width: 1, dash: []), topMargin: 10, leadingMargin: 12,
                    trailingMargin: 6
                ),
                iconSize: 18, font: .barLabel
            ),
            floatingButton: phoneFloatingButton
        )

        /// The phone's board (Task 8's table, Board; the controller's ruling on #175, 2026-11-04): 10 between columns,
        /// 16 in at its sides, 16 more after its last column (`Phone.dc.html`, the gap and `.board::after`) and 24 at
        /// its bottom, snapping; a column 296 wide and rounded 18, its header padded 13 14 9 with no rule and no
        /// chevron, its drop ring 2; a card rounded 13 with a 0.5 hairline, its check 22 across in a 42 by 44 hit, its
        /// title callout-sized. The table gives a column's padding and cards' gap neither: the cards are 8 apart
        /// (`task-4-canvas.md`, "column body gap 8") and 8 in; a column's header no height: a block's 44; a card's row
        /// the row's numbers but its check, its title and its edges: 0 in, the check's hit at its edge, 12 short of its
        /// end, rounded as the card. The card's check keeps the row's ring and mark, the canvas resizing only its
        /// circle, and it has the menu and no swipe. Its open card fills the card, its own corners and resting shadow,
        /// its check the row's, its body 44 in and 12 short of its end and bottom (`Phone.dc.html`, the column's card).
        /// "+ Add task" 44 high, rounded 13, padded 11 and 12, the plus 18 and 6 before its title; "+ Add list" a
        /// column 200 wide edged in a 1.5 dashed line, as rounded as a column, 52 high, padded 16, the plus 18 and 8
        /// before its title. The table gives the dash no lengths: 5 and 4, the sidebar's dashed line.
        static let phoneColumns = Metrics(
            style: phoneStyle(fade: nil), glass: phoneGlass, header: phoneHeader(bottomMargin: 12),
            tagBar: phoneTagBar, empty: phoneEmpty,
            blocks: .columns(Board(
                spacing: 10, horizontalPadding: 16, endRoom: 16, bottomPadding: 24, snaps: true,
                column: { color in
                    .init(
                        width: 296, cornerRadius: 18, cardSpacing: 8, padding: 8, cardCornerRadius: 13,
                        cardRing: LineStyle(color: .glassLine, width: 0.5, dash: []), fill: .fill,
                        cardBackground: .surface, cardShadow: .resting, dropRingWidth: 2, dropTint: color.dropTint,
                        dropRing: color.check.fill, dropAnimation: .dropHighlights
                    )
                },
                header: .init(
                    titleToSubtitle: 8, rule: nil, height: 44, topMargin: 0, trailingMargin: 0, bottomMargin: 0,
                    leadingMargin: 0, topPadding: 13, horizontalPadding: 14, bottomPadding: 9, cornerRadius: 0,
                    foldHitSide: nil
                ),
                card: Row(
                    style: { isOpen, lifts, isFresh in
                        .init(
                            titleToMeta: 3, metaSpacing: 10, metaLineSpacing: 3, verticalPadding: 11, titleLeading: 2,
                            titleTrailing: 4, leading: 0, trailing: 12, minimumHeight: 44, cornerRadius: 13,
                            strike: isOpen ? nil : .ink3, lift: lifts ? columnLift : nil, fresh: nil,
                            landingScale: isFresh ? 1.05 : nil, landingAnimation: .drop, titleAnimation: .titleFades,
                            leaving: taskLeaving, ground: nil
                        )
                    },
                    check: { color in
                        .init(
                            diameter: 22, ringWidth: 1.75, markSize: 15, markStrokeWidth: 1.75, hitWidth: 42,
                            hitHeight: 44, animation: .check, fillAnimation: .checkFills,
                            markAnimation: .checkMarkDraws, pop: checkPop, mark: checkMark, colors: color.check
                        )
                    },
                    title: .nestedRowTitle, metaIconSize: 13, metaIconSpacing: 3, swipe: nil, indicator: nil
                ),
                openCard: Card(
                    style: { color, isOpen in
                        .init(
                            expandHitSide: 44, cornerRadius: 13, topMargin: 0, horizontalMargin: 0, bottomMargin: 0,
                            bodyLeading: 44, bodyTrailing: 12, bodyBottom: 12, subtasksToPills: 10, pillSpacing: 6,
                            shadow: .resting, background: .surface, entrance: cardEntrance, subtasksOutdent: 12,
                            titleToNotes: 2, notesToSubtasks: 4, subtaskDraftCircle: phoneSubtaskCheck(color),
                            leaving: taskLeaving, titleStrike: isOpen ? nil : .ink3
                        )
                    },
                    check: phoneCheck, subtaskCheck: phoneSubtaskCheck, subtask: phoneSubtask, titleHeight: 44,
                    titlePadding: 2, expandSize: 19, notesHeight: 22, subtaskFieldHeight: 40,
                    addSubtask: phoneAddSubtask, pill: phonePill
                ),
                addTask: AddRow(
                    style: .init(
                        iconCellWidth: 18, spacing: 6, height: 44, width: nil, cornerRadius: 13, topPadding: 0,
                        leadingPadding: 11, trailingPadding: 12, dash: nil, rule: nil, topMargin: 0, leadingMargin: 0,
                        trailingMargin: 0
                    ),
                    iconSize: 18, font: .addRow
                )
            )),
            addList: AddRow(
                style: .init(
                    iconCellWidth: 18, spacing: 8, height: 52, width: 200, cornerRadius: 18, topPadding: 0,
                    leadingPadding: 16, trailingPadding: 16,
                    dash: LineStyle(color: .line, width: 1.5, dash: [5, 4]), rule: nil, topMargin: 0,
                    leadingMargin: 0, trailingMargin: 0
                ),
                iconSize: 18, font: .barLabel
            ),
            floatingButton: phoneFloatingButton
        )

        /// How every check of the phone pops (`Phone.dc.html`, `cbPop`): down to .8 by 35 % of its motion, up to 1.14
        /// by 70 %.
        private static let checkPop = CheckStyle.Pop(dipScale: 0.8, dipAt: 0.35, peakScale: 1.14, peakAt: 0.7)

        /// The tick of every check of the phone, `M6.5 12.5l3.5 3.5 7.5-8` in the canvas's 24-unit box, its ends and its
        /// corner round (`Phone.dc.html`, `.cb`, its `stroke-linecap` and `stroke-linejoin`).
        private static let checkMark = CheckStyle.Mark(
            box: 24, points: [.init(x: 6.5, y: 12.5), .init(x: 10, y: 16), .init(x: 17.5, y: 8)], isRound: true
        )

        /// How a phone's row, a column's card or an open card leaves as its task is completed (`Phone.dc.html`,
        /// `.tt-done` and `.row-leave`): its title in ink 2 and struck in ink 3, sinking 12 as it fades on the row's
        /// motion, and on the same motion with no wait where it was deleted.
        private static let taskLeaving = TaskLeavingStyle(
            titleColor: .ink2, strike: .ink3, offset: 12, animation: .rowLeaves, deleteAnimation: .rowDeleted
        )

        /// A check of the phone's row and of its open card: 24 across with a 1.75 ring and the 15 pt mark stroked 1.75
        /// in a 44 hit (Task 8's table, Row).
        private static func phoneCheck(_ color: Tile) -> CheckStyle {
            CheckStyle(
                diameter: 24, ringWidth: 1.75, markSize: 15, markStrokeWidth: 1.75, hitWidth: 44, hitHeight: 44,
                animation: .check, fillAnimation: .checkFills, markAnimation: .checkMarkDraws, pop: checkPop,
                mark: checkMark, colors: color.check
            )
        }

        /// A subtask's check in the open card: 18 across with a 1.5 ring and the 12 pt mark in a 40 by 44 hit (Task 8's
        /// table, Card), the canvas's 2.8 in its 24-unit box stroked 1.4 at that size (`CheckStyle.markStrokeWidth`).
        private static func phoneSubtaskCheck(_ color: Tile) -> CheckStyle {
            CheckStyle(
                diameter: 18, ringWidth: 1.5, markSize: 12, markStrokeWidth: 1.4, hitWidth: 40, hitHeight: 44,
                animation: .check, fillAnimation: .checkFills, markAnimation: .checkMarkDraws, pop: checkPop,
                mark: checkMark, colors: color.check
            )
        }

        /// A subtask in the phone's open card, 44 high and struck in ink 3 where it is no longer open (Task 8's table,
        /// Card; canvas).
        private static func phoneSubtask(isOpen: Bool) -> SubtaskRowStyle {
            SubtaskRowStyle(height: 44, strike: isOpen ? nil : .ink3, titleAnimation: .titleFades)
        }

        /// The phone's row (Task 8's table, Row and Swipe): 8 in and 12 short of the edges, its check `phoneCheck`, its
        /// title the row title padded 11 above and below, 2 after the check's hit and 4 short of the end, the meta 3
        /// under it, its items 10 apart and its lines 3, its glyphs 13 and 3 before their text, at least 44 high;
        /// dragged 40 leftward it stays moved 88, over a Delete 78 wide, 3 in from its top and bottom and 10 from its
        /// end, rounded 12. The table gives the row no radius: 12, the add row's under it, until Task 8's hand check
        /// tunes it. It stands on the paper, the screen's ground.
        private static let phoneRow = Row(
            style: { isOpen, lifts, isFresh in
                .init(
                    titleToMeta: 3, metaSpacing: 10, metaLineSpacing: 3, verticalPadding: 11, titleLeading: 2,
                    titleTrailing: 4, leading: 8, trailing: 12, minimumHeight: 44, cornerRadius: 12,
                    strike: isOpen ? nil : .ink3, lift: lifts ? phoneLift : nil, fresh: isFresh ? .fresh : nil,
                    landingScale: nil, landingAnimation: .fresh, titleAnimation: .titleFades, leaving: taskLeaving,
                    ground: .paper
                )
            },
            check: phoneCheck, title: .rowTitle, metaIconSize: 13, metaIconSpacing: 3,
            swipe: .init(
                threshold: 40, shift: -88, buttonWidth: 78, buttonVerticalInset: 3, buttonTrailingInset: 10,
                buttonCornerRadius: 12, background: .red, animation: .swipe
            ),
            indicator: phoneDropMark
        )

        /// The phone's open card (Task 8's table, Card; `Phone.dc.html`, the open card): 6 10 10 from what stands round
        /// it, rounded 18, casting the raised shadow; its check `phoneCheck`, its title field 44 high and padded 2, the
        /// canvas's 2 before and 4 after in one padding; Open full screen 19 in a 44 hit; its body 46 in and 14 short
        /// of its end and bottom; the notes 2 under the top row; the subtasks 4 under the notes and 12 outside the
        /// body's leading edge, one 44 high, its field 40 after a ring-only circle of the subtask check's size; the
        /// pills 6 apart and 10 under the subtasks. The table gives the notes no height: 22, their 15 pt line at the
        /// canvas's 1.45, the least a field grows from.
        private static let phoneCard = Card(
            style: { color, isOpen in
                .init(
                    expandHitSide: 44, cornerRadius: 18, topMargin: 6, horizontalMargin: 10, bottomMargin: 10,
                    bodyLeading: 46, bodyTrailing: 14, bodyBottom: 14, subtasksToPills: 10, pillSpacing: 6,
                    shadow: .raised, background: .surface, entrance: cardEntrance, subtasksOutdent: 12,
                    titleToNotes: 2, notesToSubtasks: 4, subtaskDraftCircle: phoneSubtaskCheck(color),
                    leaving: taskLeaving, titleStrike: isOpen ? nil : .ink3
                )
            },
            check: phoneCheck, subtaskCheck: phoneSubtaskCheck, subtask: phoneSubtask, titleHeight: 44,
            titlePadding: 2, expandSize: 19, notesHeight: 22, subtaskFieldHeight: 40, addSubtask: phoneAddSubtask,
            pill: phonePill
        )

        /// How an open card comes in (`Phone.dc.html`, `xIn`): from .3 opaque, .97 of its size and 4 above where it
        /// rests, over the card's motion.
        private static let cardEntrance = EntranceStyle(
            opacity: 0.3, scale: 0.97, offset: -4, anchorX: 0.5, anchorY: 0.5, animation: .cardOpens
        )

        /// "Add subtask" in the phone's card (`Phone.dc.html`, the open card): 44 high, its plus 17 in a 40 cell under
        /// the subtasks' checks, 12 outside the body's leading edge as they are, its title right after it and 12 short
        /// of its end, rounded 12.
        private static let phoneAddSubtask = AddRow(
            style: .init(
                iconCellWidth: 40, spacing: 0, height: 44, width: nil, cornerRadius: 12, topPadding: 0,
                leadingPadding: 0, trailingPadding: 12, dash: nil, rule: nil, topMargin: 0, leadingMargin: -12,
                trailingMargin: 0
            ),
            iconSize: 17, font: .notes
        )

        /// The phone's pill (Task 8's table, Card; `Phone.dc.html`, `.xpill`): 32 high, a capsule, padded 10 and 12,
        /// its glyph 6 before its text, the sun 16, the flag 15, the hash 14.
        private static let phonePill = Pill(
            style: .init(
                height: 32, cornerRadius: 16, leadingPadding: 10, trailingPadding: 12, spacing: 6, background: .fill
            ),
            sunSize: 16, flagSize: 15, hashSize: 14
        )

        /// How the phone's row looks lifted (Task 8's table, Lift and slot): grown to 1.03, rounded 14 on the surface
        /// and casting the lifted shadow, and dimmed to .35 where it is dragged from, the column's card's value, as the
        /// system's copy of it moves (the controller's ruling on #177, 2026-11-07).
        private static let phoneLift = TaskLiftStyle(
            scale: 1.03, opacity: 0.35, cornerRadius: 14, background: .surface, shadow: .lifted,
            dimAnimation: .dropHighlights
        )

        /// The mark of a drop's place among the phone's rows (Task 8's table, Lift and slot), 10 high, placed from the
        /// rows' leading edge: the circle 8 across at 52, ringed 2 in the list's check fill and filled with the paper,
        /// which stands in for the canvas's unfilled dot since the mark stands on the screen's paper, and the line 2
        /// thick in the check fill, rounded 1, from 62 to 20 short of the right edge.
        private static let phoneDropMark: @Sendable (Tile) -> DropIndicatorStyle = { color in
            DropIndicatorStyle(
                height: 10, line: LineStyle(color: color.check.fill, width: 2, dash: []), lineOffset: 62,
                lineCornerRadius: 1, trailingGap: 20, circleDiameter: 8, circleOffset: 52,
                circleRing: LineStyle(color: color.check.fill, width: 2, dash: []), circleFill: .paper
            )
        }

        /// How a column's card looks lifted (Task 8's table, Lift and slot): the row's, but for its corners, the card's
        /// own 13, which the table gives the card no other number for. Its column's tint marks the drop.
        private static let columnLift = TaskLiftStyle(
            scale: 1.03, opacity: 0.35, cornerRadius: 13, background: .surface, shadow: .lifted,
            dimAnimation: .dropHighlights
        )

        /// The phone's glass buttons (Task 8's table, Glass buttons; `Phone.dc.html`, `.glass` and the buttons' row):
        /// 44 circles on the glass, edged with its 0.5 hairline and casting the raised shadow; the back chevron 24
        /// across set 2 left of centre, "…" 22.
        private static let phoneGlass = Glass(
            back: GlassControlStyle(
                iconOffset: -2, diameter: 44, surface: .glass,
                line: LineStyle(color: .glassLine, width: 0.5, dash: []), shadow: .raised
            ),
            backGlyphSize: 24,
            more: GlassControlStyle(
                iconOffset: 0, diameter: 44, surface: .glass,
                line: LineStyle(color: .glassLine, width: 0.5, dash: []), shadow: .raised
            ),
            moreGlyphSize: 22
        )

        /// The phone's screen (Task 8's table, Glass buttons; `Phone.dc.html`, the buttons' row and the scroller): the
        /// circles 14 from the screen's sides; under them a fade of the paper that is the canvas's 108 less its 54
        /// status bar, solid to 64 % of the 108, with the content 56 under the safe area's top and ending 116 above the
        /// safe area's bottom, the canvas's 150 less the home indicator's 34; on the board the fade is `nil`, its
        /// buttons standing in the flow; all of it on the paper.
        private static func phoneStyle(fade: ListScreenStyle.Fade?) -> ListScreenStyle {
            ListScreenStyle(edgeInset: 14, fade: fade, contentTop: 56, contentBottom: 116, background: .paper)
        }

        /// The list's fade (see `phoneStyle`); the board has none.
        private static let phoneFade = ListScreenStyle.Fade(color: .paper, height: 54, solidDepth: 15.12)

        /// The phone's floating "+" (Task 8's table, Floating "+"): a 48 circle, its plus 22, 16 in from the screen's
        /// right edge and 30 above its bottom.
        private static let phoneFloatingButton = FloatingButton(
            style: .init(diameter: 48, fill: .accent, shadow: .raised, trailingMargin: 16, bottomMargin: 30),
            glyphSize: 22
        )

        /// The phone's header (Task 8's table, Header): 20 in from the screen's sides, the tile 38 across, rounded 11,
        /// its glyph 23, 12 before the title (`task-4-canvas.md`, "gap 12"), the subtitle 6 under it and 50 in; what
        /// follows it and the tag bar, the list's first block or the board, 10 under them in the list and 12 in the
        /// board (`Phone.dc.html`, the list's `margin-top:10px` and `.board`'s 12).
        private static func phoneHeader(bottomMargin: Double) -> Header {
            Header(
                style: .init(
                    horizontalPadding: 20, bottomMargin: bottomMargin, spacing: 12, titleToSubtitle: 6,
                    subtitleLeading: 50
                ),
                tile: TileSize(side: 38, cornerRadius: 11, glyphSize: 23)
            )
        }

        /// The phone's tag bar (Task 8's table, Tag bar): 7 under the header, chips 6 apart in a row padded 20 with 20
        /// more after the last (`Phone.dc.html`, the gap and `.tagbar::after`), the bar 20 past the content's sides,
        /// fading in over 16 and out over 28; a chip 30 high, a capsule, padded 10 and 12, its hash 13 and 5 before its
        /// title, in a 44 tap area.
        private static let phoneTagBar = TagBar(
            style: .init(
                topMargin: 7, spacing: 6, padding: 20, endRoom: 20, fadeIn: 16, fadeOut: 28, leadingMargin: -20,
                trailingMargin: -20
            ),
            chip: { color, isLit in
                .init(
                    height: 30, cornerRadius: 15, leadingPadding: 10, trailingPadding: 12, spacing: 5, hitHeight: 44,
                    background: isLit ? color.check.fill : .fill, animation: .chipToggles
                )
            },
            hashSize: 13
        )

        /// The phone's empty state (Task 8's table, Empty state): the tile 64 across, rounded 18, its glyph 32, the
        /// title 18 under it and the line 6 under that, 84 from the top, 40 in, and 270 wide at most.
        private static let phoneEmpty = Empty(
            style: .init(tileToTitle: 18, titleToText: 6, topPadding: 84, horizontalPadding: 40, maxWidth: 270),
            tile: TileSize(side: 64, cornerRadius: 18, glyphSize: 32)
        )
    }
}
