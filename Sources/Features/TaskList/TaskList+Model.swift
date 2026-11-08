// Sources/Features/TaskList/TaskList+Model.swift
import DesignSystemComponents
import TodoCore

extension TaskList {
    /// What a view draws: the screen's header, the tag bar, the blocks in the layout the list is shown as, Show as, the
    /// empty state, the Done strip, the rows that add and the sentence, each a model of the design system's components
    /// with every size, colour and word finished, so that a platform draws them and decides nothing but its containers,
    /// its gestures, scrolling and focus (spec sections 1 to 7; ADR-0007, amendment of 2026-10-30). It is computed from
    /// the module's state on every read and never kept beside it (owner's review of #101).
    public struct Model: Equatable, Sendable {
        /// The list's tile and title, and under them its date where its rule names one day, Today's; on a group's
        /// screen the list's tile, the group's name, and the list's title with the group's date (spec sections 1 and
        /// 2).
        public let header: ScreenHeaderModel

        /// The glass button that goes back, over the content at the top left.
        public let back: GlassButtonModel<UserAction>

        /// The glass button at the top right, the label of `showAs`, which it puts up.
        public let more: GlassButtonLabelModel

        /// How the screen itself stands: what it stands on, how the glass buttons and their fade stand over the
        /// content, and where the content starts and ends under them.
        public let style: ListScreenStyle

        /// The tags of the list's open tasks, the most used first, and nil when no chip would show (spec section 7).
        public let tagBar: TagBarModel<UserAction>?

        /// The blocks, as a list or as the board's columns.
        public let layout: Layout

        /// The menu `more` puts up, Show as: List, and Columns, disabled with its reason where there is nothing to show
        /// as columns, the layout the list is shown as checked (spec section 5).
        public let showAs: MenuModel<UserAction>

        /// What the screen shows when no block has a row, after the tag bar's filter, and the list has no lists inside,
        /// and nil otherwise (canvas, the empty state).
        public let empty: EmptyScreenModel?

        /// The Done strip's capsule, "Done today · N", after "+ Add list": nil for a list that draws finished tasks as
        /// its rows, Logbook's and Trash's, where nothing was done today or the tag bar's filter leaves none of it, and
        /// in columns, which have no strip (spec section 3; canvas).
        public let done: DoneStripModel<UserAction>?

        /// What stands under the capsule while it is open, none while it is closed: the tasks done, each a row, or the
        /// open card in its place, since a tap on a row of the strip opens its card like any row's (spec section 3; the
        /// controller's ruling on #176, 2026-11-05).
        public let doneRows: [Row]

        /// The floating "+", nil where no task can be added (spec section 4).
        public let addTask: FloatingButtonModel<UserAction>?

        /// "+ Add list" after the last block, nil on a group's screen, for a list that draws finished tasks as its
        /// rows, and in columns, where the board holds it (`Board.addList`; spec section 4).
        public let addList: AddRowModel<UserAction>?

        /// What went wrong, as the finished sentence the view shows, and nil when there is nothing to say: `send`
        /// cannot throw, so a failure inside it has nowhere else to go, and a view that had to spell one would be a
        /// view holding logic (spec section 2).
        public let problem: String?

        /// The shape of the screen's blocks, which a view switches over once to pick its container, every case drawn
        /// (`docs/style.md`, "Views").
        public enum Layout: Equatable, Sendable {
            /// One block under another, each with its header and its rows.
            case list([Block])

            /// The blocks side by side, each a column of cards (spec section 5).
            case columns(Board)

            /// The layout a person chooses in Show as, which the device keeps per list (ADR-0010).
            public enum Kind: String, Codable, Equatable, Sendable {
                case list, columns
            }
        }

