// Sources/Features/TaskViewList/TaskViewList+Components.swift
import DesignSystem
import DesignSystemComponents
import FeatureModule
import TodoCore

/// The models of the Lists screen's components, built from the rows and this person's session with the numbers Task 7's
/// views drew the phone's screen with from the canvas (`Phone.dc.html`): every size, gap, radius and line in points,
/// every colour, font, icon, animation and shadow a token of the design system, every word finished, in English until
/// the formatting service arrives, and every control's action a value. A platform draws them and decides nothing but
/// its container, its gestures, the drag, scrolling, focus and Reduce Motion (the owner, 2026-10-30; ADR-0007,
/// amendment of 2026-10-30). A wide window gets the same models with the sidebar's tiles and title fonts, which
/// `ReadRow` chooses by the width, and the phone's other numbers until the sidebar's own arrive (Lists screen plan,
/// Task 9).
extension TaskViewList {
    /// The rows a person sees as the screen draws them, an area's line or a list's row each, with the window and this
    /// person's session projected onto them: the tiles and the title fonts for the width; the counts, the grips and
    /// the menus as edit mode shows them, the menus with Open in New Window where a window can open beside this one;
    /// the folds; the highlight on `selection`; and the field, with its draft, on the row being renamed.
    ///
    /// One pass in tree order, like the read, carrying the centres of the tiles of the branch it is in, so that each
    /// list's row has a guide under every ancestor's tile (`Phone.dc.html`, `guidesFor`): in tree order a row's
    /// ancestor at a depth is the last list passed at that depth, and the lists under an area's line stand at the
    /// line's own depth, so the line takes no guide and its lists stand under none.
    static func drawnRows(
        _ rows: [ReadRow], in width: WindowWidth, isEditing: Bool, counts: [ViewID: Int], collapsedViews: Set<ViewID>,
        selection: ViewID?, rename: (id: ViewID, draft: String)?, supportsMultipleWindows: Bool
    ) -> [Model.Row] {
        var centres: [Double] = []
        return rows.map { row in
            let draft = rename.flatMap { $0.id == row.id ? $0.draft : nil }
            switch row.kind {
            case .area:
                let line = areaLine(
                    row, isEditing: isEditing, draft: draft, end: lineEnd(isEditing: isEditing),
                    tap: .rowSelected(row.id), menu: isEditing ? nil : lineMenu(row.id)
                )
                return Model.Row(id: row.id, depth: row.depth, kind: .area(line))
            case .list:
                // Edit mode takes the counts off the rows, and a count of zero is drawn as nothing on every list (Lists
                // screen spec, sections 1 and 4). A fold is drawn only on a list with lists inside it, where a chevron
                // can take it back.
                let count = isEditing ? nil : counts[row.id].flatMap { $0 > 0 ? $0 : nil }
                let fold = row.hasChildren ? chevron(row.id, isFolded: collapsedViews.contains(row.id)) : nil
                let list = listRow(
                    row, in: width, guides: Array(centres.prefix(row.depth)),
                    end: rowEnd(count: count, chevron: fold, hasGrip: isEditing), draft: draft,
                    isSelected: row.id == selection, tap: .rowSelected(row.id),
                    menu: isEditing ? nil : listMenu(row.id, supportsMultipleWindows: supportsMultipleWindows)
                )
                centres = list.childGuides
                return Model.Row(id: row.id, depth: row.depth, kind: .list(list))
            }
        }
    }

    /// The bar at the bottom of the screen (`Phone.dc.html`, the bar; Lists screen spec, sections 1 and 7): outside
    /// edit mode "…" on the platform's container, a menu holding Edit, the search capsule, and "+" on the accent, a
    /// menu holding New Task, New List and New Area in the canvas's order; in edit mode "+ List" and "+ Area" on one
    /// container, and Done, the check that ends edit mode, on the accent. The controls are 48 high, 10 apart and 16 in
    /// from the edges, their glyphs 20 pt semibold, Done's bold, in the ink on the container and white on the accent;
    /// the group's buttons are 40 high, their plus 15 pt and 6 before the word in the accent, 4 in from the group's
    /// ends, with a rule of the line colour 1 by 22 between the two.
    static func bar(isEditing: Bool) -> BarModel<UserAction> {
        let items: [BarModel<UserAction>.Item] = if isEditing {
            [
                .group([
                    groupButton("List", saying: Words.newList, .newListMenuItemChosen(in: nil)),
                    groupButton("Area", saying: Words.newArea, .newAreaMenuItemChosen),
                ]),
                .button(doneButton),
            ]
        } else {
            [.menuButton(moreButton), .search(searchField), .menuButton(addButton)]
        }
        return BarModel(
            items: items, controlHeight: 48, spacing: 10, padding: 16, groupButtonHeight: 40, groupButtonSpacing: 6,
            groupPadding: 4, groupDividerHeight: 22, groupDivider: StrokeModel(color: .line, width: 1, dash: [])
        )
    }

