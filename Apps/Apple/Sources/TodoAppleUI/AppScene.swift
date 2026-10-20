// Apps/Apple/Sources/TodoAppleUI/AppScene.swift
import SwiftUI

/// The app's scene, and the one thing this library exports: its callers from outside are the `@main` of the Mac
/// executable and the `@main` of the iOS app target, whose body is the same one line in each, as the watch's will be
/// (ADR-0008).
///
/// A window group, so that the Mac opens as many windows as are asked for, Cmd-N among them, each made by its own view
/// around a host of its own (`docs/specs/navigation.md`, section 5). On the Mac and on iOS the group's value is the
/// window's route in its text form beside an identity of the window's own, `WindowView.Value`, whose synthesized
/// `Codable` and `Hashable` are what the group asks of its value. The identity is there because equal values bring a
/// window forward instead of opening one (probed 2026-10-20), so Open in New Window mints a new one and opens a window
/// on the view a window shows too (the owner, 2026-10-20). The window's view writes the route back into the value after
/// every change, keeping its identity, and into the scene's storage beside it (`WindowView`). The Mac restores a window
/// from its value (section 7), and so does iOS: on 2026-10-20, in the iOS 26.3 simulator, a scene the system ended in
/// the background was made again from the value its saved state kept, and on the iPad, where a launch connects only the
/// front scene, each other saved scene was made from its own value once its session was activated. The scene's storage
/// is what a window reads when it has no value of its own, the watch's only restoration; a window opened with neither,
/// the first and every Cmd-N, opens the default window, or the route `TODO_ROUTE` named for the first
/// (`TodoApp.makeWindow`). On watchOS the group takes no value, because `WindowGroup(for:)`, `openWindow` and
/// `handlesExternalEvents` are unavailable there (a file typechecked against the watchOS 10 SDK on 2026-10-14), and its
/// one window opens the default window, or the route its scene's storage kept: a departure from the spec's group with a
/// value on every Apple platform, and the scene's one platform condition. The watch is a compile check in this epic
/// (spec section 8).
public struct AppScene: Scene {
    public init() {}

    public var body: some Scene {
        #if os(watchOS)
        WindowGroup {
            WindowView(app: TodoApp.shared, value: .constant(nil))
        }
        #else
        WindowGroup("Todo", for: WindowView.Value.self) { $value in
            WindowView(app: TodoApp.shared, value: $value)
        }
        #endif
    }
}
