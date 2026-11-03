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
