// Sources/Features/TaskViewList/TaskViewList+Components.swift
import DesignSystem
import DesignSystemComponents
import FeatureModule
import TodoCore

/// The models of the Lists screen's components, built from the rows and this person's session with the canvas's numbers
/// for the window's width: the phone's in a narrow window, as Task 7's views drew them from `Phone.dc.html`, and the
/// sidebar's in a wide one, the Mac board's (`Mac.dc.html`), which the Mac and the iPad draw alike (Lists screen spec,
/// section 8). Every size, gap, radius and line is in points, every colour, font, icon, animation and shadow a token of
/// the design system, every word finished, in English until the formatting service arrives, and every control's action
/// a value. A platform draws them and decides nothing but its container, its gestures, the drag, scrolling, focus and
/// Reduce Motion (the owner, 2026-10-30; ADR-0007, amendment of 2026-10-30). The numbers are one value per width
/// (`Metrics`), picked once where a model is built, so that no builder branches on the width; the bar is chosen by
/// whether the platform has edit mode instead (Lists screen plan, Task 9).
extension TaskViewList {
    /// The rows a person sees as the screen draws them, an area's line or a list's row each, with the window and this
    /// person's session projected onto them: the numbers of the width; the counts, the grips and the menus as edit
    /// mode shows them, the menus with Open in New Window where a window can open beside this one; the folds; the
    /// highlight on `selection`; and the field, with its draft, on the row being renamed.
    ///
    /// One pass in tree order, like the read, carrying the centres of the tiles of the branch it is in, so that each
    /// list's row has a guide under every ancestor's tile (`Phone.dc.html`, `guidesFor`): in tree order a row's
    /// ancestor at a depth is the last list passed at that depth, and the lists under an area's line stand at the
    /// line's own depth, so the line takes no guide and its lists stand under none.
    static func drawnRows(
        _ rows: [ReadRow], in width: WindowWidth, isEditing: Bool, counts: [ViewID: Int], collapsedViews: Set<ViewID>,
        selection: ViewID?, rename: (id: ViewID, draft: String)?, opensWindowsBeside: Bool
    ) -> [Model.Row] {
        let metrics = Metrics.of(width)
        var centres: [Double] = []
        return rows.map { row in
            let draft = rename.flatMap { $0.id == row.id ? $0.draft : nil }
            switch row.kind {
            case .area:
                let line = areaLine(
                    row, metrics, isEditing: isEditing, draft: draft,
                    end: isEditing ? metrics.line.editingEnd : metrics.line.end, tap: .rowSelected(row.id),
                    menu: isEditing ? nil : lineMenu(row.id)
                )
                return Model.Row(id: row.id, depth: row.depth, kind: .area(line))
            case .list:
                // Edit mode takes the counts off the rows, and a count of zero is drawn as nothing on every list (Lists
                // screen spec, sections 1 and 4). A fold is drawn only on a list with lists inside it, where a chevron
                // can take it back.
                let count = isEditing ? nil : counts[row.id].flatMap { $0 > 0 ? $0 : nil }
                let fold = row.hasChildren
                    ? chevron(row.id, isFolded: collapsedViews.contains(row.id), size: metrics.chevronSize) : nil
                let list = listRow(
                    row, metrics, guides: Array(centres.prefix(row.depth)),
                    end: rowEnd(count: count, chevron: fold, hasGrip: isEditing, metrics), draft: draft,
                    isHighlighted: row.id == selection,
                    background: metrics.rowBackground(isHighlighted: row.id == selection), tap: .rowSelected(row.id),
                    menu: isEditing ? nil : listMenu(row.id, opensWindowsBeside: opensWindowsBeside)
                )
                centres = list.childGuides
                return Model.Row(id: row.id, depth: row.depth, kind: .list(list))
            }
        }
    }

    /// The bar at the bottom of the screen, chosen by whether the platform has edit mode, and the same on every width
    /// (Lists screen plan, Task 9). Where it has edit mode (`Phone.dc.html`, the bar; Lists screen spec, sections 1 and
    /// 7): outside edit mode "…" on the platform's container, a menu holding Edit, the search capsule, and "+" on the
    /// accent, a menu holding New Task, New List and New Area in the canvas's order; in edit mode "+ List" and "+ Area"
    /// on one container, and Done, the check that ends edit mode, on the accent. The controls are 48 high, 10 apart and
    /// 16 in from the edges, on a bar as high as they are with no rule, their glyphs 20 pt semibold, Done's bold, in
    /// the ink on the container and white on the accent; the group's plus is 15 pt and in the accent. Where the
    /// platform has no edit mode, on the Mac, it is the bar without it, which nothing changes (`barWithoutEditMode`).
    static func bar(isEditing: Bool, hasEditMode: Bool) -> BarModel<UserAction> {
        guard hasEditMode else { return barWithoutEditMode }
        let items: [BarModel<UserAction>.Item] = if isEditing {
            [
                .group([
                    groupButton("List", saying: Words.newList, .newListMenuItemChosen(in: nil)),
                    groupButton("Area", saying: Words.newArea, .newAreaMenuItemChosen),
                ]),
                .button(doneButton),
            ]
        } else {
            [.menuButton(moreButton), .search(searchCapsule), .menuButton(addButton)]
        }
        return bar(items, height: 48, rule: nil, controlHeight: 48, spacing: 10, padding: 16)
    }

    /// The bar without edit mode (`Mac.dc.html`, the bottom of the column): the search field on the fill colour and
    /// "+", with its menu's shortcuts, 48 high under a rule 1 pt in the line colour, the controls 30 high, 8 apart and
    /// 10 in from the column's edges. It has no "…", which holds Edit alone, and no edit bar, since nothing enters edit
    /// mode, so no group stands on it.
    private static let barWithoutEditMode = bar(
        [.search(filledSearchField), .menuButton(addButtonWithShortcuts)], height: 48,
        rule: StrokeModel(color: .line, width: 1, dash: []), controlHeight: 30, spacing: 8, padding: 10
    )

