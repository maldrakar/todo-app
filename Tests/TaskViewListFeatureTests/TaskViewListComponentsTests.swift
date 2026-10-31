import Testing
import TestSupport
import DesignSystem
import DesignSystemComponents
import FeatureModule
import TaskViewListFeature
import TodoCore

private typealias Action = TaskViewList.UserAction

/// A sidebar made on no list in a window of the width, on the phone unless it is told a window can open beside it.
private func sidebar(
    _ store: Store, width: WindowWidth = .narrow, supportsMultipleWindows: Bool = false
) throws -> TaskViewList {
    try TaskViewList(store: store, route: .init(list: nil), width: width, supportsMultipleWindows: supportsMultipleWindows)
}

/// The area's line the model draws for a view, and nil when no row holds the view or its row is a list's.
private func areaLine(_ id: ViewID, in model: TaskViewList.Model) -> AreaLineModel<Action>? {
    guard case .area(let line)? = model.rows.first(where: { $0.id == id })?.kind else { return nil }
    return line
}

/// The menu of a list's row (Lists screen spec, section 6): Rename, New List, Open in New Window where a window can
/// open beside this one, and Move to…, then, after a divider, Delete.
private func listMenu(_ id: ViewID, openInNewWindow: Bool) -> MenuModel<Action> {
    let window: [MenuModel<Action>.Item] = openInNewWindow
        ? [.init(title: "Open in New Window", icon: .newWindow, isDestructive: false, action: .openInNewWindowMenuItemChosen(id))]
        : []
    return MenuModel(sections: [
        .init(items: [
            .init(title: "Rename", icon: .pen, isDestructive: false, action: .renameMenuItemChosen(id)),
            .init(title: "New List", icon: .plus, isDestructive: false, action: .newListMenuItemChosen(in: id)),
        ] + window + [
            .init(title: "Move to…", icon: .folder, isDestructive: false, action: .moveToMenuItemChosen(id)),
        ]),
        .init(items: [.init(title: "Delete", icon: .trash, isDestructive: true, action: .deleteMenuItemChosen(id))]),
    ])
}

/// The menu of an area's line: Rename and New List, then, after a divider, Delete Area; no Move to…, since an area
/// moves along the root alone, by the drag, and no Open in New Window, since an area never opens.
private func lineMenu(_ id: ViewID) -> MenuModel<Action> {
    MenuModel(sections: [
        .init(items: [
            .init(title: "Rename", icon: .pen, isDestructive: false, action: .renameMenuItemChosen(id)),
            .init(title: "New List", icon: .plus, isDestructive: false, action: .newListMenuItemChosen(in: id)),
        ]),
        .init(items: [.init(title: "Delete Area", icon: .trash, isDestructive: true, action: .deleteMenuItemChosen(id))]),
    ])
}

/// The grip of a row and of a line in edit mode, 18 pt in ink3.
private let grip = IconModel(icon: .grip, size: 18, weight: .regular, color: .ink3)

/// The phone's accessories in the tree, in their order: the count in ink2, or its cell kept empty, 20 wide, where the
/// row has none; the chevron, or its cell kept empty, 36 wide; and the grip in edit mode.
private func accessories(
    count: String?, chevron: AccessoryModel<Action>.Chevron?, isEditing: Bool = false
) -> [AccessoryModel<Action>] {
    [
        count.map { .text(TextModel(text: $0, font: .count, color: .ink2)) } ?? .space(20),
        chevron.map { .chevron($0) } ?? .space(36),
    ] + (isEditing ? [.grip(grip)] : [])
}

/// The chevron of a list with lists inside it, down while its branch is open and a quarter turned left while it is
/// folded, saying what a tap will do.
private func chevron(_ id: ViewID, folded: Bool) -> AccessoryModel<Action>.Chevron {
    .init(
        icon: IconModel(icon: .chevron, size: 13, weight: .semibold, color: .ink2), rotation: folded ? -90 : 0,
        animation: .popover, accessibilityLabel: folded ? "Expand" : "Collapse", action: .disclosureTapped(id)
    )
}

