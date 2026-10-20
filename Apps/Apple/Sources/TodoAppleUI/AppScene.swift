// Apps/Apple/Sources/TodoAppleUI/AppScene.swift
import SwiftUI

/// The app's scene, and the one thing this library exports: the executable's `@main` is its only caller from
/// outside, and the app targets of the other platforms will be the same one line (ADR-0008).
///
/// A window group, so that the Mac opens as many windows as are asked for, Cmd-N among them, each made by its own
/// view around a host of its own (`docs/specs/navigation.md`, section 5). On the Mac and on iOS the group's value is
/// the window's route in its text form, a `String`, which is `Codable` and `Hashable`, what the group asks of its
/// value, and the window's view writes the route back into it after every change, which is what the Mac restores a
/// window from (section 7), and into the scene's storage beside it, which iPhone restores a scene from and the window
/// reads when it has no value of its own (`WindowView`); a window opened with neither, the first and every Cmd-N,
/// opens the default window, or the route `TODO_ROUTE` named for the first (`TodoApp.makeWindow`). On watchOS the
/// group takes no value, because `WindowGroup(for:)`, `openWindow` and `handlesExternalEvents` are unavailable there
/// (a file typechecked against the watchOS 10 SDK on 2026-10-14), and its one window opens the default window, or the
/// route its scene's storage kept: a departure from the spec's group with a value on every Apple platform, and the
/// scene's one platform condition. The watch is a compile check in this epic (spec section 8).
public struct AppScene: Scene {
    public init() {}

    public var body: some Scene {
        #if os(watchOS)
        WindowGroup {
            WindowView(app: TodoApp.shared, path: .constant(nil))
        }
        #else
        WindowGroup("Todo", for: String.self) { $path in
            WindowView(app: TodoApp.shared, path: $path)
        }
        #endif
    }
}
