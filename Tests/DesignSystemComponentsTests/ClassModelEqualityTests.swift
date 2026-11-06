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

private let text = TextModel(text: "Home", font: .rowTitle, color: .ink)
private let icon = IconModel(icon: .grip, size: 18, weight: .regular, color: .ink3)
private let stroke = StrokeModel(color: .line, width: 1, dash: [])
private let menu = MenuModel<Action>(sections: [])

private func field(_ text: String) -> TextFieldModel<Action> {
    TextFieldModel(
        text: text, placeholder: "Title", font: .rowTitle, color: .ink, background: .surface, minimumWidth: 140,
        height: 34, padding: 10, cornerRadius: 10, ring: stroke, submitted: .first, cancelled: .first, focusLost: .first
    )
}

private func listRow(
    height: Double = 46, leading: Double = 20,
    tile: TileModel = TileModel(color: .stone, icon: .bullets, side: 30, cornerRadius: 8, glyphSize: 19),
    tileToTitle: Double = 12, title: TextModel = text, field: TextFieldModel<Action>? = nil, need: Double = 274,
    background: DesignSystem.Color = .paper, backgroundInset: Double = 0, cornerRadius: Double = 0,
    guides: [Double] = [], childGuides: [Double] = [35], guide: StrokeModel = stroke,
    accessories: [AccessoryModel<Action>] = [.space(20)], fadeWidth: Double = 10, textMinimumWidth: Double = 20,
    cellMinimumWidth: Double = 36, endGap: Double = 4, accessoriesWidth: Double = 72, tap: Action = .first,
    menu: MenuModel<Action>? = nil
) -> ListRowModel<Action> {
    ListRowModel(
        height: height, leading: leading, tile: tile, tileToTitle: tileToTitle, title: title, field: field, need: need,
        background: background, backgroundInset: backgroundInset, cornerRadius: cornerRadius, guides: guides,
        childGuides: childGuides, guide: guide, accessories: accessories, fadeWidth: fadeWidth,
        textMinimumWidth: textMinimumWidth, cellMinimumWidth: cellMinimumWidth, endGap: endGap,
        accessoriesWidth: accessoriesWidth, tap: tap, menu: menu
    )
}

@Test func aListRowComparesEveryStoredProperty() {
    expectEveryPropertyCompared({ listRow() }, [
        "height": listRow(height: 47),
        "leading": listRow(leading: 42),
        "tile": listRow(tile: TileModel(color: .teal, icon: .bullets, side: 30, cornerRadius: 8, glyphSize: 19)),
        "tileToTitle": listRow(tileToTitle: 10),
        "title": listRow(title: TextModel(text: "House", font: .rowTitle, color: .ink)),
        "field": listRow(field: field("Home")),
        "need": listRow(need: 310),
        "background": listRow(background: .fill),
        "backgroundInset": listRow(backgroundInset: 10),
        "cornerRadius": listRow(cornerRadius: 7),
        "guides": listRow(guides: [35]),
        "childGuides": listRow(childGuides: [35, 55]),
        "guide": listRow(guide: StrokeModel(color: .line, width: 1.5, dash: [])),
        "accessories": listRow(accessories: [.space(20), .space(36)]),
        "fadeWidth": listRow(fadeWidth: 0),
        "textMinimumWidth": listRow(textMinimumWidth: 22),
        "cellMinimumWidth": listRow(cellMinimumWidth: 18),
        "endGap": listRow(endGap: 20),
        "accessoriesWidth": listRow(accessoriesWidth: 108),
        "tap": listRow(tap: .second),
        "menu": listRow(menu: menu),
    ])
}

private func areaLine(
    height: Double = 36, leading: Double = 20, spacing: Double = 10, label: TextModel? = text,
    field: TextFieldModel<Action>? = nil, line: StrokeModel = stroke, lineToAccessories: Double = 20,
    accessories: [AccessoryModel<Action>] = [], cellMinimumWidth: Double = 22, endGap: Double = 0, tap: Action = .first,
    menu: MenuModel<Action>? = nil
) -> AreaLineModel<Action> {
    AreaLineModel(
        height: height, leading: leading, spacing: spacing, label: label, field: field, line: line,
        lineToAccessories: lineToAccessories, accessories: accessories, cellMinimumWidth: cellMinimumWidth,
        endGap: endGap, tap: tap, menu: menu
    )
}

