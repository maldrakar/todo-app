// Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsBottomBar.swift
import SwiftUI
import TaskViewListFeature

/// The bar at the bottom of the Lists screen, as the canvas draws it (`Phone.dc.html`, the bar), with no title above
/// the tree, as the canvas has none (Lists screen spec, sections 1 and 7). Outside edit mode: "…" at the left, a menu
/// holding Edit; the search capsule in the middle, which sends nothing until the search epic; and "+" at the right, a
/// menu holding New Task, New List and New Area. In edit mode: a capsule holding "+ List" and "+ Area", and the Done
/// check at the right. Every control sends the action its control is named for, and what follows is the module's.
///
/// The controls stand on glass, the canvas's blurred translucent fill with a hairline and a soft shadow, drawn here as
/// the regular material, the hairline as the ink at 8 % and one shadow for both appearances, since the look has no
/// token for any of the three; "+" and Done are filled with the accent instead, their glyphs white, as the canvas's.
struct ListsBottomBar: View {
    private let isEditing: Bool
    private let send: (TaskViewList.UserAction) -> Void

    init(isEditing: Bool, send: @escaping (TaskViewList.UserAction) -> Void) {
        self.isEditing = isEditing
        self.send = send
    }

    var body: some View {
        HStack(spacing: 10) {
            if isEditing {
                editCapsule
                doneButton
            } else {
                #if !os(watchOS)
                // Not on the watch, where `Menu` is unavailable (a file typechecked against the watchOS 10 SDK with
                // Xcode 27.1 on 2026-10-27), and whose build is a compile check in this epic; "+" below is left out
                // there for the same reason.
                moreMenu
                #endif
                searchCapsule
                #if !os(watchOS)
                addMenu
                #endif
            }
        }
        .padding(.horizontal, 16)
    }

    #if !os(watchOS)
    /// "…", which holds Edit alone for now (the owner, 2026-10-25).
    private var moreMenu: some View {
        Menu {
            Button("Edit", systemImage: "line.3.horizontal") { send(.editMenuItemChosen) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(.ink))
                .frame(width: Self.controlHeight, height: Self.controlHeight)
                .glass(in: Circle())
        }
        .accessibilityLabel("More")
    }

    /// "+", which makes a task, a list or an area: where each goes, and that a task is quick entry's, is the module's
    /// to decide (Lists screen spec, section 7). Its items stand in the order written, the canvas's, where iOS would
    /// otherwise put the first nearest the button.
    private var addMenu: some View {
        Menu {
            Button("New Task", systemImage: "checkmark.circle") { send(.newTaskMenuItemChosen) }
            Button("New List", systemImage: "checklist") { send(.newListMenuItemChosen(in: nil)) }
            Button("New Area", systemImage: "rectangle.split.1x2") { send(.newAreaMenuItemChosen) }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Self.controlHeight, height: Self.controlHeight)
                .background(Color(.accent), in: Circle())
                .barShadow()
        }
        .menuOrder(.fixed)
        .accessibilityLabel("Add")
    }
    #endif

    /// The search capsule, drawn as the canvas has it, its magnifier, "Search" and microphone in ink2, and a view and
    /// not a control: a tap on it opens nothing in this epic (the owner, 2026-10-25), so it sends nothing.
    private var searchCapsule: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17))
            Text("Search")
                .font(.body)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "mic")
                .font(.system(size: 17))
                .frame(width: 36, height: 36)
        }
        .foregroundStyle(Color(.ink2))
        .padding(.leading, 15)
        .padding(.trailing, 6)
        .frame(maxWidth: .infinity)
        .frame(height: Self.controlHeight)
        .glass(in: Capsule())
    }

    /// The edit bar's capsule: "+ List" and "+ Area" in the accent with a hairline between them, which make a list at
    /// the end of the tree and an area at the end of the root, as "+" makes them.
    private var editCapsule: some View {
        HStack(spacing: 0) {
            editButton("List", accessibilityLabel: "New List") { send(.newListMenuItemChosen(in: nil)) }
            Rectangle()
                .fill(Color(.line))
                .frame(width: 1, height: 22)
            editButton("Area", accessibilityLabel: "New Area") { send(.newAreaMenuItemChosen) }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .frame(height: Self.controlHeight)
        .glass(in: Capsule())
    }

    /// One half of the edit bar's capsule: a plus and the word, the canvas's 15 pt semibold, which no font of the look
    /// names, so it is the subheadline's size in semibold.
    private func editButton(
        _ title: LocalizedStringKey, accessibilityLabel: LocalizedStringKey, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(.accent))
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Done, the check that ends edit mode.
    private var doneButton: some View {
        Button { send(.doneButtonTapped) } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: Self.controlHeight, height: Self.controlHeight)
                .background(Color(.accent), in: Circle())
                .barShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Done")
    }

    /// The height of every control of the bar, and the side of its round ones (`Phone.dc.html`, the bar's 48 px).
    private static let controlHeight: CGFloat = 48
}

extension View {
    /// The canvas's glass under a control of the bar, in its shape.
    fileprivate func glass(in shape: some Shape) -> some View {
        background(.regularMaterial, in: shape)
            .overlay { shape.stroke(Color(.ink).opacity(0.08), lineWidth: 0.5) }
            .barShadow()
    }

    /// The canvas's soft shadow under a control of the bar.
    fileprivate func barShadow() -> some View {
        shadow(color: .black.opacity(0.12), radius: 12, y: 5)
    }
}
