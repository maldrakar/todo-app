import Testing
import DesignSystem
import DesignSystemComponents

// The component models that are classes compare by a hand-written `==`, since Swift derives one for a struct and not
// for a class. Each test here builds the model twice the same, which must compare equal, and then once for each of its
// stored properties with that property changed, which must not; and it holds the names of the properties it changed
// against the names reflection finds on the model, so that a stored property added later and left out of `==` fails
// here twice: it is missing from the names, and once it is added, its change compares equal.

/// An action of a model under test, two of them so that an action can change.
private enum Action: Equatable, Sendable {
    case first
    case second
}

/// The names of a value's stored properties, as reflection finds them.
private func storedProperties(of value: Any) -> Set<String> {
    Set(Mirror(reflecting: value).children.compactMap(\.label))
}

/// Expects a model built the same to compare equal, the model to compare equal to itself, each of the variants, named
/// for the one stored property it changes, to compare unequal, and the names to be every stored property of the model.
private func expectEveryPropertyCompared<Model: Equatable>(
    _ build: () -> Model, _ variants: KeyValuePairs<String, Model>, sourceLocation: SourceLocation = #_sourceLocation
) {
    let base = build()
    #expect(base == base, sourceLocation: sourceLocation)
    #expect(build() == base, "built the same", sourceLocation: sourceLocation)
    for (name, variant) in variants {
        #expect(variant != base, "\(name) changed", sourceLocation: sourceLocation)
    }
    #expect(Set(variants.map(\.key)) == storedProperties(of: base), sourceLocation: sourceLocation)
}

private let text = TextModel(text: "Home", style: TextStyle(font: .rowTitle, color: .ink))
private let icon = IconModel(icon: .grip, style: IconStyle(size: 18, weight: .regular, color: .ink3))
private let stroke = LineStyle(color: .line, width: 1, dash: [])
private let menu = MenuModel<Action>(sections: [])

private func field(_ text: String) -> TextFieldModel<Action> {
    TextFieldModel(
        text: text, placeholder: "Title",
        style: FieldStyle(
            font: .rowTitle, color: .ink, placeholder: .placeholder, background: .surface, minimumWidth: 140,
            height: 34, padding: 10, cornerRadius: 10, ring: stroke
        ),
        submitted: .first, cancelled: .first, focusLost: .first
    )
}

private let tileStyle = TileStyle(
    color: .stone, side: 30, cornerRadius: 8, glyphSize: 19, glyphWeight: .medium
)

private let listRowStyle = ListRowStyle(
    height: 46, leading: 20, tileToTitle: 12, need: 274, background: .paper, backgroundInset: 0, cornerRadius: 0,
    guides: [], childGuides: [35], guide: stroke, fadeWidth: 10, textMinimumWidth: 20, cellMinimumWidth: 36, endGap: 4,
    accessoriesWidth: 72
)

private func listRow(
    tile: TileModel = TileModel(icon: .bullets, style: tileStyle), style: ListRowStyle = listRowStyle,
    title: TextModel = text, field: TextFieldModel<Action>? = nil,
    accessories: [AccessoryModel<Action>] = [.space(20)], tap: Action = .first, menu: MenuModel<Action>? = nil
) -> ListRowModel<Action> {
    ListRowModel(tile: tile, style: style, title: title, field: field, accessories: accessories, tap: tap, menu: menu)
}

@Test func aListRowComparesEveryStoredProperty() {
    expectEveryPropertyCompared({ listRow() }, [
        "tile": listRow(tile: TileModel(icon: .bullets, style: TileStyle(
            color: .teal, side: 30, cornerRadius: 8, glyphSize: 19, glyphWeight: .medium
        ))),
        "style": listRow(style: ListRowStyle(
            height: 47, leading: 20, tileToTitle: 12, need: 274, background: .paper, backgroundInset: 0,
            cornerRadius: 0, guides: [], childGuides: [35], guide: stroke, fadeWidth: 10, textMinimumWidth: 20,
            cellMinimumWidth: 36, endGap: 4, accessoriesWidth: 72
        )),
        "title": listRow(title: TextModel(text: "House", style: TextStyle(font: .rowTitle, color: .ink))),
        "field": listRow(field: field("Home")),
        "accessories": listRow(accessories: [.space(20), .space(36)]),
        "tap": listRow(tap: .second),
        "menu": listRow(menu: menu),
    ])
}

