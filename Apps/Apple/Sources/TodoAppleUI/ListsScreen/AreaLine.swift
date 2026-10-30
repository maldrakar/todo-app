// Apps/Apple/Sources/TodoAppleUI/ListsScreen/AreaLine.swift
import DesignSystemComponents
import SwiftUI
import TaskViewListFeature

/// An area's line as its model describes it (`AreaLineModel`; `Phone.dc.html`, the area's row): from the model's
/// leading edge to its trailing gap short of the right edge of what it is laid out on, the label, or the field in its
/// model's look while the area is being renamed, then the line across the rest, then the grip where the line drags, the
/// model's spacing apart and as high as the model says. Whether there is a label, and what it says, is the model's: an
/// unnamed area has none outside edit mode and "Area" in it (Lists screen spec, sections 1 and 3). The tree and the
/// move picker both draw it, and the drag's card a picture of it (`init(lifted:)`).
struct AreaLine: View {
    private let model: AreaLineModel<TaskViewList.UserAction>

    /// What the field sends, and nil for the picture the drag's card carries, which draws its label in the field's
    /// place, since a card is not typed into: Task 7's card drew the lifted line with no field.
    private let send: ((TaskViewList.UserAction) -> Void)?

    /// The line of the tree or of the move picker, with its field while the area is being renamed.
    init(_ model: AreaLineModel<TaskViewList.UserAction>, send: @escaping (TaskViewList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    /// The line lifted by the drag, as its card carries it: its label, and never its field.
    init(lifted model: AreaLineModel<TaskViewList.UserAction>) {
        self.model = model
        send = nil
    }

    var body: some View {
        HStack(spacing: model.spacing) {
            if let field = model.field, let send {
                TitleField(field, send: send)
                    .fieldLook(field)
                    .frame(width: field.minimumWidth)
            } else if let label = model.label {
                Text(label)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            Rule(model.line, along: .horizontal)
            if let grip = model.grip {
                // As on a list's row, the grip says the line drags and takes no gesture.
                Glyph(grip)
                    .accessibilityHidden(true)
            }
        }
        .padding(.leading, model.leading)
        .padding(.trailing, model.trailing)
        .frame(height: model.height)
    }
}
