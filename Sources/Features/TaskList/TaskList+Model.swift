// Sources/Features/TaskList/TaskList+Model.swift
import DesignSystemComponents
import TodoCore

extension TaskList {
    /// What a view draws: the screen's header, the tag bar, the blocks in the layout the list is shown as, Show as, the
    /// empty state and the sentence, each a model of the design system's components with every size, colour and word
    /// finished, so that a platform draws them and decides nothing but its containers, its gestures, scrolling and
    /// focus (spec sections 1, 2, 5 and 7; ADR-0007, amendment of 2026-10-30). It is computed from the module's state
    /// on every read and never kept beside it (owner's review of #101).
    public struct Model: Equatable, Sendable {
        /// The list's tile and title, and under them its date where its rule names one day, Today's; on a group's
        /// screen the list's tile, the group's name, and the list's title with the group's date (spec sections 1 and
        /// 2).
        public let header: ScreenHeaderModel

        /// The tags of the list's open tasks, the most used first, and nil when no chip would show (spec section 7).
        public let tagBar: TagBarModel<UserAction>?

        /// The blocks, as a list or as the board's columns.
        public let layout: Layout

        /// "…" and its menu, Show as: List, and Columns, disabled with its reason where there is nothing to show as
        /// columns (spec section 5).
        public let showAs: MenuButtonModel<UserAction>

        /// What the screen shows when no block has a row, after the tag bar's filter, and the list has no lists inside,
        /// and nil otherwise (canvas, the empty state).
        public let empty: EmptyScreenModel?

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
        /// `horizontalPadding` in from the screen's sides and `bottomPadding` above its bottom, in points, snapping to
        /// a column as it scrolls where `snaps` says so: the phone's does, the Mac's scrolls freely (spec section 5).
        public struct Board: Equatable, Sendable {
            public let columns: [Block]
            public let spacing: Double
            public let horizontalPadding: Double
            public let bottomPadding: Double
            public let snaps: Bool
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
        }

        /// A row of a block, a view switching over its kind to pick the row to draw, every case drawn (`docs/style.md`,
        /// "Views"). The task's id is carried beside the component's model, which holds none of the store's.
        public enum Row: Equatable, Sendable, Identifiable {
            case task(TaskID, TaskRowModel<UserAction>)

            public var id: TaskID {
                switch self {
                case .task(let id, _): id
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
