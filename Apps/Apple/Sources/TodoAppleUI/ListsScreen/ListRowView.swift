// Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListRowView.swift
import SwiftUI
import TaskViewListFeature
import TodoCore

/// A list's row on the phone as the canvas draws it (`Phone.dc.html`, `.vrow`): the tile with its leading edge at
/// 20 + 22 × depth pt, and 12 pt after it the title in ink on one line, or the field while the row is being renamed,
/// 46 pt high and as wide as it is laid out. The tile and the title's font arrive built by the module for the row's
/// drawn depth, so the view builds no `TileModel` and picks no size (ADR-0007, amendment of 2026-10-26). The tree and
/// the move picker both draw it, each with what stands at its right: the count, the chevron and the grip in the tree
/// (`ListRowAccessories`), the check in the picker.
struct ListRowView: View {
    /// The height of a list's row.
    static let height: CGFloat = 46

    /// How much room a row's title takes at the least, which a tree too deep for the screen's width scrolls sideways to
    /// give it (`Phone.dc.html`, a row's `need`).
    static let minimumTitleWidth: CGFloat = 140

    private let list: TaskViewList.Model.ListRow
    private let depth: Int
    private let draft: String?
    private let send: (TaskViewList.UserAction) -> Void

    init(
        _ list: TaskViewList.Model.ListRow, depth: Int, draft: String?,
        send: @escaping (TaskViewList.UserAction) -> Void
    ) {
        self.list = list
        self.depth = depth
        self.draft = draft
        self.send = send
    }

    var body: some View {
        HStack(spacing: Self.tileToTitle) {
            ListTile(list.tile)
            if let draft {
                // The canvas's field on a row: 34 pt high, on the surface, with a 2 pt ring in the accent.
                TitleField("Title", draft: draft, send: send)
                    .font(Font(list.titleFont))
                    .foregroundStyle(Color(.ink))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(Color(.surface), in: .rect(cornerRadius: 10))
                    .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color(.accent), lineWidth: 2) }
            } else {
                Text(list.title)
                    .font(Font(list.titleFont))
                    .foregroundStyle(Color(.ink))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Self.tileLeading(atDepth: depth))
        .frame(height: Self.height)
    }

    /// The gap between the tile and the title.
    static let tileToTitle: CGFloat = 12

    /// How much further in each level of the tree stands (`Phone.dc.html`, `tileLeft`), which is also how far a finger
    /// carries a lifted row sideways to change its depth by one (`ListsDrag`).
    nonisolated static let indent: CGFloat = 22

    /// Where the tile of a row of the drawn depth starts, 20 pt from the tree's edge and an indent further for each
    /// level (`Phone.dc.html`, `tileLeft`): the one indent of the screen, which its guides, its slot and its card are
    /// placed by too.
    nonisolated static func tileLeading(atDepth depth: Int) -> CGFloat {
        20 + indent * CGFloat(depth)
    }
}

/// What stands at the right of a list's row in the tree (`Phone.dc.html`, the row's sticky end): the count in ink2, a
/// cell for the chevron, which holds it when the list has lists inside it, and the grip in edit mode. The tree pins it
/// to the right edge of the screen while the rows scroll sideways under it, so it is drawn on the row's own background,
/// which fades in over its first 10 pt, so that a title passing under it ends softly.
struct ListRowAccessories: View {
    /// How much of a row the accessories take, which the title leaves them: the fade's 10 pt, the count's 20 and the
    /// chevron's 36, the 6 the canvas leaves before them, and the grip's 36 in edit mode (`Phone.dc.html`, a row's
    /// `need`).
    static func width(isEditing: Bool) -> CGFloat {
        72 + (isEditing ? cellWidth : 0)
    }

    /// The width of the chevron's cell and of the grip's.
    private static let cellWidth: CGFloat = 36

    private let list: TaskViewList.Model.ListRow
    private let id: ViewID
    private let isEditing: Bool
    private let background: Color
    private let send: (TaskViewList.UserAction) -> Void

    /// Whether a person asked for less motion, which only the view can read: the chevron then turns without its
    /// animation (Lists screen spec, section 9).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        _ list: TaskViewList.Model.ListRow, id: ViewID, isEditing: Bool, background: Color,
        send: @escaping (TaskViewList.UserAction) -> Void
    ) {
        self.list = list
        self.id = id
        self.isEditing = isEditing
        self.background = background
        self.send = send
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(list.countText)
                .font(Font(.count))
                .foregroundStyle(Color(.ink2))
                .lineLimit(1)
                .frame(minWidth: 20, alignment: .trailing)
            // The chevron's cell stands on every row, so that the counts stand in one column (canvas).
            ZStack {
                if list.hasChildren {
                    Button { send(.disclosureTapped(id)) } label: {
                        // The canvas's chevron, down while the branch is open and turned a quarter left while it is
                        // folded, turning with the popover's motion.
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(.ink2))
                            .rotationEffect(.degrees(list.isCollapsed ? -90 : 0))
                            .animation(reduceMotion ? nil : Animation(.popover), value: list.isCollapsed)
                            .frame(width: Self.cellWidth, height: ListRowView.height)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(list.isCollapsed ? "Expand" : "Collapse")
                }
            }
            .frame(width: Self.cellWidth, height: ListRowView.height)
            if isEditing {
                RowGrip()
                    .foregroundStyle(Color(.ink3))
                    .frame(width: Self.cellWidth, height: ListRowView.height)
            }
            Color.clear.frame(width: 4, height: 1)
        }
        .padding(.leading, 10)
        .background {
            HStack(spacing: 0) {
                LinearGradient(colors: [background.opacity(0), background], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 10)
                background
            }
        }
    }
}

/// The grip of a row in edit mode, which says that the row drags (Lists screen spec, section 7): the canvas's three
/// lines, 20 pt, in the colour and the cell its row gives it. The drag itself starts anywhere on the row
/// (`ListsDragGesture`), so the grip says so and takes no gesture of its own.
struct RowGrip: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 18))
            .accessibilityHidden(true)
    }
}

/// The guides down the levels a row stands under, 1.5 pt in the line colour, one under the centre of each ancestor's
/// tile (`Phone.dc.html`, `.guide`), drawn the whole height of the row so that the rows of a branch join them into
/// lines.
struct TreeGuides: View {
    /// Where each guide's centre stands, from the tree's leading edge.
    private let centres: [CGFloat]

    init(_ centres: [CGFloat]) {
        self.centres = centres
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(centres.indices, id: \.self) { index in
                Rectangle()
                    .fill(Color(.line))
                    .frame(width: 1.5)
                    .offset(x: centres[index] - 0.75)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
