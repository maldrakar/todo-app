// Apps/Apple/Sources/TodoAppleUI/AppScene.swift
import AppFeature
import SwiftUI

// Behind `#if os(macOS)` because iOS and watchOS have no `Window`. What they put on screen as their scene is decided
// when the Xcode project brings them (ADR-0008); until then the library compiles for both without one.
#if os(macOS)
/// The app's scene, and the one thing this library exports: the executable's `@main` is its only caller from
/// outside (ADR-0008).
public struct AppScene: Scene {
    public init() {}

    /// One `Window` and not yet a `WindowGroup`. The composition root makes a host per window, and the scene
    /// that opens a window per route, each window making and holding its own host, is #94's; until then a
    /// second window over the one host here would draw the first one's highlight and open field again.
    public var body: some Scene {
        Window("Todo", id: "main") {
            RootView(host: AppScene.host)
        }
    }

    /// The host of the one window, made from no path, so that it opens as the default window, the first time the
    /// window's view reads it. A `static let`, initialised once, where the initial value of a `@State` is evaluated on
    /// every creation of its struct and each evaluation would make another host and another root
    /// (`docs/specs/navigation.md`, "Risks"; ADR-0008). A window that cannot be made ends the process with the error,
    /// as a launch that throws does.
    private static let host: ModuleHost<AppModule> = {
        do {
            return try TodoApp.shared.makeHost(path: nil)
        } catch {
            fatalError("The window could not be made: \(error)")
        }
    }()
}
#endif
