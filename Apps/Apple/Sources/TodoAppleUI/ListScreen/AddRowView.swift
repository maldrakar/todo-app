// Apps/Apple/Sources/TodoAppleUI/ListScreen/AddRowView.swift
import DesignSystemComponents
import SwiftUI

/// A row that adds as its model describes it (`AddRowModel`; `Phone.dc.html`, "+ Add task", "Add subtask" and "+ Add
/// list"): its rule along its top and the room under it, where it has one; its glyph centred in its cell and its title
/// after it, the whole of it the button, tinted under the pointer where its style gives the tint (`Hovering`); its
/// dashed edge where it has one; and its margins.
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
                .hoverTint(
                    model.style.hover, in: RoundedRectangle(cornerRadius: model.style.cornerRadius, style: .circular)
                )
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
        // One geometry, so that its plus and its words move as one as the rows above close up, as a row's do
        // (`CompletingTask`): they drifted apart on that motion (the iOS 26.3 simulator, 2026-11-07).
        .geometryGroup()
    }
}
