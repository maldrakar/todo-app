// Sources/DesignSystemComponents/PickerModel.swift
import DesignSystem

/// A picker that puts something into a tree, as every platform draws it (`Phone.dc.html`, the Move to… sheet): its
/// title, with its Cancel beside it, the hint under the title, `hintGap` above the rows, then the top level, which the
/// canvas draws apart from the tree, and the tree's rows, each an option drawn as its `Row`, at least
/// `minimumOptionHeight` high. The present choice has the check at its right, `checkTrailing` from the edge, and every
/// other row keeps the check's room, so that the rows end in one column; an option that cannot be chosen is drawn at
/// `disabledOpacity` and takes no tap. The rest of an option is its row's: its tap, and how it draws (ADR-0007,
/// amendment of 2026-10-30).
public struct PickerModel<Row: Equatable & Sendable, Action: Equatable & Sendable>: Equatable, Sendable {
    /// The top level, a row of its own: `height` high, `leading` in from either edge, a tile `tileSide` across with
    /// corners of `tileCornerRadius` in `tileColor` with `icon` on it, then `tileToTitle` after it the title, in points;
    /// checked where it is the present choice, and sending `action` when tapped.
    public struct TopLevel: Equatable, Sendable {
        public let icon: IconModel
        public let tileSide: Double
        public let tileCornerRadius: Double
        public let tileColor: DesignSystem.Color
        public let tileToTitle: Double
        public let title: TextModel
        public let leading: Double
        public let height: Double
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
            self.isChecked = isChecked
            self.action = action
        }
    }

    /// A row of the tree as the picker offers it: the row as it draws, whether it cannot be chosen, and whether it is
    /// the present choice.
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

    /// The check that marks the present choice.
    public let check: IconModel

    public let checkTrailing: Double
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
        check: IconModel,
        checkTrailing: Double,
        hintGap: Double,
        minimumOptionHeight: Double,
        disabledOpacity: Double
    ) {
        self.title = title
        self.hint = hint
        self.cancel = cancel
        self.topLevel = topLevel
        self.options = options
        self.check = check
        self.checkTrailing = checkTrailing
        self.hintGap = hintGap
        self.minimumOptionHeight = minimumOptionHeight
        self.disabledOpacity = disabledOpacity
    }
}
