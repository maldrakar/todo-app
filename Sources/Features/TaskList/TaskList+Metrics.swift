// Sources/Features/TaskList/TaskList+Metrics.swift
import DesignSystem
import DesignSystemComponents

extension TaskList {
    /// The numbers the screen's components are drawn with in one layout, in points, picked once by the layout
    /// (`of(_:)`), so that no builder branches on it: the phone's list (`phone`) and the phone's board
    /// (`phoneColumns`), which share the header, the tag bar, the empty state and the floating "+" and differ in their
    /// blocks, their "+ Add list" and the Done strip, which only the list has.
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

        /// The chevron that folds a block in the list: its glyph's size and its square hit's side. A column's header
        /// has none, so the board carries none.
        struct Chevron {
            let size: Double
            let hitSide: Double
        }

        /// A check: the circle's side and ring, the mark's size and stroke, and its tap area.
        struct Check {
            let diameter: Double
            let ringWidth: Double
            let markSize: Double
            let markStrokeWidth: Double
            let hitWidth: Double
            let hitHeight: Double
        }

        /// A row's swipe to its Delete: how far it drags before it stays, how far it stays, and the button's width,
        /// insets and corners.
        struct Swipe {
            let threshold: Double
            let shift: Double
            let buttonWidth: Double
            let buttonVerticalInset: Double
            let buttonTrailingInset: Double
            let buttonCornerRadius: Double
        }

        /// A task's row, or a column's card: its insets, its check, the title's font and paddings, the meta line's gaps
        /// and glyphs, its least height, its corners and its swipe, nil for a column's card, which has none (canvas).
        struct Row {
            let leading: Double
            let trailing: Double
            let check: Check
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
            let swipe: Swipe?
        }

        /// A pill of the open card: its height, a capsule's, its paddings, the gap between its glyph and its text, and
        /// the sizes of its glyphs, the sun's, the flag's and the hash's.
        struct Pill {
            let height: Double
            let leadingPadding: Double
            let trailingPadding: Double
            let spacing: Double
            let sunSize: Double
            let flagSize: Double
            let hashSize: Double
        }

        /// The open card: its margins, corners and shadow; its check, its title field's height and padding, and the
        /// button that opens it full screen; its body's insets, the notes' height, the subtasks' check and height and
        /// their field's height, and the row that adds one; and its pills, their gap and their distance under the
        /// subtasks.
        struct Card {
            let topMargin: Double
            let horizontalMargin: Double
            let bottomMargin: Double
            let cornerRadius: Double
            let shadow: DesignSystem.Shadow
            let check: Check
            let titleHeight: Double
            let titlePadding: Double
            let expandSize: Double
            let expandHitSide: Double
            let bodyLeading: Double
            let bodyTrailing: Double
            let bodyBottom: Double
            let notesHeight: Double
            let subtaskCheck: Check
            let subtaskHeight: Double
            let subtaskFieldHeight: Double
            let addSubtask: AddRow
            let subtasksToPills: Double
            let pillSpacing: Double
            let pill: Pill
        }

        /// A row that adds: its glyph's size and cell, the gap to its title and the title's font, its height, its width
        /// where it has its own, its corners, its paddings, its dashed edge and its rule where it has them, and its
        /// margins.
        struct AddRow {
            let iconSize: Double
            let iconCellWidth: Double
            let spacing: Double
            let font: DesignSystem.Font
            let height: Double
            let width: Double?
            let cornerRadius: Double
            let topPadding: Double
            let leadingPadding: Double
            let trailingPadding: Double
            let dash: StrokeModel?
            let rule: StrokeModel?
            let topMargin: Double
            let leadingMargin: Double
            let trailingMargin: Double
        }

        /// The Done strip's capsule: its glyph, chevron, height, paddings, gap and margins. The row and the card drawn
        /// under it are the list's.
        struct DoneStrip {
            let iconSize: Double
            let chevronSize: Double
            let height: Double
            let spacing: Double
            let leadingPadding: Double
            let trailingPadding: Double
            let topMargin: Double
            let leadingMargin: Double
            let trailingMargin: Double
        }

        /// The floating "+": the circle's side and its glyph's.
        struct FloatingButton {
            let diameter: Double
            let glyphSize: Double
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
        /// cards' gap, header, drop ring and "+ Add task"; a card's corners, ring and row, and the card it opens into.
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
            let openCard: Card
            let addTask: AddRow
        }

