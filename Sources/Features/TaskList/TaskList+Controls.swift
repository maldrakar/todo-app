// Sources/Features/TaskList/TaskList+Controls.swift
import DesignSystem
import DesignSystemComponents
import TodoCore

/// The screen's controls that write: the rows that add and the floating "+", the Done strip's capsule, a row's swipe
/// and its menu (Task 8's table, Add rows, Done strip, Floating "+" and Swipe; the controller's ruling on #176,
/// 2026-11-05, their words).
extension TaskList {
    /// A block's "+ Add task", and none where the block's rule reads as no edit.
    static func addTaskRow(for block: PageBlock, _ metrics: Metrics.AddRow) -> AddRowModel<UserAction>? {
        block.edit.map { _ in addRow(title: "Add task", action: .addTaskRowTapped(in: block.id), metrics) }
    }

    /// "+ Add list", in the list and on the board.
    static func addListRow(_ metrics: Metrics.AddRow) -> AddRowModel<UserAction> {
        addRow(title: "Add list", action: .addListTapped, metrics)
    }

    /// A row that adds, its plus and its title in ink 2.
    static func addRow(title: String, action: UserAction, _ metrics: Metrics.AddRow) -> AddRowModel<UserAction> {
        AddRowModel(
            icon: IconModel(icon: .plus, size: metrics.iconSize, weight: .regular, color: .ink2),
            title: TextModel(text: title, font: metrics.font, color: .ink2), style: metrics.style, action: action
        )
    }

    /// What a task with no title is called: what the floating "+" adds, what the card's title field shows while it is
    /// empty, and what a row draws for such a task (the controller's ruling on #176, 2026-11-05).
    static let newTaskTitle = "New task"

    /// What a row draws for a task and a check reads aloud, on the row and on its open card alike: its title, and
    /// `newTaskTitle` for a task with none or a blank one.
    static func drawnTitle(of task: TodoTask) -> String {
        task.title.trimmed().isEmpty ? newTaskTitle : task.title
    }

    /// The floating "+": a white plus on the accent, casting the raised shadow.
    static func floatingButton(_ metrics: Metrics.FloatingButton) -> FloatingButtonModel<UserAction> {
        FloatingButtonModel(
            icon: IconModel(icon: .plus, size: metrics.glyphSize, weight: .semibold, color: .onAccent),
            style: metrics.style, fill: .accent, shadow: .raised, accessibilityLabel: newTaskTitle,
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
            background: .fill, style: metrics.style, isOpen: isOpen, action: .doneStripTapped
        )
    }

    /// What a row's swipe and its menu both call what they do.
    private static let deleteTitle = "Delete"

    /// A row's swipe to its Delete.
    static func swipe(of id: TaskID, _ style: SwipeModel<UserAction>.Style) -> SwipeModel<UserAction> {
        SwipeModel(
            style: style,
            button: TextModel(text: deleteTitle, font: .barLabel, color: .onAccent), background: .red,
            animation: .swipe, action: .deleteSwiped(id)
        )
    }

    /// A row's menu, the Mac's right click: Delete, with the trash's glyph, as what destroys something (spec section 6;
    /// the controller's ruling on #176, 2026-11-05).
    static func deleteMenu(of id: TaskID) -> MenuModel<UserAction> {
        MenuModel(sections: [
            .init(items: [
                .init(
                    title: deleteTitle, icon: .trash, isDestructive: true, shortcut: nil,
                    action: .deleteMenuItemChosen(id)
                ),
            ]),
        ])
    }
}
