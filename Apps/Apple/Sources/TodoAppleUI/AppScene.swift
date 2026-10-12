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
                // An executable without an Info.plist starts `BackgroundOnly`, the policy AppKit's header
                // describes as "The application does not appear in the Dock and may not create windows or be
                // activated." (This one opened its window all the same.) The regular policy makes it
                // `Foreground`, and `activate()` then brings it in front of the terminal that launched it;
                // macOS's cooperative activation can still leave it behind an application that does not yield,
                // as it did with Telegram and with Arc in front (2026-10-12). Both calls go when the app has a
                // bundle (ADR-0008).
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate()
                }
        }
    }
}
