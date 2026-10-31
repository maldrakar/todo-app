import Testing
import TestSupport
import DesignSystem
import DesignSystemComponents
import FeatureModule
import TaskViewListFeature
import TodoCore

private typealias Action = TaskViewList.UserAction

/// What the iPad's window offers: a window beside it, and edit mode.
private let iPad = WindowCapabilities(opensWindowsBeside: true, hasEditMode: true)

/// A sidebar made on no list in a window of the width, on iPhone unless it is told what else its window offers.
private func sidebar(
    _ store: Store, width: WindowWidth = .narrow, capabilities: WindowCapabilities = iPhone
) throws -> TaskViewList {
    try TaskViewList(store: store, route: .init(list: nil), width: width, capabilities: capabilities)
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
        ? [.init(title: "Open in New Window", icon: .newWindow, isDestructive: false, shortcut: nil, action: .openInNewWindowMenuItemChosen(id))]
        : []
    return MenuModel(sections: [
        .init(items: [
            .init(title: "Rename", icon: .pen, isDestructive: false, shortcut: nil, action: .renameMenuItemChosen(id)),
            .init(title: "New List", icon: .plus, isDestructive: false, shortcut: nil, action: .newListMenuItemChosen(in: id)),
        ] + window + [
            .init(title: "Move to…", icon: .folder, isDestructive: false, shortcut: nil, action: .moveToMenuItemChosen(id)),
        ]),
        .init(items: [.init(title: "Delete", icon: .trash, isDestructive: true, shortcut: nil, action: .deleteMenuItemChosen(id))]),
    ])
}

