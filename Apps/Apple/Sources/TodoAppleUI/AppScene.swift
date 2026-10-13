// Apps/Apple/Sources/TodoAppleUI/AppScene.swift
import SwiftUI

// Behind `#if os(macOS)` because iOS and watchOS have no `Window`. What they put on screen as their scene is decided
// when the Xcode project brings them (ADR-0008); until then the library compiles for both without one.
#if os(macOS)
/// The app's scene, and the one thing this library exports: the executable's `@main` is its only caller from
/// outside (ADR-0008).
public struct AppScene: Scene {
    public init() {}

    /// One `Window` and not a `WindowGroup`, because there is one host and one root per process: a group is
    /// there to hold more windows than one, and a second window over the same host would draw the first one's
    /// highlight and open field again. More windows are the navigation epic's (#67).
    public var body: some Scene {
        Window("Todo", id: "main") {
            RootView(host: TodoApp.host)
        }
    }
}
#endif
