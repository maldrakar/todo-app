// Apps/Apple/Sources/TodoAppleUI/AppScene.swift
import AppKit
import SwiftUI

/// The app's scene, and the one thing this library exports: the executable's `@main` is its only caller from
/// outside, and holds nothing else (ADR-0008).
public struct AppScene: Scene {
    public init() {}

    /// One `Window` and not a `WindowGroup`, because there is one host and one root per process: a group is
    /// there to hold more windows than one, and a second window over the same host would draw the first one's
    /// highlight and open field again. More windows are the navigation epic's (#67).
    public var body: some Scene {
        Window("Todo", id: "main") {
            RootView(host: TodoApp.host)
                // AppKit's header on the policy this app starts with: "The application does not appear in the
                // Dock and may not create windows or be activated.  This corresponds to LSBackgroundOnly=1 in
                // the Info.plist.  This is also the default for unbundled executables that do not have
                // Info.plists." Launched from a shell on 2026-10-12 without the first call, it read as
                // `BackgroundOnly`, opened its window all the same, and stayed behind the front application even
                // with `activate(ignoringOtherApps: true)`; with the first call alone it read as `Foreground`
                // and still stayed behind. With both, it came in front of the terminal it was launched from
                // within a second, and stayed behind another application that was in front, as it also did with
                // `activate(ignoringOtherApps: true)` in place of `activate()`: the header does not promise that
                // `activate()` is granted, and the older call did no better. Both calls stand in for the bundle
                // the app does not have yet, and go when it gets one (ADR-0008).
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate()
                }
        }
    }
}
