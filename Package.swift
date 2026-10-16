// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "todo-core",
    platforms: [.macOS(.v14), .iOS(.v17), .watchOS(.v10)],
    products: [
        // A library for each target `Apps/Apple` imports and for no other: another package reaches a target
        // only through a product, and a target in none stays this package's own.
        .library(name: "TodoCore", targets: ["TodoCore"]),
        .library(name: "DeviceFile", targets: ["DeviceFile"]),
        .library(name: "FeatureModule", targets: ["FeatureModule"]),
        .library(name: "TaskViewListFeature", targets: ["TaskViewListFeature"]),
        .library(name: "TaskListFeature", targets: ["TaskListFeature"]),
        .library(name: "TaskScreenFeature", targets: ["TaskScreenFeature"]),
        .library(name: "QuickEntryFeature", targets: ["QuickEntryFeature"]),
        .library(name: "AppFeature", targets: ["AppFeature"]),
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
        // The contract, and beside it the shared form of a parent, the routable module and its seat, and the
        // error a route's text form is refused with. It depends on nothing: a seat is handed the way to make its
        // child by the parent, so the contract names no dependency, and a screen that needs none, or others than
        // the store, needs nothing from it (ADR-0007, amendment of 2026-10-15).
        .target(name: "FeatureModule"),
        // One target per feature, so that `internal` means "inside this feature" and the dependency graph
        // is read here rather than taken on trust: a feature depends on the core, the contract and the
        // features it opens, which are its children, held in seats of its own (ADR-0009), and never on a
        // sibling or on the root module (ADR-0007). The sidebar opens the task list, and the task list opens
        // the task screen.
        .target(name: "TaskViewListFeature", dependencies: ["TodoCore", "FeatureModule", "TaskListFeature"], path: "Sources/Features/TaskViewList"),
        .target(name: "TaskListFeature", dependencies: ["TodoCore", "FeatureModule", "TaskScreenFeature"], path: "Sources/Features/TaskList"),
        .target(name: "TaskScreenFeature", dependencies: ["TodoCore", "FeatureModule"], path: "Sources/Features/TaskScreen"),
        .target(name: "QuickEntryFeature", dependencies: ["TodoCore", "FeatureModule"], path: "Sources/Features/QuickEntry"),
        // The root module, which is the features' parent and not one of them: it depends on them, since
        // composing them is what it is for, and none of them depends on it (ADR-0007). It opens the sidebar,
        // the task list and quick entry, and it names the task screen too, which the task list opens and not
        // the root: the root writes and reads the whole window's route in its one text form, in which the task
        // open in the list is a segment (spec section 2).
        .target(
            name: "AppFeature",
            dependencies: ["TodoCore", "FeatureModule", "TaskViewListFeature", "TaskListFeature", "TaskScreenFeature", "QuickEntryFeature"],
            path: "Sources/Features/App"
        ),
        // The test helpers as an ordinary target: a test target cannot be depended on, and every feature's
        // tests open a store the same way. It is in no product, so nothing ships it.
        .target(name: "TestSupport", dependencies: ["TodoCore"], path: "Tests/Support"),
        .executableTarget(name: "todo", dependencies: ["TodoCLI"]),
        .executableTarget(
            name: "WasmSizeProbe",
            dependencies: ["TodoCore", "FeatureModule", "AppFeature", "TaskViewListFeature", "TaskListFeature", "TaskScreenFeature", "QuickEntryFeature"]
        ),
        .testTarget(name: "SQLiteKitTests", dependencies: ["SQLiteKit"]),
        .testTarget(name: "TodoCoreTests", dependencies: ["TodoCore", "TestSupport"]),
        .testTarget(name: "TodoCLITests", dependencies: ["TodoCLI"]),
        .testTarget(name: "DeviceFileTests", dependencies: ["DeviceFile", "TodoCore"]),
        .testTarget(name: "FeatureModuleTests", dependencies: ["FeatureModule"]),
        .testTarget(
            name: "TaskViewListFeatureTests",
            dependencies: ["TaskViewListFeature", "TaskListFeature", "TaskScreenFeature", "TodoCore", "SQLiteKit", "TestSupport"]
        ),
        .testTarget(name: "TaskListFeatureTests", dependencies: ["TaskListFeature", "TaskScreenFeature", "TodoCore", "SQLiteKit", "TestSupport"]),
        .testTarget(name: "TaskScreenFeatureTests", dependencies: ["TaskScreenFeature", "TodoCore", "TestSupport"]),
        .testTarget(name: "QuickEntryFeatureTests", dependencies: ["QuickEntryFeature", "TodoCore", "SQLiteKit", "TestSupport"]),
        .testTarget(
            name: "AppFeatureTests",
            dependencies: ["AppFeature", "FeatureModule", "TaskViewListFeature", "TaskListFeature", "TaskScreenFeature", "QuickEntryFeature", "TodoCore", "TestSupport"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
