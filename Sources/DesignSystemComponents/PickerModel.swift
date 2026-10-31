// Sources/DesignSystemComponents/PickerModel.swift
import DesignSystem

/// A picker that puts something into a tree, as every platform draws it (`Phone.dc.html`, the Move to… sheet): its
/// title, with its Cancel beside it, the hint under the title, `hintGap` above the rows, then the top level, which the
/// canvas draws apart from the tree, and the tree's rows, each an option drawn as its `Row`, at least
/// `minimumOptionHeight` high. Each row carries what stands at its right, the check on the present choice and the room
/// for it on every other, so that the rows end in one column; an option that cannot be chosen is drawn at
/// `disabledOpacity` and takes no tap. The rest of an option is its row's: its tap, and how it draws (ADR-0007,
/// amendment of 2026-10-30).
///
/// A class, for the reason a list's row is one (`ListRowModel`): a screen's model holds it, every comparison of the
/// screen's model compares it, and it is some 500 bytes on wasm32. Its `==` compares every stored property, and a test
/// changes them one at a time.
public final class PickerModel<Row: Equatable & Sendable, Action: Equatable & Sendable>: Equatable, Sendable {
    /// The top level, a row of its own: `height` high, a tile `tileSide` across at `leading` from its left edge with
    /// corners of `tileCornerRadius` in `tileColor` with `icon` on it, then `tileToTitle` after it the title, and at
    /// its right its accessories in the order given, a text as wide as it reads, a chevron, a grip or a check each
    /// centred in a cell at least `cellMinimumWidth` wide and as wide as its glyph on its platform, a space as wide as
    /// it says and a hidden accessory's room empty, with `endGap` after them, in points; chosen where it is the present
    /// choice, which a view reads for what it says aloud, and sending `action` when tapped.
    public struct TopLevel: Equatable, Sendable {
        public let icon: IconModel
        public let tileSide: Double
        public let tileCornerRadius: Double
        public let tileColor: DesignSystem.Color
        public let tileToTitle: Double
        public let title: TextModel
        public let leading: Double
        public let height: Double
        public let accessories: [AccessoryModel<Action>]
        public let cellMinimumWidth: Double
        public let endGap: Double
        public let isChecked: Bool
        public let action: Action

        public init(
            icon: IconModel,
            tileSide: Double,
            tileCornerRadius: Double,
            tileColor: DesignSystem.Color,
            tileToTitle: Double,
            title: TextModel,
            leading: Double,
            height: Double,
            accessories: [AccessoryModel<Action>],
            cellMinimumWidth: Double,
            endGap: Double,
            isChecked: Bool,
            action: Action
        ) {
            self.icon = icon
            self.tileSide = tileSide
            self.tileCornerRadius = tileCornerRadius
            self.tileColor = tileColor
            self.tileToTitle = tileToTitle
            self.title = title
            self.leading = leading
            self.height = height
            self.accessories = accessories
            self.cellMinimumWidth = cellMinimumWidth
            self.endGap = endGap
            self.isChecked = isChecked
            self.action = action
        }
    }

    /// A row of the tree as the picker offers it: the row as it draws, with the check or the room for it at its right;
    /// whether it cannot be chosen; and whether it is the present choice, which a view reads for what it says aloud.
    public struct Option: Equatable, Sendable {
        public let row: Row
        public let isDisabled: Bool
        public let isChecked: Bool

        public init(row: Row, isDisabled: Bool, isChecked: Bool) {
            self.row = row
            self.isDisabled = isDisabled
            self.isChecked = isChecked
        }
    }

    public let title: String
    public let hint: TextModel

    /// The picker's Cancel, which every way the platform has of closing the picker is.
    public let cancel: ChoiceModel<Action>

    public let topLevel: TopLevel
    public let options: [Option]
    public let hintGap: Double
    public let minimumOptionHeight: Double

    /// The opacity an option that cannot be chosen is drawn at, from 0 to 1.
    public let disabledOpacity: Double

    public init(
        title: String,
        hint: TextModel,
        cancel: ChoiceModel<Action>,
        topLevel: TopLevel,
        options: [Option],
        hintGap: Double,
        minimumOptionHeight: Double,
        disabledOpacity: Double
    ) {
        self.title = title
        self.hint = hint
        self.cancel = cancel
        self.topLevel = topLevel
        self.options = options
        self.hintGap = hintGap
        self.minimumOptionHeight = minimumOptionHeight
        self.disabledOpacity = disabledOpacity
    }

    public static func == (lhs: PickerModel, rhs: PickerModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.title == rhs.title
            && lhs.hint == rhs.hint
            && lhs.cancel == rhs.cancel
            && lhs.topLevel == rhs.topLevel
            && lhs.options == rhs.options
            && lhs.hintGap == rhs.hintGap
            && lhs.minimumOptionHeight == rhs.minimumOptionHeight
            && lhs.disabledOpacity == rhs.disabledOpacity
    }
}
