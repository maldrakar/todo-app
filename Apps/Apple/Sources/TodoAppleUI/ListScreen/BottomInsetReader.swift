// Apps/Apple/Sources/TodoAppleUI/ListScreen/BottomInsetReader.swift
import SwiftUI

/// Reads what the safe area covers at the bottom into its binding, the keyboard's region apart: a scroll view stands
/// above the keyboard, its region not ignored.
///
/// `BottomInsetReader` was probed free as `DesignSystem` was: unresolved in a file importing SwiftUI, Foundation and
/// Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (2026-11-07).
struct BottomInsetReader: ViewModifier {
    @Binding var inset: CGFloat

    func body(content: Content) -> some View {
        content.background {
            Color.clear
                .ignoresSafeArea(.keyboard)
                .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { inset = $0 }
        }
    }
}
