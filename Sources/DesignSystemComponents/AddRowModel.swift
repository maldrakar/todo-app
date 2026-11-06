// Sources/DesignSystemComponents/AddRowModel.swift
import DesignSystem

/// A row that adds, "+ Add task" at the end of a block or a column, "Add subtask" in a card and "+ Add list" after the
/// blocks or the columns (`Phone.dc.html`): `height` high and `width` wide, with corners of `cornerRadius`,
/// `topPadding` under its top edge and `leadingPadding` in from its leading edge its glyph, centred in a cell
/// `iconCellWidth` wide and as high as the row, as a row's check is in its tap area, so that the plus stands under the
/// checks, then `spacing` after the cell its title, `trailingPadding` short of its trailing edge; `topMargin` below
/// what stands before it and `leadingMargin` and `trailingMargin` in from the sides, in points. Its numbers, its `dash`
/// and its `rule` are the fields of its `AddRowStyle`.
///
/// A class, for the reason a list's row is one (`ListRowModel`): a block, a card, a board and the screen's model each
/// hold one, every copy and comparison of the screen's model copies and compares them, and inline it is some 440 bytes
/// on wasm32. Its `==` compares every stored property, and a test changes them one at a time.
public final class AddRowModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let icon: IconModel
    public let title: TextModel
    public let style: AddRowStyle

    /// What a tap on the row sends.
    public let action: Action

    public init(
        icon: IconModel,
        title: TextModel,
        style: AddRowStyle,
        action: Action
    ) {
        self.icon = icon
        self.title = title
        self.style = style
        self.action = action
    }

    public static func == (lhs: AddRowModel, rhs: AddRowModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.icon == rhs.icon
            && lhs.style == rhs.style
            && lhs.title == rhs.title
            && lhs.action == rhs.action
    }
}
