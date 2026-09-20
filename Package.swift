// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "todo-core",
    platforms: [.macOS(.v14), .iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "TodoCore", targets: ["TodoCore"]),
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
        .target(name: "TodoCLI", dependencies: ["TodoCore"]),
        .executableTarget(name: "todo", dependencies: ["TodoCLI"]),
        .executableTarget(name: "WasmSizeProbe", dependencies: ["TodoCore"]),
        .testTarget(name: "SQLiteKitTests", dependencies: ["SQLiteKit"]),
        .testTarget(name: "TodoCoreTests", dependencies: ["TodoCore"]),
        .testTarget(name: "TodoCLITests", dependencies: ["TodoCLI"]),
    ],
    swiftLanguageModes: [.v6]
)