/// The guides under every list's row, 1.5 pt in the line colour.
private let guide = StrokeModel(color: .line, width: 1.5, dash: [])

/// A field a name is typed into, the title's on a list's row and the name's on an area's line: in the ink on the
/// surface with the accent's ring, sending Return, Esc and a lost focus as the title field's.
private func field(
    _ text: String, placeholder: String, font: DesignSystem.Font, minimumWidth: Double, height: Double, padding: Double,
    cornerRadius: Double
) -> TextFieldModel<Action> {
    TextFieldModel(
        text: text, placeholder: placeholder, font: font, color: .ink, background: .surface, minimumWidth: minimumWidth,
        height: height, padding: padding, cornerRadius: cornerRadius,
        ring: StrokeModel(color: .accent, width: 2, dash: []), submitted: .titleFieldSubmitted,
        cancelled: .titleFieldCancelled, focusLost: .titleFieldLostFocus
    )
}

/// The field on a list's row, in the row's title font: 140 by 34, padded 10 and rounded 10, with the canvas's
/// placeholder.
private func titleField(_ text: String, font: DesignSystem.Font) -> TextFieldModel<Action> {
    field(text, placeholder: "Title", font: font, minimumWidth: 140, height: 34, padding: 10, cornerRadius: 10)
}

/// A list's row whole as the phone draws it outside edit mode, but for what a test spells: its title and title font,
/// its tile, where it starts, its need, its guides, its count and its chevron. It is 46 high with the title 12 after
/// the tile in the ink, on the paper with no field, under guides 1.5 pt in the line colour, its accessories over a fade
/// of 10, the count's cell at least 20 wide and the others at least 36, with 4 at the end, in the 72 of its need, and a
/// tap selects it; its menu is a list's on a phone.
private func phoneRow(
    _ id: ViewID, title: String, font: DesignSystem.Font, tile: TileModel, leading: Double, need: Double,
    guides: [Double], childGuides: [Double], count: String?, chevron: AccessoryModel<Action>.Chevron?
) -> ListRowModel<Action> {
    ListRowModel(
        height: 46, leading: leading, tile: tile, tileToTitle: 12,
        title: TextModel(text: title, font: font, color: .ink), field: nil, need: need, background: .paper,
        guides: guides, childGuides: childGuides, guide: guide,
        accessories: accessories(count: count, chevron: chevron), fadeWidth: 10, textMinimumWidth: 20,
        cellMinimumWidth: 36, endGap: 4, accessoriesWidth: 72,
        tap: .rowSelected(id), menu: listMenu(id, openInNewWindow: false)
    )
}

/// The chevron the model draws on a view's row, and nil where it draws none.
private func chevron(of id: ViewID, in model: TaskViewList.Model) -> AccessoryModel<Action>.Chevron? {
    listRow(id, in: model).flatMap(drawnChevron)
}

/// An area's line whole as the phone draws it, but for what a test spells: its height, its label, the text of its
/// field where one is open, whether it has the grip, and its menu. It starts 20 in, the label in the area label's font
/// in ink2 10 before the line, 1 pt in the line colour, and a tap on it is sent as the row's selection; the line ends
/// 20 short of the edge, and with the grip 10 before it, at the glyph's own width in a cell of no least width, 12 short
/// of the edge.
private func phoneLine(
    _ id: ViewID, height: Double, label: String?, fieldText: String?, hasGrip: Bool, menu: MenuModel<Action>?
) -> AreaLineModel<Action> {
    AreaLineModel(
        height: height, leading: 20, spacing: 10,
        label: label.map { TextModel(text: $0, font: .areaLabel, color: .ink2) }, field: fieldText.map(areaField),
        line: StrokeModel(color: .line, width: 1, dash: []), lineToAccessories: hasGrip ? 10 : 20,
        accessories: hasGrip ? [.grip(grip)] : [], cellMinimumWidth: 0, endGap: hasGrip ? 12 : 0, tap: .rowSelected(id),
        menu: menu
    )
}