private let areaLineStyle = AreaLineStyle(
    height: 36, leading: 20, spacing: 10, line: stroke, lineToAccessories: 20, cellMinimumWidth: 22, endGap: 0
)

private func areaLine(
    style: AreaLineStyle = areaLineStyle, label: TextModel? = text, field: TextFieldModel<Action>? = nil,
    accessories: [AccessoryModel<Action>] = [], tap: Action = .first, menu: MenuModel<Action>? = nil
) -> AreaLineModel<Action> {
    AreaLineModel(style: style, label: label, field: field, accessories: accessories, tap: tap, menu: menu)
}

@Test func anAreaLineComparesEveryStoredProperty() {
    expectEveryPropertyCompared({ areaLine() }, [
        "style": areaLine(style: AreaLineStyle(
            height: 17, leading: 20, spacing: 10, line: stroke, lineToAccessories: 20, cellMinimumWidth: 22, endGap: 0
        )),
        "label": areaLine(label: nil),
        "field": areaLine(field: field("Work")),
        "accessories": areaLine(accessories: [.grip(icon)]),
        "tap": areaLine(tap: .second),
        "menu": areaLine(menu: menu),
    ])
}

private let slot = DragStyle.Slot(
    height: 52, inset: 6, trailingGap: 12, verticalInset: 4, cornerRadius: 13, fill: .accentSoft, stroke: stroke
)

private let card = DragStyle.Card(
    raise: 6, scale: 1.03, rotation: -1.5, shadow: .lifted, background: .surface, grip: icon, gripCell: 40,
    minimumWidth: 120, listHeight: 50, listInset: 2, listPadding: 12, listTrailingGap: 6, listCornerRadius: 14,
    lineHeight: 36, lineInset: 8, lineTrailingGap: 8, lineCornerRadius: 12
)

private func drag(
    indent: IndentStyle = IndentStyle(start: 20, step: 22), animation: DesignSystem.Animation = .popover,
    look: DragStyle.Look = .slot(slot, card)
) -> DragStyle {
    DragStyle(indent: indent, animation: animation, look: look)
}

private let indicator = DropIndicatorStyle(
    height: 12, line: LineStyle(color: .accent, width: 2, dash: []), lineOffset: 2, lineCornerRadius: 1,
    trailingGap: 18, circleDiameter: 10, circleOffset: -6, circleRing: LineStyle(color: .accent, width: 2, dash: []),
    circleFill: .sidebar
)

private let indicatorCard = DragStyle.IndicatorCard(
    width: 170, height: 30, offset: 14, cornerRadius: 7, background: .surface, shadow: .lifted, rotation: -1.2,
    opacity: 0.95, padding: 10, tileToTitle: 8, tileSide: 18, tileCornerRadius: 5, glyphSize: 12, titleFont: .rowTitle
)

@Test func aDragComparesEveryStoredProperty() {
    expectEveryPropertyCompared({ drag() }, [
        "indent": drag(indent: IndentStyle(start: 20, step: 24)),
        "animation": drag(animation: .check),
        "look": drag(look: .indicator(indicator, indicatorCard)),
    ])
    #expect(drag(look: .slot(slot, card)) != drag(look: .slot(DragStyle.Slot(
        height: 50, inset: 6, trailingGap: 12, verticalInset: 4, cornerRadius: 13, fill: .accentSoft, stroke: stroke
    ), card)), "the slot is compared")
    #expect(drag(look: .slot(slot, card)) != drag(look: .slot(slot, DragStyle.Card(
        raise: 8, scale: 1.03, rotation: -1.5, shadow: .lifted, background: .surface, grip: icon, gripCell: 40,
        minimumWidth: 120, listHeight: 50, listInset: 2, listPadding: 12, listTrailingGap: 6, listCornerRadius: 14,
        lineHeight: 36, lineInset: 8, lineTrailingGap: 8, lineCornerRadius: 12
    ))), "the card is compared")
}

