// Apps/Apple/Sources/TodoAppleUI/ListScreen/BlockHeaderView.swift
import DesignSystemComponents
import SwiftUI
import TaskListFeature

/// A block's or a column's header as its model describes it (`BlockHeaderModel`; `Phone.dc.html`, the group header and
/// `.bcol-h`): its title and its subtitle on one baseline as the button that opens the block, or the field in their
/// place while the list is being named; the chevron that folds it, where it has one; and its rule along its bottom,
/// where it has one. The title is tinted under the pointer where the style gives the tint (`Hovering`).
struct BlockHeaderView: View {
    private let model: BlockHeaderModel<TaskList.UserAction>
    private let send: (TaskList.UserAction) -> Void

    /// Whether a person asked for less motion: the chevron then turns without its animation.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ model: BlockHeaderModel<TaskList.UserAction>, send: @escaping (TaskList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            title
            if let fold = model.fold {
                chevron(fold)
            }
        }
        .frame(height: model.style.height)
        .overlay(alignment: .bottom) {
            if let rule = model.style.rule {
                Rule(rule, along: .horizontal)
            }
        }
        .padding(.top, model.style.topMargin)
        .padding(.trailing, model.style.trailingMargin)
        .padding(.bottom, model.style.bottomMargin)
        .padding(.leading, model.style.leadingMargin)
        // One geometry, as a row that adds has (`AddRowView`).
        .geometryGroup()
    }

    /// The title's control, padded in the header's height, on the header's whole width beside the chevron.
    @ViewBuilder private var title: some View {
        if let field = model.field {
            PlainField(
                field, focusesOnAppear: true, selectsAllOnFocus: true, changed: { .listNameFieldChanged($0) },
                send: send
            )
                .padding(.top, model.style.topPadding)
                .padding(.horizontal, model.style.horizontalPadding)
                .padding(.bottom, model.style.bottomPadding)
        } else {
            Button { send(model.titleTapped) } label: {
                HStack(alignment: .firstTextBaseline, spacing: model.style.titleToSubtitle) {
                    Text(model.title)
                        .lineLimit(1)
                    if let subtitle = model.subtitle {
                        Text(subtitle)
                            .lineLimit(1)
                    }
                }
                .padding(.top, model.style.topPadding)
                .padding(.horizontal, model.style.horizontalPadding)
                .padding(.bottom, model.style.bottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .hoverTint(
                    model.style.hover, in: RoundedRectangle(cornerRadius: model.style.cornerRadius, style: .circular)
                )
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    /// The chevron that folds the block, turning on its motion, centred in its square cell, which reads aloud what a
    /// tap will do.
    private func chevron(_ fold: AccessoryModel<TaskList.UserAction>.Chevron) -> some View {
        let side = model.style.foldHitSide.map { CGFloat($0) }
        return Button { send(fold.action) } label: {
            Icon(fold.icon)
                .rotationEffect(.degrees(fold.style.rotation))
                .animation(reduceMotion ? nil : Animation(fold.style.animation), value: fold.style.rotation)
                .frame(width: side, height: side)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fold.accessibilityLabel)
    }
}