/// The field on an area's line: 160 by 28, padded 8 and rounded 8, in the area label's font, with the canvas's
/// placeholder.
private func areaField(_ text: String) -> TextFieldModel<Action> {
    field(text, placeholder: "Area name", font: .areaLabel, minimumWidth: 160, height: 28, padding: 8, cornerRadius: 8)
}

/// A root list's row and a nested one's carry the phone's numbers whole (`Phone.dc.html`; Task 7's views): 46 high,
/// the tile at 20 + 22 × depth with the title 12 after it, a need of the tile, the gap, a title of 140 and the 72 of the
/// accessories, the guides of the levels it stands under, the count, a list with no rule counting the lists inside it,
/// the chevron where the list has lists inside it, and the menu of a list, with no Open in New Window on a phone. A tap
/// on the row sends its selection.
@Test func aRootAndANestedListsRowsCarryThePhonesNumbers() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk"))
    let projects = try store.createView(NewTaskView(title: "Projects", color: .teal, icon: "folder"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects, icon: "house", filter: .status([.open])))
    let model = try sidebar(store).model
    #expect(listRow(projects, in: model) == phoneRow(
        projects, title: "Projects", font: .rowTitleEmphasized,
        tile: TileModel(color: .teal, icon: .folder, side: 30, cornerRadius: 8, glyphSize: 19), leading: 20, need: 274,
        guides: [], childGuides: [35], count: "1", chevron: chevron(projects, folded: false)
    ))
    #expect(listRow(home, in: model) == phoneRow(
        home, title: "Home", font: .nestedRowTitle,
        tile: TileModel(color: .stone, icon: .house, side: 26, cornerRadius: 7, glyphSize: 16), leading: 42, need: 292,
        guides: [35], childGuides: [35, 55], count: "1", chevron: nil
    ))
}

/// The highlighted row stands on the fill colour and every other on the paper, accessories included, which is all a
/// view draws of the highlight row by row.
@Test func theHighlightedRowStandsOnTheFillColour() throws {
    let store = try makeStore()
    let model = try sidebar(store).model
    #expect(model.rows.map { listRow($0)?.background } == [.fill, .paper, .paper, .paper, .paper])
}

/// The guides run under the centre of every ancestor's tile, so a row three deep stands under three; an area's line
/// draws none and ends the branch above it, so its lists stand under none, and theirs under their own.
@Test func theGuidesRunUnderTheAncestorsTiles() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects))
    let garden = try store.createView(NewTaskView(title: "Garden", parent: home))
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    let acme = try store.createView(NewTaskView(title: "Acme", parent: clients))
    let model = try sidebar(store).model
    let guides = [projects, home, garden, clients, acme].map { listRow($0, in: model).map { [$0.guides, $0.childGuides] } }
    #expect(guides == [[[], [35]], [[35], [35, 55]], [[35, 55], [35, 55, 77]], [[], [35]], [[35], [35, 55]]])
}

/// A fold turns the chevron a quarter left and says Expand, and the unfold turns it back and says Collapse, on the
/// popover's motion either way.
@Test func aFoldTurnsTheChevronAndChangesWhatItSays() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    try store.createView(NewTaskView(title: "Home", parent: projects))
    let list = try sidebar(store)
    #expect(chevron(of: projects, in: list.model) == chevron(projects, folded: false))
    _ = list.send(.action(.disclosureTapped(projects)))
    #expect(chevron(of: projects, in: list.model) == chevron(projects, folded: true))
    _ = list.send(.action(.disclosureTapped(projects)))
    #expect(chevron(of: projects, in: list.model) == chevron(projects, folded: false))
}

