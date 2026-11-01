// Apps/Apple/Sources/TodoAppleUI/ListsScreen/MovePickerSheet.swift
import DesignSystemComponents
import SwiftUI
import TaskViewListFeature

/// The picker of Move to… as its model describes it (`PickerModel`; `Phone.dc.html`, the Move to… sheet): its title,
/// which names the list being moved, and Cancel in its bar; the hint under the title; "Top level" first, a row of its
/// own; then the whole tree drawn with the screen's own rows, `ListRowView` with its end and `AreaLine`, picked by the
/// one switch over a row's kind (`docs/style.md`, "Views"), each at least as high as the model's least; the rows that
/// cannot take the list dimmed as the model says and disabled. Every row, "Top level" among them, ends in what its
/// model puts at its right, the check on the list's present parent and the room for it on every other row, so that the
/// rows end in one column (Lists screen spec, section 6; the owner, on #163's thread r4431052930). A row's tap sends
/// the action its model holds, `movePickerRowTapped`, and Cancel its own, `movePickerCancelled`; what a tap moves, and
/// that the picker closes, is the module's. The sheet is the platform's container, on the paper.
///
/// A row here has none of the guides or the pinning the tree gives it, as the canvas's picker has none: a list is
/// picked here and not opened or folded, and the module builds the rows with no menu, count, chevron, grip or highlight
/// (Task 7; the Lists screen plan, Task 8, the picker's options). A list's row stands on its background whole, as in
/// the tree.
struct MovePickerSheet: View {
    private let model: PickerModel<TaskViewList.Model.Kind, TaskViewList.UserAction>
    private let send: (TaskViewList.UserAction) -> Void

    init(
        model: PickerModel<TaskViewList.Model.Kind, TaskViewList.UserAction>,
        send: @escaping (TaskViewList.UserAction) -> Void
    ) {
        self.model = model
        self.send = send
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    topLevelRow
                    ForEach(model.options.indices, id: \.self) { index in
                        option(model.options[index])
                    }
                }
            }
            // The canvas's line under the title, on the sheet's paper.
            .safeAreaInset(edge: .top, spacing: 0) {
                Text(model.hint)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, model.hintGap)
                    .background(Color(.paper))
            }
            .navigationTitle(model.title)
            #if !os(macOS)
            // The title in the bar beside Cancel, as the canvas's, where iOS would otherwise draw it large under the
            // bar; the modifier is unavailable on macOS.
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.cancel.title, role: model.cancel.isDestructive ? .destructive : nil) {
                        send(model.cancel.action)
                    }
                }
            }
        }
        #if os(macOS)
        // A sheet on the Mac is as large as what it holds, and a scroll view asks for no height of its own: the size
        // the sidebar's plain picker had (2026-10-12), which no model holds, since it is the container's. iOS sizes a
        // sheet itself, and a minimum height there would cut the sheet of an iPhone turned sideways.
        .frame(minWidth: 320, minHeight: 400)
        #endif
        .presentationBackground(Color(.paper))
    }

    /// "Top level", with its glyph on a tile of its own where a list has its tile, and its accessories at its right, as
    /// the model has them.
    private var topLevelRow: some View {
        let topLevel = model.topLevel
        return Button { send(topLevel.action) } label: {
            HStack(spacing: 0) {
                HStack(spacing: topLevel.tileToTitle) {
                    Icon(topLevel.icon)
                        .frame(width: topLevel.tileSide, height: topLevel.tileSide)
                        .background(Color(topLevel.tileColor), in: .rect(cornerRadius: topLevel.tileCornerRadius))
                    Text(topLevel.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Accessories(
                    topLevel.accessories, cellMinimumWidth: topLevel.cellMinimumWidth, textMinimumWidth: nil,
                    endGap: topLevel.endGap, height: topLevel.height, send: send
                )
            }
            .padding(.leading, topLevel.leading)
            .frame(height: topLevel.height)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(topLevel.isChecked ? .isSelected : [])
    }

    /// A row of the tree, drawn by the screen's own row of its kind with what stands at its right, at least the model's
    /// least height, so that an unnamed area, the line alone, is no 17 pt target.
    @ViewBuilder private func option(
        _ option: PickerModel<TaskViewList.Model.Kind, TaskViewList.UserAction>.Option
    ) -> some View {
        switch option.row {
        case .area(let line):
            choice(option, tap: line.tap) {
                AreaLine(line, changed: TaskViewList.UserAction.titleFieldChanged, send: send)
            }
        case .list(let list):
            choice(option, tap: list.tap) {
                HStack(spacing: 0) {
                    ListRowView(list, changed: TaskViewList.UserAction.titleFieldChanged, send: send)
                    ListRowView.End(list, send: send)
                }
                .background(Color(list.background))
            }
        }
    }

    /// An option as a button that sends the row's tap, disabled and dimmed where it cannot be chosen.
    private func choice(
        _ option: PickerModel<TaskViewList.Model.Kind, TaskViewList.UserAction>.Option, tap: TaskViewList.UserAction,
        @ViewBuilder row: () -> some View
    ) -> some View {
        Button { send(tap) } label: {
            row()
                .frame(minHeight: model.minimumOptionHeight)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(option.isChecked ? .isSelected : [])
        .disabled(option.isDisabled)
        .opacity(option.isDisabled ? model.disabledOpacity : 1)
    }
}
