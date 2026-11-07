// Apps/Apple/Sources/TodoAppleUI/ListScreen/TaskRowView.swift
import DesignSystemComponents
import SwiftUI

/// A task's row as its model describes it (`TaskRowModel`; `Phone.dc.html`, the list screen's row), and a card of a
/// column, which the column stands on its card's look (`BlockRow`): its check, and beside it its title and meta line as
/// the button that opens it, every size, colour, font and word the model's. Each sends the action its model holds, and
/// what follows is the module's.
///
/// The drag, the menu, the swipe and the fresh fade wrap this view from outside (list screen plan, Task 8).
struct TaskRowView<Action: Equatable & Sendable>: View {
    private let model: TaskRowModel<Action>
    private let send: (Action) -> Void

    init(_ model: TaskRowModel<Action>, send: @escaping (Action) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            CheckButton(model.check, isChecked: model.check.isChecked) { send(model.check.action) }
            Button { send(model.tap) } label: { titleAndMeta }
                .buttonStyle(.plain)
        }
        .padding(.leading, model.style.leading)
        .padding(.trailing, model.style.trailing)
        .frame(minHeight: model.style.minimumHeight, alignment: .top)
    }

    /// The title and the meta line under it, the whole width the check leaves a place to tap.
    private var titleAndMeta: some View {
        VStack(alignment: .leading, spacing: model.style.titleToMeta) {
            Text(model.title)
                .strikethrough(model.style.strike != nil, color: model.style.strike.map { Color($0) })
                .multilineTextAlignment(.leading)
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