/// An area's line on the phone (`Phone.dc.html`, the area's row): 20 in, the label 10 before the line and the line 20
/// short of the edge, a named area's label in ink2 on a line 36 high and an unnamed area's line alone, 17 high, each
/// with the menu of a line. Renamed, the field takes the label's place, 160 by 28 on the surface with the accent's
/// ring, and the line is 36 high. In edit mode the grip comes, 12 short of the edge, no menu, and an unnamed area is
/// labelled "Area".
@Test func anAreasLineUnnamedNamedRenamingAndInEditMode() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let unnamed = try store.createView(NewTaskView(title: "", kind: .area))
    let list = try sidebar(store)
    #expect(areaLine(work, in: list.model) == phoneLine(
        work, height: 36, label: "Work", fieldText: nil, hasGrip: false, menu: lineMenu(work)
    ))
    #expect(areaLine(unnamed, in: list.model) == phoneLine(
        unnamed, height: 17, label: nil, fieldText: nil, hasGrip: false, menu: lineMenu(unnamed)
    ))
    _ = list.send(.action(.renameMenuItemChosen(unnamed)))
    #expect(areaLine(unnamed, in: list.model) == phoneLine(
        unnamed, height: 36, label: nil, fieldText: "", hasGrip: false, menu: lineMenu(unnamed)
    ))
    _ = list.send(.action(.titleFieldCancelled))
    _ = list.send(.action(.editMenuItemChosen))
    #expect(areaLine(unnamed, in: list.model) == phoneLine(
        unnamed, height: 36, label: "Area", fieldText: nil, hasGrip: true, menu: nil
    ))
    #expect(areaLine(work, in: list.model) == phoneLine(
        work, height: 36, label: "Work", fieldText: nil, hasGrip: true, menu: nil
    ))
}

/// Open in New Window is in a list's menu only where a window can open beside this one, which the sidebar is told
/// when it is made, and never in a line's; in edit mode no row has a menu, every row takes the grip and its cell, and
/// the counts are empty (Lists screen spec, sections 6 and 7).
@Test func theMenusFollowWhetherAWindowCanOpenAndGoInEditMode() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk"))
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    let phone = try sidebar(store).model
    let mac = try sidebar(store, supportsMultipleWindows: true).model
    #expect(listRow(clients, in: phone)?.menu == listMenu(clients, openInNewWindow: false))
    #expect(listRow(clients, in: mac)?.menu == listMenu(clients, openInNewWindow: true))
    #expect(areaLine(work, in: phone)?.menu == lineMenu(work))
    #expect(areaLine(work, in: mac)?.menu == lineMenu(work))
    #expect(listRow(inbox, in: mac).map(drawnCount) == "1", "the Inbox counts its task; this is the setup")

    let editing = try sidebar(store, supportsMultipleWindows: true)
    _ = editing.send(.action(.editMenuItemChosen))
    let lists = editing.model.rows.compactMap(listRow)
    #expect(lists.map(\.menu) == Array(repeating: nil, count: 6))
    let gripped = accessories(count: nil, chevron: nil, isEditing: true)
    #expect(lists.map(\.accessories) == Array(repeating: gripped, count: 6), "no count, no chevron, and the grip")
    #expect(lists.map(\.accessoriesWidth) == Array(repeating: 108, count: 6), "72 and the grip's cell of 36")
    #expect(
        lists.map(\.need) == Array(repeating: 310, count: 6), "20 + 30 + 12 + 140 + 108, the grip's cell among them"
    )
    #expect(lists.map(\.fadeWidth) == Array(repeating: 10, count: 6), "the fade stays in edit mode")
    #expect(lists.map(\.textMinimumWidth) == Array(repeating: 20, count: 6), "the empty count's cell holds the column")
    #expect(lists.map(\.cellMinimumWidth) == Array(repeating: 36, count: 6), "the grip's cell is a chevron's")
    #expect(lists.map(\.endGap) == Array(repeating: 4, count: 6), "4 at the end, after the grip")
    #expect(areaLine(work, in: editing.model)?.menu == nil)
    #expect(areaLine(work, in: editing.model)?.accessories == [.grip(grip)])
}