        /// The blocks' numbers in the layout: the list's header, its chevron, its row, its open card, its "+ Add task" and
        /// its Done strip, or the board's, which has no strip (canvas). Indirect, as the layout's whole numbers are some
        /// 1,300 bytes on wasm32, which a debug build would put on the stack at every copy of `Metrics`.
        indirect enum Blocks {
            case list(header: BlockHeader, chevron: Chevron, row: Row, card: Card, addTask: AddRow, doneStrip: DoneStrip)
            case columns(Board)
        }

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
        /// title, over the line's 1 pt rule, its chevron 18 in a 44 hit; the row and the open card below; "+ Add task" 40
        /// high, 8 in and 12 short of the edges, its plus 18 in a 44 cell with its title right after it and 12 short of
        /// its end, rounded 12; "+ Add list" 44 high over the line's 1 pt rule with 4 under it, 10 under what stands above
        /// and 12 in and 6 short of the edges, its plus 18 in a 40 cell; the Done strip's capsule 36 high and 20 under what
        /// stands above, 14 in and 16 short of the edges, its glyph 18 and 10 in, its chevron 15 and 14 short of its end, 8
        /// on either side of its label.
        static let phone = Metrics(
            header: phoneHeader, tagBar: phoneTagBar, empty: phoneEmpty,
            blocks: .list(
                header: BlockHeader(
                    height: 44, topMargin: 6, trailingMargin: 6, bottomMargin: 2, leadingMargin: 12, topPadding: 13,
                    horizontalPadding: 8, bottomPadding: 0, titleToSubtitle: 8,
                    rule: StrokeModel(color: .line, width: 1, dash: [])
                ),
                chevron: Chevron(size: 18, hitSide: 44), row: phoneRow, card: phoneCard,
                addTask: AddRow(
                    iconSize: 18, iconCellWidth: 44, spacing: 0, font: .addRow, height: 40, width: nil,
                    cornerRadius: 12, topPadding: 0, leadingPadding: 0, trailingPadding: 12, dash: nil, rule: nil,
                    topMargin: 0, leadingMargin: 8, trailingMargin: 12
                ),
                doneStrip: DoneStrip(
                    iconSize: 18, chevronSize: 15, height: 36, spacing: 8, leadingPadding: 10, trailingPadding: 14,
                    topMargin: 20, leadingMargin: 14, trailingMargin: 16
                )
            ),
            addList: AddRow(
                iconSize: 18, iconCellWidth: 40, spacing: 0, font: .barLabel, height: 44, width: nil, cornerRadius: 12,
                topPadding: 4, leadingPadding: 0, trailingPadding: 12, dash: nil,
                rule: StrokeModel(color: .line, width: 1, dash: []), topMargin: 10, leadingMargin: 12, trailingMargin: 6
            ),
            floatingButton: phoneFloatingButton
        )