/// The menu of an area's line: Rename and New List, then, after a divider, Delete Area; no Move to…, since an area
/// moves along the root alone, by the drag, and no Open in New Window, since an area never opens.
private func lineMenu(_ id: ViewID) -> MenuModel<Action> {
    MenuModel(sections: [
        .init(items: [
            .init(title: "Rename", icon: .pen, isDestructive: false, shortcut: nil, action: .renameMenuItemChosen(id)),
            .init(title: "New List", icon: .plus, isDestructive: false, shortcut: nil, action: .newListMenuItemChosen(in: id)),
        ]),
        .init(items: [.init(title: "Delete Area", icon: .trash, isDestructive: true, shortcut: nil, action: .deleteMenuItemChosen(id))]),
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
        backgroundInset: 0, cornerRadius: 0, guides: guides, childGuides: childGuides, guide: guide,
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
    let mac = try sidebar(store, capabilities: iPad).model
    #expect(listRow(clients, in: phone)?.menu == listMenu(clients, openInNewWindow: false))
    #expect(listRow(clients, in: mac)?.menu == listMenu(clients, openInNewWindow: true))
    #expect(areaLine(work, in: phone)?.menu == lineMenu(work))
    #expect(areaLine(work, in: mac)?.menu == lineMenu(work))
    #expect(listRow(inbox, in: mac).map(drawnCount) == "1", "the Inbox counts its task; this is the setup")

    let editing = try sidebar(store, capabilities: iPad)
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
            .init(items: [.init(title: "Edit", icon: .grip, isDestructive: false, shortcut: nil, action: .editMenuItemChosen)]),
        ])
    )
    let search = SearchFieldModel(
        placeholder: TextModel(text: "Search", font: .search, color: .ink2),
        leadingIcon: IconModel(icon: .magnifier, size: 17, weight: .regular, color: .ink2),
        trailingGlyph: .init(icon: IconModel(icon: .microphone, size: 17, weight: .regular, color: .ink2), cell: 36),
        spacing: 8, leadingPadding: 15, trailingPadding: 6, fill: .container, cornerRadius: 24
    )
    let add = MenuButtonModel<Action>(
        label: ButtonLabelModel(
            icon: IconModel(icon: .plus, size: 20, weight: .semibold, color: .onAccent), title: nil,
            accessibilityLabel: "Add", fill: .color(.accent)
        ),
        menu: MenuModel(sections: [
            .init(items: [
                .init(title: "New Task", icon: .checkCircle, isDestructive: false, shortcut: nil, action: .newTaskMenuItemChosen),
                .init(title: "New List", icon: .list, isDestructive: false, shortcut: nil, action: .newListMenuItemChosen(in: nil)),
                .init(title: "New Area", icon: .divider, isDestructive: false, shortcut: nil, action: .newAreaMenuItemChosen),
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
        items: items, height: 48, rule: nil, controlHeight: 48, spacing: 10, padding: 16, groupButtonHeight: 40,
        groupButtonSpacing: 6, groupPadding: 4, groupDividerHeight: 22,
        groupDivider: StrokeModel(color: .line, width: 1, dash: []), buttonShadow: .raised
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
        look: .slot(
            .init(
                height: 52, inset: 6, trailingGap: 12, verticalInset: 4, cornerRadius: 13, fill: .accentSoft,
                stroke: StrokeModel(color: .accent, width: 1.5, dash: [5, 4])
            ),
            .init(
                raise: 6, scale: 1.03, rotation: -1.5, shadow: .lifted, background: .surface,
                grip: IconModel(icon: .grip, size: 18, weight: .regular, color: .ink2), gripCell: 40, minimumWidth: 120,
                listHeight: 50, listInset: 2, listPadding: 12, listTrailingGap: 6, listCornerRadius: 14, lineHeight: 36,
                lineInset: 8, lineTrailingGap: 8, lineCornerRadius: 12
            )
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
            need: leading + tile.side + 12 + 140 + 38, background: .paper, backgroundInset: 0, cornerRadius: 0,
            guides: [], childGuides: [], guide: guide,
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

/// What the Mac's window offers: a window beside it, and no edit mode.
private let mac = WindowCapabilities(opensWindowsBeside: true, hasEditMode: false)

/// The sidebar's accessories in the tree (`Mac.dc.html`, the row's sticky end), in their order: the count in ink2, or
/// its cell kept empty, 18 wide, where the row has none; the chevron, or its cell kept empty, 20 wide; and the grip in
/// edit mode.
private func sidebarAccessories(
    count: String?, chevron: AccessoryModel<Action>.Chevron?, isEditing: Bool = false
) -> [AccessoryModel<Action>] {
    [
        count.map { .text(TextModel(text: $0, font: .count, color: .ink2)) } ?? .space(18),
        chevron.map { .chevron($0) } ?? .space(20),
    ] + (isEditing ? [.grip(grip)] : [])
}

/// The sidebar's chevron, 12 pt semibold in ink2, down while its branch is open and a quarter turned left while it is
/// folded, saying what a tap will do.
private func sidebarChevron(_ id: ViewID, folded: Bool) -> AccessoryModel<Action>.Chevron {
    .init(
        icon: IconModel(icon: .chevron, size: 12, weight: .semibold, color: .ink2), rotation: folded ? -90 : 0,
        animation: .popover, accessibilityLabel: folded ? "Expand" : "Collapse", action: .disclosureTapped(id)
    )
}

/// The guides under every row of the sidebar, 1 pt in the guide colour.
private let sidebarGuide = StrokeModel(color: .guide, width: 1, dash: [])

/// A list's row whole as the sidebar draws it (`Mac.dc.html`, a list's row), but for what a test spells: its title and
/// title font, its tile, where it starts, its need, whether it is highlighted, its guides, its count, its chevron,
/// whether it is in edit mode and its menu. It is 30 high with the title 8 after the tile in the ink and no field, on
/// the sidebar colour, or the selection where it is highlighted, inset 10 from the tree's sides and rounded 7, under
/// guides 1 pt in the guide colour, its accessories over a fade of 8, the count's cell at least 18 and the others at
/// least 20, with 4 at the end, in the 70 of its need, 90 with the grip, and a tap selects it.
private func sidebarRow(
    _ id: ViewID, title: String, font: DesignSystem.Font, tile: TileModel, leading: Double, need: Double,
    isHighlighted: Bool = false, guides: [Double], childGuides: [Double], count: String?,
    chevron: AccessoryModel<Action>.Chevron?, isEditing: Bool = false, menu: MenuModel<Action>?
) -> ListRowModel<Action> {
    ListRowModel(
        height: 30, leading: leading, tile: tile, tileToTitle: 8,
        title: TextModel(text: title, font: font, color: .ink), field: nil, need: need,
        background: isHighlighted ? .selection : .sidebar, backgroundInset: 10, cornerRadius: 7, guides: guides,
        childGuides: childGuides, guide: sidebarGuide,
        accessories: sidebarAccessories(count: count, chevron: chevron, isEditing: isEditing), fadeWidth: 8,
        textMinimumWidth: 18, cellMinimumWidth: 20, endGap: 4, accessoriesWidth: isEditing ? 90 : 70,
        tap: .rowSelected(id), menu: menu
    )
}

/// A tile of the sidebar's root depth, 22 across, rounded 6, its glyph 14 (`Mac.dc.html`, `tileSize`).
private func rootTile(_ color: DesignSystem.Color.Components.Tile, _ icon: DesignSystem.Icon) -> TileModel {
    TileModel(color: color, icon: icon, side: 22, cornerRadius: 6, glyphSize: 14)
}

/// A tile of the sidebar deeper than its root, 18 across, rounded 5, its glyph 12.
private func nestedTile(_ color: DesignSystem.Color.Components.Tile, _ icon: DesignSystem.Icon) -> TileModel {
    TileModel(color: color, icon: icon, side: 18, cornerRadius: 5, glyphSize: 12)
}

/// A wide window's rows carry the sidebar's numbers whole (`Mac.dc.html`, a list's row): 30 high, the tile at 18 + 16
/// × depth, 22 across at the root's depth and 18 deeper, the title 8 after it in the sidebar's body, emphasized where
/// the list has lists inside it or is highlighted, a need of the tile's leading edge, the tile, 8, a title of 90 and
/// the accessories' 70, the guides at the centres of the ancestors' tiles, the Inbox, which the sidebar declares, on
/// the selection and every other row on the sidebar colour, each inset 10 and rounded 7, with the count and the
/// chevron, and the menu of a list with Open in New Window, on the Mac.
@Test func aWideWindowsRowsCarryTheSidebarsNumbers() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk"))
    let projects = try store.createView(NewTaskView(title: "Projects", color: .teal, icon: "folder"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects, icon: "house", filter: .status([.open])))
    let model = try sidebar(store, width: .wide, capabilities: mac).model
    #expect(listRow(inbox, in: model) == sidebarRow(
        inbox, title: "Inbox", font: .rowTitleEmphasized, tile: rootTile(.blue, .tray), leading: 18, need: 208,
        isHighlighted: true, guides: [], childGuides: [29], count: "1", chevron: nil,
        menu: listMenu(inbox, openInNewWindow: true)
    ))
    #expect(listRow(BuiltInTaskViews.today, in: model)?.background == .sidebar)
    #expect(listRow(BuiltInTaskViews.today, in: model)?.title.font == .rowTitle)
    #expect(listRow(projects, in: model) == sidebarRow(
        projects, title: "Projects", font: .rowTitleEmphasized, tile: rootTile(.teal, .folder), leading: 18, need: 208,
        guides: [], childGuides: [29], count: "1", chevron: sidebarChevron(projects, folded: false),
        menu: listMenu(projects, openInNewWindow: true)
    ))
    #expect(listRow(home, in: model) == sidebarRow(
        home, title: "Home", font: .rowTitle, tile: nestedTile(.stone, .house), leading: 34, need: 220,
        guides: [29], childGuides: [29, 43], count: "1", chevron: nil, menu: listMenu(home, openInNewWindow: true)
    ))
}

