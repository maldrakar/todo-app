// Apps/Apple/Sources/todo-ios/TodoIOS.swift
import SwiftUI
import TodoAppleUI

/// The `@main` of the iPhone and iPad app, the scene the library's, as the Mac executable's is. The app target that
/// builds this file, in `Todo.xcodeproj`, adds what a bundle needs around it, the Info.plist beside this file and the
/// signing, and nothing else; no target of the package builds this directory (ADR-0008, amended 2026-10-14;
/// `docs/specs/navigation.md`, section 9).
@main
struct TodoIOS: App {
    var body: some Scene { AppScene() }
}