    /// The look of the drag (`Phone.dc.html`, the drag's slot and card), the same in a window of either width until the
    /// sidebar's arrive: the tree's indent; the slot 52 high with 44 drawn, from 6 before the tile of its depth to 12
    /// short of the right edge, rounded 13, on the accent's soft fill with a 1.5 pt accent stroke dashed 5 and 4; the
    /// card raised 6 above the row it lifts, grown to 1.03 and turned 1.5° left, casting the lifted shadow, on the
    /// surface: a list's 50 high from 2 before the tile of the slot's depth, its tile 12 in, its grip 18 pt in ink2 in
    /// a cell of 40, 6 short of the right edge and rounded 14, and a line's 36 high from 8 in to 8 short of the right
    /// edge, rounded 12, each at least 120 wide; the lift, the release and a move of the slot on the popover's motion.
    /// The canvas's overshoot of the card to 1.045 and its bob have no motion of the look and are left out.
    ///
    /// A line's card ends 8 short of the edge because Task 7 drew it 8 in and 16 narrower than the tree on screen: each
    /// trailing gap is how far short of the right edge a shape's right end stands, the list card's 6 and the slot's 12
    /// as much as the line card's.
    static let drag = DragModel(
        indent: Phone.indent, animation: .popover,
        slot: DragModel.Slot(
            height: 52, inset: 6, trailingGap: 12, verticalInset: 4, cornerRadius: 13, fill: .accentSoft,
            stroke: StrokeModel(color: .accent, width: 1.5, dash: [5, 4])
        ),
        card: DragModel.Card(
            raise: 6, scale: 1.03, rotation: -1.5, shadow: .lifted, background: .surface,
            grip: IconModel(icon: .grip, size: Phone.gripSize, weight: .regular, color: .ink2), gripCell: 40,
            minimumWidth: 120, listHeight: 50, listInset: 2, listPadding: 12, listTrailingGap: 6, listCornerRadius: 14,
            lineHeight: 36, lineInset: 8, lineTrailingGap: 8, lineCornerRadius: 12
        )
    )

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
    /// list being moved, its hint in ink2 says what to do 8 above the rows, and "Top level" is a row of its own, a 15
    /// pt divider glyph in ink2 on a 30 pt tile of the fill colour rounded 8, 20 in, checked when the list stands at
    /// the root. Its options are the whole tree in tree order with the folds ignored, each drawn by the screen's rules
    /// for the width with none of this person's session on it, since nothing in the picker is hidden, highlighted or
    /// renamed: no menu, no count, no chevron, no grip, no guides, and an unnamed area's line alone, as outside edit
    /// mode (the owner's answer on #160, thread r4415002540); each sends `movePickerRowTapped`. The list being moved
    /// and every list inside it cannot take it, and are drawn at 35 %; its present parent, a list, an area's line or
    /// the top level, has the check at its right and every other row the room for it (`Picker`); and an option is at
    /// least 36 high, so that an unnamed area's line is no 17 pt target.
    static func movePicker(
        moving list: ReadRow, among rows: [ReadRow], in width: WindowWidth
    ) -> PickerModel<Model.Kind, UserAction> {
        let inside = subtree(of: list.id, in: rows)
        let options = rows.map { row in
            let isChecked = row.id == list.parent
            let kind: Model.Kind = switch row.kind {
            case .area:
                .area(areaLine(
                    row, isEditing: false, draft: nil, end: Picker.lineEnd(isChecked: isChecked),
                    tap: .movePickerRowTapped(row.id), menu: nil
                ))
            case .list:
                .list(listRow(
                    row, in: width, guides: nil, end: Picker.rowEnd(isChecked: isChecked), draft: nil,
                    isSelected: false, tap: .movePickerRowTapped(row.id), menu: nil
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
                icon: IconModel(icon: .divider, size: 15, weight: .regular, color: .ink2), tileSide: 30,
                tileCornerRadius: 8, tileColor: .fill, tileToTitle: Phone.tileToTitle,
                title: TextModel(text: "Top level", font: .rowTitle, color: .ink), leading: 20, height: Phone.rowHeight,
                accessories: Picker.accessories(isChecked: list.parent == nil),
                cellMinimumWidth: Picker.cellMinimumWidth, endGap: Picker.endGap, isChecked: list.parent == nil,
                action: .movePickerRowTapped(nil)
            ),
            options: options, hintGap: 8, minimumOptionHeight: 36, disabledOpacity: 0.35
        )
    }

    /// A list's row, the screen's and the picker's (`Phone.dc.html`, `.vrow`): 46 high, its tile at the indent of its
    /// drawn depth with the title in the ink 12 after it, or the field in the title's place, at least the title's 140
    /// wide, 34 high, padded 10, rounded 10; a need of the tile, the gap, the title's 140 and the accessories
    /// (`Phone.dc.html`, a row's `need`); on the fill colour where it is highlighted and on the paper otherwise; the
    /// guides it stands under, 1.5 pt in the line colour, with those a row one level deeper stands under, its own and
    /// one under the centre of its tile; and what stands at its right, the tree's or the picker's. The picker draws no
    /// guides, so there `guides` is nil and the row and a row under it stand under none.
    private static func listRow(
        _ row: ReadRow, in width: WindowWidth, guides: [Double]?, end: RowEnd, draft: String?, isSelected: Bool,
        tap: UserAction, menu: MenuModel<UserAction>?
    ) -> ListRowModel<UserAction> {
        let leading = Phone.indent.leading(atDepth: row.depth)
        let tile = row.tile(in: width)
        let font = row.titleFont(in: width)
        return ListRowModel(
            height: Phone.rowHeight, leading: leading, tile: tile, tileToTitle: Phone.tileToTitle,
            title: TextModel(text: row.title, font: font, color: .ink),
            field: draft.map {
                titleField(
                    $0, placeholder: "Title", font: font, minimumWidth: Phone.titleWidth, height: 34, padding: 10,
                    cornerRadius: 10
                )
            },
            need: leading + tile.side + Phone.tileToTitle + Phone.titleWidth + end.accessoriesWidth,
            background: isSelected ? .fill : .paper, guides: guides ?? [],
            childGuides: guides.map { $0 + [leading + tile.side / 2] } ?? [],
            guide: StrokeModel(color: .line, width: 1.5, dash: []), accessories: end.accessories,
            fadeWidth: end.fadeWidth, countMinimumWidth: Phone.countWidth, cellMinimumWidth: end.cellMinimumWidth,
            endGap: end.endGap, accessoriesWidth: end.accessoriesWidth, tap: tap, menu: menu
        )
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

    /// What stands at a list's row's right in the tree (`Phone.dc.html`, the row's sticky end): over a fade of 10, the
    /// count in ink2 against the right of a cell at least 20 wide, or the cell kept empty where the row has no count;
    /// the chevron in a cell of 36, or the cell kept empty on a list with no lists inside it, so that the counts stand
    /// in one column; the grip in a cell of 36 more where the row drags; and 4 at the end, in the 72 pt of the row's
    /// need, which leaves 2 to spare, and 36 more with the grip. Each glyph's cell is 36 at least, wider than the glyph
    /// on every platform, so that the column holds.
    private static func rowEnd(count: Int?, chevron: AccessoryModel<UserAction>.Chevron?, hasGrip: Bool) -> RowEnd {
        let counted: AccessoryModel<UserAction> = if let count {
            .count(TextModel(text: String(count), font: .count, color: .ink2))
        } else {
            .space(Phone.countWidth)
        }
        let folds: AccessoryModel<UserAction> = if let chevron { .chevron(chevron) } else { .space(Phone.cellWidth) }
        return RowEnd(
            accessories: [counted, folds] + (hasGrip ? [.grip(Phone.grip)] : []), fadeWidth: 10,
            cellMinimumWidth: Phone.cellWidth, endGap: 4, accessoriesWidth: 72 + (hasGrip ? Phone.cellWidth : 0)
        )
    }

    /// The chevron of a list with lists inside it: 13 pt semibold in ink2, down while its branch is open and turned a
    /// quarter left while it is folded, turning on the popover's motion, saying what a tap on it will do, and sending
    /// the tap that folds or unfolds the branch.
    private static func chevron(_ id: ViewID, isFolded: Bool) -> AccessoryModel<UserAction>.Chevron {
        AccessoryModel.Chevron(
            icon: IconModel(icon: .chevron, size: 13, weight: .semibold, color: .ink2), rotation: isFolded ? -90 : 0,
            animation: .popover, accessibilityLabel: isFolded ? "Expand" : "Collapse", action: .disclosureTapped(id)
        )
    }

    /// An area's line (`Phone.dc.html`, the area's row): 20 in, its label in ink2, or the field in the label's place,
    /// 160 by 28, padded 8, rounded 8, then 10 after it the line, 1 pt in the line colour, and what stands at its
    /// right, the tree's or the picker's; 36 high with a label or a field and 17 with the line alone. The label is the
    /// area's name, and an unnamed area has none, the line alone being the whole of how it looks, but in edit mode,
    /// where it reads "Area", the label a tap renames it by (Lists screen spec, sections 1 and 3).
    private static func areaLine(
        _ row: ReadRow, isEditing: Bool, draft: String?, end: LineEnd, tap: UserAction, menu: MenuModel<UserAction>?
    ) -> AreaLineModel<UserAction> {
        let label: String? = if !row.title.isEmpty { row.title } else if isEditing { "Area" } else { nil }
        let field = draft.map {
            titleField(
                $0, placeholder: "Area name", font: .areaLabel, minimumWidth: 160, height: 28, padding: 8,
                cornerRadius: 8
            )
        }
        return AreaLineModel(
            height: label == nil && field == nil ? 17 : 36, leading: 20, spacing: 10,
            label: label.map { TextModel(text: $0, font: .areaLabel, color: .ink2) }, field: field,
            line: StrokeModel(color: .line, width: 1, dash: []), lineToAccessories: end.lineToAccessories,
            accessories: end.accessories, cellMinimumWidth: end.cellMinimumWidth, endGap: end.endGap, tap: tap,
            menu: menu
        )
    }

    /// What stands at an area's line's right, and the sizes it stands by (`AreaLineModel`): the tree's (`lineEnd`) or
    /// the picker's (`Picker.lineEnd`).
    private struct LineEnd {
        let lineToAccessories: Double
        let accessories: [AccessoryModel<UserAction>]
        let cellMinimumWidth: Double
        let endGap: Double
    }

    /// What stands at an area's line's right in the tree: nothing, the line ending 20 short of the edge, and in edit
    /// mode the grip, 10 after the line at the glyph's own width, as Task 7 drew it, in a cell of no least width, and
    /// 12 short of the edge.
    private static func lineEnd(isEditing: Bool) -> LineEnd {
        if isEditing {
            LineEnd(lineToAccessories: 10, accessories: [.grip(Phone.grip)], cellMinimumWidth: 0, endGap: 12)
        } else {
            LineEnd(lineToAccessories: 20, accessories: [], cellMinimumWidth: 0, endGap: 0)
        }
    }

    /// The title field, where a name is typed, a list's row's title or an area's line's name: the draft, in the ink on
    /// the surface with the accent's ring, 2 pt, at its minimum width and height, with its padding and its corners,
    /// sending Return, Esc and a lost focus as the field's three actions. What it sends as the person types is its
    /// view's to make from the text, `titleFieldChanged`.
    private static func titleField(
        _ draft: String, placeholder: String, font: DesignSystem.Font, minimumWidth: Double, height: Double,
        padding: Double, cornerRadius: Double
    ) -> TextFieldModel<UserAction> {
        TextFieldModel(
            text: draft, placeholder: placeholder, font: font, color: .ink, background: .surface,
            minimumWidth: minimumWidth, height: height, padding: padding, cornerRadius: cornerRadius,
            ring: StrokeModel(color: .accent, width: 2, dash: []), submitted: .titleFieldSubmitted,
            cancelled: .titleFieldCancelled, focusLost: .titleFieldLostFocus
        )
    }

    /// The menu of a list's row (Lists screen spec, section 6): Rename, New List, Open in New Window only where a
    /// window can open beside this one, which iPhone cannot (`docs/specs/navigation.md`, section 5), and Move to…,
    /// then, after a divider, Delete.
    private static func listMenu(_ id: ViewID, supportsMultipleWindows: Bool) -> MenuModel<UserAction> {
        let window: [MenuModel<UserAction>.Item] = if supportsMultipleWindows {
            [
                .init(
                    title: "Open in New Window", icon: .newWindow, isDestructive: false,
                    action: .openInNewWindowMenuItemChosen(id)
                ),
            ]
        } else {
            []
        }
        return MenuModel(sections: [
            .init(items: renameAndNewList(id) + window + [
                .init(title: "Move to…", icon: .folder, isDestructive: false, action: .moveToMenuItemChosen(id)),
            ]),
            .init(items: [
                .init(title: Words.delete, icon: .trash, isDestructive: true, action: .deleteMenuItemChosen(id)),
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
                .init(title: "Delete Area", icon: .trash, isDestructive: true, action: .deleteMenuItemChosen(id)),
            ]),
        ])
    }

    /// The two items every row's menu starts with: Rename, and New List, which makes the list inside the row's list or
    /// area.
    private static func renameAndNewList(_ id: ViewID) -> [MenuModel<UserAction>.Item] {
        [
            .init(title: "Rename", icon: .pen, isDestructive: false, action: .renameMenuItemChosen(id)),
            .init(title: Words.newList, icon: .plus, isDestructive: false, action: .newListMenuItemChosen(in: id)),
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
            .init(items: [.init(title: "Edit", icon: .grip, isDestructive: false, action: .editMenuItemChosen)]),
        ])
    )

    /// The search capsule: its magnifier, "Search" and the microphone in ink2, the glyphs 17 pt and the microphone in a
    /// cell of 36, 8 apart, 15 in from its start and 6 from its end. It sends nothing until the search epic (the owner,
    /// 2026-10-25).
    private static let searchField = SearchFieldModel(
        placeholder: TextModel(text: "Search", font: .search, color: .ink2),
        leadingIcon: IconModel(icon: .magnifier, size: 17, weight: .regular, color: .ink2),
        trailingIcon: IconModel(icon: .microphone, size: 17, weight: .regular, color: .ink2), trailingCell: 36,
        spacing: 8, leadingPadding: 15, trailingPadding: 6
    )

    /// "+", on the accent, a menu that makes a task, a list or an area: where each goes, and that a task is quick
    /// entry's, is the module's to decide (Lists screen spec, section 7).
    private static let addButton = MenuButtonModel<UserAction>(
        label: ButtonLabelModel(
            icon: IconModel(icon: .plus, size: 20, weight: .semibold, color: .onAccent), title: nil,
            accessibilityLabel: "Add", fill: .color(.accent)
        ),
        menu: MenuModel(sections: [
            .init(items: [
                .init(title: "New Task", icon: .checkCircle, isDestructive: false, action: .newTaskMenuItemChosen),
                .init(title: Words.newList, icon: .list, isDestructive: false, action: .newListMenuItemChosen(in: nil)),
                .init(title: Words.newArea, icon: .divider, isDestructive: false, action: .newAreaMenuItemChosen),
            ]),
        ])
    )

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

    /// The phone's numbers that more than one component shares, in points, which a window of either width takes until
    /// the sidebar's own arrive (Lists screen plan, Task 9).
    private enum Phone {
        /// The tree's indent: a tile of the root at 20 and each level 22 further (`Phone.dc.html`, `tileLeft`), which
        /// is also how far a finger carries a lifted row sideways to change its depth by one.
        static let indent = IndentModel(start: 20, step: 22)

        /// A list's row's height, and the picker's "Top level"'s.
        static let rowHeight: Double = 46

        /// The gap between a tile and its title, a row's and "Top level"'s.
        static let tileToTitle: Double = 12

        /// The least room a row's title takes, which its field takes too, and which a tree too deep for the screen's
        /// width scrolls sideways to give it (`Phone.dc.html`, a row's `need`).
        static let titleWidth: Double = 140

        /// The least width of a row's count's cell, which a row with no count keeps empty.
        static let countWidth: Double = 20

        /// The width of a row's chevron's cell and of its grip's: the least a glyph's cell takes, and what an empty
        /// chevron's cell keeps.
        static let cellWidth: Double = 36

        /// The size of the grip's glyph, a row's, a line's and a lifted row's card's.
        static let gripSize: Double = 18

        /// The grip of a row and of a line in edit mode, which says that it drags (Lists screen spec, section 7).
        static let grip = IconModel(icon: .grip, size: gripSize, weight: .regular, color: .ink3)
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