    /// A bar of the items at its sizes, under its rule where it has one, with what every bar shares: a group's buttons
    /// 40 high, their glyph 6 before the word, 4 in from the group's ends, with a rule of the line colour 1 by 22
    /// between two, as the edit bar's group draws them; and the raised shadow under a button alone on a fill of its
    /// own, the canvas's small shadow on both its boards.
    private static func bar(
        _ items: [BarModel<UserAction>.Item], height: Double, rule: StrokeModel?, controlHeight: Double,
        spacing: Double, padding: Double
    ) -> BarModel<UserAction> {
        BarModel(
            items: items, height: height, rule: rule, controlHeight: controlHeight, spacing: spacing, padding: padding,
            groupButtonHeight: 40, groupButtonSpacing: 6, groupPadding: 4, groupDividerHeight: 22,
            groupDivider: StrokeModel(color: .line, width: 1, dash: []), buttonShadow: .raised
        )
    }

    /// The look of the drag in a window of the width (`Metrics.drag`), the same in and out of edit mode.
    static func drag(in width: WindowWidth) -> DragModel {
        Metrics.of(width).drag
    }

    /// The confirmation of a delete (Lists screen spec, section 6): the question, which names the list or the area, and
    /// what the delete takes with it and what it leaves, computed from the rows on every read, so that a list a peer
    /// puts under the one being deleted is counted among those that go with it; then Delete, which destroys, and
    /// Cancel.
    static func confirmation(deleting row: ReadRow, among rows: [ReadRow]) -> ConfirmationModel<UserAction> {
        let title: String
        let message: String
        switch row.kind {
        case .area:
            // An unnamed area has no name to put in the question, and an invented one is worse than none.
            title = row.title.isEmpty ? "Delete the area?" : "Delete the “\(row.title)” area?"
            message = "Its lists stay."
        case .list:
            let inside = subtree(of: row.id, in: rows).count - 1
            let going = switch inside {
            case 0: ""
            case 1: "One list inside it goes with it. "
            default: "\(inside) lists inside it go with it. "
            }
            title = "Delete “\(row.title)”?"
            message = going + "No task is deleted."
        }
        return ConfirmationModel(
            title: title, message: message,
            confirm: ChoiceModel(title: Words.delete, isDestructive: true, action: .deleteConfirmed),
            cancel: ChoiceModel(title: Words.cancel, isDestructive: false, action: .deleteCancelled)
        )
    }

    /// The picker of Move to… (Lists screen spec, section 6; `Phone.dc.html`, the Move to… sheet): its title names the
    /// list being moved, its hint in ink2 says what to do 8 above the rows, and "Top level" is a row of its own, the
    /// divider glyph in ink2 on a tile of the fill colour the size of a list's at the root's depth, where such a tile
    /// stands and as high as a row, checked when the list stands at the root. Its options are the whole tree in tree
    /// order with the folds ignored, each drawn by the screen's rules for the width with none of this person's session
    /// on it, since nothing in the picker is hidden, highlighted or renamed: no menu, no count, no chevron, no grip, no
    /// guides, and an unnamed area's line alone, as outside edit mode (the owner's answer on #160, thread r4415002540),
    /// and each list's row on the sheet's paper in every width (`Picker.background`); each sends `movePickerRowTapped`.
    /// The list being moved and every list inside it cannot take it, and are drawn at 35 %; its present parent, a list,
    /// an area's line or the top level, has the check at its right and every other row the room for it (`Picker`); and
    /// an option is at least the width's least option height.
    static func movePicker(
        moving list: ReadRow, among rows: [ReadRow], in width: WindowWidth
    ) -> PickerModel<Model.Kind, UserAction> {
        let metrics = Metrics.of(width)
        let inside = subtree(of: list.id, in: rows)
        let options = rows.map { row in
            let isChecked = row.id == list.parent
            let kind: Model.Kind = switch row.kind {
            case .area:
                .area(areaLine(
                    row, metrics, isEditing: false, draft: nil,
                    end: Picker.lineEnd(isChecked: isChecked),
                    tap: .movePickerRowTapped(row.id), menu: nil
                ))
            case .list:
                .list(listRow(
                    row, metrics, guides: nil, end: Picker.rowEnd(isChecked: isChecked), draft: nil,
                    isHighlighted: false, background: Picker.background, tap: .movePickerRowTapped(row.id),
                    menu: nil
                ))
            }
            return PickerModel<Model.Kind, UserAction>.Option(
                row: kind, isDisabled: inside.contains(row.id), isChecked: isChecked
            )
        }
        return PickerModel(
            title: "Move “\(list.title)” to…",
            hint: TextModel(text: "Choose where it goes.", font: .hint, color: .ink2),
            cancel: ChoiceModel(title: Words.cancel, isDestructive: false, action: .movePickerCancelled),
            topLevel: PickerModel.TopLevel(
                icon: IconModel(icon: .divider, size: metrics.topLevelGlyphSize, weight: .regular, color: .ink2),
                tileSide: metrics.root.tileSide, tileCornerRadius: metrics.root.tileCornerRadius, tileColor: .fill,
                tileToTitle: metrics.tileToTitle,
                title: TextModel(text: "Top level", font: metrics.root.title, color: .ink),
                leading: metrics.indent.start, height: metrics.rowHeight,
                accessories: Picker.accessories(isChecked: list.parent == nil),
                cellMinimumWidth: Picker.cellMinimumWidth, endGap: Picker.endGap,
                isChecked: list.parent == nil, action: .movePickerRowTapped(nil)
            ),
            options: options, hintGap: 8, minimumOptionHeight: metrics.minimumOptionHeight, disabledOpacity: 0.35
        )
    }

