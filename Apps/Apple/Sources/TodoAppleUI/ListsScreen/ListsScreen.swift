// Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsScreen.swift
import SwiftUI
import TaskViewListFeature

/// The Lists screen on a phone, at the root of a narrow window's stack, as the canvas draws it (`Phone.dc.html`; Lists
/// screen spec, sections 1, 6 and 7): the tree (`ListsTree`) with no title and no navigation bar, on the paper, the bar
/// at the bottom (`Bar`), the confirmation of a delete as an alert and Move to… as a sheet (`MovePickerSheet`).
/// Everything it draws arrives finished in the model, each part of it the model of the component that draws it, with
/// every size, colour, font, glyph and word (ADR-0007, amendment of 2026-10-30), and each gesture is sent as the action
/// its control's model holds: what follows is the module's. It decides only what is the platform's: its containers,
/// the fades and the sheet and the alert. The tree, its gestures and the drag are the tree's, which the wide window's
/// sidebar draws too (`ListsSidebar`).
struct ListsScreen: View {
    private let model: TaskViewList.Model
    private let send: (TaskViewList.UserAction) -> Void

    init(model: TaskViewList.Model, send: @escaping (TaskViewList.UserAction) -> Void) {
        self.model = model
        self.send = send
    }

    var body: some View {
        ListsTree(model: model, send: send)
            .background(Color(.paper))
            .safeAreaInset(edge: .top, spacing: 0) { top }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottom }
            #if !os(macOS)
            // The canvas has no title and no bar over the tree; the screens pushed over it keep theirs. The placement
            // is unavailable on macOS.
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .modifier(ListsDialogs(model: model, send: send) { MovePickerSheet(model: $0, send: send) })
    }

    /// The bar, and the sentence under the rows above it, where it stays as the sidebar's does, with the root's strip
    /// under the window below both (`RootView`); the sentence's strip is the one every module's sentence shares, whose
    /// look no component's model holds yet (Lists screen plan, Task 8). The canvas fades the rows out behind the bar
    /// over the 52 pt above it, which the tree's last row scrolls up to clear; the fade is the platform's, as the glass
    /// under the bar's controls is, and takes no touch, so a row behind it is still tapped.
    private var bottom: some View {
        VStack(spacing: 0) {
            if let problem = model.problem {
                Text(problem).listsSentence(on: .paper)
            }
            Bar(model.bar, send: send)
        }
        .padding(.top, 52)
        .background {
            LinearGradient(
                stops: [
                    .init(color: Color(.paper).opacity(0), location: 0), .init(color: Color(.paper), location: 0.72),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
    }

    /// The canvas's 4 pt between the status bar and the first row, and its fade under the status bar, the paper down to
    /// 55 % of the way and fading out below, so that the rows scrolled up under the status bar do not run into its
    /// text: the platform's, as the fade over the bar is. An inset of the screen's own, whose fade reaches up under the
    /// status bar: the scroll view already stands under it, so a fade laid over the scroll view's top and told to
    /// ignore the safe area stayed 2 pt tall (the iOS 26.3 simulator, 2026-10-29).
    private var top: some View {
        Color.clear
            .frame(height: 4)
            .background {
                LinearGradient(
                    stops: [
                        .init(color: Color(.paper), location: 0.55),
                        .init(color: Color(.paper).opacity(0), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            }
            .allowsHitTesting(false)
    }
}
