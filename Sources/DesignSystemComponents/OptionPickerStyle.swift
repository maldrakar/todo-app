// Sources/DesignSystemComponents/OptionPickerStyle.swift

/// The numbers a `PickerModel` is drawn with, in points, and the opacity of an option that cannot be chosen, which a
/// builder hands over as one value.
public struct OptionPickerStyle: Equatable, Sendable {
    public let hintGap: Double
    public let minimumOptionHeight: Double

    /// The opacity an option that cannot be chosen is drawn at, from 0 to 1.
    public let disabledOpacity: Double

    public init(hintGap: Double, minimumOptionHeight: Double, disabledOpacity: Double) {
        self.hintGap = hintGap
        self.minimumOptionHeight = minimumOptionHeight
        self.disabledOpacity = disabledOpacity
    }
}
