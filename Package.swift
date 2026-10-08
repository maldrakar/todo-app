// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "todo-core",
    platforms: [.macOS(.v14), .iOS(.v17), .watchOS(.v10)],
    products: [
        // A library for each target `Apps/Apple` imports and for no other: another package reaches a target
        // only through a product, and a target in none stays this package's own.
        .library(name: "TodoCore", targets: ["TodoCore"]),
        .library(name: "FeatureModule", targets: ["FeatureModule"]),
        .executable(name: "todo", targets: ["todo"]),
        .executable(name: "wasm-size-probe", targets: ["WasmSizeProbe"]),
    ],
    targets: [
        .target(
            name: "CSQLite",
            cSettings: [
                .define("SQLITE_ENABLE_FTS5"),
                .define("SQLITE_THREADSAFE", to: "0"),
                .define("SQLITE_OMIT_LOAD_EXTENSION"),
                .define("SQLITE_OMIT_DEPRECATED"),
                .define("SQLITE_OMIT_SHARED_CACHE"),
                .define("SQLITE_DQS", to: "0"),
                .define("SQLITE_DEFAULT_MEMSTATUS", to: "0"),
                .define("SQLITE_LIKE_DOESNT_MATCH_BLOBS"),
                .define("SQLITE_MAX_EXPR_DEPTH", to: "0"),
                .define("SQLITE_USE_ALLOCA"),
                .define("SQLITE_TEMP_STORE", to: "3"),
            ]
        ),
        .target(name: "SQLiteKit", dependencies: ["CSQLite"]),
        .target(name: "TodoCore", dependencies: ["SQLiteKit"]),
        .target(name: "TodoCLI", dependencies: ["TodoCore", "DeviceFile"]),
        // Where an identity is kept beside its database, in a target of its own because two consumers keep
        // it, the demo and the Apple app, and they agree on where it lives only by sharing the code (ADR-0005).
        .target(name: "DeviceFile"),
        .target(name: "FeatureModule"),
        // One target per feature, so that `internal` means "inside this feature" and the dependency graph
        // is read here rather than taken on trust: a feature depends on the core and the contract, never on
        // another feature and never on the root module (ADR-0007).
        .target(name: "TaskViewListFeature", dependencies: ["TodoCore", "FeatureModule"], path: "Sources/Features/TaskViewList"),
        // The root module, which is the features' parent and not one of them: it depends on them, since
        // composing them is what it is for, and none of them depends on it (ADR-0007).
        .target(name: "AppFeature", dependencies: ["TodoCore", "FeatureModule", "TaskViewListFeature"], path: "Sources/Features/App"),
        // The test helpers as an ordinary target: a test target cannot be depended on, and every feature's
        // tests open a store the same way. It is in no product, so nothing ships it.
        .target(name: "TestSupport", dependencies: ["TodoCore"], path: "Tests/Support"),
        .executableTarget(name: "todo", dependencies: ["TodoCLI"]),
        .executableTarget(name: "WasmSizeProbe", dependencies: ["TodoCore", "AppFeature", "TaskViewListFeature"]),
        .testTarget(name: "SQLiteKitTests", dependencies: ["SQLiteKit"]),
        .testTarget(name: "TodoCoreTests", dependencies: ["TodoCore", "TestSupport"]),
        .testTarget(name: "TodoCLITests", dependencies: ["TodoCLI"]),
        .testTarget(name: "DeviceFileTests", dependencies: ["DeviceFile", "TodoCore"]),
        .testTarget(name: "TaskViewListFeatureTests", dependencies: ["TaskViewListFeature", "TodoCore", "SQLiteKit", "TestSupport"]),
        .testTarget(name: "AppFeatureTests", dependencies: ["AppFeature", "TaskViewListFeature", "TodoCore", "TestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
