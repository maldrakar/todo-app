// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Animation+DesignSystem.swift
import DesignSystem
import SwiftUI

extension Animation {
    /// A motion of the look as SwiftUI's animation of the same curve and duration. The `switch` names every case with
    /// no `default`, so a kind of motion added to the look stops this compiling until it is drawn.
    init(_ animation: DesignSystem.Animation) {
        self = switch animation {
        case .spring(let duration): .spring(duration: duration)
        case .easeIn(let duration): .easeIn(duration: duration)
        case .curve(let x1, let y1, let x2, let y2, let duration): .timingCurve(x1, y1, x2, y2, duration: duration)
        }
    }
}