/// The highlight moves the sidebar's emphasis with it: a row chosen takes the emphasized title and the selection, and
/// the Inbox it leaves goes back to the plain title on the sidebar colour; a fold that hides the chosen row lights the
/// folded list, emphasized as a list with lists inside it is.
@Test func theHighlightCarriesTheEmphasisInTheSidebar() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects))
    let list = try sidebar(store, width: .wide, capabilities: mac)
    _ = list.send(.action(.rowSelected(home)))
    #expect(listRow(home, in: list.model)?.title.font == .rowTitleEmphasized)
    #expect(listRow(home, in: list.model)?.background == .selection)
    #expect(listRow(inbox, in: list.model)?.title.font == .rowTitle)
    #expect(listRow(inbox, in: list.model)?.background == .sidebar)
    _ = list.send(.action(.disclosureTapped(projects)))
    #expect(listRow(projects, in: list.model)?.background == .selection)
    #expect(listRow(projects, in: list.model)?.title.font == .rowTitleEmphasized)
}

/// An area's line in the sidebar (`Mac.dc.html`, an area's line): 15 high, its name always on it where it has one, 18
/// in, in capitals in the area's caption in ink3, the line 6 after it, 1 pt in the line colour, ending 18 short of the
/// edge, which is 8 short of the tree's content inset 10, and the line alone where it has no name; each with the menu
/// of a line. Renamed, it is 28 high, the field 16 in, 160 by 22, padded 6, rounded 6, in the canvas's 12.5 pt
/// semibold, the callout's. In edit mode, on the iPad, the grip comes, 8 after the line in a cell of 20, 14 short of the
/// edge, in the column of the rows' grips, no menu, and an unnamed area is labelled "AREA".
@Test func aWideWindowsAreaLines() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let unnamed = try store.createView(NewTaskView(title: "", kind: .area))
    func sidebarLine(
        _ id: ViewID, height: Double, leading: Double = 18, label: String?, field: TextFieldModel<Action>? = nil,
        isEditing: Bool = false, menu: MenuModel<Action>?
    ) -> AreaLineModel<Action> {
        AreaLineModel(
            height: height, leading: leading, spacing: 6,
            label: label.map { TextModel(text: $0, font: .areaCaption, color: .ink3) }, field: field,
            line: StrokeModel(color: .line, width: 1, dash: []), lineToAccessories: isEditing ? 8 : 18,
            accessories: isEditing ? [.grip(grip)] : [], cellMinimumWidth: isEditing ? 20 : 0,
            endGap: isEditing ? 14 : 0, tap: .rowSelected(id), menu: menu
        )
    }
    let list = try sidebar(store, width: .wide, capabilities: mac)
    #expect(areaLine(work, in: list.model) == sidebarLine(work, height: 15, label: "WORK", menu: lineMenu(work)))
    #expect(areaLine(unnamed, in: list.model) == sidebarLine(unnamed, height: 15, label: nil, menu: lineMenu(unnamed)))
    _ = list.send(.action(.renameMenuItemChosen(work)))
    let nameField = field(
        "Work", placeholder: "Area name", font: .nestedRowTitleEmphasized, minimumWidth: 160, height: 22, padding: 6,
        cornerRadius: 6
    )
    #expect(areaLine(work, in: list.model) == sidebarLine(
        work, height: 28, leading: 16, label: "WORK", field: nameField, menu: lineMenu(work)
    ))

    let iPadList = try sidebar(store, width: .wide, capabilities: iPad)
    _ = iPadList.send(.action(.editMenuItemChosen))
    #expect(areaLine(work, in: iPadList.model) == sidebarLine(
        work, height: 15, label: "WORK", isEditing: true, menu: nil
    ))
    #expect(areaLine(unnamed, in: iPadList.model) == sidebarLine(
        unnamed, height: 15, label: "AREA", isEditing: true, menu: nil
    ))
}

