// Apps/Apple/Sources/TodoAppleUI/ListScreen/TaskRowView.swift
import DesignSystemComponents
import SwiftUI

/// A task's row as its model describes it (`TaskRowModel`; `Phone.dc.html`, the list screen's row), and a card of a
/// column, which the column stands on its card's look (`BlockRow`): its check, and beside it its title and meta line as
/// the button that opens it, every size, colour, font and word the model's. Each sends the action its model holds, and
/// what follows is the module's.
///
/// A tap on an open row's check takes the row away as `CompletingTask` says.
///
/// The drag, the menu, the swipe and the fresh fade wrap this view from outside (`BlockRow`).
struct TaskRowView<Action: Equatable & Sendable>: View {
    private let model: TaskRowModel<Action>
    private let send: (Action) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ model: TaskRowModel<Action>, send: @escaping (Action) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        CompletingTask(model.check, leaving: model.style.leaving, send: send) { isCompleting, checkTapped in
            HStack(alignment: .top, spacing: 0) {
                CheckButton(model.check, isChecked: model.check.isChecked || isCompleting, action: checkTapped)
                Button { send(model.tap) } label: { titleAndMeta(isCompleting: isCompleting) }
                    .buttonStyle(.plain)
            }
            .padding(.leading, model.style.leading)
            .padding(.trailing, model.style.trailing)
            .frame(minHeight: model.style.minimumHeight, alignment: .top)
        }
    }

    /// The title and the meta line under it, the whole width the check leaves a place to tap.
    private func titleAndMeta(isCompleting: Bool) -> some View {
        VStack(alignment: .leading, spacing: model.style.titleToMeta) {
            title(isCompleting: isCompleting)
            if !model.meta.isEmpty {
                WrappingRow(spacing: model.style.metaSpacing, lineSpacing: model.style.metaLineSpacing) {
                    ForEach(model.meta.indices, id: \.self) { index in
                        metaItem(model.meta[index])
                    }
                }
            }
        }
        .padding(.vertical, model.style.verticalPadding)
        .padding(.leading, model.style.titleLeading)
        .padding(.trailing, model.style.titleTrailing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    /// The title, in its model's colour and line or as its row leaves.
    private func title(isCompleting: Bool) -> some View {
        let strike = isCompleting ? model.style.leaving.strike : model.style.strike
        return Text(model.title.text)
            .font(Font(model.title.style.font))
            .strikethrough(strike != nil, color: strike.map { Color($0) })
            .multilineTextAlignment(.leading)
            // The colour alone: over the whole text, the motion moved its words off their line as it struck them
            // (the iOS 26.3 simulator, 2026-11-07).
            .animation(reduceMotion ? nil : Animation(model.style.titleAnimation)) { text in
                text.foregroundStyle(Color(isCompleting ? model.style.leaving.titleColor : model.title.style.color))
            }
    }

    /// One item of the meta line: its glyph, its text, or both its spacing apart.
    private func metaItem(_ item: MetaItemModel) -> some View {
        HStack(spacing: item.style.spacing) {
            if let icon = item.icon {
                Icon(icon)
            }
            if let text = item.text {
                Text(text)
            }
        }
    }
}
