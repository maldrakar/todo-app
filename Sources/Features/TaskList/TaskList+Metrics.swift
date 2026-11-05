// Sources/Features/TaskList/TaskList+Metrics.swift
import DesignSystem
import DesignSystemComponents

extension TaskList {
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
