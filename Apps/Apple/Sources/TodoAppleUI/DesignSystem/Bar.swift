// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Bar.swift
import DesignSystemComponents
import SwiftUI

/// A bar of controls as its model describes it (`BarModel`; `Phone.dc.html`, the bar; `Mac.dc.html`, the bottom of the
/// column): as high as the model says, under its rule where it has one, its items in a row, a button or a menu button
/// alone round, the search field, and a group of buttons on one capsule with a divider between them, every size, glyph,
/// word and colour the model's. A button sends the action its model holds, a menu button puts up the menu its model
/// holds, with the keys of each item that has them (`MenuItems`), and the search field sends nothing; what follows is
/// the module's that built the model.
///
/// A control stands on what its model says (`FillModel`): on the platform's container, or on a fill of its own. The
/// container is glass, the canvas's blurred translucent fill with a hairline and a soft shadow, which is the platform's
/// and no model's (Lists screen plan, Task 8): drawn here as the regular material, the hairline as the ink at 8 % and
/// the look's raised shadow for both appearances. A button alone on a fill of its own casts the model's shadow instead
/// (`BarModel.buttonShadow`), and a search field on one casts none.
///
/// `Bar` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and Observation for
/// macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-10-31).
struct Bar<Action: Equatable & Sendable>: View {
    private let model: BarModel<Action>
    private let send: (Action) -> Void

    init(_ model: BarModel<Action>, send: @escaping (Action) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        HStack(spacing: model.spacing) {
            ForEach(model.items.indices, id: \.self) { index in
                item(model.items[index])
            }
        }
        .padding(.horizontal, model.padding)
        .frame(height: model.height)
        .overlay(alignment: .top) {
            if let rule = model.rule {
                Rule(rule, along: .horizontal)
            }
        }
    }

    /// One item of the bar, through the one switch over what stands on a bar, every case drawn and none by `default`
    /// (`docs/style.md`, "Views"). A menu button's items stand in the order the model gives them, where iOS would
    /// otherwise put the first nearest the button.
    @ViewBuilder private func item(_ item: BarModel<Action>.Item) -> some View {
        switch item {
        case .button(let button):
            pressing(button) { alone(button.label) }
        case .menuButton(let button):
            #if os(watchOS)
            // Left out on the watch, where `Menu` is unavailable (a file typechecked against the watchOS 10 SDK with
            // Xcode 27.1 on 2026-10-27), and whose build is a compile check in this epic.
            EmptyView()
            #else
            // Its label alone, as a plain button draws it, with no indicator of its own: the Mac's default style puts
            // the label in a pull-down button's bezel beside its arrow, where iOS's draws the label as it is.
            Menu { MenuItems(button.menu, send: send) } label: { alone(button.label) }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .menuOrder(.fixed)
                .accessibilityLabel(button.label.accessibilityLabel)
            #endif
        case .search(let search):
            searchField(search)
        case .group(let buttons):
            group(buttons)
        }
    }

    /// A button that sends its action when pressed, and reads its label's words aloud.
    private func pressing(_ button: ButtonModel<Action>, @ViewBuilder label: () -> some View) -> some View {
        Button { send(button.action) } label: { label() }
            .buttonStyle(.plain)
            .accessibilityLabel(button.label.accessibilityLabel)
    }

    /// A button or a menu button standing alone, a circle as high as the bar's controls, on what its label puts it on.
    private func alone(_ label: ButtonLabelModel) -> some View {
        standing(content(of: label).frame(width: model.controlHeight, height: model.controlHeight), on: label.fill)
    }

    /// A button alone on what its label puts it on: the glass of its container, or a fill of its own with the model's
    /// shadow under it.
    @ViewBuilder private func standing(_ label: some View, on fill: FillModel) -> some View {
        switch fill {
        case .container:
            label.glass(in: Circle())
        case .color(let color):
            label
                .background(Color(color), in: Circle())
                .shadow(model.buttonShadow)
        }
    }

    /// What a button shows: its label's glyph, and its word after it where it has one, the group's spacing apart.
    private func content(of label: ButtonLabelModel) -> some View {
        HStack(spacing: model.groupButtonSpacing) {
            Icon(label.icon)
            if let title = label.title {
                Text(title)
            }
        }
    }

    /// The search field, its glyphs and its placeholder as its model has them, as high as the bar's controls, its
    /// corners as its model rounds them, on what its model puts it on, and a view and not a control, since its model
    /// holds no action. Its corners are SwiftUI's default style, the one its `Capsule` drew the phone's in, which a
    /// rounded rectangle of half the height draws to the same pixels (ImageRenderer on macOS 26, 2026-10-31).
    private func searchField(_ search: SearchFieldModel) -> some View {
        HStack(spacing: search.spacing) {
            Icon(search.leadingIcon)
            Text(search.placeholder)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let trailing = search.trailingGlyph {
                Icon(trailing.icon)
                    .frame(width: trailing.cell, height: trailing.cell)
            }
        }
        .padding(.leading, search.leadingPadding)
        .padding(.trailing, search.trailingPadding)
        .frame(maxWidth: .infinity)
        .frame(height: model.controlHeight)
        .standing(on: search.fill, in: RoundedRectangle(cornerRadius: search.cornerRadius))
    }

    /// Buttons grouped on one capsule of glass, sharing its width, with the group's divider between each two of them.
    private func group(_ buttons: [ButtonModel<Action>]) -> some View {
        HStack(spacing: 0) {
            ForEach(buttons.indices, id: \.self) { index in
                if index > 0 {
                    Rule(model.groupDivider, along: .vertical)
                        .frame(height: model.groupDividerHeight)
                }
                pressing(buttons[index]) {
                    standingInGroup(
                        content(of: buttons[index].label)
                            .frame(maxWidth: .infinity)
                            .frame(height: model.groupButtonHeight),
                        on: buttons[index].label.fill
                    )
                    .contentShape(.capsule)
                }
            }
        }
        .padding(.horizontal, model.groupPadding)
        .frame(maxWidth: .infinity)
        .frame(height: model.controlHeight)
        .glass(in: Capsule())
    }

    /// A button of a group on what its label puts it on: the group's glass, which is under it already, or a fill of its
    /// own in a capsule.
    @ViewBuilder private func standingInGroup(_ label: some View, on fill: FillModel) -> some View {
        switch fill {
        case .container:
            label
        case .color(let color):
            label.background(Color(color), in: Capsule())
        }
    }
}

extension View {
    /// The canvas's glass under a control of the bar, in its shape: the platform's container, with the look's raised
    /// shadow, the canvas's small one, which is the container's and no model's.
    fileprivate func glass(in shape: some Shape) -> some View {
        background(.regularMaterial, in: shape)
            .overlay { shape.stroke(Color(.ink).opacity(0.08), lineWidth: 0.5) }
            .shadow(.raised)
    }

    /// A search field in its shape on what its model puts it on, every case drawn and none by `default`
    /// (`docs/style.md`, "Views"): the glass of its container, or a fill of its own with no shadow.
    @ViewBuilder fileprivate func standing(on fill: FillModel, in shape: some Shape) -> some View {
        switch fill {
        case .container:
            glass(in: shape)
        case .color(let color):
            background(Color(color), in: shape)
        }
    }
}
