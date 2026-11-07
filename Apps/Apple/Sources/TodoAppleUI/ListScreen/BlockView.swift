// Apps/Apple/Sources/TodoAppleUI/ListScreen/BlockView.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature

/// A block of the list as its model describes it (`TaskList.Model.Block`; `Phone.dc.html`, the group): its header where
/// it has one, its rows, and "+ Add task" at its end where its rule reads as an edit. What it holds arrives finished in
/// the model, and folding it takes its rows out of it, so this view decides nothing.
struct BlockView: View {
    private let block: TaskList.Model.Block
    private let send: (TaskList.UserAction) -> Void

    init(_ block: TaskList.Model.Block, send: @escaping (TaskList.UserAction) -> Void) {
        self.block = block
        self.send = send
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header = block.header {
                BlockHeaderView(header, send: send)
            }
            ForEach(block.rows) { row in
                BlockRow(row, send: send)
            }
            if let addTask = block.addTask {
                AddRowView(addTask, send: send)
            }
        }
    }
}

/// A row of a block, of the strip or of a column, by its kind: the one switch over a row's kinds, every case drawn and
/// none by `default` (`docs/style.md`, "Views"). In a column, whose style it is given, a row stands on the card's look
/// and an open card, which draws its own surface and shadow, has only the card's hairline round it (`Phone.dc.html`,
/// `.card`).
struct BlockRow: View {
    private let row: TaskList.Model.Row
    private let column: ColumnStyle?
    private let send: (TaskList.UserAction) -> Void

    init(_ row: TaskList.Model.Row, column: ColumnStyle? = nil, send: @escaping (TaskList.UserAction) -> Void) {
        self.row = row
        self.column = column
        self.send = send
    }

    var body: some View {
        switch row {
        case .task(_, let task):
            TaskRowView(task, send: send)
                .modifier(ColumnCardSurface(column: column))
                .modifier(ColumnCardRing(column: column))
        case .card(_, let card):
            TaskCardView(
                card, titleChanged: { .titleFieldChanged($0) }, notesChanged: { .notesFieldChanged($0) },
                subtaskChanged: { .subtaskFieldChanged($0) }, send: send
            )
            .modifier(ColumnCardRing(column: column))
        }
    }

    /// What a card of a column stands on, and nothing for a row of the list.
    private struct ColumnCardSurface: ViewModifier {
        let column: ColumnStyle?

        func body(content: Content) -> some View {
            if let column {
                content.background {
                    RoundedRectangle(cornerRadius: column.cardCornerRadius, style: .circular)
                        .fill(Color(column.cardBackground))
                        .shadow(column.cardShadow)
                }
            } else {
                content
            }
        }
    }

    /// The hairline round a card of a column, and nothing for a row of the list.
    private struct ColumnCardRing: ViewModifier {
        let column: ColumnStyle?

        func body(content: Content) -> some View {
            if let column {
                content.overlay {
                    RoundedRectangle(cornerRadius: column.cardCornerRadius, style: .circular)
                        .stroke(column.cardRing)
                }
            } else {
                content
            }
        }
    }
}

/// A block's or a column's header as its model describes it (`BlockHeaderModel`; `Phone.dc.html`, the group header and
/// `.bcol-h`): its title and its subtitle on one baseline as the button that opens the block, or the field in their
/// place while the list is being named; the chevron that folds it, where it has one; and its rule along its bottom,
/// where it has one.
struct BlockHeaderView: View {
    private let model: BlockHeaderModel<TaskList.UserAction>
    private let send: (TaskList.UserAction) -> Void

    /// Whether a person asked for less motion: the chevron then turns without its animation.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ model: BlockHeaderModel<TaskList.UserAction>, send: @escaping (TaskList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            title
            if let fold = model.fold {
                chevron(fold)
            }
        }
        .frame(height: model.style.height)
        .overlay(alignment: .bottom) {
            if let rule = model.style.rule {
                Rule(rule, along: .horizontal)
            }
        }
        .padding(.top, model.style.topMargin)
        .padding(.trailing, model.style.trailingMargin)
        .padding(.bottom, model.style.bottomMargin)
        .padding(.leading, model.style.leadingMargin)
    }

    /// The title's control, padded in the header's height, on the header's whole width beside the chevron.
    @ViewBuilder private var title: some View {
        if let field = model.field {
            PlainField(field, focusesOnAppear: true, changed: { .listNameFieldChanged($0) }, send: send)
                .padding(.top, model.style.topPadding)
                .padding(.horizontal, model.style.horizontalPadding)
                .padding(.bottom, model.style.bottomPadding)
        } else {
            Button { send(model.titleTapped) } label: {
                HStack(alignment: .firstTextBaseline, spacing: model.style.titleToSubtitle) {
                    Text(model.title)
                        .lineLimit(1)
                    if let subtitle = model.subtitle {
                        Text(subtitle)
                            .lineLimit(1)
                    }
                }
                .padding(.top, model.style.topPadding)
                .padding(.horizontal, model.style.horizontalPadding)
                .padding(.bottom, model.style.bottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    /// The chevron that folds the block, turning on its motion, centred in its square cell, which reads aloud what a
    /// tap will do.
    private func chevron(_ fold: AccessoryModel<TaskList.UserAction>.Chevron) -> some View {
        let side = model.style.foldHitSide.map { CGFloat($0) }
        return Button { send(fold.action) } label: {
            Icon(fold.icon)
                .rotationEffect(.degrees(fold.style.rotation))
                .animation(reduceMotion ? nil : Animation(fold.style.animation), value: fold.style.rotation)
                .frame(width: side, height: side)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fold.accessibilityLabel)
    }
}

/// A row that adds as its model describes it (`AddRowModel`; `Phone.dc.html`, "+ Add task", "Add subtask" and "+ Add
/// list"): its rule along its top and the room under it, where it has one; its glyph centred in its cell and its title
/// after it, the whole of it the button; its dashed edge where it has one; and its margins.
struct AddRowView<Action: Equatable & Sendable>: View {
    private let model: AddRowModel<Action>
    private let send: (Action) -> Void

    init(_ model: AddRowModel<Action>, send: @escaping (Action) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let rule = model.style.rule {
                Rule(rule, along: .horizontal)
            }
            Button { send(model.action) } label: {
                HStack(spacing: model.style.spacing) {
                    Icon(model.icon)
                        .frame(width: model.style.iconCellWidth, height: model.style.height)
                    Text(model.title)
                        .lineLimit(1)
                }
                .padding(.leading, model.style.leadingPadding)
                .padding(.trailing, model.style.trailingPadding)
                .frame(width: model.style.width.map { CGFloat($0) }, alignment: .leading)
                .contentShape(.rect(cornerRadius: model.style.cornerRadius, style: .circular))
            }
            .buttonStyle(.plain)
            .padding(.top, model.style.topPadding)
        }
        .overlay {
            if let dash = model.style.dash {
                RoundedRectangle(cornerRadius: model.style.cornerRadius, style: .circular)
                    .strokeBorder(
                        Color(dash.color),
                        style: StrokeStyle(lineWidth: dash.width, dash: dash.dash.map { CGFloat($0) })
                    )
            }
        }
        .padding(.top, model.style.topMargin)
        .padding(.leading, model.style.leadingMargin)
        .padding(.trailing, model.style.trailingMargin)
    }
}