    /// A list's row, the screen's and the picker's (`Phone.dc.html`, `.vrow`; `Mac.dc.html`, a list's row): its tile at
    /// the indent of its drawn depth, at the sizes of that depth, with the title in the ink after it, in the title font
    /// of that depth, emphasized where the list has lists inside it, and in the sidebar where it is highlighted too, or
    /// the field in the title's place, at least the title's least width; a need of the tile, the gap, that width and
    /// the accessories (`Phone.dc.html` and `Mac.dc.html`, a row's `need`), from the tree's leading edge; on the
    /// background it is given, the tree's or the picker's; the guides it stands under, with those a row one level
    /// deeper stands under, its own and one under the centre of its tile; and what stands at its right, the tree's or
    /// the picker's. The picker draws no guides, so there `guides` is nil and the row and a row under it stand under
    /// none.
    private static func listRow(
        _ row: ReadRow, _ metrics: Metrics, guides: [Double]?, end: RowEnd, draft: String?, isHighlighted: Bool,
        background: RowBackground, tap: UserAction, menu: MenuModel<UserAction>?
    ) -> ListRowModel<UserAction> {
        let level = metrics.level(atDepth: row.depth)
        let leading = metrics.indent.leading(atDepth: row.depth)
        let tile = level.tile(row.tileColor, row.tileIcon)
        let isEmphasized = row.hasChildren || isHighlighted && metrics.emphasizesHighlight
        let font = isEmphasized ? level.emphasizedTitle : level.title
        return ListRowModel(
            height: metrics.rowHeight, leading: leading, tile: tile, tileToTitle: metrics.tileToTitle,
            title: TextModel(text: row.title, font: font, color: .ink),
            field: draft.map {
                titleField($0, placeholder: "Title", font: font, minimumWidth: metrics.titleWidth, metrics.rowField)
            },
            need: leading + tile.side + metrics.tileToTitle + metrics.titleWidth + end.accessoriesWidth,
            background: background.color, backgroundInset: background.inset, cornerRadius: background.cornerRadius,
            guides: guides ?? [],
            childGuides: guides.map { $0 + [leading + tile.side / 2] } ?? [], guide: metrics.guide,
            accessories: end.accessories, fadeWidth: end.fadeWidth, textMinimumWidth: metrics.countWidth,
            cellMinimumWidth: end.cellMinimumWidth, endGap: end.endGap, accessoriesWidth: end.accessoriesWidth,
            tap: tap, menu: menu
        )
    }

    /// What a list's row stands on (`ListRowModel`): its colour, how far in from either side of the tree it stands,
    /// and its corners' radius, the tree's (`Metrics.rowBackground`) or the picker's (`Picker.background`).
    private struct RowBackground {
        let color: DesignSystem.Color
        let inset: Double
        let cornerRadius: Double
    }

    /// What stands at a list's row's right, and the sizes it stands by (`ListRowModel`): the tree's (`rowEnd`) or the
    /// picker's (`Picker.rowEnd`).
    private struct RowEnd {
        let accessories: [AccessoryModel<UserAction>]
        let fadeWidth: Double
        let cellMinimumWidth: Double
        let endGap: Double

        /// How much of the row they take, which its need counts.
        let accessoriesWidth: Double
    }

    /// What stands at a list's row's right in the tree (`Phone.dc.html` and `Mac.dc.html`, the row's sticky end): over
    /// the width's fade, the count in ink2 against the right of a cell at least the count's width, or the cell kept
    /// empty where the row has no count; the chevron in a glyph's cell, or the cell kept empty on a list with no lists
    /// inside it, so that the counts stand in one column; the grip in a glyph's cell more where the row drags; and 4 at
    /// the end, in the width's room for the accessories, and a glyph's cell more with the grip. A glyph's cell is wider
    /// than the glyph on every platform, so that the column holds.
    private static func rowEnd(
        count: Int?, chevron: AccessoryModel<UserAction>.Chevron?, hasGrip: Bool, _ metrics: Metrics
    ) -> RowEnd {
        let counted: AccessoryModel<UserAction> = if let count {
            .text(TextModel(text: String(count), font: .count, color: .ink2))
        } else {
            .space(metrics.countWidth)
        }
        let folds: AccessoryModel<UserAction> = if let chevron { .chevron(chevron) } else { .space(metrics.cellWidth) }
        return RowEnd(
            accessories: [counted, folds] + (hasGrip ? [.grip(grip)] : []), fadeWidth: metrics.fadeWidth,
            cellMinimumWidth: metrics.cellWidth, endGap: 4,
            accessoriesWidth: metrics.accessoriesWidth + (hasGrip ? metrics.cellWidth : 0)
        )
    }

    /// The chevron of a list with lists inside it: `size` pt semibold in ink2, down while its branch is open and turned
    /// a quarter left while it is folded, turning on the popover's motion, saying what a tap on it will do, and sending
    /// the tap that folds or unfolds the branch.
    private static func chevron(_ id: ViewID, isFolded: Bool, size: Double) -> AccessoryModel<UserAction>.Chevron {
        AccessoryModel.Chevron(
            icon: IconModel(icon: .chevron, size: size, weight: .semibold, color: .ink2), rotation: isFolded ? -90 : 0,
            animation: .popover, accessibilityLabel: isFolded ? "Expand" : "Collapse", action: .disclosureTapped(id)
        )
    }