/// A list's field in the sidebar: in the row's title font, at least the title's 90 wide, 24 high, padded 6 and rounded
/// 6, with the canvas's placeholder; the row keeps the rest of its look.
@Test func aWideWindowsListFieldIsTheSidebars() throws {
    let store = try makeStore()
    let projects = try store.createView(NewTaskView(title: "Projects"))
    try store.createView(NewTaskView(title: "Home", parent: projects))
    let list = try sidebar(store, width: .wide, capabilities: mac)
    _ = list.send(.action(.renameMenuItemChosen(projects)))
    #expect(listRow(projects, in: list.model)?.field == field(
        "Projects", placeholder: "Title", font: .rowTitleEmphasized, minimumWidth: 90, height: 24, padding: 6,
        cornerRadius: 6
    ))
    #expect(listRow(projects, in: list.model)?.height == 30)
}

/// In edit mode, on the iPad's wide window, the sidebar's rows take the grip in a cell of 20 after the chevron's, the
/// counts go and no row has a menu; the need grows by the grip's cell (Lists screen spec, sections 7 and 8).
@Test func aWideWindowsRowsInEditMode() throws {
    let store = try makeStore()
    try store.createTask(NewTask(title: "Buy milk"))
    let list = try sidebar(store, width: .wide, capabilities: iPad)
    _ = list.send(.action(.editMenuItemChosen))
    #expect(listRow(inbox, in: list.model) == sidebarRow(
        inbox, title: "Inbox", font: .rowTitleEmphasized, tile: rootTile(.blue, .tray), leading: 18, need: 228,
        isHighlighted: true, guides: [], childGuides: [29], count: nil, chevron: nil, isEditing: true, menu: nil
    ))
}