private let topLevelStyle = PickerTopLevelStyle(
    tileSide: 30, tileCornerRadius: 8, tileColor: .fill, tileToTitle: 12, leading: 20, height: 46,
    cellMinimumWidth: 18, endGap: 20
)

private let topLevel = PickerModel<Int, Action>.TopLevel(
    icon: icon, title: text, accessories: [.space(18)], isChecked: false, action: .first, style: topLevelStyle
)

private let cancel = ChoiceModel<Action>(title: "Cancel", isDestructive: false, action: .second)

private let optionPickerStyle = OptionPickerStyle(hintGap: 8, minimumOptionHeight: 36, disabledOpacity: 0.35)

private func picker(
    title: String = "Move “Home” to…", hint: TextModel = text, cancel: ChoiceModel<Action> = cancel,
    topLevel: PickerModel<Int, Action>.TopLevel = topLevel,
    options: [PickerModel<Int, Action>.Option] = [.init(row: 1, isDisabled: false, isChecked: true)],
    style: OptionPickerStyle = optionPickerStyle
) -> PickerModel<Int, Action> {
    PickerModel(title: title, hint: hint, cancel: cancel, topLevel: topLevel, options: options, style: style)
}

@Test func aPickerComparesEveryStoredProperty() {
    expectEveryPropertyCompared({ picker() }, [
        "title": picker(title: "Move “Work” to…"),
        "hint": picker(hint: TextModel(text: "Choose where it goes.", style: TextStyle(font: .hint, color: .ink2))),
        "cancel": picker(cancel: ChoiceModel(title: "Cancel", isDestructive: false, action: .first)),
        "topLevel": picker(topLevel: .init(
            icon: icon, title: text, accessories: [.check(icon)], isChecked: true, action: .first,
            style: topLevelStyle
        )),
        "options": picker(options: [.init(row: 1, isDisabled: true, isChecked: true)]),
        "style": picker(style: OptionPickerStyle(hintGap: 10, minimumOptionHeight: 36, disabledOpacity: 0.35)),
    ])
}

private func check(isChecked: Bool = false) -> CheckModel<Action> {
    CheckModel(
        style: .init(
            diameter: 24, ringWidth: 1.75, markSize: 15, markStrokeWidth: 1.75, hitWidth: 44, hitHeight: 44,
            animation: .check, fillAnimation: .checkFills, markAnimation: .checkMarkDraws, pop: checkPop,
            mark: checkMark, colors: DesignSystem.Color.Components.Tile.blue.check
        ),
        isChecked: isChecked,
        accessibilityLabel: "Complete", action: .first
    )
}

private let swipe = SwipeModel<Action>(
    style: .init(
        threshold: 40, shift: -88, buttonWidth: 78, buttonVerticalInset: 3, buttonTrailingInset: 10,
        buttonCornerRadius: 12, background: .red, animation: .swipe
    ),
    button: TextModel(text: "Delete", style: TextStyle(font: .barLabel, color: .onAccent)),
    accessibilityLabel: "Delete Call the plumber", action: .second
)

private let taskLeaving = TaskLeavingStyle(
    titleColor: .ink2, strike: .ink3, offset: 12, animation: .rowLeaves, deleteAnimation: .rowDeleted
)

private let taskRowStyle = TaskRowStyle(
    titleToMeta: 3, metaSpacing: 10, metaLineSpacing: 3, verticalPadding: 11, titleLeading: 2, titleTrailing: 4,
    leading: 8, trailing: 12, minimumHeight: 44, cornerRadius: 0, freshAnimation: .fresh,
    strike: nil, lift: nil, fresh: nil, landingScale: nil, landingAnimation: .drop, titleAnimation: .titleFades,
    leaving: taskLeaving
)

private func taskRow(
    check: CheckModel<Action> = check(), title: TextModel = text,
    meta: [MetaItemModel] = [], style: TaskRowStyle = taskRowStyle, swipe: SwipeModel<Action>? = nil,
    tap: Action = .first, menu: MenuModel<Action>? = nil
) -> TaskRowModel<Action> {
    TaskRowModel(
        check: check, title: title, meta: meta, style: style, swipe: swipe, tap: tap, menu: menu
    )
}

