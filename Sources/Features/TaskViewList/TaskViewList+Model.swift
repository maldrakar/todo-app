// Sources/Features/TaskViewList/TaskViewList+Model.swift
import DesignSystemComponents
import TodoCore

extension TaskViewList {
    /// What a view draws: the rows of the tree, the highlighted one and the one being renamed named once more for a
    /// view that reads them as one value, whether the screen is in edit mode, the bar and its "+" menu named once more
    /// for the app's menu bar, the look of the drag, the dialog up over the rows, and the sentence. The rows, the bar,
    /// the drag and the dialogs are the models of the components that draw them, built for the screen in
    /// `TaskViewList+Components.swift` with every value a platform needs to draw them, so that every platform draws the
    /// same components and no decision stays behind on one (ADR-0007, amendment of 2026-10-30).
    public struct Model: Equatable, Sendable {
        /// One row of the tree, an area's line or a list's row (spec section 5).
        public struct Row: Equatable, Sendable, Identifiable {
            public let id: ViewID

            /// The depth the row is drawn at, which its model is placed by already and the drag reads to find the
            /// block it lifts and the depths its slot can take: a list of the root at 0 and its lists at 1, and an
            /// area's line at 0 with the lists under it at 0 too and theirs at 1, since the line, and not an indent,
            /// says which area a list belongs to (spec section 3).
            public let depth: Int

            /// What the row is, which a view switches over once to pick the row it draws, every case drawn and no
            /// `default` (`docs/style.md`, "Views").
            public let kind: Kind
        }

        /// A row's kind, an enum so that a row is one of the two explicitly and never both or neither (the owner,
        /// 2026-10-25, on the spec's first revision), each the model of the component that draws it, which is a class,
        /// so that a row and an option of the picker hold a reference to it and not the model itself (`ListRowModel`).
        public enum Kind: Equatable, Sendable {
            /// An area's line, labelled with its name, and with none for an unnamed area, the line alone being the
            /// whole of how it looks (spec section 3), but in edit mode, where its label is "Area", the label a tap
            /// renames it by (spec section 1).
            case area(AreaLineModel<UserAction>)
            /// A list's row, with everything it draws.
            case list(ListRowModel<UserAction>)
        }

        public let rows: [Row]

        /// The id of the highlighted row, and nil when no row is highlighted: the highlight as one value, so that a
        /// reader that wants it reads a field instead of searching the rows for one (spec section 4).
        ///
        /// It is the highlight a list's row draws as its background, held a second way: a client that draws row by
        /// row reads the row. Both come off the same drawn rows when the model is assembled, so they name the same row
        /// or none.
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

        /// The id of the row whose field is open, and nil when no row drawn has one: what a view reads to show the
        /// field as it opens, the phone's screen scrolling to it, instead of searching the rows for it (the owner's 👍
        /// on #160's thread r4415002151). It comes off the same drawn rows as the field, so the two name the same row
        /// or none, and a row a fold hides has no field drawn.
        ///
        /// The field's text is the draft, what the person typed, down to the spaces at its ends; what the store keeps
        /// is that text trimmed (`commit`), since a caret is no place for the module to be moving text about. The draft
        /// is the module's, put on the row's field when the model is assembled and never kept in one. A read replaces
        /// every row, so a draft that lived in a row would be emptied by a peer's edit arriving while a person was
        /// typing. What ends it is its row going, which `reread` decides.
        public let renaming: ViewID?

        /// Whether the screen is in edit mode, entered from "…" and left with Done (spec section 7). What edit mode
        /// draws, every row and line with a grip, the counts empty, no menus, the labels it gives and its bar, is in
        /// the rows' and the bar's models already, so a view reads this for the drag, which only edit mode has where
        /// the platform has edit mode; one without it, the Mac, never enters it and drags its rows at any time (Lists
        /// screen plan, Task 9). It is session state, which no relaunch restores (ADR-0009, amendment of 2026-10-25).
        public let isEditing: Bool

        /// The bar at the bottom of the screen, its controls as edit mode has them or not (spec sections 1 and 7), and
        /// the Mac board's where the platform has no edit mode (Lists screen plan, Task 9).
        public let bar: BarModel<UserAction>

        /// The menu of the bar's "+", which makes a task, a list or an area, as the platform's bar holds it, with its
        /// shortcuts where the platform has no edit mode, and named once more for the app's menu bar, which draws its
        /// items wherever the bar is, in edit mode and with the sidebar hidden too: on the Mac a closed menu's items
        /// answer no key, so ⌘N and ⇧⌘N are the menu bar's (the controller's ruling on #149's hand check, 2026-10-31).
        public let addMenu: MenuModel<UserAction>

        /// The look of the drag for the window's width, whose gesture, lifted block, place and depth are the platform's
        /// (the owner, 2026-10-30).
        public let drag: DragModel

        /// The confirmation of a delete while it is up, and nil when none is: a view draws it as an alert, its title
        /// and message with its two choices, which send `deleteConfirmed` and `deleteCancelled` (spec section 6). It
        /// is the module's state and not a screen, and no relaunch restores it (ADR-0009, amendment of 2026-10-25).
        public let confirmation: ConfirmationModel<UserAction>?

        /// The picker of Move to… while it is open, and nil when it is closed: a view draws it as a sheet, "Top level"
        /// first and then its options, which send `movePickerRowTapped`, with its Cancel, which sends
        /// `movePickerCancelled` (spec section 6). Each option is a row of the tree of the kind the screen draws it
        /// as, so that a view draws it with the screen's own row, with the check at its right where it is the present
        /// choice and the room for one where it is not. It is the module's state and not a screen, and no relaunch
        /// restores it (ADR-0009, amendment of 2026-10-25).
        public let movePicker: PickerModel<Kind, UserAction>?

        /// What went wrong, as the finished sentence the view shows, and nil when there is nothing to say:
        /// `send` cannot throw, so a failure inside it has nowhere else to go, and a view that had to spell one
        /// would be a view holding logic (spec section 2). A list that could not be opened is said here, where
        /// the list that stays open is drawn beside it; what the list says about itself is in its own model.
        public let problem: String?
    }
}
