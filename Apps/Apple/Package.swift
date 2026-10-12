// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "todo-apple",
    // macOS 14 is the first release with Observation, which the host is built on.
    platforms: [.macOS(.v14)],
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
        // The `@main` and nothing else: the app is the library, which the Xcode app target that arrives when the
        // store needs a bundle imports the way this does (ADR-0008).
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
