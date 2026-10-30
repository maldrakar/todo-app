// Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListRowView.swift
import DesignSystemComponents
import SwiftUI
import TaskViewListFeature

/// A list's row as its model describes it (`ListRowModel`; `Phone.dc.html`, `.vrow`): the tile at the model's leading
/// edge, and after the model's gap the title on one line, or the field in its model's look while the row is being
/// renamed, as high as the model says and as wide as it is laid out. Every size, colour, font and word is the model's,
/// built by the module for the row's drawn depth, so the view picks none (ADR-0007, amendments of 2026-10-26 and
/// 2026-10-30). The tree and the move picker both draw it, each with what stands at its right: the accessories in the
/// tree (`Accessories`), the check in the picker.
///
/// The field fills the room the tree leaves it, which is never less than its minimum width, since the row's need, which
/// the tree is at least as wide as, leaves it that.
struct ListRowView: View {
    private let model: ListRowModel<TaskViewList.UserAction>
    private let send: (TaskViewList.UserAction) -> Void

    init(_ model: ListRowModel<TaskViewList.UserAction>, send: @escaping (TaskViewList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        HStack(spacing: model.tileToTitle) {
            ListTile(model.tile)
            if let field = model.field {
                TitleField(field, send: send)
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
    /// What stands at the right of a list's row in the tree as its model describes it (`ListRowModel.Accessories`;
    /// `Phone.dc.html`, the row's sticky end): the count, a cell for the chevron on every row, which holds it when the
    /// list has lists inside it, so that the counts stand in one column, the grip's cell where the row drags, and the
    /// gap at the end. The tree pins it to the right edge of the screen while the rows scroll sideways under it, so it
    /// is drawn on the row's own background, which fades in over the model's fade, so that a title passing under it
    /// ends softly.
    struct Accessories: View {
        private let model: ListRowModel<TaskViewList.UserAction>.Accessories
        private let background: Color
        private let height: Double
        private let send: (TaskViewList.UserAction) -> Void

        /// Whether a person asked for less motion, which only the view can read: the chevron then turns without its
        /// animation (`DesignSystem.Animation`).
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        /// The accessories of a row as high as `height`, on the row's background.
        init(
            _ model: ListRowModel<TaskViewList.UserAction>.Accessories, background: Color, height: Double,
            send: @escaping (TaskViewList.UserAction) -> Void
        ) {
            self.model = model
            self.background = background
            self.height = height
            self.send = send
        }

        var body: some View {
            HStack(spacing: 0) {
                Text(model.count)
                    .lineLimit(1)
                    .frame(minWidth: model.countMinimumWidth, alignment: .trailing)
                ZStack {
                    if let chevron = model.chevron {
                        Button { send(chevron.action) } label: {
                            Glyph(chevron.icon)
                                .rotationEffect(.degrees(chevron.rotation))
                                .animation(reduceMotion ? nil : Animation(chevron.animation), value: chevron.rotation)
                                .frame(width: model.cellWidth, height: height)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(chevron.accessibilityLabel)
                    }
                }
                .frame(width: model.cellWidth, height: height)
                if let grip = model.grip {
                    // The drag starts anywhere on the row (`ListsDragGesture`), so the grip says so and takes no
                    // gesture of its own, and VoiceOver passes it by.
                    Glyph(grip)
                        .accessibilityHidden(true)
                        .frame(width: model.cellWidth, height: height)
                }
                Color.clear.frame(width: model.endGap, height: 1)
            }
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