    /// An area's line (`Phone.dc.html`, the area's row; `Mac.dc.html`, an area's line): its label at the width's
    /// leading edge, or the field in the label's place at the field's, then the line after them, 1 pt in the line
    /// colour, and what stands at its right, the tree's or the picker's, as high as the width has a line with a field,
    /// with a label or alone. The label is the area's name, in capitals where the width writes them, and an unnamed
    /// area has none, the line alone being the whole of how it looks, but in edit mode, where it reads "Area", the
    /// label a tap renames it by (Lists screen spec, sections 1 and 3).
    private static func areaLine(
        _ row: ReadRow, _ metrics: Metrics, isEditing: Bool, draft: String?, end: LineEnd, tap: UserAction,
        menu: MenuModel<UserAction>?
    ) -> AreaLineModel<UserAction> {
        let line = metrics.line
        let name: String? = if !row.title.isEmpty { row.title } else if isEditing { "Area" } else { nil }
        let label = name.map { line.uppercasesLabel ? $0.uppercased() : $0 }
        let field = draft.map {
            titleField($0, placeholder: "Area name", font: line.fieldFont, minimumWidth: line.fieldWidth, line.field)
        }
        let height = if field != nil {
            line.fieldHeight
        } else if label != nil {
            line.labelledHeight
        } else {
            line.height
        }
        return AreaLineModel(
            height: height, leading: field == nil ? line.leading : line.fieldLeading, spacing: line.spacing,
            label: label.map { TextModel(text: $0, font: line.labelFont, color: line.labelColor) }, field: field,
            line: StrokeModel(color: .line, width: 1, dash: []), lineToAccessories: end.lineToAccessories,
            accessories: end.accessories, cellMinimumWidth: end.cellMinimumWidth, endGap: end.endGap, tap: tap,
            menu: menu
        )
    }

    /// What stands at an area's line's right, and the sizes it stands by (`AreaLineModel`): the tree's
    /// (`Metrics.Line`) or the picker's (`Picker.lineEnd`).
    private struct LineEnd {
        let lineToAccessories: Double
        let accessories: [AccessoryModel<UserAction>]
        let cellMinimumWidth: Double
        let endGap: Double
    }

    /// The title field, where a name is typed, a list's row's title or an area's line's name: the draft, in the ink on
    /// the surface with the accent's ring, 2 pt, at its minimum width and at its sizes, sending Return, Esc and a lost
    /// focus as the field's three actions. What it sends as the person types is its view's to make from the text,
    /// `titleFieldChanged`.
    private static func titleField(
        _ draft: String, placeholder: String, font: DesignSystem.Font, minimumWidth: Double, _ size: Metrics.FieldSize
    ) -> TextFieldModel<UserAction> {
        TextFieldModel(
            text: draft, placeholder: placeholder, font: font, color: .ink, background: .surface,
            minimumWidth: minimumWidth, height: size.height, padding: size.padding, cornerRadius: size.cornerRadius,
            ring: StrokeModel(color: .accent, width: 2, dash: []), submitted: .titleFieldSubmitted,
            cancelled: .titleFieldCancelled, focusLost: .titleFieldLostFocus
        )
    }

    /// The menu of a list's row (Lists screen spec, section 6): Rename, New List, Open in New Window only where a
    /// window can open beside this one, which iPhone cannot (`docs/specs/navigation.md`, section 5), and Move to…,
    /// then, after a divider, Delete.
    private static func listMenu(_ id: ViewID, opensWindowsBeside: Bool) -> MenuModel<UserAction> {
        let window: [MenuModel<UserAction>.Item] = if opensWindowsBeside {
            [
                .init(
                    title: "Open in New Window", icon: .newWindow, isDestructive: false, shortcut: nil,
                    action: .openInNewWindowMenuItemChosen(id)
                ),
            ]
        } else {
            []
        }
        return MenuModel(sections: [
            .init(items: renameAndNewList(id) + window + [
                .init(
                    title: "Move to…", icon: .folder, isDestructive: false, shortcut: nil,
                    action: .moveToMenuItemChosen(id)
                ),
            ]),
            .init(items: [
                .init(
                    title: Words.delete, icon: .trash, isDestructive: true, shortcut: nil,
                    action: .deleteMenuItemChosen(id)
                ),
            ]),
        ])
    }

    /// The menu of an area's line: Rename and New List, then, after a divider, Delete Area. It has no Move to…, since
    /// an area moves along the root alone, by the drag (Lists screen spec, section 6), and no Open in New Window, since
    /// an area never opens (section 2).
    private static func lineMenu(_ id: ViewID) -> MenuModel<UserAction> {
        MenuModel(sections: [
            .init(items: renameAndNewList(id)),
            .init(items: [
                .init(
                    title: "Delete Area", icon: .trash, isDestructive: true, shortcut: nil,
                    action: .deleteMenuItemChosen(id)
                ),
            ]),
        ])
    }

    /// The two items every row's menu starts with: Rename, and New List, which makes the list inside the row's list or
    /// area.
    private static func renameAndNewList(_ id: ViewID) -> [MenuModel<UserAction>.Item] {
        [
            .init(title: "Rename", icon: .pen, isDestructive: false, shortcut: nil, action: .renameMenuItemChosen(id)),
            .init(
                title: Words.newList, icon: .plus, isDestructive: false, shortcut: nil,
                action: .newListMenuItemChosen(in: id)
            ),
        ]
    }

    /// "…", on the platform's container, a menu holding Edit alone for now (the owner, 2026-10-25), with the grip's
    /// glyph.
    private static let moreButton = MenuButtonModel<UserAction>(
        label: ButtonLabelModel(
            icon: IconModel(icon: .ellipsis, size: 20, weight: .semibold, color: .ink), title: nil,
            accessibilityLabel: "More", fill: .container
        ),
        menu: MenuModel(sections: [
            .init(items: [
                .init(title: "Edit", icon: .grip, isDestructive: false, shortcut: nil, action: .editMenuItemChosen),
            ]),
        ])
    )