        /// The blocks as the board's columns, each with its column's look, `spacing` apart, the board
        /// `horizontalPadding` in from the screen's sides, with `endRoom` more after the last column, and
        /// `bottomPadding` above its bottom, in points, snapping to a column as it scrolls where `snaps` says so: the
        /// phone's does, the Mac's scrolls freely (spec section 5).
        public struct Board: Equatable, Sendable {
            public let columns: [Block]
            public let spacing: Double
            public let horizontalPadding: Double
            public let endRoom: Double
            public let bottomPadding: Double
            public let snaps: Bool

            /// The dashed last column, "+ Add list", nil where the list has none to add (spec section 4).
            public let addList: AddRowModel<UserAction>?
        }

        /// A block of the screen: one of the list's own groups, or a list inside it (spec section 2).
        public struct Block: Equatable, Sendable, Identifiable {
            public let id: BlockID

            /// The block's header in the list, its title and the chevron that folds it, and nil for the own block of a
            /// list that groups by nothing, for the one block of a group's screen, and in columns, where the column's
            /// header is the block's (`column`), so that a block has one header and never two.
            public let header: BlockHeaderModel<UserAction>?

            /// The block's tasks, after the tag bar's filter, and none while it is folded.
            public let rows: [Row]

            /// Whether the block is folded, which it is only in the list: columns do not fold.
            public let isFolded: Bool

            /// The column's look in columns, its header among it, and nil in the list.
            public let column: ColumnModel<UserAction>?

            /// "+ Add task" at the block's end, nil where the block's rule reads as no edit and while it is folded
            /// (spec section 4; canvas).
            public let addTask: AddRowModel<UserAction>?

            /// Whether the block takes a dropped task, by its rule read as an edit, as its column's `isDropTarget` says
            /// it: a view draws no slot and no tint where it does not (spec section 6).
            public let takesDrop: Bool

            /// Whether a task dragged within the block lands where it is let go, its rows being one manual order: each
            /// of the list's own blocks, and a list inside with one group of rows. A list inside that groups its tasks
            /// orders each group apart, so a task dragged in it keeps to its group wherever it is let go, and a view
            /// marks no place there and takes no drop (the owner's review of #177, 2026-11-08).
            public let keepsDroppedPlace: Bool

            /// The mark of the place where a task dragged within the block would land among its rows, in the colour of
            /// its list, and nil in columns, where its column's tint marks the drop.
            public let indicator: DropIndicatorStyle?

            /// The block's look while a task dragged from another block would land in it, in the colour of its list,
            /// where the block takes it last or by its order and no line could say where; nil in columns, where its
            /// column's tint marks the drop (the owner's review of #177, 2026-11-08).
            public let dropTint: BlockDropStyle?
        }

        /// A row of a block, a view switching over its kind to pick the row to draw, every case drawn (`docs/style.md`,
        /// "Views"). The task's id is carried beside the component's model, which holds none of the store's.
        public enum Row: Equatable, Sendable, Identifiable {
            case task(TaskID, TaskRowModel<UserAction>)

            /// The task opened in place, one at a time, where its row stood (spec section 3).
            case card(TaskID, CardModel<UserAction>)

            public var id: TaskID {
                switch self {
                case .task(let id, _), .card(let id, _): id
                }
            }

            /// How the row looks lifted, and nil for one that cannot be: an open card, which is neither lifted nor has
            /// a menu (the controller's ruling on #177, 2026-11-07), and a row with no menu.
            public var lift: TaskLiftStyle? {
                switch self {
                case .task(_, let row): row.style.lift
                case .card: nil
                }
            }

            /// The row's swipe to its Delete, and nil for one that is not swiped: an open card, a row of the strip, a
            /// task in the Trash and a column's card.
            public var swipe: SwipeModel<UserAction>? {
                switch self {
                case .task(_, let row): row.swipe
                case .card: nil
                }
            }
        }

        /// What a block is, which an action names it by: one of the list's own blocks, by its group's key, nil for the
        /// one block of a list that groups by nothing; or a list inside, by its view.
        public enum BlockID: Hashable, Sendable {
            case own(GroupKey?)
            case list(ViewID)
        }
    }
}