/// The bar at the bottom of the screen (`Phone.dc.html`, the bar): outside edit mode "…" on the glass with Edit, the
/// search capsule, and "+" on the accent with New Task, New List and New Area; in edit mode "+ List" and "+ Area" on
/// one capsule, and Done on the accent. The controls are 48 high, 10 apart and 16 in; their glyphs 20 semibold, Done's
/// bold, in the ink or white on the accent; the group's buttons 40 high, each a 15 pt plus 6 before its word in the
/// accent, 4 in from the capsule's ends, with a 1 by 22 rule between the two.
@Test func theBarInAndOutOfEditMode() throws {
    let list = try sidebar(try makeStore())
    #expect(list.model.bar == barOutsideEditMode())
    _ = list.send(.action(.editMenuItemChosen))
    #expect(list.model.bar == barInEditMode())
    _ = list.send(.action(.doneButtonTapped))
    #expect(list.model.bar == barOutsideEditMode())
}

/// The bar outside edit mode: "…" on the platform's container, a menu button holding Edit; the search capsule, its
/// magnifier, "Search" and microphone in ink2, the glyphs 17 pt and the microphone in a 36 cell, 8 apart, 15 in and 6
/// at the end; and "+" on the accent, a menu button holding New Task, New List and New Area.
private func barOutsideEditMode() -> BarModel<Action> {
    let more = MenuButtonModel<Action>(
        label: ButtonLabelModel(
            icon: IconModel(icon: .ellipsis, size: 20, weight: .semibold, color: .ink), title: nil,
            accessibilityLabel: "More", fill: .container
        ),
        menu: MenuModel(sections: [
            .init(items: [.init(title: "Edit", icon: .grip, isDestructive: false, action: .editMenuItemChosen)]),
        ])
    )
    let search = SearchFieldModel(
        placeholder: TextModel(text: "Search", font: .search, color: .ink2),
        leadingIcon: IconModel(icon: .magnifier, size: 17, weight: .regular, color: .ink2),
        trailingIcon: IconModel(icon: .microphone, size: 17, weight: .regular, color: .ink2), trailingCell: 36,
        spacing: 8, leadingPadding: 15, trailingPadding: 6
    )
    let add = MenuButtonModel<Action>(
        label: ButtonLabelModel(
            icon: IconModel(icon: .plus, size: 20, weight: .semibold, color: .onAccent), title: nil,
            accessibilityLabel: "Add", fill: .color(.accent)
        ),
        menu: MenuModel(sections: [
            .init(items: [
                .init(title: "New Task", icon: .checkCircle, isDestructive: false, action: .newTaskMenuItemChosen),
                .init(title: "New List", icon: .list, isDestructive: false, action: .newListMenuItemChosen(in: nil)),
                .init(title: "New Area", icon: .divider, isDestructive: false, action: .newAreaMenuItemChosen),
            ]),
        ])
    )
    return phoneBar([.menuButton(more), .search(search), .menuButton(add)])
}

/// The bar in edit mode: "+ List" and "+ Area" on one container, each a 15 pt plus in the accent 6 before its word,
/// reading aloud what the menu items say, and Done, the check in bold, on the accent.
private func barInEditMode() -> BarModel<Action> {
    func groupButton(_ word: String, saying label: String, _ action: Action) -> ButtonModel<Action> {
        ButtonModel(
            label: ButtonLabelModel(
                icon: IconModel(icon: .plus, size: 15, weight: .semibold, color: .accent),
                title: TextModel(text: word, font: .barLabel, color: .accent), accessibilityLabel: label,
                fill: .container
            ),
            action: action
        )
    }
    let done = ButtonModel<Action>(
        label: ButtonLabelModel(
            icon: IconModel(icon: .check, size: 20, weight: .bold, color: .onAccent), title: nil,
            accessibilityLabel: "Done", fill: .color(.accent)
        ),
        action: .doneButtonTapped
    )
    return phoneBar([
        .group([
            groupButton("List", saying: "New List", .newListMenuItemChosen(in: nil)),
            groupButton("Area", saying: "New Area", .newAreaMenuItemChosen),
        ]),
        .button(done),
    ])
}

