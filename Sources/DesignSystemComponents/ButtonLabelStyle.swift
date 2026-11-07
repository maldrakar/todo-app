// Sources/DesignSystemComponents/ButtonLabelStyle.swift

/// What a `ButtonLabelModel` stands on (`ControlFillStyle`), which a builder hands over as one value.
public struct ButtonLabelStyle: Equatable, Sendable {
    public let fill: ControlFillStyle

    public init(fill: ControlFillStyle) {
        self.fill = fill
    }
}
