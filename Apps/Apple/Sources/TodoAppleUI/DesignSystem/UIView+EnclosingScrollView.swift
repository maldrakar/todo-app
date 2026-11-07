// Apps/Apple/Sources/TodoAppleUI/DesignSystem/UIView+EnclosingScrollView.swift
// iOS alone: `UIScrollView` behind a SwiftUI `ScrollView` is UIKit's, which the Mac and the watch do not have.
#if os(iOS)
import UIKit

extension UIView {
    /// The nearest `UIScrollView` above this view, which SwiftUI builds a `ScrollView` as (iOS 26.3's
    /// `HostingScrollView`; spike #145), so that a plain view placed inside one can reach what only UIKit gives. iOS
    /// 18's `UIGestureRecognizerRepresentable` is the official route to its recognizers, and iOS 17 needs this one.
    var enclosingScrollView: UIScrollView? {
        var view = superview
        while let candidate = view, !(candidate is UIScrollView) { view = candidate.superview }
        return view as? UIScrollView
    }
}
#endif
