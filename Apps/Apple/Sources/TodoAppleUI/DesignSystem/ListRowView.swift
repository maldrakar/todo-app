// Apps/Apple/Sources/TodoAppleUI/DesignSystem/ListRowView.swift
import DesignSystemComponents
import SwiftUI

/// A list's row as its model describes it (`ListRowModel`; `Phone.dc.html`, `.vrow`): the tile at the model's leading
/// edge, and after the model's gap the title on one line, or the field in its model's look while the row is being
/// renamed, as high as the model says and as wide as it is laid out. Every size, colour, font and word is the model's,
/// built by the screen's module, so the view picks none (ADR-0007, amendments of 2026-10-26 and 2026-10-30). What
/// stands at the row's right is its end (`End`), which a screen lays out where its rows put it, and the row's
/// background and guides are the screen's to lay under both.
///
/// The field fills the room it is given, which is never less than its minimum width, since the row's need, which a tree
/// is at least as wide as, leaves it that.
struct ListRowView<Action: Equatable & Sendable>: View {
    private let model: ListRowModel<Action>
    private let changed: (String) -> Action
    private let send: (Action) -> Void

    /// The row, whose field sends what `changed` makes of the text as it is typed, and its model's actions.
    init(
        _ model: ListRowModel<Action>, changed: @escaping (String) -> Action, send: @escaping (Action) -> Void
    ) {
        self.model = model
        self.changed = changed
        self.send = send
    }

    var body: some View {
        HStack(spacing: model.tileToTitle) {
            ListTile(model.tile)
            if let field = model.field {
                TitleField(field, changed: changed, send: send)
                    .fieldLook(field)
                    .frame(minWidth: field.minimumWidth)
            } else {
                Text(model.title)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, model.leading)
        .frame(height: model.height)
    }
}

extension ListRowView {
    /// What stands at the right of a list's row as its model describes it (`Phone.dc.html`, the row's sticky end): its
    /// accessories (`Accessories`), as high as the row, on the row's own background, which fades in over the model's
    /// fade, so that a title passing under them ends softly where a tree pins them to the right edge of the screen and
    /// scrolls the rows sideways under them.
    struct End: View {
        private let model: ListRowModel<Action>
        private let send: (Action) -> Void

        init(_ model: ListRowModel<Action>, send: @escaping (Action) -> Void) {
            self.model = model
            self.send = send
        }

        var body: some View {
            let background = Color(model.background)
            Accessories(
                model.accessories, cellMinimumWidth: model.cellMinimumWidth,
                countMinimumWidth: model.countMinimumWidth, endGap: model.endGap, height: model.height, send: send
            )
            .padding(.leading, model.fadeWidth)
            .background {
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [background.opacity(0), background], startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: model.fadeWidth)
                    background
                }
            }
        }
    }
}
