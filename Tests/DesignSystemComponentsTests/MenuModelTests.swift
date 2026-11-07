import Testing
import DesignSystemComponents

/// The items that came before Show as are built as they were: an item can be chosen and has nothing under its title
/// unless it is given otherwise.
@Test func anItemIsEnabledAndHasNoSubtitleUnlessItIsGivenThem() {
    let item = MenuModel.Item(title: "Delete", icon: .trash, isDestructive: true, shortcut: nil, action: 1)
    #expect(!item.isDisabled)
    #expect(item.subtitle == nil)
}

/// Show as's Columns, for a list with one block and no grouping, cannot be chosen and says why under its title (list
/// screen spec, section 5).
@Test func anItemCarriesWhetherItCanBeChosenAndTheLineUnderItsTitle() {
    let item = MenuModel.Item(
        title: "Columns", subtitle: "This list has one block", icon: .columns, isDestructive: false,
        isDisabled: true, shortcut: nil, action: 2
    )
    #expect(item.isDisabled)
    #expect(item.subtitle == "This list has one block")
}

/// A menu has no heading, and an item is no current choice, unless they are given: the menus that came before Show as
/// are built as they were.
@Test func aMenuHasNoHeadingAndItsItemsAreUncheckedUnlessTheyAreGiven() {
    let item = MenuModel.Item(title: "Delete", icon: .trash, isDestructive: true, shortcut: nil, action: 1)
    #expect(!item.isChecked)
    #expect(MenuModel(sections: [.init(items: [item])]).heading == nil)
}

/// Show as is headed "Show as" and checks its current layout's item (list screen spec, section 5).
@Test func aMenuCarriesItsHeadingAndWhichItemIsChecked() {
    let item = MenuModel.Item(
        title: "List", icon: .list, isDestructive: false, isChecked: true, shortcut: nil, action: 1
    )
    let menu = MenuModel(heading: "Show as", sections: [.init(items: [item])])
    #expect(menu.heading == "Show as")
    #expect(menu.sections.first?.items.first?.isChecked == true)
}
