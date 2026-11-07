// Apps/Apple/Sources/TodoAppleUI/ListScreen/AddRowView.swift
import DesignSystemComponents
import SwiftUI

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