    /// The search capsule, on the platform's container: its magnifier, "Search" and the microphone in ink2, the glyphs
    /// 17 pt and the microphone in a cell of 36, 8 apart, 15 in from its start and 6 from its end, its corners half the
    /// bar's 48. It sends nothing until the search epic (the owner, 2026-10-25).
    private static let searchCapsule = SearchFieldModel(
        placeholder: TextModel(text: "Search", font: .search, color: .ink2),
        leadingIcon: IconModel(icon: .magnifier, size: 17, weight: .regular, color: .ink2),
        trailingGlyph: .init(icon: IconModel(icon: .microphone, size: 17, weight: .regular, color: .ink2), cell: 36),
        spacing: 8, leadingPadding: 15, trailingPadding: 6, fill: .container, cornerRadius: 24
    )

    /// The search field on the fill colour (`Mac.dc.html`, the bottom of the column): rounded 8, its magnifier 15 pt in
    /// ink2 9 in from its start, then 6 after it "Search" in ink2, the canvas's 13.5 pt, the body on the Mac, and 4 at
    /// its end. It has no trailing glyph and no hint of ⌘F, since no command answers ⌘F until the search epic, and
    /// sends nothing until then.
    private static let filledSearchField = SearchFieldModel(
        placeholder: TextModel(text: "Search", font: .search, color: .ink2),
        leadingIcon: IconModel(icon: .magnifier, size: 15, weight: .regular, color: .ink2), trailingGlyph: nil,
        spacing: 6, leadingPadding: 9, trailingPadding: 4, fill: .color(.fill), cornerRadius: 8
    )

    /// "+", on the accent, the menu that makes a task, a list or an area, its plus 20 pt semibold.
    private static let addButton = MenuButtonModel<UserAction>(
        label: ButtonLabelModel(
            icon: IconModel(icon: .plus, size: 20, weight: .semibold, color: .onAccent), title: nil,
            accessibilityLabel: "Add", fill: .color(.accent)
        ),
        menu: addMenu(newTask: nil, newList: nil)
    )

    /// "+" on the accent with its menu's shortcuts (`Mac.dc.html`, the "+" and its menu): its plus 16 pt bold, the
    /// canvas's stroke of 2.4 against the icons' 1.8; New Task ⌘N and New List ⇧⌘N.
    private static let addButtonWithShortcuts = MenuButtonModel<UserAction>(
        label: ButtonLabelModel(
            icon: IconModel(icon: .plus, size: 16, weight: .bold, color: .onAccent), title: nil,
            accessibilityLabel: "Add", fill: .color(.accent)
        ),
        menu: addMenu(
            newTask: .init(key: "n", modifiers: [.command]), newList: .init(key: "n", modifiers: [.shift, .command])
        )
    )

    /// The menu of "+", which makes a task, a list or an area, in the canvas's order, New Task and New List with the
    /// shortcuts they are given and New Area with none: where each goes, and that a task is quick entry's, is the
    /// module's to decide (Lists screen spec, section 7).
    private static func addMenu(
        newTask: MenuModel<UserAction>.Item.Shortcut?, newList: MenuModel<UserAction>.Item.Shortcut?
    ) -> MenuModel<UserAction> {
        MenuModel(sections: [
            .init(items: [
                .init(
                    title: "New Task", icon: .checkCircle, isDestructive: false, shortcut: newTask,
                    action: .newTaskMenuItemChosen
                ),
                .init(
                    title: Words.newList, icon: .list, isDestructive: false, shortcut: newList,
                    action: .newListMenuItemChosen(in: nil)
                ),
                .init(
                    title: Words.newArea, icon: .divider, isDestructive: false, shortcut: nil,
                    action: .newAreaMenuItemChosen
                ),
            ]),
        ])
    }

    /// Done, on the accent, the check that ends edit mode.
    private static let doneButton = ButtonModel<UserAction>(
        label: ButtonLabelModel(
            icon: IconModel(icon: .check, size: 20, weight: .bold, color: .onAccent), title: nil,
            accessibilityLabel: "Done", fill: .color(.accent)
        ),
        action: .doneButtonTapped
    )

    /// One half of the edit bar's group, a plus and the word in the accent, which makes a list at the end of the tree
    /// or an area at the end of the root, as "+" makes them, and reads aloud what its menu item says.
    private static func groupButton(
        _ word: String, saying accessibilityLabel: String, _ action: UserAction
    ) -> ButtonModel<UserAction> {
        ButtonModel(
            label: ButtonLabelModel(
                icon: IconModel(icon: .plus, size: 15, weight: .semibold, color: .accent),
                title: TextModel(text: word, font: .barLabel, color: .accent), accessibilityLabel: accessibilityLabel,
                fill: .container
            ),
            action: action
        )
    }

    /// The size of the grip's glyph, a row's, a line's and the phone's lifted row's card's.
    private static let gripSize: Double = 18

    /// The grip of a row and of a line in edit mode, which says that it drags (Lists screen spec, section 7), in ink3,
    /// the same on every width: the Mac board draws none, since the Mac has no edit mode, and the iPad's sidebar takes
    /// the phone's.
    private static let grip = IconModel(icon: .grip, size: gripSize, weight: .regular, color: .ink3)

    /// The numbers a window of one width draws the screen's components with, in points, which more than one builder
    /// reads, picked once by the width (`of(_:)`), so that no builder branches on it (Lists screen plan, Task 9): the
    /// phone's in a narrow window (`phone`) and the sidebar's in a wide one (`sidebar`). A place is measured from the
    /// tree's leading edge, and the sidebar's tree is the whole column, its content inset 10 from either side.
    private struct Metrics {
        /// A list's row at a level of the tree, the root's drawn depth, an area's lists among it, or deeper: its tile's
        /// side, corner radius and glyph's size, and its title's font, plain and emphasized.
        struct Level {
            let tileSide: Double
            let tileCornerRadius: Double
            let glyphSize: Double
            let title: DesignSystem.Font
            let emphasizedTitle: DesignSystem.Font

