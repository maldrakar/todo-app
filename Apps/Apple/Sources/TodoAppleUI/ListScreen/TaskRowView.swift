// Apps/Apple/Sources/TodoAppleUI/ListScreen/TaskRowView.swift
import DesignSystemComponents
import SwiftUI

/// A task's row as its model describes it (`TaskRowModel`; `Phone.dc.html`, the list screen's row; `Mac.dc.html`, the
/// pane's row), and a card of a column, which the column stands on its card's look (`BlockRow`): its check, and beside
/// it its title and meta line as the button that opens it, every size, colour, font and word the model's, the meta
/// under the title or after it on its line as its style says. Each sends the action its model holds, and what follows
/// is the module's: a tap beside the check sends its `tap`, which a click is on the Mac.
///
/// A tap on an open row's check takes the row away as `CompletingTask` says. While the pointer is over the row it is
/// tinted where its style gives the tint (`Hovering`).
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
        CompletingTask(model.check, leaving: model.style.leaving, send: send) { isCompleting, check, sendCheck in
            HStack(alignment: .top, spacing: 0) {
                CheckButton(check, send: sendCheck)
                Button { send(model.tap) } label: { titleAndMeta(isCompleting: isCompleting) }
                    .buttonStyle(.plain)
            }
            .padding(.leading, model.style.leading)
            .padding(.trailing, model.style.trailing)
            .frame(minHeight: model.style.minimumHeight, alignment: .top)
            .hoverTint(model.style.hover)
        }
    }

    /// The title and the meta line, the whole width the check leaves a place to tap: on the title's line after it,
    /// the title on one line and cut short before the items, which keep their size; or under it, wrapping.
    private func titleAndMeta(isCompleting: Bool) -> some View {
        Group {
            if model.style.metaTrailing {
                HStack(spacing: model.style.titleToMeta) {
                    title(isCompleting: isCompleting)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !model.meta.isEmpty {
                        HStack(spacing: model.style.metaSpacing) { meta }
                            .fixedSize()
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: model.style.titleToMeta) {
                    title(isCompleting: isCompleting)
                    if !model.meta.isEmpty {
                        WrappingRow(spacing: model.style.metaSpacing, lineSpacing: model.style.metaLineSpacing) {
                            meta
                        }
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

    /// The meta line's items, in their order.
    private var meta: some View {
        ForEach(model.meta.indices, id: \.self) { index in
            metaItem(model.meta[index])
        }
    }

    /// One item of the meta line: its glyph, its text, or both its spacing apart, on its capsule where it has one.
    @ViewBuilder private func metaItem(_ item: MetaItemModel) -> some View {
        let face = HStack(spacing: item.style.spacing) {
            if let icon = item.icon {
                Icon(icon)
            }
            if let text = item.text {
                Text(text)
            }
        }
        if let capsule = item.style.capsule {
            face
                .padding(.leading, capsule.leadingPadding)
                .padding(.trailing, capsule.trailingPadding)
                .frame(height: capsule.height)
                .background(
                    Color(capsule.background), in: .rect(cornerRadius: capsule.cornerRadius, style: .circular)
                )
        } else {
            face
        }
    }
}
