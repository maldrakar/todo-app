// Apps/Apple/Sources/TodoAppleUI/DesignSystem/Impact+DesignSystem.swift
// iOS alone: the impact is played by UIKit's feedback generator, which the Mac and the watch do not have.
#if os(iOS)
import DesignSystem
import UIKit

extension UIImpactFeedbackGenerator.FeedbackStyle {
    /// An impact of the look as UIKit's of the same strength. The `switch` names every impact with no `default`, so an
    /// impact added to the look stops this compiling until it is played.
    init(_ impact: DesignSystem.Impact) {
        switch impact {
        case .light: self = .light
        }
    }
}
#endif
