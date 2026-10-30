// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Shadow+DesignSystem.swift
import DesignSystem
import SwiftUI

extension View {
    /// The view casting a shadow of the look: black at the shadow's opacity, blurred over its radius and dropped by its
    /// `y`, straight down.
    func shadow(_ shadow: DesignSystem.Shadow) -> some View {
        self.shadow(color: .black.opacity(shadow.opacity), radius: shadow.radius, y: shadow.y)
    }
}
