// Sources/Features/TaskViewList/TaskViewList+Rows.swift
import DesignSystem
import DesignSystemComponents
import FeatureModule
import TodoCore

extension TaskViewList {
    /// One row of the tree as a read of the store produced it, before anything about this person's session or this
    /// window is projected onto it. It is what the store answered and nothing else, which is what lets the same read
    /// serve a highlight that moves, a field that opens and a window that narrows without being read again.
    struct ReadRow {
        let id: ViewID
        let title: String
        let kind: TaskViewKind

        /// The store's names of the list's colour and icon, kept as the store gives them: a new list made inside this
        /// one takes its colour by the store's name, and the tile reads both as the design system's when the model is
        /// computed.
        let color: TaskViewColor?
        let icon: String?

        /// The depth the row is drawn at (`Model.Row.depth`).
        let depth: Int
        let hasChildren: Bool
    }

    /// The tree as one read produced it. `views()` answers parents before children with the effective parent
    /// already resolved, so a row's depth is its parent's plus one and the depths the walk has passed are all
    /// it carries: one pass, no stack, and a chain a thousand deep from sync reads like a flat list
    /// (`docs/style.md`, "No recursion over data-shaped depth"). A parent the walk has not passed reads as
    /// no parent, the way the core resolves a link it cannot use, rather than as a row left out of the list.
    ///
    /// The depth is the drawn one: under an area's line the lists stand at the line's own depth, since the line and
    /// not an indent says which area a list belongs to, and their lists one deeper (Lists screen spec, section 3). The
    /// store reads an area that is nested as a list, so the walk meets an area only at the root. In tree order a row's
    /// first child follows it at once, so a row has lists inside it exactly when the next row's parent is this row.
    static func rows(of store: Store) throws(StoreError) -> [ReadRow] {
        let views = try store.views()
        var passed: [ViewID: (depth: Int, isArea: Bool)] = [:]
        return views.indices.map { index in
            let view = views[index]
            let parent = view.parent.flatMap { passed[$0] }
            let depth = parent.map { $0.isArea ? $0.depth : $0.depth + 1 } ?? 0
            passed[view.id] = (depth, view.kind == .area)
            return ReadRow(
                id: view.id, title: view.title, kind: view.kind, color: view.color, icon: view.icon, depth: depth,
                hasChildren: views.indices.contains(index + 1) && views[index + 1].parent == view.id
            )
        }
    }

    /// The rows a person sees: every read row but the lists inside a folded one, however deep (Lists screen spec,
    /// section 5). One pass in tree order, like the read, carrying the folded row whose branch is hidden, with its
    /// depth: a folded list hides the rows deeper than itself that follow it, and the first row at its depth or above
    /// ends the branch and clears it. The depth is the drawn one, so an area's line folds nothing even with its id in
    /// the set, which no chevron on the line could take out: the lists under the line stand at its own depth, and the
    /// first of them ends the branch. That is what a list folded on this device comes to when a peer's move makes it
    /// read as an area again, an area that had arrived nested (ADR-0004, amendment of 2026-10-25).
    ///
    /// It answers in the same pass the row the highlight is on: the declared view's own row when it is shown, and the
    /// folded row that hides it when it is not, as the Finder lights a folder that closes over the selection (the
    /// owner, 2026-10-29, #158). A row inside a hidden branch is skipped before it is asked whether it folds, so of two
    /// folds above the declared row the one that hides it is the outer, which is the one drawn.
    static func unfolded(
        _ rows: [ReadRow], collapsedViews: Set<ViewID>, declared: ViewID?
    ) -> (rows: [ReadRow], highlighted: ViewID?) {
        var fold: (id: ViewID, depth: Int)?
        var shown: [ReadRow] = []
        var highlighted: ViewID?
        for row in rows {
            let hiddenBy = fold.flatMap { row.depth > $0.depth ? $0.id : nil }
            if row.id == declared { highlighted = hiddenBy ?? row.id }
            guard hiddenBy == nil else { continue }
            fold = collapsedViews.contains(row.id) ? (row.id, row.depth) : nil
            shown.append(row)
        }
        return (shown, highlighted)
    }