@Test func anAreaLineComparesEveryStoredProperty() {
    expectEveryPropertyCompared({ areaLine() }, [
        "height": areaLine(height: 17),
        "leading": areaLine(leading: 8),
        "spacing": areaLine(spacing: 12),
        "label": areaLine(label: nil),
        "field": areaLine(field: field("Work")),
        "line": areaLine(line: StrokeModel(color: .line, width: 2, dash: [])),
        "lineToAccessories": areaLine(lineToAccessories: 10),
        "accessories": areaLine(accessories: [.grip(icon)]),
        "cellMinimumWidth": areaLine(cellMinimumWidth: 18),
        "endGap": areaLine(endGap: 12),
        "tap": areaLine(tap: .second),
        "menu": areaLine(menu: menu),
    ])
}

private let slot = DragModel.Slot(
    height: 52, inset: 6, trailingGap: 12, verticalInset: 4, cornerRadius: 13, fill: .accentSoft, stroke: stroke
)

private let card = DragModel.Card(
    raise: 6, scale: 1.03, rotation: -1.5, shadow: .lifted, background: .surface, grip: icon, gripCell: 40,
    minimumWidth: 120, listHeight: 50, listInset: 2, listPadding: 12, listTrailingGap: 6, listCornerRadius: 14,
    lineHeight: 36, lineInset: 8, lineTrailingGap: 8, lineCornerRadius: 12
)

private func drag(
    indent: IndentModel = IndentModel(start: 20, step: 22), animation: DesignSystem.Animation = .popover,
    look: DragModel.Look = .slot(slot, card)
) -> DragModel {
    DragModel(indent: indent, animation: animation, look: look)
}

private let indicator = DropIndicatorModel(
    height: 12, line: StrokeModel(color: .accent, width: 2, dash: []), lineOffset: 2, lineCornerRadius: 1,
    trailingGap: 18, circleDiameter: 10, circleOffset: -6, circleRing: StrokeModel(color: .accent, width: 2, dash: []),
    circleFill: .sidebar
)

private let indicatorCard = DragModel.IndicatorCard(
    width: 170, height: 30, offset: 14, cornerRadius: 7, background: .surface, shadow: .lifted, rotation: -1.2,
    opacity: 0.95, padding: 10, tileToTitle: 8, tileSide: 18, tileCornerRadius: 5, glyphSize: 12, titleFont: .rowTitle
)

@Test func aDragComparesEveryStoredProperty() {
    expectEveryPropertyCompared({ drag() }, [
        "indent": drag(indent: IndentModel(start: 20, step: 24)),
        "animation": drag(animation: .check),
        "look": drag(look: .indicator(indicator, indicatorCard)),
    ])
    #expect(drag(look: .slot(slot, card)) != drag(look: .slot(DragModel.Slot(
        height: 50, inset: 6, trailingGap: 12, verticalInset: 4, cornerRadius: 13, fill: .accentSoft, stroke: stroke
    ), card)), "the slot is compared")
    #expect(drag(look: .slot(slot, card)) != drag(look: .slot(slot, DragModel.Card(
        raise: 8, scale: 1.03, rotation: -1.5, shadow: .lifted, background: .surface, grip: icon, gripCell: 40,
        minimumWidth: 120, listHeight: 50, listInset: 2, listPadding: 12, listTrailingGap: 6, listCornerRadius: 14,
        lineHeight: 36, lineInset: 8, lineTrailingGap: 8, lineCornerRadius: 12
    ))), "the card is compared")
}

private let topLevel = PickerModel<Int, Action>.TopLevel(
    icon: icon, tileSide: 30, tileCornerRadius: 8, tileColor: .fill, tileToTitle: 12, title: text, leading: 20,
    height: 46, accessories: [.space(18)], cellMinimumWidth: 18, endGap: 20, isChecked: false, action: .first
)

private let cancel = ChoiceModel<Action>(title: "Cancel", isDestructive: false, action: .second)

private func picker(
    title: String = "Move “Home” to…", hint: TextModel = text, cancel: ChoiceModel<Action> = cancel,
    topLevel: PickerModel<Int, Action>.TopLevel = topLevel,
    options: [PickerModel<Int, Action>.Option] = [.init(row: 1, isDisabled: false, isChecked: true)],
    hintGap: Double = 8, minimumOptionHeight: Double = 36, disabledOpacity: Double = 0.35
) -> PickerModel<Int, Action> {
    PickerModel(
        title: title, hint: hint, cancel: cancel, topLevel: topLevel, options: options, hintGap: hintGap,
        minimumOptionHeight: minimumOptionHeight, disabledOpacity: disabledOpacity
    )
}

