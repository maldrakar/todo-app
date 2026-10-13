// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "todo-apple",
    // The first releases with Observation, which the host is built on. Only macOS runs the app today; iOS and
    // watchOS are declared so that the macOS job compiles `TodoAppleUI` for them, the library their app targets
    // will import (ADR-0008).
    platforms: [.macOS(.v14), .iOS(.v17), .watchOS(.v10)],
    dependencies: [
        // Named after the root manifest's own `name`, because SwiftPM names an unnamed path dependency after
        // the directory it points at, and a clone into a directory not called `todo-app` would then resolve
        // none of the products below (probed 2026-10-08 with Swift 6.3.3 and Xcode's 6.2.4, a copy of the
        // repository under another name).
        .package(name: "todo-core", path: "../.."),
    ],
    targets: [
        .target(name: "TodoAppleUI", dependencies: [
            .product(name: "AppFeature", package: "todo-core"),
            .product(name: "DeviceFile", package: "todo-core"),
            .product(name: "FeatureModule", package: "todo-core"),
            .product(name: "TaskViewListFeature", package: "todo-core"),
            .product(name: "TodoCore", package: "todo-core"),
        ]),
        // The `@main`, and the activation an executable without a bundle needs: the app is `TodoAppleUI`, and the
        // Xcode app target that arrives when iOS, watchOS or the store needs a bundle imports it the same way
        // (ADR-0008).
        .executableTarget(name: "todo-mac", dependencies: ["TodoAppleUI"]),
        .testTarget(name: "TodoAppleUITests", dependencies: [
            "TodoAppleUI",
            .product(name: "AppFeature", package: "todo-core"),
            .product(name: "DeviceFile", package: "todo-core"),
            .product(name: "FeatureModule", package: "todo-core"),
            .product(name: "TaskViewListFeature", package: "todo-core"),
            .product(name: "TodoCore", package: "todo-core"),
        ]),
    ],
    swiftLanguageModes: [.v6]
)
