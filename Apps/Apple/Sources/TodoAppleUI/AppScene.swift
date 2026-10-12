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
                // The app has no bundle (ADR-0008), and AppKit's header gives an executable without an
                // Info.plist the prohibited activation policy, which "may not … be activated". Launched from a
                // shell without these two calls, it was not the front application three seconds later, and with
                // them it was (2026-10-12). `activate()` only asks, and is granted when the front application
                // yields, which nothing here makes it do, so the call is the one the header says activates
                // regardless.
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
    }
}