/// The menus are the module's on every width and with every capability (Lists screen spec, section 6): a list's with
/// Open in New Window only where a window can open beside this one, the built-ins' among them, and a line's, the same
/// in a narrow and a wide window, with and without edit mode.
@Test func theMenusFollowWhetherAWindowCanOpenOnEveryWidth() throws {
    let store = try makeStore()
    let work = try store.createView(NewTaskView(title: "Work", kind: .area))
    let clients = try store.createView(NewTaskView(title: "Clients", parent: work))
    for width in [WindowWidth.narrow, .wide] {
        for capabilities in [iPhone, iPad, mac] {
            let model = try sidebar(store, width: width, capabilities: capabilities).model
            let opens = capabilities.opensWindowsBeside
            #expect(listRow(inbox, in: model)?.menu == listMenu(inbox, openInNewWindow: opens), "\(width) \(opens)")
            #expect(listRow(clients, in: model)?.menu == listMenu(clients, openInNewWindow: opens))
            #expect(areaLine(work, in: model)?.menu == lineMenu(work))
        }
    }
}

/// The bar is chosen by whether the platform has edit mode and not by the width: with it, the phone's bar of Task 8 in
/// a narrow and a wide window alike, its edit bar in edit mode; without it, on the Mac, the canvas's bar
/// (`Mac.dc.html`, the bottom of the column), which Edit sent all the same leaves as it is.
@Test func theBarFollowsEditModeAndNotTheWidth() throws {
    for width in [WindowWidth.narrow, .wide] {
        for capabilities in [iPhone, iPad] {
            let list = try sidebar(try makeStore(), width: width, capabilities: capabilities)
            #expect(list.model.bar == barOutsideEditMode())
            _ = list.send(.action(.editMenuItemChosen))
            #expect(list.model.bar == barInEditMode())
        }
    }
    let list = try sidebar(try makeStore(), width: .wide, capabilities: mac)
    #expect(list.model.bar == barWithoutEditMode())
    _ = list.send(.action(.editMenuItemChosen))
    #expect(list.model.bar == barWithoutEditMode())
}