            /// A list's tile in the colour and with the icon its row reads from the store's names, at this level.
            func tile(_ color: DesignSystem.Color.Components.Tile, _ icon: DesignSystem.Icon) -> TileModel {
                TileModel(
                    color: color, icon: icon, side: tileSide, cornerRadius: tileCornerRadius, glyphSize: glyphSize
                )
            }
        }

        /// A field's height, the room between its edge and its text at either end, and its corners' radius.
        struct FieldSize {
            let height: Double
            let padding: Double
            let cornerRadius: Double
        }

        /// An area's line: as high as it is alone, with a label, and with a field; where the label starts, and where
        /// the field does in its place; the gap after either before the line; the label's font and colour, and whether
        /// the width writes it in capitals; what stands at its right outside edit mode and in it; and the field's least
        /// width, sizes and font.
        struct Line {
            let height: Double
            let labelledHeight: Double
            let fieldHeight: Double
            let leading: Double
            let fieldLeading: Double
            let spacing: Double
            let labelFont: DesignSystem.Font
            let labelColor: DesignSystem.Color
            let uppercasesLabel: Bool
            let end: LineEnd
            let editingEnd: LineEnd
            let fieldWidth: Double
            let field: FieldSize
            let fieldFont: DesignSystem.Font
        }

        /// The tree's indent, which is also how far a finger or the pointer carries a lifted row sideways to change its
        /// depth by one.
        let indent: IndentModel

        /// A list's row's height, and the picker's "Top level"'s.
        let rowHeight: Double

        /// A list's row at the root's drawn depth and deeper.
        let root: Level
        let nested: Level

        /// Whether the highlighted row's title is emphasized, which the sidebar's is and the phone's is not.
        let emphasizesHighlight: Bool

        /// The gap between a tile and its title, a row's and "Top level"'s.
        let tileToTitle: Double

        /// The least room a row's title takes, which its field takes too, and which a tree too deep for the window's
        /// width scrolls sideways to give it (a row's `need`).
        let titleWidth: Double

        let rowField: FieldSize

        /// A list's row's background, and the highlighted row's, how far in from either side of the tree it stands, and
        /// its corners' radius.
        let background: DesignSystem.Color
        let highlight: DesignSystem.Color
        let backgroundInset: Double
        let rowCornerRadius: Double

        /// The guides down the branches.
        let guide: StrokeModel

        /// A row's end: the fade before it; the least width of the count's cell, which a row with no count keeps
        /// empty; the least width of a glyph's cell, which an empty chevron's cell keeps; the room the accessories take
        /// in a row's need, without the grip; and the chevron's size.
        let fadeWidth: Double
        let countWidth: Double
        let cellWidth: Double
        let accessoriesWidth: Double
        let chevronSize: Double

        let line: Line

        /// The size of the divider glyph on "Top level"'s tile, and how high a picker's option is at least.
        let topLevelGlyphSize: Double
        let minimumOptionHeight: Double

        let drag: DragModel

        /// The numbers of the width.
        static func of(_ width: WindowWidth) -> Metrics {
            switch width {
            case .narrow: phone
            case .wide: sidebar
            }
        }

        /// The row at the drawn depth's level.
        func level(atDepth depth: Int) -> Level {
            depth == 0 ? root : nested
        }

        /// What a row of the tree stands on: the highlight's colour where it is highlighted and the tree's otherwise,
        /// at the width's inset and corners.
        func rowBackground(isHighlighted: Bool) -> RowBackground {
            RowBackground(
                color: isHighlighted ? highlight : background, inset: backgroundInset, cornerRadius: rowCornerRadius
            )
        }

        /// The phone's numbers, as Task 7's views drew them (`Phone.dc.html`). A tile of the root at 20 and each level
        /// 22 further (`tileLeft`); rows 46 high; a tile 30 across, rounded 8, its glyph 19 at the root's drawn depth,
        /// and 26, 7 and 16 deeper (`tileSize`), the title 12 after it, the row title at the root's depth and the
        /// nested row title deeper, emphasized over lists alone; a title at least 140 wide, its field 34 high, padded
        /// 10 and rounded 10; on the paper, or the fill colour where highlighted, the whole width of the tree with
        /// square corners; the guides 1.5 pt in the line colour; the end over a fade of 10, the count's cell at least
        /// 20 and a glyph's 36, in the 72 pt of the row's need, which leaves 2 to spare, the chevron 13 pt. An area's
        /// line 20 in with its field, its label in the area label's font in ink2 10 before the line, 36 high with a
        /// label or a field and 17 alone, ending 20 short of the edge, and in edit mode with the grip 10 after the line
        /// at the glyph's own width, 12 short of the edge, as Task 7 drew it; its field 160 by 28, padded 8 and rounded
        /// 8, in the area label's font. "Top level"'s divider glyph 15, and an option at least 36 high, so that an
        /// unnamed area's line is no 17 pt target. The drag's slot and card (`phoneDrag`).
        static let phone = Metrics(
            indent: phoneIndent, rowHeight: 46,
            root: Level(
                tileSide: 30, tileCornerRadius: 8, glyphSize: 19, title: .rowTitle, emphasizedTitle: .rowTitleEmphasized
            ),
            nested: Level(
                tileSide: 26, tileCornerRadius: 7, glyphSize: 16, title: .nestedRowTitle,
                emphasizedTitle: .nestedRowTitleEmphasized
            ),
            emphasizesHighlight: false, tileToTitle: 12, titleWidth: 140,
            rowField: FieldSize(height: 34, padding: 10, cornerRadius: 10), background: .paper, highlight: .fill,
            backgroundInset: 0, rowCornerRadius: 0, guide: StrokeModel(color: .line, width: 1.5, dash: []),
            fadeWidth: 10, countWidth: 20, cellWidth: 36, accessoriesWidth: 72, chevronSize: 13,
            line: Line(
                height: 17, labelledHeight: 36, fieldHeight: 36, leading: 20, fieldLeading: 20, spacing: 10,
                labelFont: .areaLabel, labelColor: .ink2, uppercasesLabel: false,
                end: LineEnd(lineToAccessories: 20, accessories: [], cellMinimumWidth: 0, endGap: 0),
                editingEnd: LineEnd(lineToAccessories: 10, accessories: [.grip(grip)], cellMinimumWidth: 0, endGap: 12),
                fieldWidth: 160, field: FieldSize(height: 28, padding: 8, cornerRadius: 8), fieldFont: .areaLabel
            ),
            topLevelGlyphSize: 15, minimumOptionHeight: 36, drag: phoneDrag
        )

