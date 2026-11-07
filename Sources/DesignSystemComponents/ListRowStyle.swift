// Sources/DesignSystemComponents/ListRowStyle.swift
import DesignSystem

/// The numbers a `ListRowModel` is drawn with, in points, and its background and guide, which a builder hands over as
/// one value. The numbers differ per row, by its depth and by what stands at its right, so a row of another depth is
/// another instance.
public struct ListRowStyle: Equatable, Sendable {
    /// The row's height, and where its tile starts, from the tree's leading edge, in points.
    public let height: Double
    public let leading: Double

    /// The gap between the tile and the title, or the field, in points.
    public let tileToTitle: Double

    /// How wide the tree must be for the row, from the tree's leading edge, in points: the tile at its leading edge,
    /// which the background's inset is inside of, the gap, the least room its title takes, and the accessories. A tree
    /// too narrow for a row's need scrolls sideways.
    public let need: Double

    /// The colour under the whole row, its accessories included, `backgroundInset` in from either side of the tree, so
    /// that the accessories end that far short of its right edge too, with corners of `cornerRadius`, in points.
    public let background: DesignSystem.Color
    public let backgroundInset: Double
    public let cornerRadius: Double

    /// Where the guides of the levels the row stands under run, one under the centre of each ancestor's tile, from the
    /// tree's leading edge, in points, drawn the whole height of the row in `guide`, so that the rows of a branch join
    /// them into lines; and the guides a row one level deeper stands under, its own and one under its own tile, which
    /// the slot of a drag after it takes as far as its depth.
    public let guides: [Double]
    public let childGuides: [Double]
    public let guide: LineStyle

    /// The room of what stands at the right of the row (`ListRowModel.accessories`; `Phone.dc.html`, the row's sticky
    /// end): over a fade `fadeWidth` wide from clear to the row's background, so that a title running under them ends
    /// softly, a text set against the right of a cell at least `textMinimumWidth` wide, a chevron, a grip or a check
    /// each centred in a cell at least `cellMinimumWidth` wide and as wide as its glyph on its platform, a space as
    /// wide as it says, a hidden accessory's room empty, and `endGap` at the end, all on the row's background and as
    /// high as the row, in points.
    public let fadeWidth: Double
    public let textMinimumWidth: Double
    public let cellMinimumWidth: Double
    public let endGap: Double

    /// How much of the row the accessories take, which the title leaves them: what they draw, with room to spare.
    public let accessoriesWidth: Double

    public init(
        height: Double,
        leading: Double,
        tileToTitle: Double,
        need: Double,
        background: DesignSystem.Color,
        backgroundInset: Double,
        cornerRadius: Double,
        guides: [Double],
        childGuides: [Double],
        guide: LineStyle,
        fadeWidth: Double,
        textMinimumWidth: Double,
        cellMinimumWidth: Double,
        endGap: Double,
        accessoriesWidth: Double
    ) {
        self.height = height
        self.leading = leading
        self.tileToTitle = tileToTitle
        self.need = need
        self.background = background
        self.backgroundInset = backgroundInset
        self.cornerRadius = cornerRadius
        self.guides = guides
        self.childGuides = childGuides
        self.guide = guide
        self.fadeWidth = fadeWidth
        self.textMinimumWidth = textMinimumWidth
        self.cellMinimumWidth = cellMinimumWidth
        self.endGap = endGap
        self.accessoriesWidth = accessoriesWidth
    }
}
