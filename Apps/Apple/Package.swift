// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "todo-apple",
    // The first releases with Observation, which the host is built on. The Mac runs the app from `todo-mac` below,
    // and iPhone and iPad from the app target of `Todo.xcodeproj`; watchOS is declared so that the macOS job
    // compiles `TodoAppleUI` for it, the library its app target will import (ADR-0008).
    platforms: [.macOS(.v14), .iOS(.v17), .watchOS(.v10)],
    // The library the app target of `Todo.xcodeproj` links. That target names a product of this package, and with
    // none declared Xcode 27.1 stopped its build with "Missing package product" (probed 2026-10-20); `todo-mac`
    // depends on the library's target and needs no product.
    products: [.library(name: "TodoAppleUI", targets: ["TodoAppleUI"])],
    dependencies: [
        // Named after the root manifest's own `name`, because SwiftPM names an unnamed path dependency after
        // the directory it points at, and a clone into a directory not called `todo-app` would then resolve
        // none of the products below (probed 2026-10-08 with Swift 6.3.3 and Xcode's 6.2.4, a copy of the
        // repository under another name).
        .package(name: "todo-core", path: "../.."),
        // Apple's model of `project.xcproj`, the Xcode project's file, which `ProjectFileTests` decodes, and the
        // home of `xcprojformatter`, which keeps that file canonical when run from here through `swift run`
        // (ADR-0008, amended 2026-10-14). Exact, because the format and the library are weeks old.
        .package(url: "https://github.com/apple/xcode-project-format", exact: "0.1.0"),
    ],
    targets: [
        .target(name: "TodoAppleUI", dependencies: [
            .product(name: "AppFeature", package: "todo-core"),
            .product(name: "DesignSystem", package: "todo-core"),
            .product(name: "DeviceFile", package: "todo-core"),
            .product(name: "FeatureModule", package: "todo-core"),
            .product(name: "QuickEntryFeature", package: "todo-core"),
            .product(name: "TaskListFeature", package: "todo-core"),
            .product(name: "TaskScreenFeature", package: "todo-core"),
            .product(name: "TaskViewListFeature", package: "todo-core"),
            .product(name: "TodoCore", package: "todo-core"),
        ]),
        // The `@main`, and the activation an executable without a bundle needs: the app is `TodoAppleUI`, and the
        // iOS app target of `Todo.xcodeproj`, whose `@main` is `Sources/todo-ios`, outside every target here,
        // imports it the same way (ADR-0008).
        .executableTarget(name: "todo-mac", dependencies: ["TodoAppleUI"]),
        .testTarget(name: "TodoAppleUITests", dependencies: [
            "TodoAppleUI",
            .product(name: "AppFeature", package: "todo-core"),
            .product(name: "DesignSystem", package: "todo-core"),
            .product(name: "DeviceFile", package: "todo-core"),
            .product(name: "FeatureModule", package: "todo-core"),
            .product(name: "TaskViewListFeature", package: "todo-core"),
            .product(name: "TodoCore", package: "todo-core"),
        ]),
        .testTarget(name: "ProjectFileTests", dependencies: [
            .product(name: "XcodeProjectFormat", package: "xcode-project-format"),
        ]),
    ],
    swiftLanguageModes: [.v6]
)
