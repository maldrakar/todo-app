// Apps/Apple/Sources/TodoAppleUI/ListScreen/FloatingButton.swift
import DesignSystemComponents
import SwiftUI

/// The round "+" that floats over the screen's corner as its model describes it (`FloatingButtonModel`;
/// `Phone.dc.html`, the new task button): its glyph on its circle, casting its shadow. Where it stands is its screen's,
/// which reads its margins (`ListScreen`).
struct FloatingButton<Action: Equatable & Sendable>: View {
    private let model: FloatingButtonModel<Action>
    private let send: (Action) -> Void

    init(_ model: FloatingButtonModel<Action>, send: @escaping (Action) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        Button { send(model.action) } label: {
            Icon(model.icon)
                .frame(width: model.style.diameter, height: model.style.diameter)
                .background {
                    Circle()
                        .fill(Color(model.style.fill))
                        .shadow(model.style.shadow)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.accessibilityLabel)
    }
}
