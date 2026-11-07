// Apps/Apple/Sources/TodoAppleUI/ListScreen/TaskRowView.swift
import DesignSystemComponents
import SwiftUI

/// A task's row as its model describes it (`TaskRowModel`; `Phone.dc.html`, the list screen's row), and a card of a
/// column, which the column stands on its card's look (`BlockRow`): its check, and beside it its title and meta line as
/// the button that opens it, every size, colour, font and word the model's. Each sends the action its model holds, and
/// what follows is the module's.
///
/// A tap on an open row's check writes the task done at once, and the module has no done task among its rows from then
/// on, so the row's last moments are this view's own, the one animation of that write (list screen spec, section 3):
/// its check fills, its title strikes through, and it stays a moment before it fades and sinks and the rows under it
/// close up. That is the `Leaving` of its style. A row that leaves any other way goes at once, a card opening in its
/// place among them, since only this tap animates. Where a person asked for less motion it goes at once too.
///
/// The drag, the menu, the swipe and the fresh fade wrap this view from outside (list screen plan, Task 8).
struct TaskRowView<Action: Equatable & Sendable>: View {
    private let model: TaskRowModel<Action>
    private let send: (Action) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Whether a tap on the check has just completed the task, whose row is drawn done from this moment, ahead of a
    /// model that will have no row for it, and which only this view can know. A row still here when its motion is over,
    /// a write the store refused among them, goes back to what its model says.
    @State private var isCompleting = false

    init(_ model: TaskRowModel<Action>, send: @escaping (Action) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            CheckButton(model.check, isChecked: model.check.isChecked || isCompleting, action: checkTapped)
            Button { send(model.tap) } label: { titleAndMeta }
                .buttonStyle(.plain)
        }
        .padding(.leading, model.style.leading)
        .padding(.trailing, model.style.trailing)
        .frame(minHeight: model.style.minimumHeight, alignment: .top)
        // One geometry, so that the row moves whole as those above it close up: its meta line's glyphs and words,
        // each placed on its own, drifted apart on that motion (the iOS 26.3 simulator, 2026-11-07).
        .geometryGroup()
        .transition(
            .asymmetric(
                insertion: .identity,
                removal: .opacity.combined(with: .offset(y: model.style.leaving.offset))
            )
        )
        .task(id: isCompleting) {
            guard isCompleting else { return }
            let motion = model.style.leaving.animation
            try? await Task.sleep(for: .seconds(motion.delay + motion.duration))
            if !Task.isCancelled { isCompleting = false }
        }
    }

    /// The check's tap: on an open row with its motion, and otherwise as it is, a done row's going back to its block at
    /// once (`Phone.dc.html`, `complete`).
    private func checkTapped() {
        guard !model.check.isChecked, !reduceMotion else {
            send(model.check.action)
            return
        }
        isCompleting = true
        withAnimation(Animation(model.style.leaving.animation)) { send(model.check.action) }
    }

    /// The title and the meta line under it, the whole width the check leaves a place to tap.
    private var titleAndMeta: some View {
        VStack(alignment: .leading, spacing: model.style.titleToMeta) {
            title
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
    private var title: some View {
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
