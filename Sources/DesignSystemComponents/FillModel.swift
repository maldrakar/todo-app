// Sources/DesignSystemComponents/FillModel.swift
import DesignSystem

/// What a control stands on: the container its platform puts it on, which is the platform's choice, the glass under a
/// bar's controls on iOS or a toolbar, with no fill of its own; or a fill of its own in a colour of the look, on which
/// its glyph and its words stand. A button's look and a search field each say what they stand on, so that the two
/// share one answer (Lists screen plan, Task 9). A view switches over it, every case drawn and no `default`
/// (`docs/style.md`, "Views").
public enum FillModel: Equatable, Sendable {
    case container
    case color(DesignSystem.Color)
}
