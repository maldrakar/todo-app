// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Animation+DesignSystem.swift
import DesignSystem
import SwiftUI

extension Animation {
    /// A motion of the look as SwiftUI's animation of the same curve and duration, after the same delay. The `switch`
    /// names every curve with no `default`, so a curve added to the look stops this compiling until it is drawn.
    init(_ animation: DesignSystem.Animation) {
        let curve: Animation = switch animation.curve {
        case .spring: .spring(duration: animation.duration)
        case .easeIn: .easeIn(duration: animation.duration)
        case .bezier(let x1, let y1, let x2, let y2): .timingCurve(x1, y1, x2, y2, duration: animation.duration)
        }
        self = curve.delay(animation.delay)
    }
}
