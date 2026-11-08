// Sources/DesignSystemComponents/GlassButtonModel.swift

/// A round button on glass as every platform draws it: its look, and the action a tap sends, as `ButtonModel` is a
/// button's look and its action.
public struct GlassButtonModel<Action: Equatable & Sendable>: Equatable, Sendable {
    public let label: GlassButtonLabelModel
    public let action: Action

    public init(label: GlassButtonLabelModel, action: Action) {
        self.label = label
        self.action = action
    }
}
