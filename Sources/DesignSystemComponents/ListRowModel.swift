// Sources/DesignSystemComponents/ListRowModel.swift
import DesignSystem

/// A list's row in a tree as every platform draws it (`Phone.dc.html`, `.vrow`): `height` high on its background, its
/// tile at `leading`, the title `tileToTitle` after the tile, or the field in its place while the row is being renamed,
/// the guides of the levels it stands under behind it, and its accessories at its right. The model holds every value
/// its platform needs to draw it, so a view decides nothing but what is the platform's: the gestures, the sideways
/// scroll that keeps the accessories at the right edge of the screen, focus and Reduce Motion (ADR-0007, amendment of
/// 2026-10-30).
///
/// A class, so that a row's kind, an option of a picker and every copy of either hold a reference to the row and not
/// the row, some 750 bytes on wasm32, which a debug build puts on the stack at every copy and every comparison (the
/// owner's 👍 on #163's thread r4431083210). Its `==` compares every stored property, as a struct's derived one would,
/// and a test changes them one at a time, so that a property added later and left out of it fails.
public final class ListRowModel<Action: Equatable & Sendable>: Equatable, Sendable {
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
    public let field: TextFieldModel<Action>?

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

    /// What stands at the right of the row, in the order given (`Phone.dc.html`, the row's sticky end): over a fade
    /// `fadeWidth` wide from clear to the row's background, so that a title running under them ends softly, a count set
    /// against the right of a cell at least `countMinimumWidth` wide, a chevron, a grip or a check each centred in a
    /// cell `cellWidth` wide, a space as wide as it says, and `endGap` at the end, all on the row's background and as
    /// high as the row, in points.
    public let accessories: [AccessoryModel<Action>]
    public let fadeWidth: Double
    public let countMinimumWidth: Double
    public let cellWidth: Double
    public let endGap: Double

    /// How much of the row the accessories take, which the title leaves them: what they draw, with room to spare.
    public let accessoriesWidth: Double

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
        field: TextFieldModel<Action>?,
        need: Double,
        background: DesignSystem.Color,
        guides: [Double],
        childGuides: [Double],
        guide: StrokeModel,
        accessories: [AccessoryModel<Action>],
        fadeWidth: Double,
        countMinimumWidth: Double,
        cellWidth: Double,
        endGap: Double,
        accessoriesWidth: Double,
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
        self.fadeWidth = fadeWidth
        self.countMinimumWidth = countMinimumWidth
        self.cellWidth = cellWidth
        self.endGap = endGap
        self.accessoriesWidth = accessoriesWidth
        self.tap = tap
        self.menu = menu
    }

    public static func == (lhs: ListRowModel, rhs: ListRowModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.height == rhs.height
            && lhs.leading == rhs.leading
            && lhs.tile == rhs.tile
            && lhs.tileToTitle == rhs.tileToTitle
            && lhs.title == rhs.title
            && lhs.field == rhs.field
            && lhs.need == rhs.need
            && lhs.background == rhs.background
            && lhs.guides == rhs.guides
            && lhs.childGuides == rhs.childGuides
            && lhs.guide == rhs.guide
            && lhs.accessories == rhs.accessories
            && lhs.fadeWidth == rhs.fadeWidth
            && lhs.countMinimumWidth == rhs.countMinimumWidth
            && lhs.cellWidth == rhs.cellWidth
            && lhs.endGap == rhs.endGap
            && lhs.accessoriesWidth == rhs.accessoriesWidth
            && lhs.tap == rhs.tap
            && lhs.menu == rhs.menu
    }
}
