// Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsBottomBar.swift
import DesignSystemComponents
import SwiftUI
import TaskViewListFeature

/// The bar at the bottom of the Lists screen as its model describes it (`BarModel`; `Phone.dc.html`, the bar), with no
/// title above the tree, as the canvas has none (Lists screen spec, sections 1 and 7): its items in a row, a button
/// alone round, the search capsule, and a group of buttons on one capsule with a divider between them, every size,
/// glyph, word and colour the model's. Outside edit mode the model gives "…", the search capsule, which sends nothing
/// until the search epic, and "+"; in edit mode "+ List" and "+ Area" in a group and Done. Every control sends the
/// action its model holds, or puts up the menu its model holds, and what follows is the module's.
///
/// The controls stand on glass, the canvas's blurred translucent fill with a hairline and a soft shadow, which is the
/// platform's container and no model's (Lists screen plan, Task 8): drawn here as the regular material, the hairline as
/// the ink at 8 % and one shadow for both appearances, under every control, a control on a fill of its own among them.
/// A button whose model puts it on the container stands on the glass; one with a fill of its own, "+" and Done, on
/// that fill instead.
struct ListsBottomBar: View {
    private let model: BarModel<TaskViewList.UserAction>
    private let send: (TaskViewList.UserAction) -> Void

    init(_ model: BarModel<TaskViewList.UserAction>, send: @escaping (TaskViewList.UserAction) -> Void) {
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
    }

    /// One item of the bar, through the one switch over what stands on a bar, every case drawn and none by `default`
    /// (`docs/style.md`, "Views").
    @ViewBuilder private func item(_ item: BarModel<TaskViewList.UserAction>.Item) -> some View {
        switch item {
        case .button(let button):
            pressing(button) {
                standing(label(of: button).frame(width: model.controlHeight, height: model.controlHeight), on: button)
            }
        case .search(let search):
            searchCapsule(search)
        case .group(let buttons):
            group(buttons)
        }
    }

    /// A button alone on what its model puts it on, a circle as high as the bar's controls: the glass of its container,
    /// or a fill of its own with the bar's shadow under it.
    @ViewBuilder private func standing(
        _ label: some View, on button: ButtonModel<TaskViewList.UserAction>
    ) -> some View {
        switch button.fill {
        case .container:
            label.glass(in: Circle())
        case .color(let color):
            label
                .background(Color(color), in: Circle())
                .barShadow()
        }
    }

    /// A button's glyph, and its word after it where it has one, the group's spacing apart.
    private func label(of button: ButtonModel<TaskViewList.UserAction>) -> some View {
        HStack(spacing: model.groupButtonSpacing) {
            Glyph(button.icon)
            if let title = button.title {
                Text(title)
            }
        }
    }

    /// What a press of a button does, by its model: send its action, or put up its menu, whose items stand in the order
    /// the model gives them, the canvas's, where iOS would otherwise put the first nearest the button. Either reads its
    /// model's words aloud.
    @ViewBuilder private func pressing(
        _ button: ButtonModel<TaskViewList.UserAction>, @ViewBuilder label: () -> some View
    ) -> some View {
        switch button.press {
        case .action(let action):
            Button { send(action) } label: { label() }
                .buttonStyle(.plain)
                .accessibilityLabel(button.accessibilityLabel)
        case .menu(let menu):
            #if os(watchOS)
            // Left out on the watch, where `Menu` is unavailable (a file typechecked against the watchOS 10 SDK with
            // Xcode 27.1 on 2026-10-27), and whose build is a compile check in this epic.
            EmptyView()
            #else
            Menu { MenuItems(menu, send: send) } label: { label() }
                .menuOrder(.fixed)
                .accessibilityLabel(button.accessibilityLabel)
            #endif
        }
    }

    /// The search capsule, its glyphs and its placeholder as its model has them, on the glass, and a view and not a
    /// control: a tap on it opens nothing in this epic (the owner, 2026-10-25), so it sends nothing.
    private func searchCapsule(_ search: SearchFieldModel) -> some View {
        HStack(spacing: search.spacing) {
            Glyph(search.leadingIcon)
            Text(search.placeholder)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Glyph(search.trailingIcon)
                .frame(width: search.trailingCell, height: search.trailingCell)
        }
        .padding(.leading, search.leadingPadding)
        .padding(.trailing, search.trailingPadding)
        .frame(maxWidth: .infinity)
        .frame(height: model.controlHeight)
        .glass(in: Capsule())
    }

    /// Buttons grouped on one capsule of glass, sharing its width, with the group's divider between each two of them.
    private func group(_ buttons: [ButtonModel<TaskViewList.UserAction>]) -> some View {
        HStack(spacing: 0) {
            ForEach(buttons.indices, id: \.self) { index in
                if index > 0 {
                    Rule(model.groupDivider, along: .vertical)
                        .frame(height: model.groupDividerHeight)
                }
                pressing(buttons[index]) {
                    standingInGroup(
                        label(of: buttons[index])
                            .frame(maxWidth: .infinity)
                            .frame(height: model.groupButtonHeight),
                        on: buttons[index]
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

    /// A button of a group on what its model puts it on: the group's glass, which is under it already, or a fill of its
    /// own in a capsule.
    @ViewBuilder private func standingInGroup(
        _ label: some View, on button: ButtonModel<TaskViewList.UserAction>
    ) -> some View {
        switch button.fill {
        case .container:
            label
        case .color(let color):
            label.background(Color(color), in: Capsule())
        }
    }
}

extension View {
    /// The canvas's glass under a control of the bar, in its shape: the platform's container.
    fileprivate func glass(in shape: some Shape) -> some View {
        background(.regularMaterial, in: shape)
            .overlay { shape.stroke(Color(.ink).opacity(0.08), lineWidth: 0.5) }
            .barShadow()
    }

    /// The canvas's soft shadow under a control of the bar, the platform's with the glass.
    fileprivate func barShadow() -> some View {
        shadow(color: .black.opacity(0.12), radius: 12, y: 5)
    }
}