        /// The sidebar's numbers, the Mac board's (`Mac.dc.html`), which the Mac and the iPad draw alike. The tree's
        /// content is inset 10 from the column's sides and a tile stands at 8 + 16 × depth inside it (`tileLeft`), so
        /// at 18 + 16 × depth from the column's edge; rows 30 high; a tile 22 across, rounded 6, its glyph 14 at the
        /// root's drawn depth, and 18, 5 and 12 deeper (`tileSize`), the title 8 after it in the row title at every
        /// depth, the body, 13 pt on the Mac where the canvas has 13.5 and 13, emphasized where the list has lists
        /// inside it or is highlighted (the title's weight, `on || ch ? 600 : 500`); a title at least 90 wide, its
        /// field 24 high, padded 6 and rounded 6; on the sidebar colour, or the selection where highlighted (`selBg`),
        /// inset 10 from the column's sides, the content's padding, and rounded 7; the guides 1 pt in the guide colour;
        /// the end over a fade of 8 from the row's background, the count's cell at least 18 and a glyph's 20, the
        /// chevron 12 pt, in the canvas's 70 of a row's need, its 50 for the count and the badge and 20 for the
        /// chevron, counted from the column's edge, which puts the canvas's 10 of inset into the need. An area's line
        /// 15 high with or without its name and 28 with a field, the name 18 in, the content's 8, in capitals in the
        /// area's caption in ink3, 6 before the line, which ends 18 short of the edge, 8 short of the content; in edit
        /// mode, which the iPad has, the grip 8 after the line in a glyph's cell, 14 short of the edge, the column of
        /// the rows' grips, since the canvas has none; its field 16 in, the canvas's 6 in the content, 160 by 22,
        /// padded 6 and rounded 6, in the canvas's 12.5 pt semibold, which the Mac's callout and body are as near to,
        /// the callout, 12 pt, keeping it below the rows' 13. "Top level"'s divider glyph 11, the phone's 15 to a
        /// list's 19 on the root's tile of 22 with its glyph of 14, and an option at least a row's 30 high. The drag's
        /// indicator and card (`sidebarDrag`).
        static let sidebar = Metrics(
            indent: sidebarIndent, rowHeight: 30,
            root: Level(
                tileSide: 22, tileCornerRadius: 6, glyphSize: 14, title: .rowTitle, emphasizedTitle: .rowTitleEmphasized
            ),
            nested: Level(
                tileSide: 18, tileCornerRadius: 5, glyphSize: 12, title: .rowTitle, emphasizedTitle: .rowTitleEmphasized
            ),
            emphasizesHighlight: true, tileToTitle: 8, titleWidth: 90,
            rowField: FieldSize(height: 24, padding: 6, cornerRadius: 6), background: .sidebar, highlight: .selection,
            backgroundInset: 10, rowCornerRadius: 7, guide: StrokeModel(color: .guide, width: 1, dash: []),
            fadeWidth: 8, countWidth: 18, cellWidth: 20, accessoriesWidth: 70, chevronSize: 12,
            line: Line(
                height: 15, labelledHeight: 15, fieldHeight: 28, leading: 18, fieldLeading: 16, spacing: 6,
                labelFont: .areaCaption, labelColor: .ink3, uppercasesLabel: true,
                end: LineEnd(lineToAccessories: 18, accessories: [], cellMinimumWidth: 0, endGap: 0),
                editingEnd: LineEnd(lineToAccessories: 8, accessories: [.grip(grip)], cellMinimumWidth: 20, endGap: 14),
                fieldWidth: 160, field: FieldSize(height: 22, padding: 6, cornerRadius: 6),
                fieldFont: .nestedRowTitleEmphasized
            ),
            topLevelGlyphSize: 11, minimumOptionHeight: 30, drag: sidebarDrag
        )

        /// The phone's indent, a tile of the root at 20 and each level 22 further, which its rows and its drag share.
        private static let phoneIndent = IndentModel(start: 20, step: 22)

        /// The sidebar's indent, a tile of the root at 18 from the column's edge and each level 16 further, which its
        /// rows and its drag share.
        private static let sidebarIndent = IndentModel(start: 18, step: 16)

