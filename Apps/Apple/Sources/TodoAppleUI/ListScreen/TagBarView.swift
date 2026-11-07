// Apps/Apple/Sources/TodoAppleUI/ListScreen/TagBarView.swift
import DesignSystemComponents
import SwiftUI

/// The tag bar as its model describes it (`TagBarModel`; `Phone.dc.html`, `.tagbar`): its chips in a row that scrolls
/// sideways, running past the content's sides to the screen's edges where its margins say so, and fading out at both
/// ends. A tap on a chip sends the action its model holds, and which tasks that leaves is the module's. The room after
/// the last chip is its style's, so that the row scrolled to its end leaves that chip clear of the fade.
struct TagBarView<Action: Equatable & Sendable>: View {
    private let model: TagBarModel<Action>
    private let send: (Action) -> Void

    /// Whether a person asked for less motion: a chip then lights at once.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ model: TagBarModel<Action>, send: @escaping (Action) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: model.style.spacing) {
                ForEach(model.chips.indices, id: \.self) { index in
                    chip(model.chips[index])
                }
            }
            .padding(.leading, model.style.padding)
            .padding(.trailing, model.style.padding + model.style.endRoom)
        }
        .scrollIndicators(.hidden)
        .mask {
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: model.style.fadeIn)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: model.style.fadeOut)
            }
        }
        .padding(.top, model.style.topMargin)
        .padding(.leading, model.style.leadingMargin)
        .padding(.trailing, model.style.trailingMargin)
    }

    /// A chip: its glyph and its title on its capsule, in a tap area taller than the capsule, read aloud as selected
    /// while it is lit.
    private func chip(_ chip: TagChipModel<Action>) -> some View {
        Button { send(chip.action) } label: {
            HStack(spacing: chip.style.spacing) {
                Icon(chip.icon)
                Text(chip.title)
                    .lineLimit(1)
            }
            .padding(.leading, chip.style.leadingPadding)
            .padding(.trailing, chip.style.trailingPadding)
            .frame(height: chip.style.height)
            .background(Color(chip.style.background), in: .rect(cornerRadius: chip.style.cornerRadius, style: .circular))
            .animation(reduceMotion ? nil : Animation(chip.style.animation), value: chip.isLit)
            .frame(height: chip.style.hitHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chip.isLit ? .isSelected : [])
    }
}
