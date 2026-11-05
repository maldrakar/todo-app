// Sources/Features/TaskList/TaskList+Controls.swift
import DesignSystem
import DesignSystemComponents
import TodoCore

/// The screen's controls that write: the rows that add and the floating "+", the Done strip's capsule, a row's swipe
/// and its menu (Task 8's table, Add rows, Done strip, Floating "+" and Swipe; the controller's ruling on #176,
/// 2026-11-05, their words).
extension TaskList {
    /// A block's "+ Add task", and none where the block's rule reads as no edits.
    static func addTaskRow(for block: PageBlock, _ metrics: Metrics.AddRow) -> AddRowModel<UserAction>? {
        block.edits.map { _ in addRow(title: "Add task", action: .addTaskRowTapped(in: block.id), metrics) }
    }

    /// "+ Add list", in the list and on the board.
    static func addListRow(_ metrics: Metrics.AddRow) -> AddRowModel<UserAction> {
        addRow(title: "Add list", action: .addListTapped, metrics)
    }

    /// A row that adds, its plus and its title in ink 2.
    static func addRow(title: String, action: UserAction, _ metrics: Metrics.AddRow) -> AddRowModel<UserAction> {
        AddRowModel(
            icon: IconModel(icon: .plus, size: metrics.iconSize, weight: .regular, color: .ink2),
            iconCellWidth: metrics.iconCellWidth, spacing: metrics.spacing,
            title: TextModel(text: title, font: metrics.font, color: .ink2), height: metrics.height,
            width: metrics.width, cornerRadius: metrics.cornerRadius, topPadding: metrics.topPadding,
            leadingPadding: metrics.leadingPadding, trailingPadding: metrics.trailingPadding, dash: metrics.dash,
            rule: metrics.rule, topMargin: metrics.topMargin, leadingMargin: metrics.leadingMargin,
            trailingMargin: metrics.trailingMargin, action: action
        )
    }

    /// The floating "+": a white plus on the accent, casting the raised shadow.
    static func floatingButton(_ metrics: Metrics.FloatingButton) -> FloatingButtonModel<UserAction> {
        FloatingButtonModel(
            icon: IconModel(icon: .plus, size: metrics.glyphSize, weight: .semibold, color: .onAccent),
            diameter: metrics.diameter, fill: .accent, shadow: .raised, accessibilityLabel: "New task",
            action: .addTaskButtonTapped
        )
    }

    /// The Done strip's capsule (spec section 3; the controller's ruling on #176, 2026-11-05): the check in a circle in
    /// the list's glyph colour, "Done today · N" on every list, and the chevron, turned half round while it is open,
    /// saying what a tap will do.
    static func doneStrip(
        count: Int, isOpen: Bool, color: Tile, _ metrics: Metrics.DoneStrip
    ) -> DoneStripModel<UserAction> {
        DoneStripModel(
            icon: IconModel(icon: .checkCircle, size: metrics.iconSize, weight: .regular, color: color.glyph),
            label: TextModel(text: "Done today · \(count)", font: .barLabel, color: .ink2),
            chevron: AccessoryModel.Chevron(
                icon: IconModel(icon: .chevron, size: metrics.chevronSize, weight: .semibold, color: .ink2),
                rotation: isOpen ? 180 : 0, animation: .fold,
                accessibilityLabel: isOpen ? "Hide done tasks" : "Show done tasks", action: .doneStripTapped
            ),
            background: .fill, height: metrics.height, cornerRadius: metrics.height / 2, spacing: metrics.spacing,
            leadingPadding: metrics.leadingPadding, trailingPadding: metrics.trailingPadding,
            topMargin: metrics.topMargin, leadingMargin: metrics.leadingMargin, trailingMargin: metrics.trailingMargin,
            isOpen: isOpen, action: .doneStripTapped
        )
    }

    /// A row's swipe to its Delete.
    static func swipe(of id: TaskID, _ metrics: Metrics.Swipe) -> SwipeModel<UserAction> {
        SwipeModel(
            threshold: metrics.threshold, shift: metrics.shift, buttonWidth: metrics.buttonWidth,
            buttonVerticalInset: metrics.buttonVerticalInset, buttonTrailingInset: metrics.buttonTrailingInset,
            buttonCornerRadius: metrics.buttonCornerRadius,
            button: TextModel(text: "Delete", font: .barLabel, color: .onAccent), background: .red, animation: .swipe,
            action: .deleteSwiped(id)
        )
    }

    /// A row's menu, the Mac's right click: Delete, with the trash's glyph, as what destroys something (spec section 6;
    /// the controller's ruling on #176, 2026-11-05).
    static func deleteMenu(of id: TaskID) -> MenuModel<UserAction> {
        MenuModel(sections: [
            .init(items: [
                .init(
                    title: "Delete", icon: .trash, isDestructive: true, shortcut: nil,
                    action: .deleteMenuItemChosen(id)
                ),
            ]),
        ])
    }
}
