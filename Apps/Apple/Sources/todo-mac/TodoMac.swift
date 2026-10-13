// Apps/Apple/Sources/todo-mac/TodoMac.swift
import AppKit
import SwiftUI
import TodoAppleUI

@main
struct TodoMac: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene { AppScene() }
}

/// What this executable needs because it has no bundle, kept out of `TodoAppleUI`, which the app targets of every
/// platform import (ADR-0008, amended 2026-10-13).
///
/// An executable without an Info.plist starts `BackgroundOnly`, the policy AppKit's header describes as "The
/// application does not appear in the Dock and may not create windows or be activated." (This one opened its window
/// all the same.) The regular policy makes it `Foreground`, and `activate()` then brings it in front of the terminal
/// that launched it. Read on 2026-10-13: `activate()` alone left the app `BackgroundOnly` behind the terminal, and
/// both calls made from `App.init`, before the launch finished, left the terminal in front. macOS's cooperative
/// activation can still leave the app behind an application that does not yield, as it did with Telegram and with
/// Arc in front (2026-10-12). An app with a bundle needs neither call.
private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }
}
