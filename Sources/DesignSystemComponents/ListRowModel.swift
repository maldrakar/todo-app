// Sources/DesignSystemComponents/ListRowModel.swift

/// A list's row in a tree as every platform draws it (`Phone.dc.html`, `.vrow`; `Mac.dc.html`, a list's row): `height`
/// high on its background, its tile at `leading`, the title `tileToTitle` after the tile, or the field in its place
/// while the row is being renamed, the guides of the levels it stands under behind it, and its accessories at its
/// right. The model holds every value its platform needs to draw it, so a view decides nothing but what is the
/// platform's: the gestures, the sideways scroll that keeps the accessories at the right edge of the screen, focus and
/// Reduce Motion (ADR-0007, amendment of 2026-10-30).
///
/// A class, so that a row's kind, an option of a picker and every copy of either hold a reference to the row and not
/// the row, some 750 bytes on wasm32, which a debug build puts on the stack at every copy and every comparison (the
/// owner's 👍 on #163's thread r4431083210). Its `==` compares every stored property, as a struct's derived one would,
/// and a test changes them one at a time, so that a property added later and left out of it fails.
///
/// Its numbers, its background and its guide are the fields of its `ListRowStyle`.
public final class ListRowModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let tile: TileModel
    public let style: ListRowStyle

    /// The title, on one line.
    public let title: TextModel

    /// The field the title is typed into while the row is being renamed, in the title's place, and nil while it is
    /// not: it fills the room between the tile and the accessories, and is never narrower than its minimum width, which
    /// the style's `need` leaves it.
    public let field: TextFieldModel<Action>?

    /// What stands at the right of the row, in the order given (`Phone.dc.html`, the row's sticky end).
    public let accessories: [AccessoryModel<Action>]

    /// What a tap on the row sends.
    public let tap: Action

    /// The menu of the row, and nil where it has none.
    public let menu: MenuModel<Action>?

    public init(
        tile: TileModel,
        style: ListRowStyle,
        title: TextModel,
        field: TextFieldModel<Action>?,
        accessories: [AccessoryModel<Action>],
        tap: Action,
        menu: MenuModel<Action>?
    ) {
        self.tile = tile
        self.style = style
        self.title = title
        self.field = field
        self.accessories = accessories
        self.tap = tap
        self.menu = menu
    }

    public static func == (lhs: ListRowModel, rhs: ListRowModel) -> Bool {
        if lhs === rhs { return true }
        return lhs.tile == rhs.tile
            && lhs.style == rhs.style
            && lhs.title == rhs.title
            && lhs.field == rhs.field
            && lhs.accessories == rhs.accessories
            && lhs.tap == rhs.tap
            && lhs.menu == rhs.menu
    }
}