@Test func aPickerComparesEveryStoredProperty() {
    expectEveryPropertyCompared({ picker() }, [
        "title": picker(title: "Move “Work” to…"),
        "hint": picker(hint: TextModel(text: "Choose where it goes.", font: .hint, color: .ink2)),
        "cancel": picker(cancel: ChoiceModel(title: "Cancel", isDestructive: false, action: .first)),
        "topLevel": picker(topLevel: .init(
            icon: icon, tileSide: 30, tileCornerRadius: 8, tileColor: .fill, tileToTitle: 12, title: text, leading: 20,
            height: 46, accessories: [.check(icon)], cellMinimumWidth: 18, endGap: 20, isChecked: true, action: .first
        )),
        "options": picker(options: [.init(row: 1, isDisabled: true, isChecked: true)]),
        "hintGap": picker(hintGap: 10),
        "minimumOptionHeight": picker(minimumOptionHeight: 44),
        "disabledOpacity": picker(disabledOpacity: 0.5),
    ])
}

private func check(isChecked: Bool = false) -> CheckModel<Action> {
    CheckModel(
        style: .init(diameter: 24, ringWidth: 1.75, markSize: 15, markStrokeWidth: 1.75, hitWidth: 44, hitHeight: 44),
        colors: DesignSystem.Color.Components.Tile.blue.check, isChecked: isChecked, animation: .check,
        accessibilityLabel: "Complete", action: .first
    )
}

private let swipe = SwipeModel<Action>(
    style: .init(
        threshold: 40, shift: -88, buttonWidth: 78, buttonVerticalInset: 3, buttonTrailingInset: 10,
        buttonCornerRadius: 12
    ),
    button: TextModel(text: "Delete", font: .barLabel, color: .onAccent), background: .red, animation: .swipe,
    action: .second
)

private let lift = TaskLiftModel(
    scale: 1.03, opacity: 1, cornerRadius: 14, background: .surface, shadow: .lifted,
    indicator: DropIndicatorModel(
        height: 10, line: StrokeModel(color: .accent, width: 2, dash: []), lineOffset: 62, lineCornerRadius: 1,
        trailingGap: 20, circleDiameter: 8, circleOffset: 52,
        circleRing: StrokeModel(color: .accent, width: 2, dash: []), circleFill: .paper
    )
)

private let taskRowStyle = TaskRowStyle(
    titleToMeta: 3, metaSpacing: 10, metaLineSpacing: 3, verticalPadding: 11, titleLeading: 2, titleTrailing: 4,
    leading: 8, trailing: 12, minimumHeight: 44, cornerRadius: 0
)

private func taskRow(
    check: CheckModel<Action> = check(), title: TextModel = text, strike: DesignSystem.Color? = nil,
    meta: [MetaItemModel] = [], style: TaskRowStyle = taskRowStyle, swipe: SwipeModel<Action>? = nil,
    lift: TaskLiftModel? = nil, fresh: DesignSystem.Color? = nil, freshAnimation: DesignSystem.Animation = .fresh,
    tap: Action = .first, menu: MenuModel<Action>? = nil
) -> TaskRowModel<Action> {
    TaskRowModel(
        check: check, title: title, strike: strike, meta: meta, style: style, swipe: swipe, lift: lift, fresh: fresh,
        freshAnimation: freshAnimation, tap: tap, menu: menu
    )
}

@Test func aTaskRowModelComparesEveryProperty() {
    expectEveryPropertyCompared({ taskRow() }, [
        "check": taskRow(check: check(isChecked: true)),
        "title": taskRow(title: TextModel(text: "Call the plumber", font: .rowTitle, color: .ink)),
        "strike": taskRow(strike: .ink3),
        "meta": taskRow(meta: [MetaItemModel(icon: icon, text: text, spacing: 3, capsule: nil)]),
        "style": taskRow(style: .init(
            titleToMeta: 3, metaSpacing: 10, metaLineSpacing: 3, verticalPadding: 11, titleLeading: 2, titleTrailing: 4,
            leading: 8, trailing: 12, minimumHeight: 44, cornerRadius: 9
        )),
        "swipe": taskRow(swipe: swipe),
        "lift": taskRow(lift: lift),
        "fresh": taskRow(fresh: .fresh),
        "freshAnimation": taskRow(freshAnimation: .drop),
        "tap": taskRow(tap: .second),
        "menu": taskRow(menu: menu),
    ])
}