/// A bar of the items with the phone's numbers: controls 48 high, 10 apart and 16 in; a group's buttons 40 high, the
/// glyph 6 before the word, 4 in from the group's ends, with a rule of the line colour 1 by 22 between two.
private func phoneBar(_ items: [BarModel<Action>.Item]) -> BarModel<Action> {
    BarModel(
        items: items, controlHeight: 48, spacing: 10, padding: 16, groupButtonHeight: 40, groupButtonSpacing: 6,
        groupPadding: 4, groupDividerHeight: 22, groupDivider: StrokeModel(color: .line, width: 1, dash: [])
    )
}

/// The drag's look on the phone (`Phone.dc.html`, the drag's slot and card), the same in and out of edit mode: the tree's
/// indent of 20 and 22; the slot 52 high with 44 drawn, from 6 before its tile to 12 short of the edge, rounded 13, on
/// the accent's soft fill with a 1.5 accent stroke dashed 5 and 4; the card raised 6, grown to 1.03 and turned −1.5°
/// with the lifted shadow on the surface, a list's 50 high from 2 before its tile, its tile 12 in, its grip 18 in ink2
/// in a 40 cell, 6 short of the edge, rounded 14, and a line's 36 high from 8 in to 8 short of the edge, rounded 12, each
/// at least 120 wide; all of it on the popover's motion.
@Test func theDragsLook() throws {
    let list = try sidebar(try makeStore())
    #expect(list.model.drag == phoneDrag())
    _ = list.send(.action(.editMenuItemChosen))
    #expect(list.model.drag == phoneDrag())
}

/// The drag's look with the phone's numbers, as the test above spells them. A line's card ends 8 short of the edge, as
/// Task 7 drew it 8 in and 16 narrower than the tree on screen.
private func phoneDrag() -> DragModel {
    DragModel(
        indent: IndentModel(start: 20, step: 22), animation: .popover,
        slot: .init(
            height: 52, inset: 6, trailingGap: 12, verticalInset: 4, cornerRadius: 13, fill: .accentSoft,
            stroke: StrokeModel(color: .accent, width: 1.5, dash: [5, 4])
        ),
        card: .init(
            raise: 6, scale: 1.03, rotation: -1.5, shadow: .lifted, background: .surface,
            grip: IconModel(icon: .grip, size: 18, weight: .regular, color: .ink2), gripCell: 40, minimumWidth: 120,
            listHeight: 50, listInset: 2, listPadding: 12, listTrailingGap: 6, listCornerRadius: 14, lineHeight: 36,
            lineInset: 8, lineTrailingGap: 8, lineCornerRadius: 12
        )
    )
}

/// `renaming` names the row whose field is open, and the field is that row's, in its title's font: nil before Rename,
/// the row once the field opens, nil while a fold hides the row, the row again once the fold is taken back, and nil
/// once the name is in (the owner's 👍 on #160's thread r4415002151).
@Test func renamingNamesTheRowWhoseFieldIsOpen() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects))
    let list = try sidebar(store)
    #expect(list.model.renaming == nil)
    _ = list.send(.action(.renameMenuItemChosen(home)))
    _ = list.send(.action(.titleFieldChanged("House")))
    #expect(list.model.renaming == home)
    #expect(listRow(home, in: list.model)?.field == titleField("House", font: .nestedRowTitle))
    #expect(list.model.rows.compactMap { listRow($0)?.field }.count == 1, "one field, on the row it names")
    _ = list.send(.action(.disclosureTapped(projects)))
    #expect(list.model.renaming == nil, "no row on screen has its field open")
    _ = list.send(.action(.disclosureTapped(projects)))
    #expect(list.model.renaming == home)
    _ = list.send(.action(.titleFieldSubmitted))
    #expect(list.model.renaming == nil)
    #expect(listRow(home, in: list.model)?.field == nil)
    #expect(listRow(home, in: list.model)?.title.text == "House")
}