/// The bar without edit mode (`Mac.dc.html`, the bottom of the column): 48 high under a rule 1 pt in the line colour,
/// its controls 30 high, 8 apart and 10 in from the column's edges; the search field on the fill colour, rounded 8, its
/// magnifier 15 pt in ink2 9 in from its start and 6 before "Search" in ink2, 4 at its end, with no trailing glyph; and
/// "+" on the accent, its plus 16 pt bold in white, casting the raised shadow, a menu of New Task ⌘N, New List ⇧⌘N and
/// New Area. The group's numbers, which no item of this bar uses, are the edit bar's.
private func barWithoutEditMode() -> BarModel<Action> {
    let search = SearchFieldModel(
        placeholder: TextModel(text: "Search", font: .search, color: .ink2),
        leadingIcon: IconModel(icon: .magnifier, size: 15, weight: .regular, color: .ink2), trailingGlyph: nil,
        spacing: 6, leadingPadding: 9, trailingPadding: 4, fill: .color(.fill), cornerRadius: 8
    )
    let add = MenuButtonModel<Action>(
        label: ButtonLabelModel(
            icon: IconModel(icon: .plus, size: 16, weight: .bold, color: .onAccent), title: nil,
            accessibilityLabel: "Add", fill: .color(.accent)
        ),
        menu: MenuModel(sections: [
            .init(items: [
                .init(
                    title: "New Task", icon: .checkCircle, isDestructive: false,
                    shortcut: .init(key: "n", modifiers: [.command]), action: .newTaskMenuItemChosen
                ),
                .init(
                    title: "New List", icon: .list, isDestructive: false,
                    shortcut: .init(key: "n", modifiers: [.shift, .command]), action: .newListMenuItemChosen(in: nil)
                ),
                .init(title: "New Area", icon: .divider, isDestructive: false, shortcut: nil, action: .newAreaMenuItemChosen),
            ]),
        ])
    )
    return BarModel(
        items: [.search(search), .menuButton(add)], height: 48, rule: StrokeModel(color: .line, width: 1, dash: []),
        controlHeight: 30, spacing: 8, padding: 10, groupButtonHeight: 40, groupButtonSpacing: 6, groupPadding: 4,
        groupDividerHeight: 22, groupDivider: StrokeModel(color: .line, width: 1, dash: []), buttonShadow: .raised
    )
}

/// The drag's look follows the width (Lists screen plan, Task 9): the phone's slot and card in a narrow window, and the
/// Mac board's indicator and card in a wide one, on the Mac and the iPad alike, in and out of edit mode, and a window
/// that narrows takes the phone's.
@Test func theDragsLookFollowsTheWidth() throws {
    let mac = try sidebar(try makeStore(), width: .wide, capabilities: mac)
    #expect(mac.model.drag == sidebarDrag())
    let iPad = try sidebar(try makeStore(), width: .wide, capabilities: iPad)
    #expect(iPad.model.drag == sidebarDrag())
    _ = iPad.send(.action(.editMenuItemChosen))
    #expect(iPad.model.drag == sidebarDrag())
    _ = iPad.send(.widthChanged(.narrow))
    #expect(iPad.model.drag == phoneDrag())
}

/// The sidebar's drag (`Mac.dc.html`, the drag's slot row and card): the tree's indent of 18 and 16; a gap of 12
/// between the rows, holding the line, 2 pt in the accent with its ends rounded 1, from 2 after the tile of the drop's
/// depth to 18 short of the edge, 8 short of the tree's content, and the circle, 10 across, ringed 2 pt in the accent
/// and filled with the sidebar colour, 6 before that tile; and the card 170 by 30, 14 after that tile, rounded 7, on the
/// surface with the lifted shadow, turned −1.2° at 95 %, a list's tile on it 18 across, rounded 5 with its glyph 12, 10
/// in, and its title 8 after it in the sidebar's body; all of it on the popover's motion.
private func sidebarDrag() -> DragModel {
    DragModel(
        indent: IndentModel(start: 18, step: 16), animation: .popover,
        look: .indicator(.init(
            height: 12, line: StrokeModel(color: .accent, width: 2, dash: []), lineOffset: 2, lineCornerRadius: 1,
            trailingGap: 18, circleDiameter: 10, circleOffset: -6,
            circleRing: StrokeModel(color: .accent, width: 2, dash: []), circleFill: .sidebar,
            card: .init(
                width: 170, height: 30, offset: 14, cornerRadius: 7, background: .surface, shadow: .lifted,
                rotation: -1.2, opacity: 0.95, padding: 10, tileToTitle: 8, tileSide: 18, tileCornerRadius: 5,
                glyphSize: 12, titleFont: .rowTitle
            )
        ))
    )
}

