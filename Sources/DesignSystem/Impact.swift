// Sources/DesignSystem/Impact.swift

extension DesignSystem {
    /// How hard a moment is felt, on a device that plays one: a platform plays it as its own impact, and one with
    /// nothing to play it on plays nothing. The look's impacts are its cases.
    public enum Impact: Equatable, Sendable {
        /// A light tap, felt as a dragged task lifts and as it lands (#211).
        case light
    }
}
