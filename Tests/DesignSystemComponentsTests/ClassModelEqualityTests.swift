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
    background: DesignSystem.Color = .paper, guides: [Double] = [], childGuides: [Double] = [35],
    guide: StrokeModel = stroke, accessories: [AccessoryModel<Action>] = [.space(20)], fadeWidth: Double = 10,
    countMinimumWidth: Double = 20, cellWidth: Double = 36, endGap: Double = 4, accessoriesWidth: Double = 72,
    tap: Action = .first, menu: MenuModel<Action>? = nil
) -> ListRowModel<Action> {
    ListRowModel(
        height: height, leading: leading, tile: tile, tileToTitle: tileToTitle, title: title, field: field, need: need,
        background: background, guides: guides, childGuides: childGuides, guide: guide, accessories: accessories,
        fadeWidth: fadeWidth, countMinimumWidth: countMinimumWidth, cellWidth: cellWidth, endGap: endGap,
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
        "guides": listRow(guides: [35]),
        "childGuides": listRow(childGuides: [35, 55]),
        "guide": listRow(guide: StrokeModel(color: .line, width: 1.5, dash: [])),
        "accessories": listRow(accessories: [.space(20), .space(36)]),
        "fadeWidth": listRow(fadeWidth: 0),
        "countMinimumWidth": listRow(countMinimumWidth: 22),
        "cellWidth": listRow(cellWidth: 18),
        "endGap": listRow(endGap: 20),
        "accessoriesWidth": listRow(accessoriesWidth: 108),
        "tap": listRow(tap: .second),
        "menu": listRow(menu: menu),
    ])
}

private func areaLine(
    height: Double = 36, leading: Double = 20, spacing: Double = 10, label: TextModel? = text,
    field: TextFieldModel<Action>? = nil, line: StrokeModel = stroke, lineToAccessories: Double = 20,
    accessories: [AccessoryModel<Action>] = [], cellWidth: Double = 22, endGap: Double = 0, tap: Action = .first,
    menu: MenuModel<Action>? = nil
) -> AreaLineModel<Action> {
    AreaLineModel(
        height: height, leading: leading, spacing: spacing, label: label, field: field, line: line,
        lineToAccessories: lineToAccessories, accessories: accessories, cellWidth: cellWidth, endGap: endGap, tap: tap,
        menu: menu
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
        "cellWidth": areaLine(cellWidth: 18),
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
    slot: DragModel.Slot = slot, card: DragModel.Card = card
) -> DragModel {
    DragModel(indent: indent, animation: animation, slot: slot, card: card)
}

@Test func aDragComparesEveryStoredProperty() {
    expectEveryPropertyCompared({ drag() }, [
        "indent": drag(indent: IndentModel(start: 20, step: 24)),
        "animation": drag(animation: .check),
        "slot": drag(slot: DragModel.Slot(
            height: 50, inset: 6, trailingGap: 12, verticalInset: 4, cornerRadius: 13, fill: .accentSoft, stroke: stroke
        )),
        "card": drag(card: DragModel.Card(
            raise: 8, scale: 1.03, rotation: -1.5, shadow: .lifted, background: .surface, grip: icon, gripCell: 40,
            minimumWidth: 120, listHeight: 50, listInset: 2, listPadding: 12, listTrailingGap: 6, listCornerRadius: 14,
            lineHeight: 36, lineInset: 8, lineTrailingGap: 8, lineCornerRadius: 12
        )),
    ])
}

private let topLevel = PickerModel<Int, Action>.TopLevel(
    icon: icon, tileSide: 30, tileCornerRadius: 8, tileColor: .fill, tileToTitle: 12, title: text, leading: 20,
    height: 46, accessories: [.space(18)], cellWidth: 18, endGap: 20, isChecked: false, action: .first
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
            height: 46, accessories: [.check(icon)], cellWidth: 18, endGap: 20, isChecked: true, action: .first
        )),
        "options": picker(options: [.init(row: 1, isDisabled: true, isChecked: true)]),
        "hintGap": picker(hintGap: 10),
        "minimumOptionHeight": picker(minimumOptionHeight: 44),
        "disabledOpacity": picker(disabledOpacity: 0.5),
    ])
}
