// Sources/DesignSystemComponents/GlassMenuButtonModel.swift

/// A glass button that puts a menu up, "…" with Show as over the list screen: its label, the glass face every glass
/// button has, and the menu a press puts up, as `MenuButtonModel` pairs a bar's button's label and its menu.
///
/// `GlassMenuButtonModel` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-09).
public struct GlassMenuButtonModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let label: GlassButtonLabelModel
    public let menu: MenuModel<Action>

    public init(label: GlassButtonLabelModel, menu: MenuModel<Action>) {
        self.label = label
        self.menu = menu
    }
}
