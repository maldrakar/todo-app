// Apps/Apple/Sources/todo-ios/TodoIOS.swift
import SwiftUI
import TodoAppleUI

/// The `@main` of the iPhone and iPad app, the scene the library's, as the Mac executable's is. The app target that
/// builds this file, in `Todo.xcodeproj`, adds what a bundle needs around it, the Info.plist beside this file and the
/// signing, and nothing else; no target of the package builds this directory (ADR-0008, amended 2026-10-14;
/// `docs/specs/navigation.md`, section 9).
///
/// Why each key of that Info.plist is there is said here, because Xcode 27.1 drops the XML comments of a plist it
/// rewrites (2026-10-21), so the plist carries none. `CFBundleExecutable`, `CFBundleIdentifier` and `CFBundleName` are
/// what an install needs: the iOS 26.3 simulator refused a bundle without the executable (2026-10-20), and an iPhone 13
/// Pro Max on iOS 26.3.1 refused one with neither a name nor a display name (2026-10-21). The `todo` scheme in
/// `CFBundleURLTypes` is the way a link arrives (section 7), and `UIApplicationSupportsMultipleScenes` lets the iPad
/// open more than one window (section 9). `UILaunchScreen`, empty, keeps iOS from running the app letterboxed at a
/// legacy size (the iOS 26.3 simulator, 2026-10-20). `UISupportedInterfaceOrientations~ipad` lists all four, without
/// which iPadOS 18.4 opened no second scene, with portrait alone or with none (iPadOS 26.3 opened one either way,
/// 2026-10-20). No version key is there, since no install or launch asked for one.
@main
struct TodoIOS: App {
    var body: some Scene { AppScene() }
}
