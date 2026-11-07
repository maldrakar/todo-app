// Sources/DesignSystemComponents/IconModel.swift
import DesignSystem

/// A glyph as a component draws it outside a tile: its icon, in a size, a weight and a colour, each a value of the
/// design system, so that a platform draws it and decides nothing (ADR-0007, amendment of 2026-10-30). Its size, its
/// weight and its colour are the fields of its `IconStyle`.
public struct IconModel: Equatable, Sendable {
    public let icon: DesignSystem.Icon
    public let style: IconStyle

    public init(icon: DesignSystem.Icon, style: IconStyle) {
        self.icon = icon
        self.style = style
    }
}