@Test func aTaskRowModelComparesEveryProperty() {
    expectEveryPropertyCompared({ taskRow() }, [
        "check": taskRow(check: check(isChecked: true)),
        "title": taskRow(title: TextModel(text: "Call the plumber", style: TextStyle(font: .rowTitle, color: .ink))),
        "meta": taskRow(meta: [MetaItemModel(icon: icon, text: text, style: MetaItemStyle(spacing: 3, capsule: nil))]),
        "style": taskRow(style: .init(
            titleToMeta: 3, metaSpacing: 10, metaLineSpacing: 3, verticalPadding: 11, titleLeading: 2, titleTrailing: 4,
            leading: 8, trailing: 12, minimumHeight: 44, cornerRadius: 9, freshAnimation: .fresh,
            strike: nil, lift: nil, fresh: nil, landingScale: nil, landingAnimation: .drop,
            titleAnimation: .titleFades, leaving: taskLeaving
        )),
        "swipe": taskRow(swipe: swipe),
        "tap": taskRow(tap: .second),
        "menu": taskRow(menu: menu),
    ])
}

private let pill = PillModel(
    icon: IconModel(icon: .flag, style: IconStyle(size: 15, weight: .medium, color: .red)), text: text,
    style: .init(
        height: 32, cornerRadius: 16, leadingPadding: 10, trailingPadding: 12, spacing: 6, background: .fill
    )
)

private let addSubtask = AddRowModel<Action>(
    icon: IconModel(icon: .plus, style: IconStyle(size: 17, weight: .medium, color: .ink2)),
    title: TextModel(text: "Add subtask", style: TextStyle(font: .notes, color: .ink2)),
    style: .init(
        iconCellWidth: 40, spacing: 0, height: 44, width: nil, cornerRadius: 0, topPadding: 0, leadingPadding: 0,
        trailingPadding: 0, dash: nil, rule: nil, topMargin: 0, leadingMargin: 0, trailingMargin: 0
    ),
    action: .first
)

private let expand = ButtonModel<Action>(
    label: ButtonLabelModel(
        icon: IconModel(icon: .expand, style: IconStyle(size: 19, weight: .medium, color: .ink2)), title: nil,
        accessibilityLabel: "Open full screen", style: ButtonLabelStyle(fill: .container)
    ),
    action: .first
)

private let cardEntrance = EntranceStyle(
    opacity: 0.3, scale: 0.97, offset: -4, anchorX: 0.5, anchorY: 0.5, animation: .cardOpens
)

private let cardStyle = CardStyle(
    expandHitSide: 44, cornerRadius: 18, topMargin: 6, horizontalMargin: 10, bottomMargin: 10, bodyLeading: 46,
    bodyTrailing: 14, bodyBottom: 14, subtasksToPills: 10, pillSpacing: 6, shadow: .raised, background: .surface,
    entrance: cardEntrance, subtasksOutdent: 12, titleToNotes: 2, notesToSubtasks: 4, subtaskDraftCircle: draftCircle,
    leaving: taskLeaving, titleStrike: nil
)

private let checkPop = CheckStyle.Pop(dipScale: 0.8, dipAt: 0.35, peakScale: 1.14, peakAt: 0.7)

private let checkMark = CheckStyle.Mark(
    box: 24, points: [.init(x: 6.5, y: 12.5), .init(x: 10, y: 16), .init(x: 17.5, y: 8)]
)

private let draftCircle = CheckStyle(
    diameter: 18, ringWidth: 1.5, markSize: 12, markStrokeWidth: 1.4, hitWidth: 40, hitHeight: 44, animation: .check,
    fillAnimation: .checkFills, markAnimation: .checkMarkDraws, pop: checkPop,
    mark: checkMark, colors: DesignSystem.Color.Components.Tile.blue.check
)