/// The picker of Move to… whole (`Phone.dc.html`, the Move to… sheet): its title naming the list, the hint, Cancel,
/// "Top level" on a tile of the fill colour with the divider glyph, and the whole tree, each row drawn as the screen's
/// with no menu, no count, no chevron, no grip, no highlight and no guides, sending `movePickerRowTapped`; the list moved
/// and the lists inside it disabled, and its parent checked, the check 15 pt bold in the accent in a cell of 18, 20
/// short of the edge, and the cell kept empty on every other row, "Top level" among them. An unnamed area's line stands
/// alone in the picker, in edit mode too, where the screen labels it (the owner's answer on #160, thread r4415002540).
@Test func thePickerWhole() throws {
    let store = try makeStore()
    for id in builtIns { try store.delete(view: id) }
    let projects = try store.createView(NewTaskView(title: "Projects", color: .teal, icon: "folder"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects))
    let errands = try store.createView(NewTaskView(title: "Errands"))
    let area = try store.createView(NewTaskView(title: "", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: area))
    let list = try sidebar(store)
    _ = list.send(.action(.moveToMenuItemChosen(home)))
    let picker = homesPicker(projects: projects, home: home, errands: errands, area: area, clients: clients)
    #expect(list.model.movePicker == picker)
    _ = list.send(.action(.movePickerCancelled))
    _ = list.send(.action(.editMenuItemChosen))
    _ = list.send(.action(.moveToMenuItemChosen(home)))
    #expect(list.model.movePicker == picker, "in edit mode too: no grip, and the unnamed area's line alone")
    _ = list.send(.action(.movePickerCancelled))
    _ = list.send(.action(.moveToMenuItemChosen(projects)))
    #expect(list.model.movePicker?.topLevel.isChecked == true, "a list of the root has the top level for its parent")
}

