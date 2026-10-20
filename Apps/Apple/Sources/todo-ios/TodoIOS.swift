import SwiftUI
import TodoAppleUI

/// The `@main` of the iPhone and iPad app, the scene the library's, as the Mac executable's is. The app target that
/// builds this file, in `Todo.xcodeproj`, adds what a bundle needs around it, the Info.plist beside this file and the
/// signing, and nothing else; this directory belongs to no target of the package, which builds the library alone
/// (ADR-0008, amended 2026-10-14; `docs/specs/navigation.md`, section 9).
@main
struct TodoIOS: App {
    var body: some Scene { AppScene() }
}