        /// The phone's drag (`Phone.dc.html`, the drag's slot and card): the slot 52 high with 44 drawn, from 6 before
        /// the tile of its depth to 12 short of the right edge, rounded 13, on the accent's soft fill with a 1.5 pt
        /// accent stroke dashed 5 and 4; the card raised 6 above the row it lifts, grown to 1.03 and turned 1.5° left,
        /// casting the lifted shadow, on the surface: a list's 50 high from 2 before the tile of the slot's depth, its
        /// tile 12 in, its grip 18 pt in ink2 in a cell of 40, 6 short of the right edge and rounded 14, and a line's
        /// 36 high from 8 in to 8 short of the right edge, rounded 12, each at least 120 wide; the lift, the release
        /// and a move of the slot on the popover's motion. The canvas's overshoot of the card to 1.045 and its bob have
        /// no motion of the look and are left out.
        ///
        /// A line's card ends 8 short of the edge because Task 7 drew it 8 in and 16 narrower than the tree on screen:
        /// each trailing gap is how far short of the right edge a shape's right end stands, the list card's 6 and the
        /// slot's 12 as much as the line card's.
        private static let phoneDrag = DragModel(
            indent: phoneIndent, animation: .popover,
            look: .slot(
                DragModel.Slot(
                    height: 52, inset: 6, trailingGap: 12, verticalInset: 4, cornerRadius: 13, fill: .accentSoft,
                    stroke: StrokeModel(color: .accent, width: 1.5, dash: [5, 4])
                ),
                DragModel.Card(
                    raise: 6, scale: 1.03, rotation: -1.5, shadow: .lifted, background: .surface,
                    grip: IconModel(icon: .grip, size: gripSize, weight: .regular, color: .ink2), gripCell: 40,
                    minimumWidth: 120, listHeight: 50, listInset: 2, listPadding: 12, listTrailingGap: 6,
                    listCornerRadius: 14, lineHeight: 36, lineInset: 8, lineTrailingGap: 8, lineCornerRadius: 12
                )
            )
        )

        /// The sidebar's drag (`Mac.dc.html`, the drag's slot row and card), the Mac's and the iPad's alike, the iPad
        /// keeping only the phone's gestures: the lifted row leaves its place with nothing behind, and a gap of 12
        /// opens at the drop's place between the rows, holding the line, 2 pt in the accent with its ends rounded 1,
        /// from 2 after the tile of the drop's depth to 18 short of the edge, 8 short of the tree's content, and the
        /// circle, 10 across, ringed 2 pt in the accent and filled with the sidebar colour, 6 before that tile, both
        /// centred in the gap; and the card, 170 by 30, 14 after that tile, centred on the line, rounded 7, on the
        /// surface with the lifted shadow, turned 1.2° left at 95 % and grown by nothing, a list's tile on it 18
        /// across, rounded 5, its glyph 12, 10 in, and its title 8 after it in the sidebar's body, the canvas's 13 pt
        /// 500. The motion is the phone's, since the canvas's drag is frozen.
        private static let sidebarDrag = DragModel(
            indent: sidebarIndent, animation: .popover,
            look: .indicator(DragModel.Indicator(
                height: 12, line: StrokeModel(color: .accent, width: 2, dash: []), lineOffset: 2, lineCornerRadius: 1,
                trailingGap: 18, circleDiameter: 10, circleOffset: -6,
                circleRing: StrokeModel(color: .accent, width: 2, dash: []), circleFill: .sidebar,
                card: DragModel.Indicator.Card(
                    width: 170, height: 30, offset: 14, cornerRadius: 7, background: .surface, shadow: .lifted,
                    rotation: -1.2, opacity: 0.95, padding: 10, tileToTitle: 8, tileSide: 18, tileCornerRadius: 5,
                    glyphSize: 12, titleFont: .rowTitle
                )
            ))
        )
    }

    /// The picker's check (`Phone.dc.html`, the Move to… sheet): 15 pt bold in the accent at the glyph's own width, in
    /// a cell of no least width, 20 short of the right edge, at the right of the present choice, and hidden in its room
    /// at the right of every other row, so that the rows end in one column, as Task 7 drew it: "Top level", a list's
    /// row and an area's line, which ends 20 before it.
    private enum Picker {
        static let check = IconModel(icon: .check, size: 15, weight: .bold, color: .accent)
        static let cellMinimumWidth: Double = 0
        static let endGap: Double = 20

        /// The room a list's row's need counts for the check, the canvas's 18 px check: the glyph's own width is its
        /// platform's, and no view reads a need in the picker, where the rows are drawn whole.
        static let checkInNeed: Double = 18

        /// What a list's row stands on in the picker, in every width: the sheet's paper, the whole width and square, as
        /// the phone's sheet draws its rows, since the sheet stands on the paper and the sidebar's colour, inset and
        /// rounded, would stand on it as a stripe (the review of #149, 2026-10-31). The rows keep the width's tiles,
        /// indent, titles and ends.
        static let background = RowBackground(color: .paper, inset: 0, cornerRadius: 0)

        /// The check where a row is the present choice, and the check hidden in its room where it is not.
        static func accessories(isChecked: Bool) -> [AccessoryModel<UserAction>] {
            [isChecked ? .check(check) : .hidden(.check(check))]
        }

        /// What stands at a list's row's right in the picker: the check or its room, with no fade, since the row is
        /// drawn whole and nothing runs under it.
        static func rowEnd(isChecked: Bool) -> RowEnd {
            RowEnd(
                accessories: accessories(isChecked: isChecked), fadeWidth: 0, cellMinimumWidth: cellMinimumWidth,
                endGap: endGap, accessoriesWidth: checkInNeed + endGap
            )
        }

        /// What stands at an area's line's right in the picker: the check or its room, 20 after the line.
        static func lineEnd(isChecked: Bool) -> LineEnd {
            LineEnd(
                lineToAccessories: 20, accessories: accessories(isChecked: isChecked),
                cellMinimumWidth: cellMinimumWidth, endGap: endGap
            )
        }
    }

    /// The words of the commands more than one control gives: New List and New Area, a menu's items and the edit
    /// bar's buttons, a menu's Delete and the confirmation's, and the Cancel of both dialogs.
    private enum Words {
        static let newList = "New List"
        static let newArea = "New Area"
        static let delete = "Delete"
        static let cancel = "Cancel"
    }
}