        /// The phone's board (Task 8's table, Board; the controller's ruling on #175, 2026-11-04): 10 between columns,
        /// 16 in at its sides and 24 at its bottom, snapping; a column 296 wide and rounded 18, its header padded 13 14
        /// 9 with no rule and no chevron, its drop ring 2; a card rounded 13 with a 0.5 hairline, its check 22 across
        /// in a 42 by 44 hit, its title callout-sized. The table gives a column's padding and cards' gap neither: the
        /// cards are 8 apart (`task-4-canvas.md`, "column body gap 8") and 8 in; a column's header no height: a block's
        /// 44; a card's row the row's numbers but its check, its title and its edges: 0 in, the check's hit at its
        /// edge, 12 short of its end, rounded as the card. The card's check keeps the row's ring and mark, the canvas
        /// resizing only its circle, and it has the menu and no swipe. Its open card fills the card, its own corners
        /// and resting shadow, its check the row's, its body 44 in and 12 short of its end and bottom (`Phone.dc.html`,
        /// the column's card). "+ Add task" 44 high, rounded 13, padded 11 and 12, the plus 18 and 6 before its title;
        /// "+ Add list" a column 200 wide edged in a 1.5 dashed line, as rounded as a column, 52 high, padded 16, the
        /// plus 18 and 8 before its title. The table gives the dash no lengths: 5 and 4, the sidebar's dashed line.
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
                    leading: 0, trailing: 12,
                    check: Check(
                        diameter: 22, ringWidth: 1.75, markSize: 15, markStrokeWidth: 1.75, hitWidth: 42, hitHeight: 44
                    ),
                    title: .nestedRowTitle, verticalPadding: 11, titleLeading: 2, titleTrailing: 4, titleToMeta: 3,
                    metaSpacing: 10, metaLineSpacing: 3, metaIconSize: 13, metaIconSpacing: 3, minimumHeight: 44,
                    cornerRadius: 13, swipe: nil
                ),
                openCard: Card(
                    topMargin: 0, horizontalMargin: 0, bottomMargin: 0, cornerRadius: 13, shadow: .resting,
                    check: phoneCheck, titleHeight: 44, titlePadding: 2, expandSize: 19, expandHitSide: 44,
                    bodyLeading: 44, bodyTrailing: 12, bodyBottom: 12, notesHeight: 22, subtaskCheck: phoneSubtaskCheck,
                    subtaskHeight: 44, subtaskFieldHeight: 40, addSubtask: phoneAddSubtask, subtasksToPills: 10,
                    pillSpacing: 6, pill: phonePill
                ),
                addTask: AddRow(
                    iconSize: 18, iconCellWidth: 18, spacing: 6, font: .addRow, height: 44, width: nil,
                    cornerRadius: 13, topPadding: 0, leadingPadding: 11, trailingPadding: 12, dash: nil, rule: nil,
                    topMargin: 0, leadingMargin: 0, trailingMargin: 0
                )
            )),
            addList: AddRow(
                iconSize: 18, iconCellWidth: 18, spacing: 8, font: .barLabel, height: 52, width: 200, cornerRadius: 18,
                topPadding: 0, leadingPadding: 16, trailingPadding: 16,
                dash: StrokeModel(color: .line, width: 1.5, dash: [5, 4]), rule: nil, topMargin: 0, leadingMargin: 0,
                trailingMargin: 0
            ),
            floatingButton: phoneFloatingButton
        )

        /// A check of the phone's row and of its open card: 24 across with a 1.75 ring and the 15 pt mark stroked 1.75
        /// in a 44 hit (Task 8's table, Row).
        private static let phoneCheck = Check(
            diameter: 24, ringWidth: 1.75, markSize: 15, markStrokeWidth: 1.75, hitWidth: 44, hitHeight: 44
        )

        /// A subtask's check in the open card: 18 across with a 1.5 ring and the 12 pt mark in a 40 by 44 hit (Task 8's
        /// table, Card), the canvas's 2.8 in its 24-unit box stroked 1.4 at that size (`CheckModel.markStrokeWidth`).
        private static let phoneSubtaskCheck = Check(
            diameter: 18, ringWidth: 1.5, markSize: 12, markStrokeWidth: 1.4, hitWidth: 40, hitHeight: 44
        )

        /// The phone's row (Task 8's table, Row and Swipe): 8 in and 12 short of the edges, its check `phoneCheck`, its
        /// title the row title padded 11 above and below, 2 after the check's hit and 4 short of the end, the meta 3
        /// under it, its items 10 apart and its lines 3, its glyphs 13 and 3 before their text, at least 44 high;
        /// dragged 40 leftward it stays moved 88, over a Delete 78 wide, 3 in from its top and bottom and 10 from its
        /// end, rounded 12. The table gives the row no radius: 12, the add row's under it, until Task 8's hand check
        /// tunes it.
        private static let phoneRow = Row(
            leading: 8, trailing: 12, check: phoneCheck, title: .rowTitle, verticalPadding: 11, titleLeading: 2,
            titleTrailing: 4, titleToMeta: 3, metaSpacing: 10, metaLineSpacing: 3, metaIconSize: 13, metaIconSpacing: 3,
            minimumHeight: 44, cornerRadius: 12,
            swipe: Swipe(
                threshold: 40, shift: -88, buttonWidth: 78, buttonVerticalInset: 3, buttonTrailingInset: 10,
                buttonCornerRadius: 12
            )
        )

        /// The phone's open card (Task 8's table, Card; `Phone.dc.html`, the open card): 6 10 10 from what stands round
        /// it, rounded 18, casting the raised shadow; its check `phoneCheck`, its title field 44 high and padded 2, the
        /// canvas's 2 before and 4 after in one padding; Open full screen 19 in a 44 hit; its body 46 in and 14 short
        /// of its end and bottom; a subtask 44 high, its field 40; the pills 6 apart and 10 under the subtasks. The
        /// table gives the notes no height: 22, their 15 pt line at the canvas's 1.45, the least a field grows from.
        private static let phoneCard = Card(
            topMargin: 6, horizontalMargin: 10, bottomMargin: 10, cornerRadius: 18, shadow: .raised, check: phoneCheck,
            titleHeight: 44, titlePadding: 2, expandSize: 19, expandHitSide: 44, bodyLeading: 46, bodyTrailing: 14,
            bodyBottom: 14, notesHeight: 22, subtaskCheck: phoneSubtaskCheck, subtaskHeight: 44, subtaskFieldHeight: 40,
            addSubtask: phoneAddSubtask, subtasksToPills: 10, pillSpacing: 6, pill: phonePill
        )

        /// "Add subtask" in the phone's card (`Phone.dc.html`, the open card): 44 high, its plus 17 in a 40 cell under
        /// the subtasks' checks, 12 outside the body's leading edge as they are, its title right after it and 12 short
        /// of its end, rounded 12.
        private static let phoneAddSubtask = AddRow(
            iconSize: 17, iconCellWidth: 40, spacing: 0, font: .notes, height: 44, width: nil, cornerRadius: 12,
            topPadding: 0, leadingPadding: 0, trailingPadding: 12, dash: nil, rule: nil, topMargin: 0,
            leadingMargin: -12, trailingMargin: 0
        )

        /// The phone's pill (Task 8's table, Card; `Phone.dc.html`, `.xpill`): 32 high, a capsule, padded 10 and 12,
        /// its glyph 6 before its text, the sun 16, the flag 15, the hash 14.
        private static let phonePill = Pill(
            height: 32, leadingPadding: 10, trailingPadding: 12, spacing: 6, sunSize: 16, flagSize: 15, hashSize: 14
        )

        /// The phone's floating "+" (Task 8's table, Floating "+"): a 48 circle, its plus 22.
        private static let phoneFloatingButton = FloatingButton(diameter: 48, glyphSize: 22)

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
