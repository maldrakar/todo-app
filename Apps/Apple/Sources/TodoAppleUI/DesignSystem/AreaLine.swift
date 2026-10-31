// Apps/Apple/Sources/TodoAppleUI/DesignSystem/AreaLine.swift
import DesignSystemComponents
import SwiftUI

/// An area's line as its model describes it (`AreaLineModel`; `Phone.dc.html`, the area's row): from the model's
/// leading edge the label, or the field in its model's look while the area is being renamed, then the line across the
/// rest, the model's spacing apart, then its gap and its accessories (`Accessories`), and its end gap short of the
/// right edge of what it is laid out on, as high as the model says. Whether there is a label, and what it says, is the
/// model's. A tree and a picker draw it, and a drag's card a picture of it (`init(lifted:)`).
struct AreaLine<Action: Equatable & Sendable>: View {
    private let model: AreaLineModel<Action>

    /// What the field sends as the name is typed, and what the line's field and accessories send, each nil for the
    /// picture a drag's card carries, which draws its label in the field's place and sends nothing, since a card is
    /// not typed into and takes no touch: Task 7's card drew the lifted line with no field.
    private let changed: ((String) -> Action)?
    private let send: ((Action) -> Void)?

    /// The line, whose field sends what `changed` makes of the text as it is typed, and its model's actions.
    init(
        _ model: AreaLineModel<Action>, changed: @escaping (String) -> Action, send: @escaping (Action) -> Void
    ) {
        self.model = model
        self.changed = changed
        self.send = send
    }

    /// The line lifted by a drag, as its card carries it: its label, and never its field.
    init(lifted model: AreaLineModel<Action>) {
        self.model = model
        changed = nil
        send = nil
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: model.spacing) {
                if let field = model.field, let changed, let send {
                    TitleField(field, changed: changed, send: send)
                        .fieldLook(field)
                        .frame(width: field.minimumWidth)
                } else if let label = model.label {
                    Text(label)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                Rule(model.line, along: .horizontal)
            }
            .padding(.trailing, model.lineToAccessories)
            Accessories(
                model.accessories, cellWidth: model.cellWidth, countMinimumWidth: nil, endGap: model.endGap,
                height: model.height, send: { send?($0) }
            )
        }
        .padding(.leading, model.leading)
        .frame(height: model.height)
    }
}
