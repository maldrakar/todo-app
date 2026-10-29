// Sources/Features/TaskViewList/TaskViewList+Model.swift
import DesignSystem
import DesignSystemComponents
import TodoCore

extension TaskViewList {
    /// What a view draws: the rows of the tree, the highlighted one named once more for a list bound to one value, and
    /// the sentence.
    public struct Model: Equatable, Sendable {
        /// One row of the tree, an area's line or a list's row (spec section 5).
        public struct Row: Equatable, Sendable, Identifiable {
            public let id: ViewID

            /// The depth the row is drawn at, which a view indents by and decides nothing with: a list of the root at
            /// 0 and its lists at 1, and an area's line at 0 with the lists under it at 0 too and theirs at 1, since
            /// the line, and not an indent, says which area a list belongs to (spec section 3).
            public let depth: Int

            /// What the row is, which a view switches over once to pick the row it draws, every case drawn and no
            /// `default` (`docs/style.md`, "Views").
            public let kind: Kind

            /// The text of the rename in progress on this row, and nil on every other row and whenever no
            /// field is open at all: a view puts a text field where this is not nil, draws the title or the
            /// label everywhere else, and that is the whole of what it knows about renaming. It is what the
            /// person typed, down to the spaces at its ends; what the store keeps is that text trimmed
            /// (`commit`), since a caret is no place for the module to be moving text about.
            ///
            /// The draft is the module's, put on the row when the model is assembled and never kept in one.
            /// A read replaces every row, so a draft that lived in a row would be emptied by a peer's edit
            /// arriving while a person was typing. What ends it is its row going, which `reread` decides.
            public let draft: String?
        }

        /// A row's kind, an enum so that a row is one of the two explicitly and never both or neither (the owner,
        /// 2026-10-25, on the spec's first revision).
        public enum Kind: Equatable, Sendable {
            /// An area's line, with its name as its label, and nil for an area that has none: the line alone is the
            /// whole of how an unnamed area looks (spec section 3). In edit mode an unnamed area's label is "Area", the
            /// label a tap renames it by (spec section 1).
            case area(label: String?)
            /// A list's row, with everything it draws.
            case list(ListRow)
        }

        /// What a list's row draws, every value finished, so that a view formats nothing and chooses nothing
        /// (`docs/style.md`, "Views").
        public struct ListRow: Equatable, Sendable {
            public let title: String

            /// The list's tile, in its colour and with its icon, at the sizes the Lists screen gives a row of its
            /// drawn depth in a window of the module's width class (`TaskViewList+Rows.swift`).
            public let tile: TileModel

            /// The title's font, one of the design system's four row titles, chosen by the same width class, the
            /// drawn depth and whether the row has lists inside it.
            public let titleFont: DesignSystem.Font

            /// The number of the list's open tasks as text, and the empty string for a count of zero, for a list
            /// that has no count and in edit mode, where counts leave the rows: a view draws it as it is, and a zero is
            /// drawn as nothing on every list (spec sections 1 and 4).
            public let countText: String

            /// Whether the list has lists inside it, which a chevron folds.
            public let hasChildren: Bool

            /// Whether the list's branch is folded on this device, the lists inside it left out of `rows` (Lists
            /// screen spec, section 5); never on a list with no lists inside.
            public let isCollapsed: Bool

            /// Whether this row is the highlighted one, which `selection` names too: the row of the view whose list is
            /// declared, or the folded list whose branch hides that row.
            public let isSelected: Bool
        }

        /// What the confirmation of a delete asks, finished: the question, which names the list or the area, and what
        /// the delete takes with it and what it leaves (spec section 6).
        public struct Confirmation: Equatable, Sendable {
            public let title: String
            public let message: String
        }

        /// What the picker of Move to… draws (spec section 6).
        public struct MovePicker: Equatable, Sendable {
            /// The question, which names the list being moved.
            public let title: String

            /// Whether the list being moved stands at the root, which marks "Top level" as its present parent.
            public let isTopLevelCurrent: Bool

            /// The whole tree in tree order, every level of it and the folds ignored.
            public let rows: [PickerRow]
        }

        /// A row of the picker: the row the screen draws, and what the picker says about it.
        public struct PickerRow: Equatable, Sendable, Identifiable {
            public var id: ViewID { row.id }

            /// The row as the screen draws it, of the same kind, at the same depth and with the same tile and title
            /// font, so that a view draws it with the screen's own row; it carries no draft, no fold and no highlight.
            public let row: Row

            /// Whether the row cannot take the list, being the list itself or a list inside it, which a view greys out.
            public let isDisabled: Bool

            /// Whether the row is the list's present parent, a list or an area's line, which a view marks.
            public let isCurrent: Bool
        }

        public let rows: [Row]

        /// The id of the highlighted row, and nil when no row is highlighted: what a list that keeps its
        /// selection as one value is bound to, as the Mac's `List(selection:)` is, so that the binding reads a
        /// field the way a text field's reads `draft`, instead of searching the rows for one (spec section 4).
        ///
        /// It is the highlight `ListRow.isSelected` carries, held a second way because it is read a second way: a
        /// list bound to one value reads this, and a client that draws row by row reads the row. Both come
        /// off the same drawn rows when the model is assembled, so they name the same row or none.
        ///
        /// The highlight is the view of the list this module declared, where a list's row holds it (navigation state
        /// spec, "Open questions"): nil when it declared nothing, and when the view it declared has no such row, a
        /// view that is gone or not yet synced, so a highlight goes with its row by computation and a row that arrives
        /// later lights up only if its list is still declared.
        ///
        /// A row hidden by a fold passes its highlight to the folded list that hides it, the outermost of the folds
        /// above it, which is the one drawn, as the Finder lights a folder that closes over the selection (the owner,
        /// 2026-10-29, #158). Only the light moves: the list declared stays open, a click on the lit row declares that
        /// row's own list as a click on any row does, and the row lights up again once no fold hides it.
        public let selection: ViewID?

        /// Whether the screen is in edit mode, entered from "…" and left with Done: every row then takes a grip and a
        /// tap renames it, and the counts and an unnamed area's missing label are drawn as `rows` gives them in it
        /// (spec section 7). It is session state, which no relaunch restores (ADR-0009, amendment of 2026-10-25).
        public let isEditing: Bool

        /// The confirmation of a delete while it is up, and nil when none is: a view draws it as an alert, its title and
        /// message with two buttons of the view's own, Delete and Cancel, which send `deleteConfirmed` and
        /// `deleteCancelled` (spec section 6). It is the module's state and not a screen, and no relaunch restores it
        /// (ADR-0009, amendment of 2026-10-25).
        public let confirmation: Confirmation?

        /// The picker of Move to… while it is open, and nil when it is closed: a view draws it as a sheet, "Top level"
        /// first and then its rows, which send `movePickerRowTapped`, with a Cancel of the view's own that sends
        /// `movePickerCancelled` (spec section 6). It is the module's state and not a screen, and no relaunch restores
        /// it (ADR-0009, amendment of 2026-10-25).
        public let movePicker: MovePicker?

        /// What went wrong, as the finished sentence the view shows, and nil when there is nothing to say:
        /// `send` cannot throw, so a failure inside it has nowhere else to go, and a view that had to spell one
        /// would be a view holding logic (spec section 2). A list that could not be opened is said here, where
        /// the list that stays open is drawn beside it; what the list says about itself is in its own model.
        public let problem: String?
    }
}
