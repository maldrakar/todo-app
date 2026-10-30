// Apps/Apple/Sources/TodoAppleUI/ListsScreen/AreaLine.swift
import SwiftUI
import TaskViewListFeature

/// An area's line on the phone as the canvas draws it (`Phone.dc.html`, the area's row): a 1 pt line in the line colour
/// from 20 pt in to the right edge of what it is laid out on, 17 pt tall alone and 36 pt with the label sitting on it,
/// in ink2, which while the area is being renamed becomes the field, and the grip at its right in edit mode. Whether
/// there is a label, and what it says, is the model's: an unnamed area has none outside edit mode and "Area" in it
/// (Lists screen spec, sections 1 and 3). The tree and the move picker both draw it.
struct AreaLine: View {
    private let label: String?
    private let draft: String?
    private let isEditing: Bool
    private let send: (TaskViewList.UserAction) -> Void

    /// Where the field of a line being renamed ends, from the line's leading edge, which the screen keeps on screen
    /// when the field opens.
    static let fieldEnd = leading + fieldWidth

    /// The canvas's 20 pt before the label, the field or the line, and the field's 160.
    private static let leading: CGFloat = 20
    private static let fieldWidth: CGFloat = 160

    init(label: String?, draft: String?, isEditing: Bool, send: @escaping (TaskViewList.UserAction) -> Void) {
        self.label = label
        self.draft = draft
        self.isEditing = isEditing
        self.send = send
    }

    var body: some View {
        HStack(spacing: 10) {
            if let draft {
                // The canvas's field on a line: 28 pt high, on the surface, with a 2 pt ring in the accent, and the
                // canvas's placeholder, since a new area's field opens empty.
                TitleField("Area name", draft: draft, send: send)
                    .font(Font(.areaLabel))
                    .foregroundStyle(Color(.ink))
                    .padding(.horizontal, 8)
                    .frame(width: Self.fieldWidth, height: 28)
                    .background(Color(.surface), in: .rect(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color(.accent), lineWidth: 2) }
            } else if let label {
                Text(label)
                    .font(Font(.areaLabel))
                    .foregroundStyle(Color(.ink2))
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            Rectangle()
                .fill(Color(.line))
                .frame(height: 1)
            if isEditing {
                ListRowView.Grip()
                    .foregroundStyle(Color(.ink3))
            }
        }
        .padding(.leading, Self.leading)
        // The canvas's 12 pt after the grip, and 20 after the line alone.
        .padding(.trailing, isEditing ? 12 : 20)
        .frame(height: label == nil && draft == nil ? 17 : 36)
    }
}