private func card(
    check: CheckModel<Action> = check(), title: TextFieldModel<Action> = field("Call the plumber"),
    notes: TextFieldModel<Action> = field(""), subtasks: [SubtaskRowModel<Action>] = [],
    subtaskField: TextFieldModel<Action>? = nil, addSubtask: AddRowModel<Action> = addSubtask,
    pills: [PillModel] = [], expand: ButtonModel<Action> = expand, style: CardStyle = cardStyle,
    backgroundTapped: Action = .first
) -> CardModel<Action> {
    CardModel(
        check: check, title: title, notes: notes, subtasks: subtasks, subtaskField: subtaskField,
        addSubtask: addSubtask, pills: pills, expand: expand, style: style, backgroundTapped: backgroundTapped
    )
}

@Test func aCardModelComparesEveryProperty() {
    expectEveryPropertyCompared({ card() }, [
        "check": card(check: check(isChecked: true)),
        "title": card(title: field("Call the plumber today")),
        "notes": card(notes: field("Ask about the boiler")),
        "subtasks": card(subtasks: [
            SubtaskRowModel(
                check: check(), title: text, style: .init(height: 44, strike: nil, titleAnimation: .titleFades)
            ),
        ]),
        "subtaskField": card(subtaskField: field("")),
        "addSubtask": card(addSubtask: AddRowModel(
            icon: IconModel(icon: .plus, style: IconStyle(size: 14, weight: .medium, color: .ink2)),
            title: TextModel(text: "Add subtask", style: TextStyle(font: .notes, color: .ink2)),
            style: .init(
                iconCellWidth: 30, spacing: 0, height: 30, width: nil, cornerRadius: 7, topPadding: 0,
                leadingPadding: 0, trailingPadding: 0, dash: nil, rule: nil, topMargin: 0, leadingMargin: 0,
                trailingMargin: 0
            ),
            action: .first
        )),
        "pills": card(pills: [pill]),
        "expand": card(expand: ButtonModel(label: expand.label, action: .second)),
        "style": card(style: .init(
            expandHitSide: 44, cornerRadius: 18, topMargin: 6, horizontalMargin: 10, bottomMargin: 10, bodyLeading: 46,
            bodyTrailing: 14, bodyBottom: 14, subtasksToPills: 10, pillSpacing: 6, shadow: .lifted,
            background: .surface, entrance: cardEntrance, subtasksOutdent: 12, titleToNotes: 2, notesToSubtasks: 4,
            subtaskDraftCircle: draftCircle, leaving: taskLeaving, titleStrike: nil
        )),
        "backgroundTapped": card(backgroundTapped: .second),
    ])
}

private let chevron = AccessoryModel<Action>.Chevron(
    icon: IconModel(icon: .chevron, style: IconStyle(size: 18, weight: .semibold, color: .ink3)),
    accessibilityLabel: "Fold", action: .second, style: ChevronStyle(rotation: 0, animation: .fold)
)

private let blockHeaderStyle = BlockHeaderStyle(
    titleToSubtitle: 8, rule: stroke, height: 44, topMargin: 6, trailingMargin: 6, bottomMargin: 2, leadingMargin: 12,
    topPadding: 13, horizontalPadding: 8, bottomPadding: 0, cornerRadius: 0, foldHitSide: 44
)

private func blockHeader(
    title: TextModel = text, subtitle: TextModel? = nil, field: TextFieldModel<Action>? = nil,
    fold: AccessoryModel<Action>.Chevron? = chevron,
    style: BlockHeaderStyle = blockHeaderStyle, titleTapped: Action = .first
) -> BlockHeaderModel<Action> {
    BlockHeaderModel(
        title: title, subtitle: subtitle, field: field, fold: fold, style: style, titleTapped: titleTapped
    )
}

