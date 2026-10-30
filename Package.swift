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
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "DesignSystemComponents", targets: ["DesignSystemComponents"]),
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
                .define("SQLITE_THREADSAFE", to: "2"),
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
        // The look's design decisions in numbers, which every platform turns into its own pixels: the colours, the
        // type as text styles, the motion and the icons, the tile's colours and the icons named as the store names
        // them. It depends on nothing, the core included, because the look must not know the domain, and the wasm
        // probe links it once a module the probe drives builds a component's model (ADR-0007, amendment of
        // 2026-10-26).
        .target(name: "DesignSystem"),
        // The models and the logic of the components every platform draws from the design system's decisions, a
        // list's tile first, whose model holds every visual parameter a platform needs to draw it. It depends on the
        // design system alone and, like it, not on the core: the feature module that builds a component's model reads
        // the store's names of a list's colour and icon as the design system's (ADR-0007, amendment of 2026-10-26).
        .target(name: "DesignSystemComponents", dependencies: ["DesignSystem"]),
        // The contract, and beside it what every parent and every flow needs and nothing of any one screen: the
        // routable module and its seat, the error a route's text form is refused with, the destination a screen
        // declares what is open over it in, the stack a flow holds the screens over its base in, the id of an
        // element of it, the protocol of a flow's enum of screens and the notice the stack sends (ADR-0007,
        // amendment of 2026-10-22), and the width class of a window, which the root lays its window out by and the
        // sidebar builds its rows for, here since a child never imports the root (ADR-0007, amendment of
        // 2026-10-27). It still depends on nothing: a seat and a stack are handed the way to make what they hold by
        // their owner, so the contract names no dependency, and a screen that needs none, or others than the
        // store, needs nothing from it (ADR-0007, amendment of 2026-10-15).
        .target(name: "FeatureModule"),
        // One target per feature, so that `internal` means "inside this feature" and the dependency graph
        // is read here rather than taken on trust: a feature depends on the core, the contract and the
        // features whose routes its destination holds, the screens it declares open over it (ADR-0009,
        // amendment of 2026-10-22), and never on a sibling or on the root module (ADR-0007). The sidebar
        // declares the task list, and the task list declares the task screen. A feature that builds the models
        // of its screen's components depends on the design system's two targets too, as the sidebar builds
        // each row's tile and chooses its title's font (ADR-0007, amendment of 2026-10-26).
        .target(
            name: "TaskViewListFeature",
            dependencies: ["TodoCore", "FeatureModule", "TaskListFeature", "DesignSystem", "DesignSystemComponents"],
            path: "Sources/Features/TaskViewList"
        ),
        .target(name: "TaskListFeature", dependencies: ["TodoCore", "FeatureModule", "TaskScreenFeature"], path: "Sources/Features/TaskList"),
        .target(name: "TaskScreenFeature", dependencies: ["TodoCore", "FeatureModule"], path: "Sources/Features/TaskScreen"),
        .target(name: "QuickEntryFeature", dependencies: ["TodoCore", "FeatureModule"], path: "Sources/Features/QuickEntry"),
        // The root module, which is the features' parent and not one of them: it depends on them, since
        // composing them is what it is for, and none of them depends on it (ADR-0007). It holds its window's
        // stack, so it depends on every kind of screen that can stand in it, the sidebar its base, the task
        // list and the task screen over it, and on quick entry, its modal (ADR-0009, amendment of 2026-10-22,
        // point 3). Which screen declares which stays in the features, and each route reads and writes its
        // own part of the window's path, so the root decides none of the transitions.
        .target(
            name: "AppFeature",
            dependencies: [
                "TodoCore", "FeatureModule", "TaskViewListFeature", "TaskListFeature", "TaskScreenFeature",
                "QuickEntryFeature",
            ],
            path: "Sources/Features/App"
        ),
        // The test helpers as an ordinary target: a test target cannot be depended on, and every feature's
        // tests open a store the same way. It is in no product, so nothing ships it.
        .target(name: "TestSupport", dependencies: ["TodoCore"], path: "Tests/Support"),
        .executableTarget(name: "todo", dependencies: ["TodoCLI"]),
        .executableTarget(
            name: "WasmSizeProbe",
            dependencies: ["TodoCore", "FeatureModule", "AppFeature"]
        ),
        .testTarget(name: "SQLiteKitTests", dependencies: ["SQLiteKit"]),
        .testTarget(name: "TodoCoreTests", dependencies: ["TodoCore", "TestSupport"]),
        .testTarget(name: "TodoCLITests", dependencies: ["TodoCLI"]),
        .testTarget(name: "DeviceFileTests", dependencies: ["DeviceFile", "TodoCore"]),
        // The core and its helpers only for the tests that hold the design system's names of a tile's colour and of
        // an icon to the store's, with which they agree by raw value.
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem", "TodoCore", "TestSupport"]),
        .testTarget(name: "DesignSystemComponentsTests", dependencies: ["DesignSystemComponents", "DesignSystem"]),
        .testTarget(name: "FeatureModuleTests", dependencies: ["FeatureModule"]),
        .testTarget(
            name: "TaskViewListFeatureTests",
            dependencies: [
                "TaskViewListFeature", "TaskListFeature", "TaskScreenFeature", "FeatureModule", "TodoCore", "SQLiteKit",
                "TestSupport", "DesignSystem", "DesignSystemComponents",
            ]
        ),
        .testTarget(
            name: "TaskListFeatureTests",
            dependencies: ["TaskListFeature", "TaskScreenFeature", "FeatureModule", "TodoCore", "SQLiteKit", "TestSupport"]
        ),
        .testTarget(name: "TaskScreenFeatureTests", dependencies: ["TaskScreenFeature", "FeatureModule", "TodoCore", "TestSupport"]),
        .testTarget(name: "QuickEntryFeatureTests", dependencies: ["QuickEntryFeature", "FeatureModule", "TodoCore", "SQLiteKit", "TestSupport"]),
        .testTarget(
            name: "AppFeatureTests",
            dependencies: [
                "AppFeature", "FeatureModule", "TaskViewListFeature", "TaskListFeature", "TaskScreenFeature",
                "QuickEntryFeature", "TodoCore", "SQLiteKit", "TestSupport", "DesignSystem", "DesignSystemComponents",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