/// The picker of Move to… in a wide window draws the sidebar's rows (Lists screen spec, section 6): each option the
/// screen's row for the width with nothing of the session on it, but standing on the sheet's paper, the whole width
/// and square, as on the phone, and "Top level" a row of the sidebar's too, 30 high, its tile the root's, 22 across
/// and rounded 6, the divider glyph 11 on it, 18 in and the title 8 after it; an option is at least a row's 30 high.
/// The check stands 20 short of the edge on every row, in one column.
@Test func thePickerInAWideWindow() throws {
    let store = try makeStore()
    for id in builtIns { try store.delete(view: id) }
    let projects = try store.createView(NewTaskView(title: "Projects", color: .teal, icon: "folder"))
    let home = try store.createView(NewTaskView(title: "Home", parent: projects))
    let area = try store.createView(NewTaskView(title: "Work", kind: .area))
    let list = try sidebar(store, width: .wide, capabilities: mac)
    _ = list.send(.action(.moveToMenuItemChosen(home)))
    let check = IconModel(icon: .check, size: 15, weight: .bold, color: .accent)
    let checked: [AccessoryModel<Action>] = [.check(check)]
    let unchecked: [AccessoryModel<Action>] = [.hidden(.check(check))]
    let picker = PickerModel<TaskViewList.Model.Kind, Action>(
        title: "Move “Home” to…", hint: TextModel(text: "Choose where it goes.", font: .hint, color: .ink2),
        cancel: ChoiceModel(title: "Cancel", isDestructive: false, action: .movePickerCancelled),
        topLevel: .init(
            icon: IconModel(icon: .divider, size: 11, weight: .regular, color: .ink2), tileSide: 22,
            tileCornerRadius: 6, tileColor: .fill, tileToTitle: 8,
            title: TextModel(text: "Top level", font: .rowTitle, color: .ink), leading: 18, height: 30,
            accessories: unchecked, cellMinimumWidth: 0, endGap: 20, isChecked: false, action: .movePickerRowTapped(nil)
        ),
        options: [
            .init(
                row: .list(ListRowModel(
                    height: 30, leading: 18, tile: rootTile(.teal, .folder), tileToTitle: 8,
                    title: TextModel(text: "Projects", font: .rowTitleEmphasized, color: .ink), field: nil,
                    need: 18 + 22 + 8 + 90 + 38, background: .paper, backgroundInset: 0, cornerRadius: 0,
                    guides: [], childGuides: [], guide: sidebarGuide, accessories: checked, fadeWidth: 0,
                    textMinimumWidth: 18, cellMinimumWidth: 0, endGap: 20, accessoriesWidth: 38,
                    tap: .movePickerRowTapped(projects), menu: nil
                )),
                isDisabled: false, isChecked: true
            ),
            .init(
                row: .list(ListRowModel(
                    height: 30, leading: 34, tile: nestedTile(.stone, .bullets), tileToTitle: 8,
                    title: TextModel(text: "Home", font: .rowTitle, color: .ink), field: nil,
                    need: 34 + 18 + 8 + 90 + 38, background: .paper, backgroundInset: 0, cornerRadius: 0,
                    guides: [], childGuides: [], guide: sidebarGuide, accessories: unchecked, fadeWidth: 0,
                    textMinimumWidth: 18, cellMinimumWidth: 0, endGap: 20, accessoriesWidth: 38,
                    tap: .movePickerRowTapped(home), menu: nil
                )),
                isDisabled: true, isChecked: false
            ),
            .init(
                row: .area(AreaLineModel(
                    height: 15, leading: 18, spacing: 6, label: TextModel(text: "WORK", font: .areaCaption, color: .ink3),
                    field: nil, line: StrokeModel(color: .line, width: 1, dash: []), lineToAccessories: 20,
                    accessories: unchecked, cellMinimumWidth: 0, endGap: 20, tap: .movePickerRowTapped(area), menu: nil
                )),
                isDisabled: false, isChecked: false
            ),
        ],
        hintGap: 8, minimumOptionHeight: 30, disabledOpacity: 0.35
    )
    #expect(list.model.movePicker == picker)
}
