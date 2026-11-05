// Sources/Features/TaskList/TaskList+Card.swift
import DesignSystem
import DesignSystemComponents
import TodoCore

/// The task opened in place (spec section 3; Task 8's table, Card; `Phone.dc.html`, the open card), and what the module
/// keeps of it between two events: session state a relaunch loses (ADR-0009, amendment of 2026-11-01).
extension TaskList {
    /// The open card: its task; what was typed into its title and its notes, nil until something was, while its fields
    /// show what the store keeps, so that a change a reread finds is drawn over a field no one typed in and never
    /// written over; its notes as read when it opened and as written since, since the list's read carries none
    /// (ADR-0002); its children, read with every reread, so that one just written shows (the controller's ruling on
    /// #176, 2026-11-05); and the subtask being typed, nil while no field is open.
    struct OpenCard {
        let id: TaskID
        var typedTitle: String?
        var notes: String
        var typedNotes: String?
        var subtasks: [TodoTask]
        var subtaskDraft: String?
    }

    /// The card of a task (spec section 3; the controller's ruling on #176, 2026-11-05): its check, its title's and
    /// notes' fields with what was typed or what the store keeps, its subtasks each with a small check, the subtask's
    /// field where one is open, "Add subtask", the pills, and Open full screen.
    static func card(
        of task: TodoTask, _ card: OpenCard, _ color: Tile, _ context: RowContext, _ metrics: Metrics.Card
    ) -> CardModel<UserAction> {
        let isOpen = task.status == .open
        return CardModel(
            check: check(title: task.title, isOpen: isOpen, color, action: .checkTapped(task.id), metrics.check),
            title: plainField(
                card.typedTitle ?? task.title, placeholder: "New task", font: .rowTitleEmphasized,
                color: isOpen ? .ink : .ink2, background: .surface, height: metrics.titleHeight,
                padding: metrics.titlePadding, submitted: .titleFieldSubmitted, cancelled: .titleFieldCancelled,
                focusLost: .titleFieldLostFocus
            ),
            notes: plainField(
                card.typedNotes ?? card.notes, placeholder: "Notes", font: .notes, color: .ink2, background: .surface,
                height: metrics.notesHeight, padding: 0, submitted: .notesFieldLostFocus, cancelled: .escapeKeyPressed,
                focusLost: .notesFieldLostFocus
            ),
            subtasks: card.subtasks.map { subtask(of: $0, color, metrics) },
            subtaskField: card.subtaskDraft.map { draft in
                plainField(
                    draft, placeholder: "Subtask", font: .notes, color: .ink, background: .surface,
                    height: metrics.subtaskFieldHeight, padding: 0, submitted: .subtaskFieldSubmitted,
                    cancelled: .subtaskFieldCancelled, focusLost: .subtaskFieldLostFocus
                )
            },
            addSubtask: addRow(title: "Add subtask", action: .addSubtaskTapped, metrics.addSubtask),
            pills: pills(of: task, today: context.today, tags: context.tags, metrics.pill),
            expand: ButtonModel(
                label: ButtonLabelModel(
                    icon: IconModel(icon: .expand, size: metrics.expandSize, weight: .regular, color: .ink2),
                    title: nil, accessibilityLabel: "Open full screen", fill: .color(.surface)
                ),
                action: .openFullScreenTapped
            ),
            expandHitSide: metrics.expandHitSide, background: .surface, cornerRadius: metrics.cornerRadius,
            topMargin: metrics.topMargin, horizontalMargin: metrics.horizontalMargin,
            bottomMargin: metrics.bottomMargin, bodyLeading: metrics.bodyLeading, bodyTrailing: metrics.bodyTrailing,
            bodyBottom: metrics.bodyBottom, subtasksToPills: metrics.subtasksToPills, pillSpacing: metrics.pillSpacing,
            shadow: metrics.shadow, animation: .cardOpens, backgroundTapped: .backgroundTapped
        )
    }

    /// A subtask's row in the card, in the card's list's colour, struck where it is no longer open (canvas).
    private static func subtask(
        of task: TodoTask, _ color: Tile, _ metrics: Metrics.Card
    ) -> SubtaskRowModel<UserAction> {
        let isOpen = task.status == .open
        return SubtaskRowModel(
            check: check(
                title: task.title, isOpen: isOpen, color, action: .subtaskCheckTapped(task.id), metrics.subtaskCheck
            ),
            title: TextModel(text: task.title, font: .notes, color: isOpen ? .ink : .ink2),
            strike: isOpen ? nil : .ink3, height: metrics.subtaskHeight
        )
    }

    /// The card's pills, drawn and inert in this epic (spec section 3; canvas, `.xpill`; the controller's ruling on
    /// #176, 2026-11-05): When with its sun, amber while it is set, and Deadline with its flag, red while it is set,
    /// each in ink 2 unset; the deadline's text red from the day it is due; and one per tag in the tags' order, the
    /// bare name after a hash in ink 2, a weight lighter than the two (`.areaLabel`, the pill's size at 500).
    private static func pills(
        of task: TodoTask, today: Day, tags: TagNames, _ metrics: Metrics.Pill
    ) -> [PillModel] {
        func pill(
            _ icon: DesignSystem.Icon, size: Double, iconColor: DesignSystem.Color, _ text: String,
            font: DesignSystem.Font = .pill, color: DesignSystem.Color
        ) -> PillModel {
            PillModel(
                icon: IconModel(icon: icon, size: size, weight: .regular, color: iconColor),
                text: TextModel(text: text, font: font, color: color), background: .fill, height: metrics.height,
                cornerRadius: metrics.height / 2, leadingPadding: metrics.leadingPadding,
                trailingPadding: metrics.trailingPadding, spacing: metrics.spacing
            )
        }
        let when = task.when.map { whenPillText($0, today: today) }
        let deadline = task.deadline
        return [
            pill(
                .sun, size: metrics.sunSize, iconColor: when == nil ? .ink2 : Tile.amber.glyph, when ?? "When",
                color: when == nil ? .ink2 : .ink
            ),
            pill(
                .flag, size: metrics.flagSize, iconColor: deadline == nil ? .ink2 : .red,
                deadline.map(deadlinePillText) ?? "Deadline",
                color: deadline.map { isDue($0, today: today) ? .red : .ink } ?? .ink2
            ),
        ] + tags.titles(of: task.tags).map {
            pill(.hash, size: metrics.hashSize, iconColor: .ink2, $0, font: .areaLabel, color: .ink)
        }
    }
}
