// Sources/DesignSystemComponents/ListRowModel.swift
import DesignSystem

/// A list's row in a tree as every platform draws it (`Phone.dc.html`, `.vrow`): `height` high on its background, its
/// tile at `leading`, the title `tileToTitle` after the tile, or the field in its place while the row is being renamed,
/// the guides of the levels it stands under behind it, and its accessories at its right. The model holds every value
/// its platform needs to draw it, so a view decides nothing but what is the platform's: the gestures, the sideways
/// scroll that keeps the accessories at the right edge of the screen, focus and Reduce Motion (ADR-0007, amendment of
/// 2026-10-30).
public struct ListRowModel<Action: Equatable & Sendable>: Equatable, Sendable {
    /// The chevron of a row with rows inside it, which folds and unfolds them: its glyph, turned by `rotation` degrees,
    /// clockwise when positive, as CSS and SwiftUI turn, moving to a new turn on `animation`, the words it reads aloud,
    /// which say what a tap on it will do, and the action the tap sends.
    public struct Chevron: Equatable, Sendable {
        public let icon: IconModel
        public let rotation: Double
        public let animation: DesignSystem.Animation
        public let accessibilityLabel: String
        public let action: Action

        public init(
            icon: IconModel, rotation: Double, animation: DesignSystem.Animation, accessibilityLabel: String,
            action: Action
        ) {
            self.icon = icon
            self.rotation = rotation
            self.animation = animation
            self.accessibilityLabel = accessibilityLabel
            self.action = action
        }
    }

    /// What stands at the right of the row (`Phone.dc.html`, the row's sticky end), in this order: a fade over
    /// `fadeWidth` from clear to the row's background, so that a title running under them ends softly; the count, at
    /// least `countMinimumWidth` wide and set against its right; a cell `cellWidth` wide on every row, which holds the
    /// chevron where the row has one, so that the counts stand in one column; a cell as wide holding the grip where
    /// there is one; and `endGap` at the end, all on the row's background and as high as the row, in points.
    public struct Accessories: Equatable, Sendable {
        /// The count of the row, finished, and empty where it is drawn as nothing.
        public let count: TextModel
        public let countMinimumWidth: Double

        /// The chevron, and nil on a row with no rows inside it.
        public let chevron: Chevron?

        /// The grip, which says the row drags, and nil where it does not.
        public let grip: IconModel?

        public let cellWidth: Double
        public let fadeWidth: Double
        public let endGap: Double

        /// How much of the row the accessories take, which the title leaves them: what they draw, with room to spare.
        public let width: Double

        public init(
            count: TextModel, countMinimumWidth: Double, chevron: Chevron?, grip: IconModel?, cellWidth: Double,
            fadeWidth: Double, endGap: Double, width: Double
        ) {
            self.count = count
            self.countMinimumWidth = countMinimumWidth
            self.chevron = chevron
            self.grip = grip
            self.cellWidth = cellWidth
            self.fadeWidth = fadeWidth
            self.endGap = endGap
            self.width = width
        }
    }

    /// The row's height, and where its tile starts, from the tree's leading edge, in points.
    public let height: Double
    public let leading: Double

    public let tile: TileModel

    /// The gap between the tile and the title, or the field, in points.
    public let tileToTitle: Double

    /// The title, on one line.
    public let title: TextModel

    /// The field the title is typed into while the row is being renamed, in the title's place, and nil while it is
    /// not: it fills the room between the tile and the accessories, and is never narrower than its minimum width, which
    /// `need` leaves it.
    public let field: FieldModel?

    /// How wide the tree must be for the row, from the tree's leading edge, in points: the tile at its leading edge,
    /// the gap, the least room its title takes, and the accessories. A tree too narrow for a row's need scrolls
    /// sideways.
    public let need: Double

    /// The colour under the whole row, its accessories included.
    public let background: DesignSystem.Color

    /// Where the guides of the levels the row stands under run, one under the centre of each ancestor's tile, from the
    /// tree's leading edge, in points, drawn the whole height of the row in `guide`, so that the rows of a branch join
    /// them into lines; and the guides a row one level deeper stands under, its own and one under its own tile, which
    /// the slot of a drag after it takes as far as its depth.
    public let guides: [Double]
    public let childGuides: [Double]
    public let guide: StrokeModel

    public let accessories: Accessories

    /// What a tap on the row sends.
    public let tap: Action

    /// The menu of the row, and nil where it has none.
    public let menu: MenuModel<Action>?

    public init(
        height: Double,
        leading: Double,
        tile: TileModel,
        tileToTitle: Double,
        title: TextModel,
        field: FieldModel?,
        need: Double,
        background: DesignSystem.Color,
        guides: [Double],
        childGuides: [Double],
        guide: StrokeModel,
        accessories: Accessories,
        tap: Action,
        menu: MenuModel<Action>?
    ) {
        self.height = height
        self.leading = leading
        self.tile = tile
        self.tileToTitle = tileToTitle
        self.title = title
        self.field = field
        self.need = need
        self.background = background
        self.guides = guides
        self.childGuides = childGuides
        self.guide = guide
        self.accessories = accessories
        self.tap = tap
        self.menu = menu
    }
}
