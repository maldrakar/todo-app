// Apps/Apple/Sources/TodoAppleUI/ListScreen/TaskCardView.swift
import DesignSystemComponents
import SwiftUI

/// A task's card, its row opened in place, as its model describes it (`CardModel`; `Phone.dc.html`, the open card):
/// along its top its check, its title's field and the button that opens it full screen; under them, in from its leading
/// edge, the notes' field, the subtasks, the field of the one being typed or the row that adds one, and the pills.
/// Every size, colour, font and word is the model's, and each control sends the action its model holds. The actions the
/// typed text of its three fields sends are made by `titleChanged`, `notesChanged` and `subtaskChanged`, which a model
/// cannot hold (`TextFieldModel`).
///
/// A tap on its check takes the card away as `CompletingTask` says, as a row's does. A tap on the card's own background
/// is the card's, so that it does not reach the screen's, which closes it (`ListScreen`). The title takes the focus
/// when the card appears with an empty title, a new task's, and the keyboard rises with it. The subtask's field takes
/// it when it appears, and back after Return, since Return opens the next (`PlainField`).
struct TaskCardView<Action: Equatable & Sendable>: View {
    private let model: CardModel<Action>
    private let titleChanged: (String) -> Action
    private let notesChanged: (String) -> Action
    private let subtaskChanged: (String) -> Action
    private let send: (Action) -> Void

    /// Whether a person asked for less motion: a subtask's title then changes colour at once.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        _ model: CardModel<Action>, titleChanged: @escaping (String) -> Action,
        notesChanged: @escaping (String) -> Action, subtaskChanged: @escaping (String) -> Action,
        send: @escaping (Action) -> Void
    ) {
        self.model = model
        self.titleChanged = titleChanged
        self.notesChanged = notesChanged
        self.subtaskChanged = subtaskChanged
        self.send = send
    }

    var body: some View {
        CompletingTask(model.check, leaving: model.style.leaving, send: send) { isCompleting, checkTapped in
            VStack(alignment: .leading, spacing: 0) {
                top(isCompleting: isCompleting, checkTapped: checkTapped)
                VStack(alignment: .leading, spacing: 0) {
                    PlainField(
                        model.notes, axis: .vertical, focusesOnAppear: false, changed: notesChanged, send: send
                    )
                    .padding(.top, model.style.titleToNotes)
                    subtasks
                        .padding(.top, model.style.notesToSubtasks)
                    WrappingRow(spacing: model.style.pillSpacing, lineSpacing: model.style.pillSpacing) {
                        ForEach(model.pills.indices, id: \.self) { index in
                            pill(model.pills[index])
                        }
                    }
                    .padding(.top, model.style.subtasksToPills)
                }
                .padding(.leading, model.style.bodyLeading)
                .padding(.trailing, model.style.bodyTrailing)
                .padding(.bottom, model.style.bodyBottom)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // The shadow on the shape alone, since on the card it would be cast by each thing on it.
            .background {
                RoundedRectangle(cornerRadius: model.style.cornerRadius, style: .circular)
                    .fill(Color(model.style.background))
                    .shadow(model.style.shadow)
            }
            .contentShape(.rect)
            .onTapGesture {}
            .modifier(Entrance(model.style.entrance))
            .padding(.top, model.style.topMargin)
            .padding(.horizontal, model.style.horizontalMargin)
            .padding(.bottom, model.style.bottomMargin)
        }
    }

    /// The check, the title's field and Open full screen.
    private func top(isCompleting: Bool, checkTapped: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 0) {
            CheckButton(model.check, isChecked: model.check.isChecked || isCompleting, action: checkTapped)
            PlainField(
                model.title, focusesOnAppear: model.title.text.isEmpty,
                color: isCompleting ? model.style.leaving.titleColor : nil,
                strike: isCompleting ? model.style.leaving.strike : model.style.titleStrike, changed: titleChanged,
                send: send
            )
            Button { send(model.expand.action) } label: {
                expandFace
                    .frame(width: model.style.expandHitSide, height: model.style.expandHitSide)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.expand.label.accessibilityLabel)
        }
    }

    /// Open full screen's glyph on what its label puts it on, every case drawn and none by `default`
    /// (`docs/style.md`, "Views"): the card's own surface under it, or a fill of its own.
    @ViewBuilder private var expandFace: some View {
        let glyph = Icon(model.expand.label.icon)
        switch model.expand.label.style.fill {
        case .container:
            glyph
        case .color(let color):
            glyph
                .frame(width: model.style.expandHitSide, height: model.style.expandHitSide)
                .background(Color(color), in: Circle())
        }
    }

    /// The subtasks, then the field of the one being typed or the row that adds one, whose own margin stands it as far
    /// outside the body's edge as the subtasks stand, so that their checks and its plus stand under the card's check.
    private var subtasks: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.subtasks.indices, id: \.self) { index in
                subtask(model.subtasks[index])
                    .padding(.leading, -model.style.subtasksOutdent)
            }
            if let field = model.subtaskField {
                subtaskField(field)
                    .padding(.leading, -model.style.subtasksOutdent)
            } else {
                AddRowView(model.addSubtask, send: send)
            }
        }
    }

    /// A subtask's row: its check, and beside it its title, struck where it is done.
    private func subtask(_ subtask: SubtaskRowModel<Action>) -> some View {
        HStack(spacing: 0) {
            CheckButton(subtask.check, isChecked: subtask.check.isChecked) { send(subtask.check.action) }
            Text(subtask.title.text)
                .font(Font(subtask.title.style.font))
                .strikethrough(subtask.style.strike != nil, color: subtask.style.strike.map { Color($0) })
                .multilineTextAlignment(.leading)
                // The colour alone, as a row's (`TaskRowView`).
                .animation(reduceMotion ? nil : Animation(subtask.style.titleAnimation)) { text in
                    text.foregroundStyle(Color(subtask.title.style.color))
                }
        }
        .frame(minHeight: subtask.style.height)
    }

    /// The field a new subtask is typed into, after a check's ring with nothing to mark yet.
    private func subtaskField(_ field: TextFieldModel<Action>) -> some View {
        let circle = model.style.subtaskDraftCircle
        return HStack(spacing: 0) {
            CheckCircle(circle, isChecked: false)
                .frame(width: circle.hitWidth, height: circle.hitHeight)
            PlainField(
                field, focusesOnAppear: true, keepsFocusOnSubmit: true, changed: subtaskChanged, send: send
            )
        }
    }

    /// A pill, which is drawn and inert in this epic (list screen spec, section 3): its glyph and its text.
    private func pill(_ pill: PillModel) -> some View {
        HStack(spacing: pill.style.spacing) {
            Icon(pill.icon)
            Text(pill.text)
                .lineLimit(1)
        }
        .padding(.leading, pill.style.leadingPadding)
        .padding(.trailing, pill.style.trailingPadding)
        .frame(height: pill.style.height)
        .background(Color(pill.style.background), in: .rect(cornerRadius: pill.style.cornerRadius, style: .circular))
    }
}