private let pill = PillModel(
    icon: IconModel(icon: .flag, size: 15, weight: .medium, color: .red), text: text, background: .fill,
    style: .init(height: 32, cornerRadius: 16, leadingPadding: 10, trailingPadding: 12, spacing: 6)
)

private let addSubtask = AddRowModel<Action>(
    icon: IconModel(icon: .plus, size: 17, weight: .medium, color: .ink2),
    title: TextModel(text: "Add subtask", font: .notes, color: .ink2),
    style: .init(
        iconCellWidth: 40, spacing: 0, height: 44, width: nil, cornerRadius: 0, topPadding: 0, leadingPadding: 0,
        trailingPadding: 0, dash: nil, rule: nil, topMargin: 0, leadingMargin: 0, trailingMargin: 0
    ),
    action: .first
)

private let expand = ButtonModel<Action>(
    label: ButtonLabelModel(
        icon: IconModel(icon: .expand, size: 19, weight: .medium, color: .ink2), title: nil,
        accessibilityLabel: "Open full screen", fill: .container
    ),
    action: .first
)

private let cardStyle = CardStyle(
    expandHitSide: 44, cornerRadius: 18, topMargin: 6, horizontalMargin: 10, bottomMargin: 10, bodyLeading: 46,
    bodyTrailing: 14, bodyBottom: 14, subtasksToPills: 10, pillSpacing: 6, shadow: .raised
)

private func card(
    check: CheckModel<Action> = check(), title: TextFieldModel<Action> = field("Call the plumber"),
    notes: TextFieldModel<Action> = field(""), subtasks: [SubtaskRowModel<Action>] = [],
    subtaskField: TextFieldModel<Action>? = nil, addSubtask: AddRowModel<Action> = addSubtask,
    pills: [PillModel] = [], expand: ButtonModel<Action> = expand, background: DesignSystem.Color = .surface,
    style: CardStyle = cardStyle, animation: DesignSystem.Animation = .cardOpens,
    backgroundTapped: Action = .first
) -> CardModel<Action> {
    CardModel(
        check: check, title: title, notes: notes, subtasks: subtasks, subtaskField: subtaskField,
        addSubtask: addSubtask, pills: pills, expand: expand, background: background, style: style,
        animation: animation, backgroundTapped: backgroundTapped
    )
}

@Test func aCardModelComparesEveryProperty() {
    expectEveryPropertyCompared({ card() }, [
        "check": card(check: check(isChecked: true)),
        "title": card(title: field("Call the plumber today")),
        "notes": card(notes: field("Ask about the boiler")),
        "subtasks": card(subtasks: [
            SubtaskRowModel(check: check(), title: text, strike: nil, style: .init(height: 44)),
        ]),
        "subtaskField": card(subtaskField: field("")),
        "addSubtask": card(addSubtask: AddRowModel(
            icon: IconModel(icon: .plus, size: 14, weight: .medium, color: .ink2),
            title: TextModel(text: "Add subtask", font: .notes, color: .ink2),
            style: .init(
                iconCellWidth: 30, spacing: 0, height: 30, width: nil, cornerRadius: 7, topPadding: 0,
                leadingPadding: 0, trailingPadding: 0, dash: nil, rule: nil, topMargin: 0, leadingMargin: 0,
                trailingMargin: 0
            ),
            action: .first
        )),
        "pills": card(pills: [pill]),
        "expand": card(expand: ButtonModel(label: expand.label, action: .second)),
        "background": card(background: .fill),
        "style": card(style: .init(
            expandHitSide: 44, cornerRadius: 18, topMargin: 6, horizontalMargin: 10, bottomMargin: 10, bodyLeading: 46,
            bodyTrailing: 14, bodyBottom: 14, subtasksToPills: 10, pillSpacing: 6, shadow: .lifted
        )),
        "animation": card(animation: .pushPop),
        "backgroundTapped": card(backgroundTapped: .second),
    ])
}