/// The picker of Move to… on Home, in the tree of the test above: Projects checked, Home disabled, Errands, the
/// unnamed area's line alone and Clients under it, each a row of the screen's with nothing of the session on it, and at
/// its right the check, or the check hidden in its room, at the glyph's own width in a cell of no least width and 20
/// short of the edge; a row's need counts the canvas's check, 18, for it.
private func homesPicker(
    projects: ViewID, home: ViewID, errands: ViewID, area: ViewID, clients: ViewID
) -> PickerModel<TaskViewList.Model.Kind, Action> {
    let check = IconModel(icon: .check, size: 15, weight: .bold, color: .accent)
    let checked: [AccessoryModel<Action>] = [.check(check)]
    let unchecked: [AccessoryModel<Action>] = [.hidden(.check(check))]
    func option(
        _ id: ViewID, _ title: String, font: DesignSystem.Font, tile: TileModel, depth: Int, isChecked: Bool = false
    ) -> TaskViewList.Model.Kind {
        let leading = 20 + 22 * Double(depth)
        return .list(ListRowModel(
            height: 46, leading: leading, tile: tile, tileToTitle: 12,
            title: TextModel(text: title, font: font, color: .ink), field: nil,
            need: leading + tile.side + 12 + 140 + 38, background: .paper, guides: [], childGuides: [], guide: guide,
            accessories: isChecked ? checked : unchecked, fadeWidth: 0, textMinimumWidth: 20, cellMinimumWidth: 0,
            endGap: 20, accessoriesWidth: 38, tap: .movePickerRowTapped(id), menu: nil
        ))
    }
    let rootTile = { (color: DesignSystem.Color.Components.Tile, icon: DesignSystem.Icon) in
        TileModel(color: color, icon: icon, side: 30, cornerRadius: 8, glyphSize: 19)
    }
    return PickerModel(
        title: "Move “Home” to…", hint: TextModel(text: "Choose where it goes.", font: .hint, color: .ink2),
        cancel: ChoiceModel(title: "Cancel", isDestructive: false, action: .movePickerCancelled),
        topLevel: .init(
            icon: IconModel(icon: .divider, size: 15, weight: .regular, color: .ink2), tileSide: 30,
            tileCornerRadius: 8, tileColor: .fill, tileToTitle: 12,
            title: TextModel(text: "Top level", font: .rowTitle, color: .ink), leading: 20, height: 46,
            accessories: unchecked, cellMinimumWidth: 0, endGap: 20, isChecked: false, action: .movePickerRowTapped(nil)
        ),
        options: [
            .init(
                row: option(
                    projects, "Projects", font: .rowTitleEmphasized, tile: rootTile(.teal, .folder), depth: 0,
                    isChecked: true
                ),
                isDisabled: false, isChecked: true
            ),
            .init(
                row: option(
                    home, "Home", font: .nestedRowTitle,
                    tile: TileModel(color: .stone, icon: .bullets, side: 26, cornerRadius: 7, glyphSize: 16), depth: 1
                ),
                isDisabled: true, isChecked: false
            ),
            .init(
                row: option(errands, "Errands", font: .rowTitle, tile: rootTile(.stone, .bullets), depth: 0),
                isDisabled: false, isChecked: false
            ),
            .init(
                row: .area(AreaLineModel(
                    height: 17, leading: 20, spacing: 10, label: nil, field: nil,
                    line: StrokeModel(color: .line, width: 1, dash: []), lineToAccessories: 20,
                    accessories: unchecked, cellMinimumWidth: 0, endGap: 20, tap: .movePickerRowTapped(area), menu: nil
                )),
                isDisabled: false, isChecked: false
            ),
            .init(
                row: option(clients, "Clients", font: .rowTitle, tile: rootTile(.stone, .bullets), depth: 0),
                isDisabled: false, isChecked: false
            ),
        ],
        hintGap: 8, minimumOptionHeight: 36, disabledOpacity: 0.35
    )
}

/// The confirmation of a delete whole: the question and what goes, as before, and its two choices, Delete, which
/// destroys, and Cancel, each sending its action.
@Test func theConfirmationWhole() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    try store.createView(NewTaskView(title: "Home", parent: projects))
    let list = try sidebar(store)
    _ = list.send(.action(.deleteMenuItemChosen(projects)))
    let confirmation = ConfirmationModel<Action>(
        title: "Delete “Projects”?", message: "One list inside it goes with it. No task is deleted.",
        confirm: ChoiceModel(title: "Delete", isDestructive: true, action: .deleteConfirmed),
        cancel: ChoiceModel(title: "Cancel", isDestructive: false, action: .deleteCancelled)
    )
    #expect(list.model.confirmation == confirmation)
}

/// A wide window builds the same models with the sidebar's tiles and title fonts, 20 pt at every depth and the row title
/// at every depth, emphasized over lists, and the phone's other numbers until the sidebar's own arrive (Lists screen
/// plan, Task 9): the need and the guides follow the tile.
@Test func aWideWindowsRowsAreThePhonesWithTheSidebarsTilesAndFonts() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects", color: .teal, icon: "folder"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects, icon: "house"))
    let model = try sidebar(store, width: .wide).model
    #expect(listRow(projects, in: model) == phoneRow(
        projects, title: "Projects", font: .rowTitleEmphasized,
        tile: TileModel(color: .teal, icon: .folder, side: 20, cornerRadius: 6, glyphSize: 13), leading: 20, need: 264,
        guides: [], childGuides: [30], count: nil, chevron: chevron(projects, folded: false)
    ))
    #expect(listRow(home, in: model) == phoneRow(
        home, title: "Home", font: .rowTitle,
        tile: TileModel(color: .stone, icon: .house, side: 20, cornerRadius: 6, glyphSize: 13), leading: 42, need: 286,
        guides: [30], childGuides: [30, 52], count: nil, chevron: nil
    ))
}
