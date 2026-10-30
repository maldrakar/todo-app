// Apps/Apple/Sources/TodoAppleUI/ListsScreen/MovePickerSheet.swift
import SwiftUI
import TaskViewListFeature

/// The picker of Move to…, as the canvas draws it (`Phone.dc.html`, the Move to… sheet): its title, which names the
/// list being moved, and Cancel in its bar; "Top level" first, then the whole tree drawn with the screen's own rows,
/// `ListRowView` and `AreaLine`, picked by the one switch over a row's kind (`docs/style.md`, "Views"); the rows that
/// cannot take the list dimmed and disabled, and the list's present parent checked (Lists screen spec, section 6). A
/// row's tap sends `movePickerRowTapped` and Cancel `movePickerCancelled`; what a tap moves, and that the picker
/// closes, is the module's. The rows carry no count and no chevron here, as the canvas's picker has none: a list is
/// picked here and not opened or folded.
struct MovePickerSheet: View {
    private let model: TaskViewList.Model.MovePicker
    private let send: (TaskViewList.UserAction) -> Void

    init(model: TaskViewList.Model.MovePicker, send: @escaping (TaskViewList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    topLevelRow
                    ForEach(model.rows) { pickerRow in
                        row(pickerRow)
                    }
                }
            }
            // The canvas's line under the title, the sheet's own words.
            .safeAreaInset(edge: .top, spacing: 0) {
                Text("Choose where it goes.")
                    .font(.footnote)
                    .foregroundStyle(Color(.ink2))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
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
                    Button("Cancel") { send(.movePickerCancelled) }
                }
            }
        }
        .presentationBackground(Color(.paper))
    }

    /// "Top level", with the canvas's glyph of a line on a tile of the fill colour where a list has its own tile.
    private var topLevelRow: some View {
        Button { send(.movePickerRowTapped(nil)) } label: {
            HStack(spacing: ListRowView.tileToTitle) {
                Image(systemName: "rectangle.split.1x2")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(.ink2))
                    .frame(width: 30, height: 30)
                    .background(Color(.fill), in: .rect(cornerRadius: 8))
                Text("Top level")
                    .font(Font(.rowTitle))
                    .foregroundStyle(Color(.ink))
                    .frame(maxWidth: .infinity, alignment: .leading)
                checkmark(model.isTopLevelCurrent)
            }
            .padding(.horizontal, 20)
            .frame(height: ListRowView.height)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.isTopLevelCurrent ? .isSelected : [])
    }

    /// A row of the tree, drawn by the screen's own row of its kind, with its check at the right. An area's line is at
    /// least the canvas's 36 pt here, where a tap on it is a choice, so that an unnamed area, the line alone, is not a
    /// 17 pt target.
    private func row(_ pickerRow: TaskViewList.Model.MovePicker.Row) -> some View {
        Button { send(.movePickerRowTapped(pickerRow.id)) } label: {
            HStack(spacing: 0) {
                switch pickerRow.row.kind {
                case .area(let label):
                    AreaLine(label: label, draft: nil, isEditing: false, send: send)
                        .frame(minHeight: 36)
                case .list(let list):
                    ListRowView(list, depth: pickerRow.row.depth, draft: nil, send: send)
                }
                checkmark(pickerRow.isCurrent)
                    .padding(.trailing, 20)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(pickerRow.isCurrent ? .isSelected : [])
        .disabled(pickerRow.isDisabled)
        // The canvas's dimming of a row that cannot take the list.
        .opacity(pickerRow.isDisabled ? 0.35 : 1)
    }

    /// The check that marks the list's present parent, in the accent, and the room for it on every other row, so that
    /// the rows end in one column. VoiceOver reads the mark as the row's selected trait instead.
    private func checkmark(_ isCurrent: Bool) -> some View {
        Image(systemName: "checkmark")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color(.accent))
            .opacity(isCurrent ? 1 : 0)
            .accessibilityHidden(true)
    }
}