@Test func aBlockHeaderModelComparesEveryProperty() {
    expectEveryPropertyCompared({ blockHeader() }, [
        "title": blockHeader(title: TextModel(text: "Work", style: TextStyle(font: .sectionTitle, color: .ink))),
        "subtitle": blockHeader(subtitle: TextModel(
            text: "Tomorrow",
            style: TextStyle(font: .areaLabel, color: .ink2)
        )),
        "field": blockHeader(field: field("New list")),
        "fold": blockHeader(fold: nil),
        "style": blockHeader(style: .init(
            titleToSubtitle: 8, rule: nil, height: 44, topMargin: 6, trailingMargin: 6, bottomMargin: 2,
            leadingMargin: 12, topPadding: 13, horizontalPadding: 8, bottomPadding: 0, cornerRadius: 0, foldHitSide: 44
        )),
        "titleTapped": blockHeader(titleTapped: .second),
    ])
}

private let plus = IconModel(icon: .plus, style: IconStyle(size: 18, weight: .regular, color: .ink2))

private let addRowStyle = AddRowStyle(
    iconCellWidth: 44, spacing: 0, height: 40, width: nil, cornerRadius: 12, topPadding: 0, leadingPadding: 0,
    trailingPadding: 12, dash: nil, rule: nil, topMargin: 0, leadingMargin: 8, trailingMargin: 12
)

private func addRow(
    icon: IconModel = plus, title: TextModel = text, style: AddRowStyle = addRowStyle,
    action: Action = .first
) -> AddRowModel<Action> {
    AddRowModel(icon: icon, title: title, style: style, action: action)
}

@Test func anAddRowModelComparesEveryProperty() {
    let line = LineStyle(color: .line, width: 1, dash: [])
    expectEveryPropertyCompared({ addRow() }, [
        "icon": addRow(icon: IconModel(icon: .plus, style: IconStyle(size: 17, weight: .regular, color: .ink2))),
        "title": addRow(title: TextModel(text: "Add list", style: TextStyle(font: .barLabel, color: .ink2))),
        "style": addRow(style: .init(
            iconCellWidth: 44, spacing: 0, height: 40, width: nil, cornerRadius: 12, topPadding: 0, leadingPadding: 0,
            trailingPadding: 12, dash: line, rule: line, topMargin: 0, leadingMargin: 8, trailingMargin: 12
        )),
        "action": addRow(action: .second),
    ])
}

private let doneRowsEntrance = EntranceStyle(
    opacity: 0, scale: 0.92, offset: -8, anchorX: 0.2, anchorY: 0, animation: .popover
)

private let doneBump = DoneStripStyle.Bump(scale: 1.22, peakAt: 0.4, animation: .check)

private let doneStripStyle = DoneStripStyle(
    height: 36, cornerRadius: 18, spacing: 8, leadingPadding: 10, trailingPadding: 14, topMargin: 20,
    leadingMargin: 14, trailingMargin: 16, background: .fill, capsuleToRows: 6, rowsEntrance: doneRowsEntrance,
    bump: doneBump
)

private func doneStrip(
    icon: IconModel = plus, label: TextModel = text, rotation: Double = 0,
    style: DoneStripStyle = doneStripStyle, isOpen: Bool = false, action: Action = .first
) -> DoneStripModel<Action> {
    DoneStripModel(
        icon: icon, label: label,
        chevron: AccessoryModel.Chevron(
            icon: plus, accessibilityLabel: "Show done tasks", action: .first,
            style: ChevronStyle(rotation: rotation, animation: .fold)
        ),
        style: style, isOpen: isOpen, action: action
    )
}

@Test func aDoneStripModelComparesEveryProperty() {
    expectEveryPropertyCompared({ doneStrip() }, [
        "icon": doneStrip(icon: IconModel(
            icon: .checkCircle,
            style: IconStyle(size: 18, weight: .regular, color: .ink2)
        )),
        "label": doneStrip(label: TextModel(text: "Done today · 3", style: TextStyle(font: .barLabel, color: .ink2))),
        "chevron": doneStrip(rotation: 180),
        "style": doneStrip(style: .init(
            height: 30, cornerRadius: 18, spacing: 8, leadingPadding: 10, trailingPadding: 14, topMargin: 20,
            leadingMargin: 14, trailingMargin: 16, background: .fill, capsuleToRows: 6, rowsEntrance: doneRowsEntrance,
            bump: doneBump
        )),
        "isOpen": doneStrip(isOpen: true),
        "action": doneStrip(action: .second),
    ])
}