    /// The number of open tasks each view selects, which the store answers for every view in one call and which is
    /// read beside every read of the rows, since a change to any task can move any count (Lists screen spec, section
    /// 4). `today` is the UTC day of the machine's clock, read again at every read, as the task list reads its own
    /// rows (`TaskList.rows(of:in:)`): a count that depends on the day is stale across midnight until the next read,
    /// until the event that tells a module the day has changed exists (Lists screen spec, "Risks").
    static func counts(of store: Store) throws(StoreError) -> [ViewID: Int] {
        try store.taskCounts(today: Day(millisSinceEpoch: Store.systemNow()))
    }
}

extension TaskViewList.ReadRow {
    /// What the row draws in a window of the width class, with the count the store answered for it, whether the device
    /// holds it folded and whether it is the highlighted one: an area's line, which carries its name and nothing else,
    /// or a list's row with everything finished. A fold is drawn only on a list with lists inside it, where a chevron
    /// can take it back. The tile and the title's font are the Lists screen's layout, built here from the row and the
    /// width whenever the model is computed, so that a window that narrows or widens moves them with no read of the
    /// store (ADR-0007, amendment of 2026-10-26).
    func drawnKind(in width: WindowWidth, count: Int?, isFolded: Bool, isSelected: Bool) -> TaskViewList.Model.Kind {
        switch kind {
        case .area:
            return .area(label: title.isEmpty ? nil : title)
        case .list:
            let size = RowSize(width, depth: depth)
            return .list(TaskViewList.Model.ListRow(
                title: title, tile: size.tile(tileColor, tileIcon), titleFont: size.titleFont(emphasized: hasChildren),
                countText: count.flatMap { $0 > 0 ? String($0) : nil } ?? "", hasChildren: hasChildren,
                isCollapsed: hasChildren && isFolded, isSelected: isSelected
            ))
        }
    }

    /// The tile's colour, the store's name read as the design system's by its raw value, and stone for a list with
    /// none or with one the design system does not know, so that a platform draws every value it is given and picks no
    /// default of its own (ADR-0007, amendment of 2026-10-26).
    private var tileColor: DesignSystem.Color.Components.Tile {
        color.flatMap { DesignSystem.Color.Components.Tile(rawValue: $0.rawValue) } ?? .stone
    }

    /// The tile's glyph, the store's name of the icon read as the design system's, and the default glyph, bullets, for
    /// a list with none or with a name this app does not know, for the same reason.
    private var tileIcon: DesignSystem.Icon {
        icon.flatMap(DesignSystem.Icon.init(rawValue:)) ?? .bullets
    }
}

/// The three sizes a list's row takes on the Lists screen, which the window's width class and the row's drawn depth
/// choose between, so that the tile and the title's font are chosen by one rule.
private enum RowSize {
    /// A row at the root's drawn depth in a narrow window, the lists under an area's line among them.
    case root
    /// A row deeper than that in a narrow window.
    case nested
    /// A row of the sidebar in a wide window, at every depth.
    case sidebar

    init(_ width: WindowWidth, depth: Int) {
        switch width {
        case .narrow: self = depth == 0 ? .root : .nested
        case .wide: self = .sidebar
        }
    }

    /// The tile of the colour and the icon at this size, in points, as the canvas draws it: on the phone a side of
    /// 30, a corner radius of 8 and a glyph of 19 at the root's depth, and 26, 7 and 16 deeper (`Phone.dc.html`,
    /// `tileSize`); in the sidebar 20, 6 and 13 at every depth, the tile of the Mac's 30 pt row (`Mac.dc.html`).
    func tile(_ color: DesignSystem.Color.Components.Tile, _ icon: DesignSystem.Icon) -> TileModel {
        switch self {
        case .root: TileModel(color: color, icon: icon, side: 30, cornerRadius: 8, glyphSize: 19)
        case .nested: TileModel(color: color, icon: icon, side: 26, cornerRadius: 7, glyphSize: 16)
        case .sidebar: TileModel(color: color, icon: icon, side: 20, cornerRadius: 6, glyphSize: 13)
        }
    }

    /// The title's font at this size, emphasized for a row with lists inside it: the row title on the phone at the
    /// root's depth and in the sidebar at every depth, whose body a platform draws at its sidebar's size, 13 pt on the
    /// Mac and 17 on the iPad, and the nested row title, a size smaller, deeper on the phone.
    func titleFont(emphasized: Bool) -> DesignSystem.Font {
        switch (self, emphasized) {
        case (.root, false), (.sidebar, false): .rowTitle
        case (.root, true), (.sidebar, true): .rowTitleEmphasized
        case (.nested, false): .nestedRowTitle
        case (.nested, true): .nestedRowTitleEmphasized
        }
    }
}