private let chevron = AccessoryModel<Action>.Chevron(
    icon: IconModel(icon: .chevron, size: 18, weight: .semibold, color: .ink3), rotation: 0, animation: .fold,
    accessibilityLabel: "Fold", action: .second
)

private let blockHeaderStyle = BlockHeaderStyle(
    titleToSubtitle: 8, rule: stroke, height: 44, topMargin: 6, trailingMargin: 6, bottomMargin: 2, leadingMargin: 12,
    topPadding: 13, horizontalPadding: 8, bottomPadding: 0, cornerRadius: 0
)

private func blockHeader(
    title: TextModel = text, subtitle: TextModel? = nil, field: TextFieldModel<Action>? = nil,
    fold: BlockHeaderModel<Action>.Fold? = BlockHeaderModel.Fold(chevron: chevron, hitSide: 44),
    style: BlockHeaderStyle = blockHeaderStyle, titleTapped: Action = .first
) -> BlockHeaderModel<Action> {
    BlockHeaderModel(
        title: title, subtitle: subtitle, field: field, fold: fold, style: style, titleTapped: titleTapped
    )
}

@Test func aBlockHeaderModelComparesEveryProperty() {
    expectEveryPropertyCompared({ blockHeader() }, [
        "title": blockHeader(title: TextModel(text: "Work", font: .sectionTitle, color: .ink)),
        "subtitle": blockHeader(subtitle: TextModel(text: "Tomorrow", font: .areaLabel, color: .ink2)),
        "field": blockHeader(field: field("New list")),
        "fold": blockHeader(fold: nil),
        "style": blockHeader(style: .init(
            titleToSubtitle: 8, rule: nil, height: 44, topMargin: 6, trailingMargin: 6, bottomMargin: 2,
            leadingMargin: 12, topPadding: 13, horizontalPadding: 8, bottomPadding: 0, cornerRadius: 0
        )),
        "titleTapped": blockHeader(titleTapped: .second),
    ])
}

private let plus = IconModel(icon: .plus, size: 18, weight: .regular, color: .ink2)

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
    let line = StrokeModel(color: .line, width: 1, dash: [])
    expectEveryPropertyCompared({ addRow() }, [
        "icon": addRow(icon: IconModel(icon: .plus, size: 17, weight: .regular, color: .ink2)),
        "title": addRow(title: TextModel(text: "Add list", font: .barLabel, color: .ink2)),
        "style": addRow(style: .init(
            iconCellWidth: 44, spacing: 0, height: 40, width: nil, cornerRadius: 12, topPadding: 0, leadingPadding: 0,
            trailingPadding: 12, dash: line, rule: line, topMargin: 0, leadingMargin: 8, trailingMargin: 12
        )),
        "action": addRow(action: .second),
    ])
}

private let doneStripStyle = DoneStripStyle(
    height: 36, cornerRadius: 18, spacing: 8, leadingPadding: 10, trailingPadding: 14, topMargin: 20,
    leadingMargin: 14, trailingMargin: 16
)

private func doneStrip(
    icon: IconModel = plus, label: TextModel = text, rotation: Double = 0, background: DesignSystem.Color = .fill,
    style: DoneStripStyle = doneStripStyle, isOpen: Bool = false, action: Action = .first
) -> DoneStripModel<Action> {
    DoneStripModel(
        icon: icon, label: label,
        chevron: AccessoryModel.Chevron(
            icon: plus, rotation: rotation, animation: .fold, accessibilityLabel: "Show done tasks", action: .first
        ),
        background: background, style: style, isOpen: isOpen, action: action
    )
}

@Test func aDoneStripModelComparesEveryProperty() {
    expectEveryPropertyCompared({ doneStrip() }, [
        "icon": doneStrip(icon: IconModel(icon: .checkCircle, size: 18, weight: .regular, color: .ink2)),
        "label": doneStrip(label: TextModel(text: "Done today · 3", font: .barLabel, color: .ink2)),
        "chevron": doneStrip(rotation: 180),
        "background": doneStrip(background: .surface),
        "style": doneStrip(style: .init(
            height: 30, cornerRadius: 18, spacing: 8, leadingPadding: 10, trailingPadding: 14, topMargin: 20,
            leadingMargin: 14, trailingMargin: 16
        )),
        "isOpen": doneStrip(isOpen: true),
        "action": doneStrip(action: .second),
    ])
}
