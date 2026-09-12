# Core Storage and Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `TodoCore` Swift package: SQLite-backed storage for tasks, tags and nested views, an operation journal ready for sync, filter-defined views, full-text search, a sync skeleton proven by a two-store convergence test, and the `todo` command-line demo, all green on the host and on wasm32.

**Architecture:** One SwiftPM package at the repository root with five targets: `CSQLite` (the vendored amalgamation), `SQLiteKit` (a thin typed wrapper), `TodoCore` (model, journal, store, views, search, sync skeleton), `TodoCLI` (commands) and `todo` (the executable). Every write becomes field-level operations applied through one path that journals them, compares per-field hybrid logical clocks and updates the state tables; reads are SQL over the state tables plus a derived `task_tree` table for effective parent and trash. The web target keeps the database in memory and moves it as a snapshot.

**Tech Stack:** Swift 6.3.3 from swift.org via swiftly (`.swift-version`), SwiftPM, swift-testing, SQLite 3.53.4 amalgamation with FTS5, Swift SDK `swift-6.3.3-RELEASE_wasm` with WasmKit for wasm32 tests, GitHub Actions.

**Spec:** `docs/specs/core-storage-and-search.md` (approved 2026-09-11). ADRs: `docs/adr/0001` (language mode), `0002` (SQLite), `0003` (journal), `0004` (flat model), the last three proposed in PR #9.

## Global Constraints

- Core modules depend only on the standard library and the FoundationEssentials API surface: `#if canImport(FoundationEssentials) import FoundationEssentials #else import Foundation #endif` in every file that needs `UUID`, `Date`, `JSONEncoder` or `JSONDecoder`. Nothing from FoundationInternationalization, no ICU (ADR-0001).
- The only C dependency is the vendored SQLite amalgamation 3.53.4, compiled with `SQLITE_ENABLE_FTS5`, `SQLITE_THREADSAFE=0`, `SQLITE_OMIT_LOAD_EXTENSION`, `SQLITE_OMIT_DEPRECATED`, `SQLITE_OMIT_SHARED_CACHE`, `SQLITE_DQS=0` (ADR-0002). The system SQLite is never imported.
- `Int` is 32-bit on wasm32: identifiers, timestamps, clocks and row counts that leave a function are `Int64` (ADR-0001).
- The core never reads the wall clock or the current day on its own: `Store` receives a `now: () -> Int64` closure (milliseconds since 1970-01-01) and every query receives `today: Day` (spec, Platform boundary). Under WasmKit `Date()` returns a fake time near 1970-01-03, so no test may assert a real wall-clock value on wasm32.
- No code path modifies the state tables except `apply` (ADR-0003). Every public write method builds operations and calls `apply`.
- `Store` is a `final class`, not `Sendable`, synchronous, with typed throws `throws(StoreError)`; no Swift concurrency inside `TodoCore` (spec, Concurrency and API shape).
- The same test suite runs on the host with `swift test` and on wasm32 with `swift test --swift-sdk swift-6.3.3-RELEASE_wasm`; both must be green before a PR.
- Web size budget: `todo.wasm` built with `-c release` for `wasm32-unknown-wasip1` is at most 4.5 MiB after `gzip -9` (measured on 2026-09-11 with SQLite, FoundationEssentials and a smoke executable: 3.74 MB).
- Toolchain: always the swiftly-managed `swift` (`~/.swiftly/bin/swift` on macOS), never `/usr/bin/swift`, which is Xcode's 6.2.4. Every command below assumes `export PATH="$HOME/.swiftly/bin:$PATH"` and the repository root as the working directory.
- Branch per task `<type>/<issue>-<slug>` with the sub-issue number from the table at the end, PR title in Conventional Commits with scope `core`, `infra` or `ci`, body per template, `Closes #<sub-issue>`; squash merge. Commit messages end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Everything in the repository is in English. No `TODO` without a linked issue.
- Every task's PR adds one line under `[Unreleased]` in `CHANGELOG.md` describing what the task delivered.

---

## File map

| Path | Responsibility |
| ---- | -------------- |
| `Package.swift` | Targets `CSQLite`, `SQLiteKit`, `TodoCore`, `todo`, two test targets |
| `Sources/CSQLite/sqlite3.c`, `include/sqlite3.h` | Vendored amalgamation, untouched |
| `Sources/SQLiteKit/SQLiteError.swift` | `SQLiteError` |
| `Sources/SQLiteKit/Value.swift` | `Value`: null, integer, real, text, blob |
| `Sources/SQLiteKit/Connection.swift` | `Connection`: open, execute, run, rows, prepare, transaction, user version, serialize, deserialize |
| `Sources/SQLiteKit/Statement.swift` | `Statement`: bind, step, columns |
| `Sources/TodoCore/Model/EntityID.swift` | `EntityID` and the `TaskID`, `TagID`, `ViewID` aliases |
| `Sources/TodoCore/Model/Day.swift` | `Day`: calendar day as days since 1970-01-01 |
| `Sources/TodoCore/Model/HLC.swift` | `HLC` value and `HybridClock` generator |
| `Sources/TodoCore/Model/Rank.swift` | `Rank.between`: fractional order keys |
| `Sources/TodoCore/Model/Entities.swift` | `Task`, `TaskStatus`, `Tag`, `View`, `SortKey`, `SortField`, `GroupBy` |
| `Sources/TodoCore/Model/Filter.swift` | `Filter`, `DayCondition`, JSON codec, `FilterError` |
| `Sources/TodoCore/Storage/Schema.swift` | DDL of schema version 1 |
| `Sources/TodoCore/Storage/Migrations.swift` | Ordered migration steps, `Migrations.run` |
| `Sources/TodoCore/Storage/Store.swift` | `Store`, `StoreError`, `ChangeSet`, open, snapshot, meta, built-in views seed |
| `Sources/TodoCore/Storage/Operation.swift` | `Operation`, `EntityKind`, `FieldMap` |
| `Sources/TodoCore/Storage/Store+Apply.swift` | `apply`, journal, field clocks, replay of unapplied operations |
| `Sources/TodoCore/Storage/Store+Tree.swift` | `task_tree` rebuild: effective parent and trash |
| `Sources/TodoCore/Storage/Store+Tasks.swift` | Task write API and reads |
| `Sources/TodoCore/Storage/Store+Tags.swift` | Tag write API and reads |
| `Sources/TodoCore/Storage/Store+Views.swift` | View write API, manual lists, reads |
| `Sources/TodoCore/Query/FilterCompiler.swift` | `Filter` to SQL fragment, sort to `ORDER BY` |
| `Sources/TodoCore/Query/Store+Query.swift` | `tasks(in:today:)`, `page(of:today:)`, grouping |
| `Sources/TodoCore/Search/Store+Search.swift` | `quickFind`, `searchNotes`, FTS query escaping |
| `Sources/TodoCore/Sync/Sync.swift` | `JournalEntry`, `SyncTransport`, `SyncError`, `InMemoryRelay`, `SyncEngine`, `Store.journal(after:)`, `Store.receive` |
| `Sources/todo/main.swift` | CLI entry: argument parsing and commands |
| `Tests/SQLiteKitTests/ConnectionTests.swift` | Wrapper tests |
| `Tests/TodoCoreTests/*.swift` | One file per task, named below |
| `scripts/wasm-size.sh` | Release wasm build and gzip size budget |
| `.github/workflows/ci.yml` | Linux job for build, tests, wasm tests (Task 1) and size (Task 13); macOS job for Apple SDK compile checks (Task 13) |

Every test creates its own `Store.openInMemory(now:)` with a deterministic clock, so tests run in parallel without shared state. The helper below is defined once in `Tests/TodoCoreTests/TestSupport.swift` (Task 4) and used by every later test file:

```swift
import TodoCore

/// A clock that starts at a fixed millisecond and advances by one on every call.
final class TestClock {
    private(set) var millis: Int64
    init(start: Int64 = 1_757_500_000_000) { millis = start }
    func now() -> Int64 { millis += 1; return millis }
    func jump(by ms: Int64) { millis += ms }
}

func makeStore(clock: TestClock = TestClock()) throws(StoreError) -> Store {
    try Store.openInMemory(now: clock.now)
}
```

---

### Task 1: Package skeleton, vendored SQLite, smoke tests on host and wasm32, and the CI job that runs them

Retires the two risks named in the spec: `UUID` and time on WASI, and SQLite as a C target on wasm32 in full Swift mode. Everything here was verified by hand on 2026-09-11; the task turns it into the repository's first code. The Linux CI job lands here too, so every later PR of the epic arrives with a green check; the size budget and the macOS compile checks follow in Task 13, once the `todo` executable exists.

**Files:**
- Create: `Package.swift`
- Create: `Sources/CSQLite/sqlite3.c`, `Sources/CSQLite/include/sqlite3.h` (downloaded, not hand-written)
- Create: `Sources/SQLiteKit/SQLiteKit.swift` (placeholder, replaced in Task 2)
- Create: `Sources/TodoCore/TodoCore.swift` (placeholder, replaced in Task 4)
- Create: `Sources/todo/main.swift` (placeholder, replaced in Task 12)
- Create: `Tests/SQLiteKitTests/ConnectionTests.swift` (placeholder, replaced in Task 2)
- Create: `Tests/TodoCoreTests/SmokeTests.swift`
- Create: `.github/workflows/ci.yml`
- Modify: `.gitignore`, `README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the module `CSQLite` (C API of SQLite), the targets every later task adds files to, and the `core` CI job that Task 13 extends.

- [ ] **Step 1: Vendor the amalgamation**

```bash
export PATH="$HOME/.swiftly/bin:$PATH"
mkdir -p Sources/CSQLite/include Sources/SQLiteKit Sources/TodoCore Sources/todo Tests/SQLiteKitTests Tests/TodoCoreTests scripts
curl -fsSL -o /tmp/sqlite.zip https://sqlite.org/2026/sqlite-amalgamation-3530400.zip
unzip -qo /tmp/sqlite.zip -d /tmp
cp /tmp/sqlite-amalgamation-3530400/sqlite3.c Sources/CSQLite/sqlite3.c
cp /tmp/sqlite-amalgamation-3530400/sqlite3.h Sources/CSQLite/include/sqlite3.h
grep -m1 '#define SQLITE_VERSION ' Sources/CSQLite/include/sqlite3.h
```

Expected: `#define SQLITE_VERSION        "3.53.4"`. SwiftPM generates the module map for a C target from the `include` directory; no `module.modulemap` is needed.

- [ ] **Step 2: Write `Package.swift`**

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "todo-core",
    platforms: [.macOS(.v14), .iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "TodoCore", targets: ["TodoCore"]),
        .executable(name: "todo", targets: ["todo"]),
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
        .executableTarget(name: "todo", dependencies: ["TodoCore"]),
        .testTarget(name: "SQLiteKitTests", dependencies: ["SQLiteKit"]),
        .testTarget(name: "TodoCoreTests", dependencies: ["TodoCore"]),
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 3: Write the placeholders so every target compiles**

`Sources/SQLiteKit/SQLiteKit.swift`:

```swift
import CSQLite

/// Replaced by the real wrapper in Task 2. Kept minimal so the package builds.
public enum SQLiteKitSmoke {
    public static func libraryVersion() -> String { String(cString: sqlite3_libversion()) }
}
```

`Sources/TodoCore/TodoCore.swift`:

```swift
import CSQLite
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Replaced by the real store in Task 4. Exercises what the spec lists as unverified on WASI.
public enum CoreSmoke {
    public static func sqliteVersion() -> String { String(cString: sqlite3_libversion()) }

    /// Creates a trigram FTS5 table in memory and counts the rows matching a Cyrillic substring.
    public static func trigramMatches(_ needle: String) -> Int64 {
        var db: OpaquePointer?
        precondition(sqlite3_open(":memory:", &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        let ddl = "CREATE VIRTUAL TABLE t USING fts5(title, tokenize='trigram remove_diacritics 1');"
        precondition(sqlite3_exec(db, ddl, nil, nil, nil) == SQLITE_OK, String(cString: sqlite3_errmsg(db)))
        precondition(sqlite3_exec(db, "INSERT INTO t VALUES ('Квартальный отчёт'), ('Купить молоко');", nil, nil, nil) == SQLITE_OK)
        var stmt: OpaquePointer?
        precondition(sqlite3_prepare_v2(db, "SELECT count(*) FROM t WHERE t MATCH ?", -1, &stmt, nil) == SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        let quoted = "\"" + needle.replacing("\"", with: "\"\"") + "\""
        sqlite3_bind_text(stmt, 1, quoted, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        precondition(sqlite3_step(stmt) == SQLITE_ROW)
        return sqlite3_column_int64(stmt, 0)
    }

    /// Serializes a database to bytes and restores it into a second connection: the web persistence bridge.
    public static func snapshotSum() -> Int64 {
        var db: OpaquePointer?
        precondition(sqlite3_open(":memory:", &db) == SQLITE_OK)
        precondition(sqlite3_exec(db, "CREATE TABLE a(x); INSERT INTO a VALUES (1),(2),(3);", nil, nil, nil) == SQLITE_OK)
        var size: sqlite3_int64 = 0
        guard let bytes = sqlite3_serialize(db, "main", &size, 0) else { preconditionFailure("serialize") }
        let copy = [UInt8](UnsafeBufferPointer(start: bytes, count: Int(size)))
        sqlite3_free(bytes)
        sqlite3_close(db)

        var db2: OpaquePointer?
        precondition(sqlite3_open(":memory:", &db2) == SQLITE_OK)
        defer { sqlite3_close(db2) }
        let buffer = sqlite3_malloc64(sqlite3_uint64(copy.count))!
        copy.withUnsafeBytes { buffer.copyMemory(from: $0.baseAddress!, byteCount: copy.count) }
        let flags = UInt32(SQLITE_DESERIALIZE_FREEONCLOSE | SQLITE_DESERIALIZE_RESIZEABLE)
        let rc = sqlite3_deserialize(db2, "main", buffer.assumingMemoryBound(to: UInt8.self), sqlite3_int64(copy.count), sqlite3_int64(copy.count), flags)
        precondition(rc == SQLITE_OK, "deserialize rc=\(rc)")
        var stmt: OpaquePointer?
        precondition(sqlite3_prepare_v2(db2, "SELECT sum(x) FROM a", -1, &stmt, nil) == SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        precondition(sqlite3_step(stmt) == SQLITE_ROW)
        return sqlite3_column_int64(stmt, 0)
    }

    public static func freshUUID() -> String { UUID().uuidString }
    public static func nowMilliseconds() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}
```

`Sources/todo/main.swift`:

```swift
import TodoCore

print("todo demo, SQLite \(CoreSmoke.sqliteVersion()), Int is \(Int.bitWidth)-bit")
```

`Tests/SQLiteKitTests/ConnectionTests.swift`:

```swift
import Testing
@testable import SQLiteKit

@Test func linksTheVendoredSQLite() {
    #expect(SQLiteKitSmoke.libraryVersion() == "3.53.4")
}
```

- [ ] **Step 4: Write the smoke tests**

`Tests/TodoCoreTests/SmokeTests.swift`:

```swift
import Testing
@testable import TodoCore

@Test func vendoredSQLiteHasTheExpectedVersion() {
    #expect(CoreSmoke.sqliteVersion() == "3.53.4")
}

@Test func trigramTokenizerFoldsCaseAndFindsCyrillicSubstrings() {
    #expect(CoreSmoke.trigramMatches("отч") == 1)
    #expect(CoreSmoke.trigramMatches("ОТЧ") == 1)
    #expect(CoreSmoke.trigramMatches("xyz") == 0)
}

@Test func databaseRoundTripsThroughSerializeAndDeserialize() {
    #expect(CoreSmoke.snapshotSum() == 6)
}

@Test func uuidIsRandomAndClockAdvances() {
    let a = CoreSmoke.freshUUID()
    #expect(a.count == 36)
    #expect(a != CoreSmoke.freshUUID())
    let t1 = CoreSmoke.nowMilliseconds()
    let t2 = CoreSmoke.nowMilliseconds()
    // Under WasmKit the clock is fake, so only monotonicity is asserted, never a wall-clock value.
    #expect(t2 >= t1)
}
```

- [ ] **Step 5: Run on the host**

```bash
swift test 2>&1 | tail -5
```

Expected: `Test run with 5 tests in 0 suites passed` (4 in TodoCoreTests, 1 in SQLiteKitTests). The first build compiles `sqlite3.c`, about 30 seconds.

- [ ] **Step 6: Run on wasm32**

```bash
swift test --swift-sdk swift-6.3.3-RELEASE_wasm 2>&1 | tail -5
```

Expected: the same 5 tests pass under WasmKit. If `swift sdk list` does not show `swift-6.3.3-RELEASE_wasm`, install it first: `swift sdk install https://download.swift.org/swift-6.3.3-release/wasm-sdk/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE_wasm.artifactbundle.tar.gz --checksum cabfa08b73bb8ac783927ecd15fa386e99d0c139c5f232445067bcf58379cae7`.

- [ ] **Step 7: Measure the wasm size once, so the budget in Task 13 is grounded**

```bash
swift build -c release --swift-sdk swift-6.3.3-RELEASE_wasm --product todo 2>&1 | tail -1
gzip -9 -c .build/wasm32-unknown-wasip1/release/todo.wasm | wc -c
```

Expected: about 3.7 MB. Record the number in the PR body.

- [ ] **Step 8: Ignore build products and database files, describe the build in the README**

Append to `.gitignore`:

```
*.sqlite
*.sqlite-wal
*.sqlite-shm
```

Replace the `## Building` section of `README.md` with:

```markdown
## Building

The core is a SwiftPM package built with the swift.org toolchain pinned in `.swift-version` and installed through [swiftly](https://www.swift.org/install/); Xcode only supplies the Apple SDKs.

```sh
swiftly install                      # reads .swift-version
swift build
swift test                           # host
swift test --swift-sdk swift-6.3.3-RELEASE_wasm   # the same suite on wasm32 under WasmKit
swift run todo --help                # command-line demo
```

The WebAssembly SDK is installed once with `swift sdk install <url> --checksum <sha256>`; the URL and checksum are in `.github/workflows/ci.yml`.
```

- [ ] **Step 9: Add the Linux CI job**

`.github/workflows/ci.yml`. One job on every pull request and every push to `main`: install the pinned toolchain through swiftly, install the WebAssembly SDK with its checksum, build, test on the host, test on wasm32. Task 13 adds the size budget step and the macOS job to this file.

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:

env:
  WASM_SDK_URL: https://download.swift.org/swift-6.3.3-release/wasm-sdk/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE_wasm.artifactbundle.tar.gz
  WASM_SDK_SHA256: cabfa08b73bb8ac783927ecd15fa386e99d0c139c5f232445067bcf58379cae7

jobs:
  core:
    name: Build and test on the host and on wasm32
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4

      - name: System packages for the swift.org toolchain
        run: |
          sudo apt-get update
          sudo apt-get install -y binutils git gnupg2 libc6-dev libcurl4-openssl-dev libedit2 libgcc-13-dev libpython3-dev libsqlite3-0 libstdc++-13-dev libxml2-dev libncurses-dev libz3-dev pkg-config tzdata unzip zlib1g-dev

      - name: Cache the toolchain and the WebAssembly SDK
        uses: actions/cache@v4
        with:
          path: |
            ~/.local/share/swiftly
            ~/.swiftpm/swift-sdks
          key: swiftly-${{ runner.os }}-${{ hashFiles('.swift-version') }}-wasm-v1

      - name: Install swiftly and the pinned toolchain
        run: |
          set -eu
          if [ ! -x "$HOME/.local/share/swiftly/bin/swiftly" ]; then
            curl -fsSL -O "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz"
            tar zxf "swiftly-$(uname -m).tar.gz"
            ./swiftly init --quiet-shell-followup --assume-yes --skip-install --no-modify-profile
          fi
          . "$HOME/.local/share/swiftly/env.sh"
          swiftly install
          echo "$HOME/.local/share/swiftly/bin" >> "$GITHUB_PATH"

      - name: Install the WebAssembly SDK
        run: |
          set -eu
          if ! swift sdk list | grep -q swift-6.3.3-RELEASE_wasm; then
            curl -fsSL -o wasm-sdk.tar.gz "$WASM_SDK_URL"
            echo "$WASM_SDK_SHA256  wasm-sdk.tar.gz" | sha256sum -c -
            swift sdk install wasm-sdk.tar.gz
          fi

      - name: Build
        run: swift build

      - name: Test on the host
        run: swift test

      - name: Test on wasm32 under WasmKit
        run: swift test --swift-sdk swift-6.3.3-RELEASE_wasm
```

Push the branch and open the PR; the job must be green before the PR is handed to the owner. If `swiftly install` fails on a missing system package, add the package the log names to the `apt-get install` line. If the first run cannot find `wasmkit`, the SDK toolset needs it on the path: add `echo "$(dirname "$(readlink -f "$(which swift)")")" >> "$GITHUB_PATH"` after the swiftly step, since the toolchain ships `wasmkit` next to `swift`.

- [ ] **Step 10: Commit**

```bash
git add Package.swift Sources Tests .gitignore README.md .github/workflows/ci.yml
git commit -m "feat(core): add the package skeleton with vendored SQLite, wasm32 smoke tests and CI"
```

---

### Task 2: SQLiteKit, a thin typed wrapper over the C API

**Files:**
- Delete: `Sources/SQLiteKit/SQLiteKit.swift`
- Create: `Sources/SQLiteKit/SQLiteError.swift`, `Sources/SQLiteKit/Value.swift`, `Sources/SQLiteKit/Connection.swift`, `Sources/SQLiteKit/Statement.swift`
- Replace: `Tests/SQLiteKitTests/ConnectionTests.swift`

**Interfaces:**
- Consumes: `CSQLite`.
- Produces, used by every `TodoCore` task:
  - `public struct SQLiteError: Error, Equatable, Sendable { let code: Int32; let message: String }`
  - `public enum Value: Equatable, Sendable { case null, integer(Int64), real(Double), text(String), blob([UInt8]) }` with `Value.text(String?)`-style helpers `Value(_ s: String?)`, `Value(_ i: Int64?)`, `Value(_ b: Bool)`, and accessors `int64`, `string`, `isNull`.
  - `public final class Connection` with `static func open(path:pragmas:) throws(SQLiteError) -> Connection`, `static func openInMemory(pragmas:) throws(SQLiteError) -> Connection` (the client's pragmas, none by default), `func execute(_ sql: String) throws(SQLiteError)`, `func run(_ sql: String, _ params: [Value] = []) throws(SQLiteError)`, `func rows(_ sql: String, _ params: [Value] = []) throws(SQLiteError) -> [[Value]]`, `func prepare(_ sql: String) throws(SQLiteError) -> Statement`, `func transaction<T>(_ body: () throws(SQLiteError) -> T) throws(SQLiteError) -> T`, `func userVersion() throws(SQLiteError) -> Int32`, `func setUserVersion(_:) throws(SQLiteError)`, `var lastInsertRowID: Int64`, `var changes: Int64`, `func serialize() throws(SQLiteError) -> [UInt8]`, `func deserialize(_ bytes: [UInt8]) throws(SQLiteError)`.
  - `public final class Statement` with `func bind(_ values: [Value]) throws(SQLiteError)`, `func step() throws(SQLiteError) -> Bool`, `func reset() throws(SQLiteError)`, `func value(at: Int32) -> Value`, `func row() -> [Value]`, `var columnCount: Int32`.

- [ ] **Step 1: Write the failing tests**

`Tests/SQLiteKitTests/ConnectionTests.swift`:

```swift
import Testing
@testable import SQLiteKit

@Test func executesDDLAndReadsRowsBack() throws {
    let db = try Connection.openInMemory(pragmas: Store.pragmas)
    try db.execute("CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT, score REAL, data BLOB)")
    try db.run("INSERT INTO t (name, score, data) VALUES (?, ?, ?)", [.text("a"), .real(1.5), .blob([1, 2, 3])])
    try db.run("INSERT INTO t (name, score, data) VALUES (?, ?, ?)", [.null, .null, .null])
    let rows = try db.rows("SELECT id, name, score, data FROM t ORDER BY id")
    #expect(rows == [
        [.integer(1), .text("a"), .real(1.5), .blob([1, 2, 3])],
        [.integer(2), .null, .null, .null],
    ])
    #expect(db.lastInsertRowID == 2)
}

@Test func reportsErrorsWithCodeAndMessage() throws {
    let db = try Connection.openInMemory()
    var caught: SQLiteError?
    do { try db.execute("SELECT * FROM missing") } catch { caught = error }
    #expect(caught?.code == 1)
    #expect(caught?.message.contains("no such table") == true)
}

@Test func transactionRollsBackOnError() throws {
    let db = try Connection.openInMemory()
    try db.execute("CREATE TABLE t (x INTEGER)")
    var caught: SQLiteError?
    do {
        try db.transaction { () throws(SQLiteError) in
            try db.run("INSERT INTO t VALUES (1)")
            try db.execute("INSERT INTO nowhere VALUES (1)")
        }
    } catch { caught = error }
    #expect(caught != nil)
    #expect(try db.rows("SELECT count(*) FROM t") == [[.integer(0)]])
    let n: Int64 = try db.transaction { () throws(SQLiteError) in
        try db.run("INSERT INTO t VALUES (2)")
        return db.lastInsertRowID
    }
    #expect(n == 1)
    #expect(try db.rows("SELECT x FROM t") == [[.integer(2)]])
}

@Test func statementsBindStepAndReset() throws {
    let db = try Connection.openInMemory()
    try db.execute("CREATE TABLE t (x INTEGER)")
    let insert = try db.prepare("INSERT INTO t VALUES (?)")
    for i in 1...3 {
        try insert.bind([.integer(Int64(i))])
        _ = try insert.step()
        try insert.reset()
    }
    let select = try db.prepare("SELECT x FROM t WHERE x > ? ORDER BY x")
    try select.bind([.integer(1)])
    var seen: [Int64] = []
    while try select.step() { seen.append(select.value(at: 0).int64 ?? -1) }
    #expect(seen == [2, 3])
    #expect(select.columnCount == 1)
}

@Test func userVersionRoundTrips() throws {
    let db = try Connection.openInMemory()
    #expect(try db.userVersion() == 0)
    try db.setUserVersion(7)
    #expect(try db.userVersion() == 7)
}

@Test func serializeAndDeserializeCopyTheDatabase() throws {
    let a = try Connection.openInMemory()
    try a.execute("CREATE TABLE t (x INTEGER); INSERT INTO t VALUES (1), (2), (3);")
    let bytes = try a.serialize()
    #expect(bytes.count > 0)
    let b = try Connection.openInMemory()
    try b.deserialize(bytes)
    #expect(try b.rows("SELECT sum(x) FROM t") == [[.integer(6)]])
    try b.run("INSERT INTO t VALUES (4)")
    #expect(try b.rows("SELECT count(*) FROM t") == [[.integer(4)]])
}

@Test func openFailsForAnUnwritablePath() {
    var caught: SQLiteError?
    do { _ = try Connection.open(path: "/nonexistent-dir/x.sqlite") } catch { caught = error }
    #expect(caught != nil)
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
rm Sources/SQLiteKit/SQLiteKit.swift
swift test --filter SQLiteKitTests 2>&1 | grep -E 'error:' | head -3
```

Expected: compile errors, `cannot find 'Connection' in scope`.

- [ ] **Step 3: Write `SQLiteError.swift` and `Value.swift`**

```swift
// Sources/SQLiteKit/SQLiteError.swift
import CSQLite

public struct SQLiteError: Error, Equatable, Sendable {
    public let code: Int32
    public let message: String

    public init(code: Int32, message: String) {
        self.code = code
        self.message = message
    }

    /// Builds the error for the last failed call on a connection.
    init(handle: OpaquePointer?, code: Int32) {
        self.code = code
        self.message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "sqlite error \(code)"
    }
}
```

```swift
// Sources/SQLiteKit/Value.swift
public enum Value: Equatable, Sendable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob([UInt8])

    public init(_ s: String?) { self = s.map { .text($0) } ?? .null }
    public init(_ i: Int64?) { self = i.map { .integer($0) } ?? .null }
    public init(_ i: Int32?) { self = i.map { .integer(Int64($0)) } ?? .null }
    public init(_ b: Bool) { self = .integer(b ? 1 : 0) }

    public var isNull: Bool { if case .null = self { return true } else { return false } }
    public var int64: Int64? { if case .integer(let v) = self { return v } else { return nil } }
    public var double: Double? { if case .real(let v) = self { return v } else { return nil } }
    public var string: String? { if case .text(let v) = self { return v } else { return nil } }
    public var bytes: [UInt8]? { if case .blob(let v) = self { return v } else { return nil } }
    public var bool: Bool { (int64 ?? 0) != 0 }
}
```

- [ ] **Step 4: Write `Statement.swift`**

```swift
// Sources/SQLiteKit/Statement.swift
import CSQLite

/// `SQLITE_TRANSIENT` is a macro the importer drops; SQLite copies the bound bytes when it sees this sentinel.
let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class Statement {
    let handle: OpaquePointer
    private let db: OpaquePointer

    init(handle: OpaquePointer, db: OpaquePointer) {
        self.handle = handle
        self.db = db
    }

    deinit { sqlite3_finalize(handle) }

    public var columnCount: Int32 { sqlite3_column_count(handle) }

    /// Binds parameters 1...n in order; a shorter array leaves the rest bound to null.
    public func bind(_ values: [Value]) throws(SQLiteError) {
        sqlite3_clear_bindings(handle)
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let rc: Int32
            switch value {
            case .null: rc = sqlite3_bind_null(handle, index)
            case .integer(let v): rc = sqlite3_bind_int64(handle, index, v)
            case .real(let v): rc = sqlite3_bind_double(handle, index, v)
            case .text(let v): rc = sqlite3_bind_text(handle, index, v, -1, sqliteTransient)
            case .blob(let v):
                rc = v.withUnsafeBytes { sqlite3_bind_blob(handle, index, $0.baseAddress, Int32(v.count), sqliteTransient) }
            }
            if rc != SQLITE_OK { throw SQLiteError(handle: db, code: rc) }
        }
    }

    /// Returns true when a row is available, false when the statement is done.
    public func step() throws(SQLiteError) -> Bool {
        let rc = sqlite3_step(handle)
        switch rc {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default: throw SQLiteError(handle: db, code: rc)
        }
    }

    public func reset() throws(SQLiteError) {
        let rc = sqlite3_reset(handle)
        if rc != SQLITE_OK { throw SQLiteError(handle: db, code: rc) }
    }

    public func value(at index: Int32) -> Value {
        switch sqlite3_column_type(handle, index) {
        case SQLITE_INTEGER: return .integer(sqlite3_column_int64(handle, index))
        case SQLITE_FLOAT: return .real(sqlite3_column_double(handle, index))
        case SQLITE_TEXT: return .text(String(cString: sqlite3_column_text(handle, index)))
        case SQLITE_BLOB:
            let count = Int(sqlite3_column_bytes(handle, index))
            guard count > 0, let base = sqlite3_column_blob(handle, index) else { return .blob([]) }
            return .blob([UInt8](UnsafeRawBufferPointer(start: base, count: count)))
        default: return .null
        }
    }

    public func row() -> [Value] { (0..<columnCount).map { value(at: $0) } }
}
```

- [ ] **Step 5: Write `Connection.swift`**

```swift
// Sources/SQLiteKit/Connection.swift
import CSQLite

public final class Connection {
    let handle: OpaquePointer

    private init(handle: OpaquePointer) { self.handle = handle }

    deinit { sqlite3_close_v2(handle) }

    public static func open(path: String, pragmas: [String] = []) throws(SQLiteError) -> Connection {
        try open(name: path, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, pragmas: pragmas)
    }

    public static func openInMemory(pragmas: [String] = []) throws(SQLiteError) -> Connection {
        try open(name: ":memory:", flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_MEMORY, pragmas: pragmas)
    }

    private static func open(name: String, flags: Int32, pragmas: [String]) throws(SQLiteError) -> Connection {
        var raw: OpaquePointer?
        let rc = sqlite3_open_v2(name, &raw, flags, nil)
        guard rc == SQLITE_OK, let raw else {
            let error = SQLiteError(handle: raw, code: rc)
            sqlite3_close_v2(raw)
            throw error
        }
        let connection = Connection(handle: raw)
        for pragma in pragmas {
            do { try connection.execute("PRAGMA \(pragma);") }
            catch { throw SQLiteError(code: error.code, message: "PRAGMA \(pragma): \(error.message)") }
        }
        return connection
    }

    /// Runs one or more statements without parameters.
    public func execute(_ sql: String) throws(SQLiteError) {
        var message: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(handle, sql, nil, nil, &message)
        if rc != SQLITE_OK {
            let text = message.map { String(cString: $0) } ?? "sqlite error \(rc)"
            sqlite3_free(message)
            throw SQLiteError(code: rc, message: text)
        }
    }

    public func prepare(_ sql: String) throws(SQLiteError) -> Statement {
        var raw: OpaquePointer?
        let rc = sqlite3_prepare_v2(handle, sql, -1, &raw, nil)
        guard rc == SQLITE_OK, let raw else { throw SQLiteError(handle: handle, code: rc) }
        return Statement(handle: raw, db: handle)
    }

    /// Runs one statement with parameters and discards rows.
    public func run(_ sql: String, _ params: [Value] = []) throws(SQLiteError) {
        let statement = try prepare(sql)
        try statement.bind(params)
        while try statement.step() {}
    }

    /// Runs one statement with parameters and returns every row.
    public func rows(_ sql: String, _ params: [Value] = []) throws(SQLiteError) -> [[Value]] {
        let statement = try prepare(sql)
        try statement.bind(params)
        var result: [[Value]] = []
        while try statement.step() { result.append(statement.row()) }
        return result
    }

    /// BEGIN IMMEDIATE ... COMMIT, with ROLLBACK if the body or the commit throws.
    public func transaction<T>(_ body: () throws(SQLiteError) -> T) throws(SQLiteError) -> T {
        try execute("BEGIN IMMEDIATE")
        let result: T
        do {
            result = try body()
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
        do {
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
        return result
    }

    public func userVersion() throws(SQLiteError) -> Int32 {
        Int32(try rows("PRAGMA user_version").first?.first?.int64 ?? 0)
    }

    public func setUserVersion(_ version: Int32) throws(SQLiteError) {
        try execute("PRAGMA user_version = \(version)")
    }

    public var lastInsertRowID: Int64 { sqlite3_last_insert_rowid(handle) }
    public var changes: Int64 { Int64(sqlite3_changes64(handle)) }

    /// A copy of the whole database as bytes (`sqlite3_serialize`).
    public func serialize() throws(SQLiteError) -> [UInt8] {
        var size: sqlite3_int64 = 0
        guard let bytes = sqlite3_serialize(handle, "main", &size, 0) else {
            throw SQLiteError(code: SQLITE_NOMEM, message: "sqlite3_serialize returned NULL")
        }
        defer { sqlite3_free(bytes) }
        return [UInt8](UnsafeBufferPointer(start: bytes, count: Int(size)))
    }

    /// Replaces the contents of this connection with a serialized database (`sqlite3_deserialize`).
    public func deserialize(_ bytes: [UInt8]) throws(SQLiteError) {
        let count = bytes.count
        guard let buffer = sqlite3_malloc64(sqlite3_uint64(max(count, 1))) else {
            throw SQLiteError(code: SQLITE_NOMEM, message: "sqlite3_malloc64 failed")
        }
        bytes.withUnsafeBytes { source in
            if let base = source.baseAddress { buffer.copyMemory(from: base, byteCount: count) }
        }
        let flags = UInt32(SQLITE_DESERIALIZE_FREEONCLOSE | SQLITE_DESERIALIZE_RESIZEABLE)
        let rc = sqlite3_deserialize(handle, "main", buffer.assumingMemoryBound(to: UInt8.self), sqlite3_int64(count), sqlite3_int64(count), flags)
        if rc != SQLITE_OK { throw SQLiteError(handle: handle, code: rc) }
    }
}
```

Note on pragmas: `open` sets none of its own. Journal mode, synchrony and foreign keys are the client's policy and arrive as `pragmas`, so a change of policy never reaches into this target (review of PR #27). They run one statement at a time and outside any transaction, which is the only way that works: `journal_mode = WAL` fails inside a transaction and `foreign_keys` is a silent no-op there. On an in-memory database `journal_mode` is accepted and ignored, so one list serves both targets.

- [ ] **Step 6: Run the tests**

```bash
swift test --filter SQLiteKitTests 2>&1 | tail -3
swift test --filter SQLiteKitTests --swift-sdk swift-6.3.3-RELEASE_wasm 2>&1 | tail -3
```

Expected: 7 tests pass on both. The unwritable-path test passes on wasm32 too because WASI has no `/nonexistent-dir`.

- [ ] **Step 7: Commit**

```bash
git add Sources/SQLiteKit Tests/SQLiteKitTests
git commit -m "feat(core): add SQLiteKit, a typed wrapper over the vendored SQLite"
```

---

### Task 3: Value types: identifiers, calendar days, hybrid logical clocks, order keys

Four small pure units with exhaustive tests. None of them touches SQLite.

**Files:**
- Delete: `Sources/TodoCore/TodoCore.swift`, `Tests/TodoCoreTests/SmokeTests.swift` (the version pin and the trigram check move to `SQLiteKitTests`; the rest of the smoke checks move into the real code paths from Task 4 on)
- Create: `Sources/TodoCore/Model/EntityID.swift`, `Sources/TodoCore/Model/Day.swift`, `Sources/TodoCore/Model/HLC.swift`, `Sources/TodoCore/Model/Rank.swift`
- Create: `Tests/TodoCoreTests/DayTests.swift`, `Tests/TodoCoreTests/HLCTests.swift`, `Tests/TodoCoreTests/RankTests.swift`, `Tests/TodoCoreTests/EntityIDTests.swift`
- Modify: `Sources/todo/main.swift` (print a `Day` instead of the smoke line)
- Modify: `Tests/SQLiteKitTests/ConnectionTests.swift` (the vendored version pin and the Cyrillic trigram check, which nothing else in the plan asserts)

**Interfaces:**
- Consumes: `UUID` from FoundationEssentials.
- Produces:
  - `public struct EntityID: Hashable, Comparable, Sendable, CustomStringConvertible { public let rawValue: String; public init(_ rawValue: String = UUID().uuidString.lowercased()) }` and `public typealias TaskID = EntityID`, `TagID`, `ViewID`. `EntityID()` mints a fresh identifier and `EntityID(raw)` wraps one that storage or sync already holds, so there is no second way to make one.
  - `public struct Day: Hashable, Comparable, Sendable, CustomStringConvertible { public init(year: Int, month: Int, day: Int); public init(_ iso: String) throws(DayParseError); public var year: Int; public var month: Int; public var day: Int; public func advanced(by: Int) -> Day; public static func - (Day, Day) -> Int }` with `daysSinceEpoch` and its initializer internal: outside the core a day is a year-month-day or an ISO string, and the integer is only how the store binds it. Parsing throws rather than returning `nil`, through `public struct DayParseError: Error, Equatable, Sendable, CustomStringConvertible { public let input: String }`.
  - `public struct HLC: Hashable, Comparable, Sendable { public static let maxCounter: Int32; public let millis: Int64; public let counter: Int32; public init(millis:counter:); public init(raw: Int64); public var raw: Int64 }` and `public final class HybridClock { public init(now: @escaping () -> Int64); public func next() -> HLC; public func observe(_ remote: HLC) }`. `init(millis:counter:)` checks both fields; `init(raw:)` checks nothing, because journal rows have to decode as what they sort as.
  - `public enum Rank { public static let initial: String; public static func between(_ lower: String?, _ upper: String?) -> String; public static func isValid(_ key: String) -> Bool }`. `between` is total: a neighbour that is not a valid key, and a pair that does not increase because two devices computed the same rank offline, are read as no neighbour on that side.

- [ ] **Step 1: Write the failing tests**

`Tests/TodoCoreTests/EntityIDTests.swift`:

```swift
import Testing
@testable import TodoCore

@Test func freshIDsAreLowercaseUUIDsAndUnique() {
    let a = EntityID(), b = EntityID()
    #expect(a != b)
    #expect(a.rawValue.count == 36)
    #expect(a.rawValue == a.rawValue.lowercased())
    #expect(a.description == a.rawValue)
}

@Test func idsCompareByRawValue() {
    #expect(EntityID("a") < EntityID("b"))
    #expect(EntityID("x") == EntityID("x"))
}
```

`Tests/TodoCoreTests/DayTests.swift`:

```swift
import Testing
@testable import TodoCore

@Test func epochIsDayZero() {
    let d = Day(year: 1970, month: 1, day: 1)
    #expect(d.daysSinceEpoch == 0)
    #expect(d.year == 1970 && d.month == 1 && d.day == 1)
}

@Test func roundTripsKnownDates() {
    let cases: [(Int, Int, Int, Int32)] = [
        (2000, 3, 1, 11017), (2024, 2, 29, 19782), (2026, 9, 11, 20707), (1969, 12, 31, -1), (2100, 2, 28, 47540),
    ]
    for (y, m, d, expected) in cases {
        let day = Day(year: y, month: m, day: d)
        #expect(day.daysSinceEpoch == expected, "\(y)-\(m)-\(d)")
        #expect(day.year == y && day.month == m && day.day == d, "\(expected)")
    }
}

@Test func arithmeticAndOrdering() {
    let a = Day(year: 2026, month: 12, day: 31)
    #expect(a.advanced(by: 1) == Day(year: 2027, month: 1, day: 1))
    #expect(Day(year: 2027, month: 1, day: 1) - a == 1)
    #expect(a < a.advanced(by: 1))
    #expect(Day(year: 2024, month: 2, day: 28).advanced(by: 1) == Day(year: 2024, month: 2, day: 29))
}

@Test func parsesAndPrintsISO() throws {
    #expect(try Day("2026-09-11") == Day(year: 2026, month: 9, day: 11))
    #expect(Day(year: 2026, month: 9, day: 1).description == "2026-09-01")
}

@Test func refusesEverythingThatIsNotAStrictISODay() {
    // The sign cases matter because `Int("+1")` parses: a day has to come back as the string it was read from.
    for bad in ["2026-9-1", "nope", "2026-13-01", "2026-02-30", "+999-01-01", "2026-01-+1", "2026-01-01 ", ""] {
        #expect(throws: DayParseError(input: bad)) { try Day(bad) }
    }
    #expect(DayParseError(input: "nope").description == "not a date: nope, expected YYYY-MM-DD")
}
```

`Tests/TodoCoreTests/HLCTests.swift`:

```swift
import Testing
@testable import TodoCore

@Test func rawEncodingPreservesOrder() {
    let a = HLC(millis: 1_000, counter: 5), b = HLC(millis: 1_000, counter: 6), c = HLC(millis: 1_001, counter: 0)
    #expect(a < b && b < c)
    #expect(HLC(raw: a.raw) == a)
    #expect(a.raw < b.raw && b.raw < c.raw)
}

@Test func nextIsMonotonicEvenWhenTheWallClockStalls() {
    var wall: Int64 = 1_000
    let clock = HybridClock(now: { wall })
    let a = clock.next()
    let b = clock.next()
    #expect(a == HLC(millis: 1_000, counter: 0))
    #expect(b == HLC(millis: 1_000, counter: 1))
    wall = 999
    #expect(clock.next() == HLC(millis: 1_000, counter: 2))
    wall = 2_000
    #expect(clock.next() == HLC(millis: 2_000, counter: 0))
}

@Test func observeJumpsForwardToARemoteClockFromTheFuture() {
    var wall: Int64 = 1_000
    let clock = HybridClock(now: { wall })
    _ = clock.next()
    clock.observe(HLC(millis: 6_000, counter: 3))
    #expect(clock.next() == HLC(millis: 6_000, counter: 4))
    wall = 6_000
    #expect(clock.next() == HLC(millis: 6_000, counter: 5))
    wall = 6_001
    #expect(clock.next() == HLC(millis: 6_001, counter: 0))
}

@Test func observeIgnoresARemoteClockFromThePast() {
    let clock = HybridClock(now: { 5_000 })
    _ = clock.next()
    clock.observe(HLC(millis: 100, counter: 9))
    #expect(clock.next() == HLC(millis: 5_000, counter: 1))
}

@Test func theCounterCeilingBorrowsTheNextMillisecond() {
    // A bulk import inside one millisecond must not abort the process; it may only cost a millisecond.
    let clock = HybridClock(now: { 1_000 })
    for _ in 0...Int(HLC.maxCounter) { _ = clock.next() }
    #expect(clock.next() == HLC(millis: 1_001, counter: 0))
}

@Test func rawDecodesEveryStoredValue() {
    // Journal rows are decoded without validation, so even a value this version would never write reads back
    // as what it sorts as instead of trapping.
    #expect(HLC(raw: -1).raw == -1)
    #expect(HLC(raw: 0) == HLC(millis: 0, counter: 0))
    #expect(HLC(raw: -1) < HLC(raw: 0))
}
```

`Tests/TodoCoreTests/RankTests.swift`:

```swift
import Testing
@testable import TodoCore

@Test func initialKeyAndNeighbours() {
    #expect(Rank.initial == "i")
    #expect(Rank.between(nil, nil) == "i")
    #expect(Rank.between(nil, "i") == "9")
    #expect(Rank.between("i", nil) == "r")
    #expect(Rank.between("9", "i") == "d")
}

@Test func betweenAlwaysSortsStrictlyBetween() {
    var keys = ["i"]
    // Insert 200 keys at random positions and at both ends; the list must stay strictly sorted.
    var seed: UInt64 = 42
    for _ in 0..<200 {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        let position = Int(seed >> 33) % (keys.count + 1)
        let lower = position == 0 ? nil : keys[position - 1]
        let upper = position == keys.count ? nil : keys[position]
        let key = Rank.between(lower, upper)
        if let lower { #expect(lower < key, "\(lower) < \(key)") }
        if let upper { #expect(key < upper, "\(key) < \(upper)") }
        #expect(Rank.isValid(key))
        keys.insert(key, at: position)
    }
    #expect(keys == keys.sorted())
    #expect(Set(keys).count == keys.count)
}

@Test func adjacentKeysGetALongerKeyBetweenThem() {
    let k = Rank.between("a", "b")
    #expect("a" < k && k < "b")
    #expect(k.count == 2)
    let z = Rank.between("z", nil)
    #expect("z" < z)
}

@Test func validityRejectsEmptyTrailingZeroAndForeignCharacters() {
    #expect(Rank.isValid("a0z"))
    #expect(!Rank.isValid(""))
    #expect(!Rank.isValid("a0"))
    #expect(!Rank.isValid("A"))
    #expect(!Rank.isValid("a-b"))
}

@Test func toleratesNeighboursThatAMergeCanProduce() {
    // Equal ranks arise when two devices append to the same list offline; a key outside the alphabet arises
    // from a corrupt row or a newer version. Neither may abort the process.
    for (lower, upper) in [("k", "k"), ("m", "d"), ("k", ""), ("k", "A")] {
        let key = Rank.between(lower, upper)
        #expect(lower < key, "\(lower) < \(key)")
        #expect(Rank.isValid(key))
    }
    let afterBrokenLower = Rank.between("A", "i")
    #expect(afterBrokenLower < "i")
    #expect(Rank.isValid(afterBrokenLower))
}
```

Appended to `Tests/SQLiteKitTests/ConnectionTests.swift`, so that the two checks worth keeping from the smoke tests live in the target that owns the vendored library:

```swift
@Test func theVendoredLibraryIsTheVersionTheRepositoryPins() throws {
    // `Sources/CSQLite/README.md` records the provenance; this is what makes a silent bump visible.
    let db = try Connection.openInMemory()
    #expect(try db.rows("SELECT sqlite_version()").first?.first?.string == "3.53.4")
}

@Test func trigramSearchFindsCyrillicSubstringsOnEveryPlatform() throws {
    // FTS5 with the trigram tokenizer is what the core searches titles with, and wasm32 is the platform the
    // spec listed as unverified, so this runs on every platform CI tests.
    let db = try Connection.openInMemory()
    try db.execute("CREATE VIRTUAL TABLE t USING fts5(title, tokenize='trigram remove_diacritics 1');")
    try db.execute("INSERT INTO t VALUES ('Квартальный отчёт'), ('Купить молоко');")
    func matches(_ needle: String) throws -> Int64 {
        try db.rows("SELECT count(*) FROM t WHERE t MATCH ?", [.text("\"\(needle)\"")]).first?.first?.int64 ?? -1
    }
    #expect(try matches("отч") == 1)
    #expect(try matches("ОТЧ") == 1)
    #expect(try matches("xyz") == 0)
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
rm Sources/TodoCore/TodoCore.swift Tests/TodoCoreTests/SmokeTests.swift
swift test --filter TodoCoreTests 2>&1 | grep -E 'error:' | head -3
```

Expected: `target 'TodoCore' referenced in product 'TodoCore' is empty`, and once the files below exist, `cannot find 'EntityID' in scope` and similar. Replace `Sources/todo/main.swift` with the line `import TodoCore` followed by `print("todo demo, the epoch day is \(Day(year: 1970, month: 1, day: 1)), Int is \(Int.bitWidth)-bit")` so the executable still compiles; the real CLI arrives in Task 12.

- [ ] **Step 3: Write `EntityID.swift`**

```swift
// Sources/TodoCore/Model/EntityID.swift
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Identifier of a task, tag or view: a lowercase UUID string. One type for all three keeps the journal generic.
public struct EntityID: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: String

    /// Without an argument this mints a fresh identifier; with one it wraps what storage or sync already holds.
    public init(_ rawValue: String = UUID().uuidString.lowercased()) { self.rawValue = rawValue }

    public var description: String { rawValue }

    public static func < (lhs: EntityID, rhs: EntityID) -> Bool { lhs.rawValue < rhs.rawValue }
}

public typealias TaskID = EntityID
public typealias TagID = EntityID
public typealias ViewID = EntityID
```

- [ ] **Step 4: Write `Day.swift`**

Uses Howard Hinnant's `days_from_civil` and `civil_from_days`, valid for the proleptic Gregorian calendar; no `Calendar`, no time zone.

```swift
// Sources/TodoCore/Model/Day.swift
/// Why a string is not a calendar day. It carries the input because everything that parses a day — the command
/// line, a filter document, a URL — reports the failure back to a person.
public struct DayParseError: Error, Equatable, Sendable, CustomStringConvertible {
    public let input: String

    public init(input: String) { self.input = input }

    public var description: String { "not a date: \(input), expected YYYY-MM-DD" }
}

/// A calendar day with no time zone, stored as days since 1970-01-01.
///
/// The conversions are Howard Hinnant's `days_from_civil` and `civil_from_days` for the proleptic Gregorian
/// calendar: plain integer arithmetic, no `Calendar` and no time zone, so the same day means the same thing
/// on every platform the core builds for.
public struct Day: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// Internal on purpose: outside the core a day is a year, a month and a day or an ISO string, and this
    /// integer is only how the store binds it to a SQLite column.
    let daysSinceEpoch: Int32

    init(daysSinceEpoch: Int32) { self.daysSinceEpoch = daysSinceEpoch }

    public init(year: Int, month: Int, day: Int) {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = month > 2 ? month - 3 : month + 9
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        daysSinceEpoch = Int32(era * 146097 + doe - 719468)
    }

    /// Parses strict `YYYY-MM-DD`. A string that is not a day is an error rather than a `nil`, so a bad date
    /// from an argument, a file or a sync payload says which string it was instead of vanishing.
    public init(_ iso: String) throws(DayParseError) {
        let parts = iso.split(separator: "-", omittingEmptySubsequences: false)
        // The widths are checked before the arithmetic, because a year of arbitrary length would overflow the
        // day count rather than fail to parse.
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else {
            throw DayParseError(input: iso)
        }
        let candidate = Day(year: y, month: m, day: d)
        // One round trip replaces every field check: `description` prints exactly `YYYY-MM-DD`, so a sign, a
        // month of 13 and a 30th of February all fail to come back as the string that was parsed.
        guard candidate.description == iso else { throw DayParseError(input: iso) }
        self = candidate
    }

    private var civil: (year: Int, month: Int, day: Int) {
        let z = Int(daysSinceEpoch) + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (m <= 2 ? y + 1 : y, m, d)
    }

    public var year: Int { civil.year }
    public var month: Int { civil.month }
    public var day: Int { civil.day }

    /// The day `days` days after this one. Traps if the result leaves the `Int32` day count, which reaches
    /// about 5.8 million years either side of 1970 and so lies past anything a date a person types can produce.
    public func advanced(by days: Int) -> Day { Day(daysSinceEpoch: daysSinceEpoch + Int32(days)) }

    /// Days between two days, positive when the left one is later. On a 32-bit platform, wasm32 included, the
    /// subtraction traps for two days at opposite ends of that same unreachable range.
    public static func - (lhs: Day, rhs: Day) -> Int { Int(lhs.daysSinceEpoch) - Int(rhs.daysSinceEpoch) }

    public static func < (lhs: Day, rhs: Day) -> Bool { lhs.daysSinceEpoch < rhs.daysSinceEpoch }

    /// `YYYY-MM-DD`, defined for the years 0 to 9999. A day outside that range still prints, but what it
    /// prints is not a string `init(_:)` parses back.
    public var description: String {
        let c = civil
        func pad(_ n: Int, _ width: Int) -> String {
            let s = String(n)
            return String(repeating: "0", count: max(0, width - s.count)) + s
        }
        return "\(pad(c.year, 4))-\(pad(c.month, 2))-\(pad(c.day, 2))"
    }
}
```

- [ ] **Step 5: Write `HLC.swift`**

```swift
// Sources/TodoCore/Model/HLC.swift
/// Hybrid logical clock value: wall-clock milliseconds and a counter, packed into one Int64 (48 + 16 bits).
public struct HLC: Hashable, Comparable, Sendable {
    /// The largest counter the 16 bits hold; `HybridClock` borrows the next millisecond rather than pass it.
    public static let maxCounter: Int32 = 65_535

    public let millis: Int64
    public let counter: Int32

    public init(millis: Int64, counter: Int32) {
        precondition(counter >= 0 && counter <= Self.maxCounter, "HLC counter overflow")
        precondition(millis >= 0 && millis < 1 << 47, "HLC milliseconds outside the 48 bits of the encoding")
        self.millis = millis
        self.counter = counter
    }

    /// Decodes what the journal stored, without the checks above: a row written by another version of the app,
    /// or a corrupt one, still has to read back as the value it sorts as instead of aborting the process.
    public init(raw: Int64) {
        millis = raw >> 16
        counter = Int32(raw & 0xFFFF)
    }

    public var raw: Int64 { (millis << 16) | Int64(counter) }

    public static func < (lhs: HLC, rhs: HLC) -> Bool { lhs.raw < rhs.raw }
}

/// Issues clocks that never go backwards on this device and stay ahead of every clock seen from other devices.
public final class HybridClock {
    private let now: () -> Int64
    private var last = HLC(millis: 0, counter: 0)

    public init(now: @escaping () -> Int64) { self.now = now }

    /// The stamp for a local event: strictly greater than every stamp this clock has issued or observed.
    public func next() -> HLC {
        let wall = now()
        if wall > last.millis {
            last = HLC(millis: wall, counter: 0)
        } else if last.counter == HLC.maxCounter {
            // The counter is all that separates stamps inside one millisecond, so when it fills up the clock
            // borrows the next millisecond. Staying ahead of itself is what the journal needs; agreeing with
            // the wall clock to the millisecond is not.
            last = HLC(millis: last.millis + 1, counter: 0)
        } else {
            last = HLC(millis: last.millis, counter: last.counter + 1)
        }
        return last
    }

    /// Records a clock seen from another device. Observing is not an event of its own, so it only raises the
    /// high-water mark and leaves the increment to the next `next()`, which is then the first stamp strictly
    /// above both this device and the remote one. The wall clock joins the maximum so that a clock that later
    /// goes backwards cannot drag a stamp below what this device has already seen.
    public func observe(_ remote: HLC) {
        last = max(last, remote, HLC(millis: now(), counter: 0))
    }
}
```

Why `observe` merges instead of incrementing: observing is not an event of its own, so the first stamp strictly above both clocks is the next `next()`. Written as a maximum it is one line, and the wall clock joins that maximum, so a clock that later goes backwards cannot drag a stamp below what this device has already seen. The counter ceiling is handled in `next()` rather than by the `HLC` initializer, which keeps its precondition: a value outside 16 bits is a programming error, while a clock that runs out of room inside one millisecond is an ordinary bulk import. And a second reason `observe` must not increment: `Store.receive` (Task 11) calls it once per incoming operation, so an increment there would spend one counter tick per received operation and exhaust the 16 bits on a large sync batch.

- [ ] **Step 6: Write `Rank.swift`**

Keys are strings over the alphabet `0-9a-z`, compared byte-wise, never empty and never ending in `0`, so they behave like fractions in (0, 1). `between` walks the common prefix and appends a midpoint digit.

```swift
// Sources/TodoCore/Model/Rank.swift
/// Fractional order keys: `between(a, b)` returns a key strictly between its arguments without renumbering anything.
///
/// Keys are strings over `0-9a-z`, compared byte-wise, never empty and never ending in `0`, so they behave like
/// fractions in (0, 1): `between` walks the common prefix of its neighbours and appends a midpoint digit.
public enum Rank {
    private static let alphabet: [Character] = Array("0123456789abcdefghijklmnopqrstuvwxyz")
    private static let base = alphabet.count

    /// The key for the first item of an empty list.
    public static let initial = "i"

    public static func isValid(_ key: String) -> Bool {
        !key.isEmpty && key.last != "0" && key.allSatisfy { alphabet.contains($0) }
    }

    /// `nil` on either side means "no neighbour": the start or the end of the list.
    ///
    /// Neighbours come out of the database, so they are whatever a merge or another version of the app wrote:
    /// a key this version would never produce, or a pair that does not increase because two devices appended
    /// to the same list offline and computed the same rank. Such a side is read as no neighbour at all, the
    /// way ADR-0003 ignores a merged parent link it cannot use instead of rejecting it.
    public static func between(_ lower: String?, _ upper: String?) -> String {
        let a = lower.flatMap(digits) ?? []
        let b = upper.flatMap(digits).flatMap { a.lexicographicallyPrecedes($0) ? $0 : nil }
        var result: [Int] = []
        var bounded = b != nil
        var i = 0
        while true {
            let x = i < a.count ? a[i] : 0
            // While `bounded` holds, `result` is the common prefix of `a` and `b`, and `a` sorts before `b`,
            // so `b` has a digit at every position `a` has one, and one more when `a` runs out.
            let y = bounded ? b![i] : base
            if y - x >= 2 {
                result.append((x + y) / 2)
                break
            }
            result.append(x)
            if y == x + 1 { bounded = false }
            i += 1
        }
        return String(result.map { alphabet[$0] })
    }

    private static func digits(_ key: String) -> [Int]? {
        guard isValid(key) else { return nil }
        return key.map { alphabet.firstIndex(of: $0)! }
    }
}
```

Why `b![i]` cannot go out of range: while `bounded` holds, `result` equals the common prefix of `a` and `b`, and `a` sorts before `b`, so `b` has a digit at every position `a` has one, and one more when `a` runs out.

- [ ] **Step 7: Run the tests on both platforms**

```bash
swift test 2>&1 | tail -3
swift test --swift-sdk swift-6.3.3-RELEASE_wasm 2>&1 | tail -3
```

Expected: 38 tests pass on both — 18 in `TodoCoreTests` and the 20 of `SQLiteKitTests`, which gained the version pin and the trigram check.

- [ ] **Step 8: Commit**

```bash
git add Sources/TodoCore/Model Sources/todo/main.swift Tests/TodoCoreTests Tests/SQLiteKitTests
git rm -q Sources/TodoCore/TodoCore.swift Tests/TodoCoreTests/SmokeTests.swift 2>/dev/null || true
git commit -m "feat(core): add identifiers, calendar days, hybrid logical clocks and order keys"
```

---

### Task 4: Schema version 1, migrations, opening a store, snapshots

**Files:**
- Create: `Sources/TodoCore/Storage/Schema.swift`, `Sources/TodoCore/Storage/Migrations.swift`, `Sources/TodoCore/Storage/Store.swift`
- Create: `Tests/TodoCoreTests/TestSupport.swift`, `Tests/TodoCoreTests/StoreOpenTests.swift`

**Interfaces:**
- Consumes: `Connection`, `Value`, `SQLiteError` (Task 2); `EntityID`, `HybridClock` (Task 3).
- Produces:
  - `public enum StoreError: Error, Equatable, Sendable { case sqlite(SQLiteError); case notFound(EntityID); case viewNeedsNewerApp(ViewID, kind: String); case invalidFilter(String); case invalid(String) }`
  - `public struct ChangeSet: Equatable, Sendable { public var tasks: Set<TaskID>; public var tags: Set<TagID>; public var views: Set<ViewID>; public var isEmpty: Bool }`
  - `public final class Store { public let deviceID: String; public var onChange: ((ChangeSet) -> Void)?; public static func open(path: String, now: @escaping () -> Int64) throws(StoreError) -> Store; public static func openInMemory(snapshot: [UInt8]? = nil, now: @escaping () -> Int64) throws(StoreError) -> Store; public func snapshot() throws(StoreError) -> [UInt8]; public func schemaVersion() throws(StoreError) -> Int32; public static func systemNow() -> Int64 }` plus internal `static let pragmas: [String]` (the pragmas every store opens with, since `SQLiteKit` sets none), `let db: Connection`, `let clock: HybridClock`, `let now: () -> Int64`, `func meta(_ key: String) throws(StoreError) -> Value`, `func setMeta(_ key: String, _ value: Value) throws(StoreError)`, `func sql<T>(_ body: () throws(SQLiteError) -> T) throws(StoreError) -> T` (wraps `SQLiteError` into `StoreError.sqlite`).
  - `enum Schema { static let version1: String }`, `enum Migrations { static let steps: [(version: Int32, sql: String)]; static func run(on db: Connection) throws(SQLiteError) -> (from: Int32, to: Int32) }`.
  - Two hooks that Task 5 and Task 6 fill in: `func replayUnappliedRows() throws(SQLiteError)` and `func rebuildTreeRows() throws(SQLiteError)`, empty in this task; their `StoreError` wrappers `replayUnapplied()` and `rebuildTree()` are called at the end of `init`.

- [ ] **Step 1: Write the test support and the failing tests**

`Tests/TodoCoreTests/TestSupport.swift`: the `TestClock` and `makeStore` from the file map above, verbatim.

`Tests/TodoCoreTests/StoreOpenTests.swift`:

```swift
import Testing
@testable import TodoCore
@testable import SQLiteKit

@Test func freshStoreIsAtSchemaVersionOneWithAllTables() throws {
    let store = try makeStore()
    #expect(try store.schemaVersion() == 1)
    let names = try store.sql { () throws(SQLiteError) in
        try store.db.rows("SELECT name FROM sqlite_master WHERE type IN ('table', 'index', 'trigger') ORDER BY name").map { $0[0].string ?? "" }
    }
    for expected in ["meta", "tasks", "tags", "task_tags", "views", "view_items", "ops", "field_clocks", "task_tree",
                     "tasks_title_fts", "tasks_notes_fts", "tags_title_fts", "views_title_fts",
                     "tasks_ai", "tasks_au", "tasks_ad", "tags_ai", "tags_au", "tags_ad", "views_ai", "views_au", "views_ad",
                     "tasks_status", "tasks_when", "tasks_deadline", "tasks_parent", "task_tags_tag", "ops_clock", "ops_identity"] {
        #expect(names.contains(expected), expected)
    }
}

@Test func deviceIDIsCreatedOnceAndKept() throws {
    let store = try makeStore()
    #expect(store.deviceID.count == 36)
    let bytes = try store.snapshot()
    let again = try Store.openInMemory(snapshot: bytes, now: TestClock().now)
    #expect(again.deviceID == store.deviceID)
}

@Test func reopeningRunsNoMigrationTwice() throws {
    let store = try makeStore()
    let bytes = try store.snapshot()
    let again = try Store.openInMemory(snapshot: bytes, now: TestClock().now)
    #expect(try again.schemaVersion() == 1)
}

@Test func migrationsAreAppliedInOrderFromAnyVersion() throws {
    let db = try Connection.openInMemory()
    let first = try Migrations.run(on: db)
    #expect(first.from == 0 && first.to == 1)
    let second = try Migrations.run(on: db)
    #expect(second.from == 1 && second.to == 1)
    #expect(Migrations.steps.map(\.version) == Array(1...Int32(Migrations.steps.count)))
}

@Test func fileStoreOpensCreatesAndReopens() throws {
    let path = "/tmp/todo-core-test-\(EntityID().rawValue).sqlite"
    let clock = TestClock()
    let a = try Store.open(path: path, now: clock.now)
    let id = a.deviceID
    let b = try Store.open(path: path, now: clock.now)
    #expect(b.deviceID == id)
}

@Test func reopeningCarriesTheClockPastEveryStampInTheJournal() throws {
    // Issue #32: the high-water mark of the clock lives in the journal, not in the process.
    let store = try makeStore()
    let remote = HLC(millis: 9_000_000_000_000, counter: 7)
    try store.sql { () throws(SQLiteError) in
        try store.db.run("INSERT INTO ops (entity, entity_id, field, value, clock, device) VALUES ('task', 't', 'title', 'x', ?, 'other')",
                         [.integer(remote.raw)])
    }
    let again = try Store.openInMemory(snapshot: try store.snapshot(), now: TestClock().now)
    #expect(again.clock.next() > remote)
}

@Test func metaRoundTrips() throws {
    let store = try makeStore()
    #expect(try store.meta("nothing").isNull)
    try store.setMeta("k", .text("v"))
    #expect(try store.meta("k") == .text("v"))
    try store.setMeta("k", .integer(2))
    #expect(try store.meta("k") == .integer(2))
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
swift test --filter StoreOpenTests 2>&1 | grep -E 'error:' | head -3
```

Expected: `cannot find 'Store' in scope`.

- [ ] **Step 3: Write `Schema.swift`**

Every state table has an explicit `INTEGER PRIMARY KEY` row id, because the FTS5 external-content tables index by row id and SQLite may renumber implicit row ids on `VACUUM`. `notes` is the last column of `tasks` and no list query selects it.

```swift
// Sources/TodoCore/Storage/Schema.swift

enum Schema {
    static let version1 = """
    CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value
    ) WITHOUT ROWID;

    CREATE TABLE tasks (
        rid INTEGER PRIMARY KEY,
        id TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL DEFAULT '',
        status INTEGER NOT NULL DEFAULT 0,
        when_day INTEGER,
        deadline_day INTEGER,
        parent TEXT,
        rank TEXT NOT NULL DEFAULT 'i',
        trashed INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        completed_at INTEGER,
        notes TEXT NOT NULL DEFAULT ''
    );
    CREATE INDEX tasks_status ON tasks(status);
    CREATE INDEX tasks_when ON tasks(when_day);
    CREATE INDEX tasks_deadline ON tasks(deadline_day);
    CREATE INDEX tasks_parent ON tasks(parent, rank);

    CREATE TABLE tags (
        rid INTEGER PRIMARY KEY,
        id TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL DEFAULT '',
        parent TEXT,
        rank TEXT NOT NULL DEFAULT 'i',
        deleted INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE task_tags (
        task_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        present INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (task_id, tag_id)
    ) WITHOUT ROWID;
    CREATE INDEX task_tags_tag ON task_tags(tag_id, task_id) WHERE present = 1;

    CREATE TABLE views (
        rid INTEGER PRIMARY KEY,
        id TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL DEFAULT '',
        parent TEXT,
        rank TEXT NOT NULL DEFAULT 'i',
        filter TEXT,
        sort TEXT NOT NULL DEFAULT '[]',
        group_by TEXT,
        deleted INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE view_items (
        view_id TEXT NOT NULL,
        task_id TEXT NOT NULL,
        present INTEGER NOT NULL DEFAULT 1,
        rank TEXT NOT NULL DEFAULT 'i',
        PRIMARY KEY (view_id, task_id)
    ) WITHOUT ROWID;

    CREATE TABLE ops (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        field TEXT NOT NULL,
        value,
        clock INTEGER NOT NULL,
        device TEXT NOT NULL,
        applied INTEGER NOT NULL DEFAULT 1
    );
    CREATE INDEX ops_clock ON ops(clock, device);
    CREATE UNIQUE INDEX ops_identity ON ops(device, clock, entity, entity_id, field);
    CREATE INDEX ops_unapplied ON ops(applied) WHERE applied = 0;

    CREATE TABLE field_clocks (
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        field TEXT NOT NULL,
        clock INTEGER NOT NULL,
        device TEXT NOT NULL,
        PRIMARY KEY (entity, entity_id, field)
    ) WITHOUT ROWID;

    CREATE TABLE task_tree (
        id TEXT PRIMARY KEY,
        parent TEXT,
        trashed INTEGER NOT NULL DEFAULT 0
    ) WITHOUT ROWID;
    CREATE INDEX task_tree_parent ON task_tree(parent);

    CREATE VIRTUAL TABLE tasks_title_fts USING fts5(title, content='tasks', content_rowid='rid', tokenize='trigram remove_diacritics 1');
    CREATE VIRTUAL TABLE tasks_notes_fts USING fts5(notes, content='tasks', content_rowid='rid', tokenize='unicode61 remove_diacritics 2', prefix='2 3');
    CREATE VIRTUAL TABLE tags_title_fts USING fts5(title, content='tags', content_rowid='rid', tokenize='trigram remove_diacritics 1');
    CREATE VIRTUAL TABLE views_title_fts USING fts5(title, content='views', content_rowid='rid', tokenize='trigram remove_diacritics 1');

    CREATE TRIGGER tasks_ai AFTER INSERT ON tasks BEGIN
        INSERT INTO tasks_title_fts(rowid, title) VALUES (new.rid, new.title);
        INSERT INTO tasks_notes_fts(rowid, notes) VALUES (new.rid, new.notes);
    END;
    CREATE TRIGGER tasks_ad AFTER DELETE ON tasks BEGIN
        INSERT INTO tasks_title_fts(tasks_title_fts, rowid, title) VALUES ('delete', old.rid, old.title);
        INSERT INTO tasks_notes_fts(tasks_notes_fts, rowid, notes) VALUES ('delete', old.rid, old.notes);
    END;
    CREATE TRIGGER tasks_au AFTER UPDATE OF title, notes ON tasks BEGIN
        INSERT INTO tasks_title_fts(tasks_title_fts, rowid, title) VALUES ('delete', old.rid, old.title);
        INSERT INTO tasks_title_fts(rowid, title) VALUES (new.rid, new.title);
        INSERT INTO tasks_notes_fts(tasks_notes_fts, rowid, notes) VALUES ('delete', old.rid, old.notes);
        INSERT INTO tasks_notes_fts(rowid, notes) VALUES (new.rid, new.notes);
    END;

    CREATE TRIGGER tags_ai AFTER INSERT ON tags BEGIN
        INSERT INTO tags_title_fts(rowid, title) VALUES (new.rid, new.title);
    END;
    CREATE TRIGGER tags_ad AFTER DELETE ON tags BEGIN
        INSERT INTO tags_title_fts(tags_title_fts, rowid, title) VALUES ('delete', old.rid, old.title);
    END;
    CREATE TRIGGER tags_au AFTER UPDATE OF title ON tags BEGIN
        INSERT INTO tags_title_fts(tags_title_fts, rowid, title) VALUES ('delete', old.rid, old.title);
        INSERT INTO tags_title_fts(rowid, title) VALUES (new.rid, new.title);
    END;

    CREATE TRIGGER views_ai AFTER INSERT ON views BEGIN
        INSERT INTO views_title_fts(rowid, title) VALUES (new.rid, new.title);
    END;
    CREATE TRIGGER views_ad AFTER DELETE ON views BEGIN
        INSERT INTO views_title_fts(views_title_fts, rowid, title) VALUES ('delete', old.rid, old.title);
    END;
    CREATE TRIGGER views_au AFTER UPDATE OF title ON views BEGIN
        INSERT INTO views_title_fts(views_title_fts, rowid, title) VALUES ('delete', old.rid, old.title);
        INSERT INTO views_title_fts(rowid, title) VALUES (new.rid, new.title);
    END;
    """
}
```

- [ ] **Step 4: Write `Migrations.swift`**

```swift
// Sources/TodoCore/Storage/Migrations.swift
import SQLiteKit

/// Ordered schema steps. A step runs once, inside one transaction with the user_version bump.
enum Migrations {
    static let steps: [(version: Int32, sql: String)] = [
        (1, Schema.version1),
    ]

    /// Applies every step above the current user_version. Returns the versions before and after.
    static func run(on db: Connection) throws(SQLiteError) -> (from: Int32, to: Int32) {
        let from = try db.userVersion()
        var current = from
        for step in steps where step.version > current {
            try db.transaction { () throws(SQLiteError) in
                try db.execute(step.sql)
                try db.setUserVersion(step.version)
            }
            current = step.version
        }
        return (from, current)
    }
}
```

- [ ] **Step 5: Write `Store.swift`**

```swift
// Sources/TodoCore/Storage/Store.swift
import SQLiteKit
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum StoreError: Error, Equatable, Sendable {
    case sqlite(SQLiteError)
    case notFound(EntityID)
    case viewNeedsNewerApp(ViewID, kind: String)
    case invalidFilter(String)
    case invalid(String)
}

/// Which entities a committed transaction touched. UI layers re-query the views they show.
public struct ChangeSet: Equatable, Sendable {
    public var tasks: Set<TaskID> = []
    public var tags: Set<TagID> = []
    public var views: Set<ViewID> = []

    public init() {}

    public var isEmpty: Bool { tasks.isEmpty && tags.isEmpty && views.isEmpty }

    mutating func merge(_ other: ChangeSet) {
        tasks.formUnion(other.tasks)
        tags.formUnion(other.tags)
        views.formUnion(other.views)
    }
}

/// The core's data layer. Synchronous, single-connection, not thread-safe: the platform confines it.
public final class Store {
    public let deviceID: String
    /// Called after every committed transaction that changed something.
    public var onChange: ((ChangeSet) -> Void)?

    let db: Connection
    let now: () -> Int64
    let clock: HybridClock

    /// Milliseconds since 1970-01-01 from the system clock. Under WasmKit this is a fake time; the platform passes a real one.
    public static func systemNow() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    /// How the core opens a database. `SQLiteKit` sets no pragmas of its own, so the policy lives here and
    /// travels with the store. On an in-memory database `journal_mode` is accepted and ignored, so one list
    /// serves the file and the web target alike.
    static let pragmas = ["foreign_keys = OFF", "journal_mode = WAL", "synchronous = NORMAL"]

    public static func open(path: String, now: @escaping () -> Int64) throws(StoreError) -> Store {
        let db: Connection
        do { db = try Connection.open(path: path, pragmas: pragmas) } catch { throw .sqlite(error) }
        return try Store(db: db, now: now)
    }

    public static func openInMemory(snapshot: [UInt8]? = nil, now: @escaping () -> Int64) throws(StoreError) -> Store {
        let db: Connection
        do {
            db = try Connection.openInMemory(pragmas: pragmas)
            if let snapshot { try db.deserialize(snapshot) }
        } catch { throw .sqlite(error) }
        return try Store(db: db, now: now)
    }

    init(db: Connection, now: @escaping () -> Int64) throws(StoreError) {
        self.db = db
        self.now = now
        self.clock = HybridClock(now: now)
        do { _ = try Migrations.run(on: db) } catch { throw .sqlite(error) }
        let stored = try Store.readMeta(db, "device_id").string
        if let stored {
            deviceID = stored
        } else {
            deviceID = EntityID().rawValue
            try Store.writeMeta(db, "device_id", .text(deviceID))
        }
        // The journal holds every stamp this device has issued or seen from another one. Without replaying its
        // maximum, a restart would let a local edit land behind a remote one and lose the last-write-wins
        // comparison in silence (#32). This runs before anything below issues a stamp.
        if let seen = try sql({ () throws(SQLiteError) in try db.rows("SELECT max(clock) FROM ops").first?.first?.int64 }) {
            clock.observe(HLC(raw: seen))
        }
        try seedBuiltInViews()
        try replayUnapplied()
        try rebuildTree()
    }

    /// The whole database as bytes, for the web page to persist.
    public func snapshot() throws(StoreError) -> [UInt8] {
        try sql { () throws(SQLiteError) in try db.serialize() }
    }

    public func schemaVersion() throws(StoreError) -> Int32 {
        try sql { () throws(SQLiteError) in try db.userVersion() }
    }

    // MARK: - Internal plumbing shared by the extensions

    /// Runs SQLiteKit calls and converts their error type.
    func sql<T>(_ body: () throws(SQLiteError) -> T) throws(StoreError) -> T {
        do { return try body() } catch { throw .sqlite(error) }
    }

    func meta(_ key: String) throws(StoreError) -> Value {
        try Store.readMeta(db, key)
    }

    func setMeta(_ key: String, _ value: Value) throws(StoreError) {
        try Store.writeMeta(db, key, value)
    }

    private static func readMeta(_ db: Connection, _ key: String) throws(StoreError) -> Value {
        do { return try db.rows("SELECT value FROM meta WHERE key = ?", [.text(key)]).first?.first ?? .null } catch { throw .sqlite(error) }
    }

    private static func writeMeta(_ db: Connection, _ key: String, _ value: Value) throws(StoreError) {
        do { try db.run("INSERT INTO meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value", [.text(key), value]) } catch { throw .sqlite(error) }
    }

    /// Filled in by Task 9: inserts Inbox, Today, Upcoming, Logbook and Trash with fixed ids and a zero clock.
    func seedBuiltInViews() throws(StoreError) {}

    /// Re-applies journal rows whose field became known after a migration. The body arrives in Task 5.
    func replayUnapplied() throws(StoreError) {
        try sql { () throws(SQLiteError) in
            try db.transaction { () throws(SQLiteError) in try replayUnappliedRows() }
        }
    }

    /// Recomputes task_tree. The body arrives in Task 6.
    func rebuildTree() throws(StoreError) {
        try sql { () throws(SQLiteError) in try rebuildTreeRows() }
    }

    /// Runs inside a transaction opened by the caller. Task 5 fills it in.
    func replayUnappliedRows() throws(SQLiteError) {}

    /// Runs inside a transaction opened by the caller. Task 6 fills it in.
    func rebuildTreeRows() throws(SQLiteError) {}
}
```

- [ ] **Step 6: Run the tests on both platforms**

```bash
swift test --filter StoreOpenTests 2>&1 | tail -3
swift test --filter StoreOpenTests --swift-sdk swift-6.3.3-RELEASE_wasm 2>&1 | tail -3
```

Expected: 6 tests pass on the host. On wasm32 the file-store test needs a writable `/tmp`; SwiftPM's WasmKit runner maps the package directory, so if that test fails with `unable to open database file` change its path to `.build/todo-core-test-<id>.sqlite`, which is inside the mapped directory on both platforms, and keep that path.

- [ ] **Step 7: Commit**

```bash
git add Sources/TodoCore/Storage Tests/TodoCoreTests/TestSupport.swift Tests/TodoCoreTests/StoreOpenTests.swift
git commit -m "feat(core): add schema version 1, migrations and store opening with snapshots"
```

---

### Task 5: Operations, the journal and `apply`

The single write path of ADR-0003. Every later write method builds operations and calls `apply`.

**Files:**
- Create: `Sources/TodoCore/Storage/Operation.swift`, `Sources/TodoCore/Storage/Store+Apply.swift`
- Modify: `Sources/TodoCore/Storage/Store.swift` (replace the empty `replayUnappliedRows`)
- Create: `Tests/TodoCoreTests/ApplyTests.swift`

**Interfaces:**
- Consumes: `Store`, `ChangeSet`, `Store.sql`, `Store.db`, `Store.clock`, `Store.deviceID` (Task 4); `HLC` (Task 3); `Value` (Task 2).
- Produces:
  - `public enum EntityKind: String, Sendable { case task, tag, view, taskTag = "task_tag", viewItem = "view_item" }`
  - `public struct Operation: Equatable, Sendable { public var entity: EntityKind; public var entityID: String; public var field: String; public var value: Value; public var clock: HLC; public var device: String; public init(entity:entityID:field:value:clock:device:); public static func pairID(_: EntityID, _: EntityID) -> String; static func splitPair(_: String) -> (String, String)? }`
  - `enum FieldMap { static func table(_ kind: EntityKind) -> String; static func isKnown(_ kind: EntityKind, _ field: String) -> Bool }`. Journal field names equal column names: for tasks `title notes status when_day deadline_day parent rank trashed deleted created_at completed_at`; tags `title parent rank deleted created_at`; views `title parent rank filter sort group_by deleted created_at`; task_tag `present`; view_item `present rank`.
  - `extension Store { @discardableResult public func apply(_ ops: [Operation]) throws(StoreError) -> ChangeSet; func op(_ kind: EntityKind, _ id: String, _ field: String, _ value: Value, _ stamp: HLC) -> Operation; func journal(_ op: Operation, applied: Bool) throws(SQLiteError); func applyToState(_ op: Operation, changes: inout ChangeSet) throws(SQLiteError) -> Bool }`.

- [ ] **Step 1: Write the failing tests**

`Tests/TodoCoreTests/ApplyTests.swift` (journal counts exclude the `seed` device because Task 9 seeds the built-in views into the journal at every open):

```swift
import Testing
@testable import TodoCore
@testable import SQLiteKit

private func titleAndCreated(_ store: Store, _ id: String) throws(StoreError) -> (String, Int64)? {
    try store.sql { () throws(SQLiteError) in
        try store.db.rows("SELECT title, created_at FROM tasks WHERE id = ?", [.text(id)]).first.map { ($0[0].string ?? "", $0[1].int64 ?? -1) }
    }
}

@Test func applyingCreateOperationsInsertsARowAndReportsTheChange() throws {
    let store = try makeStore()
    var reported: [ChangeSet] = []
    store.onChange = { reported.append($0) }
    let stamp = HLC(millis: 1_000, counter: 0)
    let ops = [
        store.op(.task, "t1", "title", .text("Buy milk"), stamp),
        store.op(.task, "t1", "created_at", .integer(1_000), stamp),
    ]
    let changes = try store.apply(ops)
    #expect(changes.tasks == [TaskID("t1")])
    #expect(reported == [changes])
    let row = try titleAndCreated(store, "t1")
    #expect(row?.0 == "Buy milk" && row?.1 == 1_000)
    let journal = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM ops WHERE device != 'seed'") }
    #expect(journal == [[.integer(2)]])
}

@Test func anOlderClockLosesButStaysInTheJournal() throws {
    let store = try makeStore()
    try store.apply([store.op(.task, "t1", "title", .text("newer"), HLC(millis: 2_000, counter: 0))])
    let changes = try store.apply([store.op(.task, "t1", "title", .text("older"), HLC(millis: 1_000, counter: 0))])
    #expect(changes.isEmpty)
    #expect(try titleAndCreated(store, "t1")?.0 == "newer")
    let count = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM ops WHERE device != 'seed'") }
    #expect(count == [[.integer(2)]])
}

@Test func differentFieldsFromDifferentDevicesBothSurvive() throws {
    let store = try makeStore()
    var a = store.op(.task, "t1", "title", .text("from A"), HLC(millis: 5_000, counter: 0)); a.device = "A"
    var b = store.op(.task, "t1", "when_day", .integer(20_707), HLC(millis: 1_000, counter: 0)); b.device = "B"
    try store.apply([a, b])
    let row = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT title, when_day FROM tasks WHERE id = 't1'") }
    #expect(row == [[.text("from A"), .integer(20_707)]])
}

@Test func equalClocksAreBrokenByDeviceIDInAnyOrder() throws {
    let stamp = HLC(millis: 1_000, counter: 0)
    for order in [["A", "B"], ["B", "A"]] {
        let store = try makeStore()
        for device in order {
            var op = store.op(.task, "t1", "title", .text("from \(device)"), stamp)
            op.device = device
            try store.apply([op])
        }
        #expect(try titleAndCreated(store, "t1")?.0 == "from B")
    }
}

@Test func unknownFieldsAreJournaledUnappliedAndReplayedWhenKnown() throws {
    let store = try makeStore()
    let changes = try store.apply([store.op(.task, "t1", "reminder_minutes", .integer(540), HLC(millis: 1_000, counter: 0))])
    #expect(changes.isEmpty)
    let unapplied = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT field, applied FROM ops WHERE device != 'seed'") }
    #expect(unapplied == [[.text("reminder_minutes"), .integer(0)]])
    #expect(try titleAndCreated(store, "t1") == nil)

    // Simulate a migration that made a field known: rewrite the journal row to a known field and replay.
    try store.sql { () throws(SQLiteError) in try store.db.run("UPDATE ops SET field = 'title', value = 'replayed' WHERE device != 'seed'") }
    try store.replayUnapplied()
    #expect(try titleAndCreated(store, "t1")?.0 == "replayed")
    let applied = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT applied FROM ops WHERE device != 'seed'") }
    #expect(applied == [[.integer(1)]])
}

@Test func theSameOperationTwiceIsJournaledOnce() throws {
    let store = try makeStore()
    let op = store.op(.task, "t1", "title", .text("x"), HLC(millis: 1_000, counter: 0))
    try store.apply([op])
    try store.apply([op])
    let count = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT count(*) FROM ops WHERE device != 'seed'") }
    #expect(count == [[.integer(1)]])
}

@Test func pairEntitiesUpsertTheirRows() throws {
    let store = try makeStore()
    let pair = Operation.pairID(TaskID("t1"), TagID("g1"))
    try store.apply([store.op(.taskTag, pair, "present", .integer(1), HLC(millis: 1_000, counter: 0))])
    var rows = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT task_id, tag_id, present FROM task_tags") }
    #expect(rows == [[.text("t1"), .text("g1"), .integer(1)]])
    let changes = try store.apply([store.op(.taskTag, pair, "present", .integer(0), HLC(millis: 1_001, counter: 0))])
    #expect(changes.tasks == [TaskID("t1")])
    rows = try store.sql { () throws(SQLiteError) in try store.db.rows("SELECT present FROM task_tags") }
    #expect(rows == [[.integer(0)]])
}

@Test func observerIsNotCalledWhenNothingChanged() throws {
    let store = try makeStore()
    try store.apply([store.op(.task, "t1", "title", .text("x"), HLC(millis: 2_000, counter: 0))])
    var calls = 0
    store.onChange = { _ in calls += 1 }
    try store.apply([store.op(.task, "t1", "title", .text("y"), HLC(millis: 1_000, counter: 0))])
    try store.apply([])
    #expect(calls == 0)
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
swift test --filter ApplyTests 2>&1 | grep -E 'error:' | head -3
```

Expected: `value of type 'Store' has no member 'op'`.

- [ ] **Step 3: Write `Operation.swift`**

```swift
// Sources/TodoCore/Storage/Operation.swift
import SQLiteKit

public enum EntityKind: String, Sendable, CaseIterable {
    case task, tag, view
    case taskTag = "task_tag"
    case viewItem = "view_item"
}

/// One field of one entity set to one value at one clock by one device. The unit of the journal and of sync.
public struct Operation: Equatable, Sendable {
    public var entity: EntityKind
    public var entityID: String
    public var field: String
    public var value: Value
    public var clock: HLC
    public var device: String

    public init(entity: EntityKind, entityID: String, field: String, value: Value, clock: HLC, device: String) {
        self.entity = entity
        self.entityID = entityID
        self.field = field
        self.value = value
        self.clock = clock
        self.device = device
    }

    /// Entity id of a pair entity (task_tag, view_item).
    public static func pairID(_ first: EntityID, _ second: EntityID) -> String {
        "\(first.rawValue)/\(second.rawValue)"
    }

    static func splitPair(_ id: String) -> (String, String)? {
        let parts = id.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return (String(parts[0]), String(parts[1]))
    }
}

/// Journal field names are the state column names. A field outside this map is journaled but not applied,
/// which is how an older app keeps operations from a newer one until it migrates.
enum FieldMap {
    private static let known: [EntityKind: Set<String>] = [
        .task: ["title", "notes", "status", "when_day", "deadline_day", "parent", "rank", "trashed", "deleted", "created_at", "completed_at"],
        .tag: ["title", "parent", "rank", "deleted", "created_at"],
        .view: ["title", "parent", "rank", "filter", "sort", "group_by", "deleted", "created_at"],
        .taskTag: ["present"],
        .viewItem: ["present", "rank"],
    ]

    static func table(_ kind: EntityKind) -> String {
        switch kind {
        case .task: return "tasks"
        case .tag: return "tags"
        case .view: return "views"
        case .taskTag: return "task_tags"
        case .viewItem: return "view_items"
        }
    }

    static func isKnown(_ kind: EntityKind, _ field: String) -> Bool {
        known[kind]?.contains(field) ?? false
    }
}
```

- [ ] **Step 4: Write `Store+Apply.swift`**

```swift
// Sources/TodoCore/Storage/Store+Apply.swift
import SQLiteKit

extension Store {
    /// The one write path: journals every operation, applies those that win their field clock,
    /// rebuilds the task tree when a structural field changed, and notifies the observer after commit.
    @discardableResult
    public func apply(_ ops: [Operation]) throws(StoreError) -> ChangeSet {
        guard !ops.isEmpty else { return ChangeSet() }
        let changes = try sql { () throws(SQLiteError) in
            try db.transaction { () throws(SQLiteError) in
                var changes = ChangeSet()
                var treeDirty = false
                for op in ops {
                    let known = FieldMap.isKnown(op.entity, op.field)
                    try journal(op, applied: known)
                    guard known else { continue }
                    if try applyToState(op, changes: &changes), op.entity == .task, Store.treeFields.contains(op.field) {
                        treeDirty = true
                    }
                }
                if treeDirty { try rebuildTreeRows() }
                return changes
            }
        }
        if !changes.isEmpty { onChange?(changes) }
        return changes
    }

    static let treeFields: Set<String> = ["parent", "trashed", "deleted"]

    /// Builds an operation stamped by this device.
    func op(_ kind: EntityKind, _ id: String, _ field: String, _ value: Value, _ stamp: HLC) -> Operation {
        Operation(entity: kind, entityID: id, field: field, value: value, clock: stamp, device: deviceID)
    }

    /// Appends to the journal. The unique index on (device, clock, entity, entity_id, field) drops duplicates.
    func journal(_ op: Operation, applied: Bool) throws(SQLiteError) {
        try db.run(
            "INSERT OR IGNORE INTO ops (entity, entity_id, field, value, clock, device, applied) VALUES (?, ?, ?, ?, ?, ?, ?)",
            [.text(op.entity.rawValue), .text(op.entityID), .text(op.field), op.value, .integer(op.clock.raw), .text(op.device), Value(applied)]
        )
    }

    /// Last write wins per field. Returns true when the operation changed the state.
    func applyToState(_ op: Operation, changes: inout ChangeSet) throws(SQLiteError) -> Bool {
        let key: [Value] = [.text(op.entity.rawValue), .text(op.entityID), .text(op.field)]
        if let existing = try db.rows("SELECT clock, device FROM field_clocks WHERE entity = ? AND entity_id = ? AND field = ?", key).first {
            let current = (existing[0].int64 ?? 0, existing[1].string ?? "")
            if current >= (op.clock.raw, op.device) { return false }
        }
        try db.run(
            "INSERT INTO field_clocks (entity, entity_id, field, clock, device) VALUES (?, ?, ?, ?, ?) ON CONFLICT(entity, entity_id, field) DO UPDATE SET clock = excluded.clock, device = excluded.device",
            key + [.integer(op.clock.raw), .text(op.device)]
        )
        let table = FieldMap.table(op.entity)
        let millis = Value(op.clock.millis)
        switch op.entity {
        case .task, .tag, .view:
            try db.run("INSERT OR IGNORE INTO \(table) (id, created_at, updated_at) VALUES (?, ?, ?)", [.text(op.entityID), millis, millis])
            try db.run("UPDATE \(table) SET \(op.field) = ?, updated_at = max(updated_at, ?) WHERE id = ?", [op.value, millis, .text(op.entityID)])
        case .taskTag:
            guard let (taskID, tagID) = Operation.splitPair(op.entityID) else { return false }
            try db.run("INSERT OR IGNORE INTO task_tags (task_id, tag_id, present) VALUES (?, ?, 0)", [.text(taskID), .text(tagID)])
            try db.run("UPDATE task_tags SET \(op.field) = ? WHERE task_id = ? AND tag_id = ?", [op.value, .text(taskID), .text(tagID)])
        case .viewItem:
            guard let (viewID, taskID) = Operation.splitPair(op.entityID) else { return false }
            try db.run("INSERT OR IGNORE INTO view_items (view_id, task_id, present) VALUES (?, ?, 0)", [.text(viewID), .text(taskID)])
            try db.run("UPDATE view_items SET \(op.field) = ? WHERE view_id = ? AND task_id = ?", [op.value, .text(viewID), .text(taskID)])
        }
        switch op.entity {
        case .task: changes.tasks.insert(TaskID(op.entityID))
        case .tag: changes.tags.insert(TagID(op.entityID))
        case .view: changes.views.insert(ViewID(op.entityID))
        case .taskTag: changes.tasks.insert(TaskID(Operation.splitPair(op.entityID)!.0))
        case .viewItem:
            let pair = Operation.splitPair(op.entityID)!
            changes.views.insert(ViewID(pair.0))
            changes.tasks.insert(TaskID(pair.1))
        }
        return true
    }
}
```

The column name in `UPDATE ... SET \(op.field)` is safe because `FieldMap.isKnown` whitelisted it before `applyToState` runs; `replayUnappliedRows` checks the same.

- [ ] **Step 5: Replace `replayUnappliedRows` in `Store.swift`**

```swift
    /// Runs inside a transaction opened by the caller: applies journal rows whose field is known now.
    func replayUnappliedRows() throws(SQLiteError) {
        let rows = try db.rows("SELECT seq, entity, entity_id, field, value, clock, device FROM ops WHERE applied = 0 ORDER BY clock, device, seq")
        var changes = ChangeSet()
        var treeDirty = false
        for row in rows {
            guard let kind = EntityKind(rawValue: row[1].string ?? ""), let field = row[3].string, FieldMap.isKnown(kind, field) else { continue }
            let op = Operation(entity: kind, entityID: row[2].string ?? "", field: field, value: row[4], clock: HLC(raw: row[5].int64 ?? 0), device: row[6].string ?? "")
            if try applyToState(op, changes: &changes), kind == .task, Store.treeFields.contains(field) { treeDirty = true }
            try db.run("UPDATE ops SET applied = 1 WHERE seq = ?", [row[0]])
        }
        if treeDirty { try rebuildTreeRows() }
    }
```

- [ ] **Step 6: Run the tests on both platforms**

```bash
swift test --filter ApplyTests 2>&1 | tail -3
swift test --filter ApplyTests --swift-sdk swift-6.3.3-RELEASE_wasm 2>&1 | tail -3
```

Expected: 8 tests pass on both.

- [ ] **Step 7: Commit**

```bash
git add Sources/TodoCore/Storage Tests/TodoCoreTests/ApplyTests.swift
git commit -m "feat(core): add the operation journal and last-write-wins apply"
```

---

### Task 6: The task tree: effective parent and inherited trash

**Files:**
- Create: `Sources/TodoCore/Model/TreeRules.swift`
- Create: `Sources/TodoCore/Storage/Store+Tree.swift`
- Modify: `Sources/TodoCore/Storage/Store.swift` (remove the empty `rebuildTreeRows`)
- Create: `Tests/TodoCoreTests/TreeTests.swift`

**Interfaces:**
- Consumes: `Store.apply`, `Store.op` (Task 5).
- Produces:
  - `enum TreeRules { struct Node { var id: String; var parent: String?; var deleted: Bool }; static func effectiveParents(_ nodes: [Node]) -> [String: String?] }`: a parent link is ignored (nil) when the parent is missing, deleted, or the walk up from it returns to the node. Shared by tasks, tags (Task 7) and views (Task 9).
  - `extension Store { func rebuildTreeRows() throws(SQLiteError) }` filling `task_tree(id, parent, trashed)` for every non-deleted task.

- [ ] **Step 1: Write the failing tests**

`Tests/TodoCoreTests/TreeTests.swift`:

```swift
import Testing
@testable import TodoCore
@testable import SQLiteKit

private func tree(_ store: Store) throws(StoreError) -> [String: (parent: String?, trashed: Bool)] {
    try store.sql { () throws(SQLiteError) in
        var result: [String: (String?, Bool)] = [:]
        for row in try store.db.rows("SELECT id, parent, trashed FROM task_tree") { result[row[0].string!] = (row[1].string, row[2].bool) }
        return result
    }
}

private func setup(_ store: Store, _ rows: [(id: String, parent: String?, trashed: Bool, deleted: Bool)]) throws(StoreError) {
    var ops: [Operation] = []
    for (i, r) in rows.enumerated() {
        let stamp = HLC(millis: 1_000 + Int64(i), counter: 0)
        ops.append(store.op(.task, r.id, "parent", Value(r.parent), stamp))
        ops.append(store.op(.task, r.id, "trashed", Value(r.trashed), stamp))
        ops.append(store.op(.task, r.id, "deleted", Value(r.deleted), stamp))
    }
    try store.apply(ops)
}

@Test func effectiveParentsIgnoreMissingDeletedAndCircularLinks() {
    let nodes = [
        TreeRules.Node(id: "a", parent: nil, deleted: false),
        TreeRules.Node(id: "b", parent: "a", deleted: false),
        TreeRules.Node(id: "c", parent: "missing", deleted: false),
        TreeRules.Node(id: "d", parent: "gone", deleted: false),
        TreeRules.Node(id: "gone", parent: nil, deleted: true),
        TreeRules.Node(id: "x", parent: "y", deleted: false),
        TreeRules.Node(id: "y", parent: "x", deleted: false),
        TreeRules.Node(id: "z", parent: "x", deleted: false),
    ]
    let parents = TreeRules.effectiveParents(nodes)
    #expect(parents["a"] == .some(nil))
    #expect(parents["b"] == "a")
    #expect(parents["c"] == .some(nil))
    #expect(parents["d"] == .some(nil))
    #expect(parents["gone"] == nil, "deleted nodes are absent")
    #expect(parents["x"] == .some(nil) && parents["y"] == .some(nil), "both members of a cycle show at the root")
    #expect(parents["z"] == "x", "a chain hanging off a cycle keeps its parent")
}

@Test func trashIsInheritedFromAncestors() throws {
    let store = try makeStore()
    try setup(store, [("p", nil, true, false), ("c", "p", false, false), ("g", "c", false, false), ("other", nil, false, false)])
    let t = try tree(store)
    #expect(t["p"]?.trashed == true)
    #expect(t["c"]?.trashed == true && t["c"]?.parent == "p")
    #expect(t["g"]?.trashed == true && t["g"]?.parent == "c")
    #expect(t["other"]?.trashed == false)
}

@Test func deletedTasksLeaveTheTreeAndTheirChildrenMoveToTheRoot() throws {
    let store = try makeStore()
    try setup(store, [("p", nil, false, true), ("c", "p", false, false)])
    let t = try tree(store)
    #expect(t["p"] == nil)
    #expect(t["c"]?.parent == nil)
}

@Test func aCycleAfterAMergePutsItsMembersAtTheRoot() throws {
    let store = try makeStore()
    try setup(store, [("a", "b", false, false), ("b", "a", true, false), ("c", "a", false, false)])
    let t = try tree(store)
    #expect(t["a"]?.parent == nil && t["b"]?.parent == nil)
    #expect(t["c"]?.parent == "a")
    #expect(t["a"]?.trashed == false && t["b"]?.trashed == true && t["c"]?.trashed == false)
}

@Test func treeIsRebuiltOnlyWhenStructuralFieldsChange() throws {
    let store = try makeStore()
    try setup(store, [("a", nil, false, false)])
    try store.apply([store.op(.task, "a", "title", .text("renamed"), HLC(millis: 9_000, counter: 0))])
    #expect(try tree(store)["a"]?.parent == nil)
    try store.apply([store.op(.task, "b", "parent", .text("a"), HLC(millis: 9_001, counter: 0))])
    #expect(try tree(store)["b"]?.parent == "a")
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
swift test --filter TreeTests 2>&1 | grep -E 'error:|failed' | head -3
```

Expected: `cannot find 'TreeRules' in scope`.

- [ ] **Step 3: Write `TreeRules.swift`**

```swift
// Sources/TodoCore/Model/TreeRules.swift

/// The one rule for parent links after a merge (spec, "Parent links"): a link to a missing or deleted parent,
/// or a link that closes a cycle, is ignored when reading, and the item shows at the root.
enum TreeRules {
    struct Node {
        var id: String
        var parent: String?
        var deleted: Bool
    }

    /// Effective parent for every non-deleted node. The result contains only non-deleted ids; a value of
    /// `.some(nil)` means "at the root". The returned links form a forest.
    static func effectiveParents(_ nodes: [Node]) -> [String: String?] {
        var byID: [String: Node] = [:]
        for node in nodes { byID[node.id] = node }
        var result: [String: String?] = [:]
        for node in nodes where !node.deleted {
            var effective: String? = nil
            if let parent = node.parent, let parentNode = byID[parent], !parentNode.deleted {
                var cursor: String? = parent
                var visited: Set<String> = []
                var circular = false
                while let current = cursor, let currentNode = byID[current], !currentNode.deleted {
                    if current == node.id { circular = true; break }
                    if !visited.insert(current).inserted { break }
                    cursor = currentNode.parent
                }
                effective = circular ? nil : parent
            }
            result[node.id] = effective
        }
        return result
    }
}
```

- [ ] **Step 4: Write `Store+Tree.swift` and remove the stub from `Store.swift`**

```swift
// Sources/TodoCore/Storage/Store+Tree.swift
import SQLiteKit

extension Store {
    /// Runs inside a transaction opened by the caller. Recomputes task_tree for every non-deleted task.
    /// Cost is one pass over the tasks table; it runs only when parent, trashed or deleted changed.
    func rebuildTreeRows() throws(SQLiteError) {
        var nodes: [TreeRules.Node] = []
        var ownTrashed: [String: Bool] = [:]
        for row in try db.rows("SELECT id, parent, trashed, deleted FROM tasks") {
            let id = row[0].string ?? ""
            nodes.append(TreeRules.Node(id: id, parent: row[1].string, deleted: row[3].bool))
            ownTrashed[id] = row[2].bool
        }
        let parents = TreeRules.effectiveParents(nodes)
        var inherited: [String: Bool] = [:]
        func trashed(_ id: String) -> Bool {
            if let known = inherited[id] { return known }
            let parent = parents[id] ?? nil
            let value = (ownTrashed[id] ?? false) || (parent.map(trashed) ?? false)
            inherited[id] = value
            return value
        }
        try db.run("DELETE FROM task_tree")
        let insert = try db.prepare("INSERT INTO task_tree (id, parent, trashed) VALUES (?, ?, ?)")
        for id in parents.keys.sorted() {
            try insert.bind([.text(id), Value(parents[id] ?? nil), Value(trashed(id))])
            _ = try insert.step()
            try insert.reset()
        }
    }
}
```

Delete the empty `rebuildTreeRows` stub from `Store.swift`.

- [ ] **Step 5: Run the tests on both platforms**

```bash
swift test --filter TreeTests 2>&1 | tail -3
swift test --filter TreeTests --swift-sdk swift-6.3.3-RELEASE_wasm 2>&1 | tail -3
```

Expected: 5 tests pass on both.

- [ ] **Step 6: Commit**

```bash
git add Sources/TodoCore Tests/TodoCoreTests/TreeTests.swift
git commit -m "feat(core): derive effective parent and inherited trash into task_tree"
```

---

### Task 7: Tasks and tags: write API and reads

**Files:**
- Create: `Sources/TodoCore/Model/Entities.swift` (the `Task`, `TaskStatus`, `Tag`, `Placement` types; `View` and its friends join in Task 9)
- Create: `Sources/TodoCore/Storage/Store+Tasks.swift`, `Sources/TodoCore/Storage/Store+Tags.swift`
- Create: `Tests/TodoCoreTests/TaskTests.swift`, `Tests/TodoCoreTests/TagTests.swift`

**Interfaces:**
- Consumes: `apply`, `op` (Task 5); `TreeRules` (Task 6); `Rank`, `Day`, `EntityID` (Task 3).
- Produces:
  - `public enum TaskStatus: Int64, Sendable, CaseIterable { case open = 0, done = 1, canceled = 2 }`
  - `public enum Placement: Sendable, Equatable { case end, start, after(EntityID) }`
  - `public struct Task: Equatable, Sendable { id, title, status, when: Day?, deadline: Day?, parent: TaskID? (effective), rank, tags: Set<TagID>, trashed: Bool (effective), createdAt: Int64, updatedAt: Int64, completedAt: Int64? }`
  - `public struct NewTask: Sendable { title, notes = "", when: Day? = nil, deadline: Day? = nil, parent: TaskID? = nil, tags: Set<TagID> = []; init(title:) }`
  - `public enum TaskChange: Sendable, Equatable { case title(String), notes(String), status(TaskStatus), when(Day?), deadline(Day?) }`
  - `public struct Tag: Equatable, Sendable { id, title, parent: TagID? (effective), rank, createdAt, updatedAt }`
  - `public enum TagChange: Sendable, Equatable { case title(String), parent(TagID?) }`
  - `extension Store`: `createTask(_:at:) -> TaskID`, `update(task:_:)`, `trash(task:)`, `restore(task:)`, `delete(task:)`, `move(task:to:at:)`, `add(tag:to:)`, `remove(tag:from:)`, `task(_:) -> Task?`, `notes(of:) -> String`, `children(of:includeTrashed:) -> [Task]`, `allTasks(includeTrashed:) -> [Task]`, `createTag(title:parent:at:) -> TagID`, `update(tag:_:)`, `delete(tag:)`, `tags() -> [Tag]`, `tag(_:) -> Tag?`; internal `loadTasks(where:_:orderBy:join:limit:)`, `requireTask(_:)`, `siblingRank(table:parentColumnValue:placement:excluding:)`, `static let taskColumns`.

- [ ] **Step 1: Write the failing tests**

`Tests/TodoCoreTests/TaskTests.swift`:

```swift
import Testing
@testable import TodoCore

@Test func createTaskStoresEveryFieldAndDefaults() throws {
    let clock = TestClock()
    let store = try makeStore(clock: clock)
    let id = try store.createTask(NewTask(title: "Write spec"))
    let task = try #require(try store.task(id))
    #expect(task.title == "Write spec")
    #expect(task.status == .open)
    #expect(task.when == nil && task.deadline == nil && task.parent == nil)
    #expect(task.rank == Rank.initial)
    #expect(task.tags.isEmpty && !task.trashed && task.completedAt == nil)
    #expect(task.createdAt > 1_757_500_000_000)
    #expect(try store.notes(of: id) == "")
    #expect(try store.task(TaskID("missing")) == nil)
}

@Test func updateChangesFieldsAndCompletionTracksStatus() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "a"))
    let when = Day(year: 2026, month: 9, day: 12)
    try store.update(task: id, [.title("b"), .notes("# md"), .when(when), .deadline(when.advanced(by: 3)), .status(.done)])
    let task = try #require(try store.task(id))
    #expect(task.title == "b" && task.when == when && task.deadline == when.advanced(by: 3))
    #expect(task.status == .done && task.completedAt != nil)
    #expect(try store.notes(of: id) == "# md")
    try store.update(task: id, [.status(.open), .when(nil)])
    let reopened = try #require(try store.task(id))
    #expect(reopened.status == .open && reopened.completedAt == nil && reopened.when == nil)
}

@Test func childrenAreOrderedByRankAndPlacementWorks() throws {
    let store = try makeStore()
    let project = try store.createTask(NewTask(title: "Project"))
    var child = NewTask(title: "1"); child.parent = project
    let first = try store.createTask(child)
    child.title = "3"
    let third = try store.createTask(child)
    child.title = "2"
    let second = try store.createTask(child, at: .after(first))
    child.title = "0"
    let zero = try store.createTask(child, at: .start)
    #expect(try store.children(of: project).map(\.title) == ["0", "1", "2", "3"])
    #expect(try store.children(of: nil).map(\.id) == [project])
    try store.move(task: third, to: project, at: .start)
    #expect(try store.children(of: project).map(\.title) == ["3", "0", "1", "2"])
    try store.move(task: zero, to: nil, at: .end)
    #expect(try store.children(of: nil).map(\.title) == ["Project", "0"])
    #expect(try store.task(second)?.parent == project)
}

@Test func moveRejectsSelfAndMissingParents() throws {
    let store = try makeStore()
    let a = try store.createTask(NewTask(title: "a"))
    var caught: StoreError?
    do { try store.move(task: a, to: a, at: .end) } catch { caught = error }
    #expect(caught == .invalid("a task cannot be its own parent"))
    do { try store.move(task: a, to: TaskID("nope"), at: .end) } catch { caught = error }
    #expect(caught == .notFound(TaskID("nope")))
}

@Test func trashRestoreAndDeleteFollowTheTree() throws {
    let store = try makeStore()
    let p = try store.createTask(NewTask(title: "p"))
    var c = NewTask(title: "c"); c.parent = p
    let child = try store.createTask(c)
    try store.trash(task: p)
    #expect(try store.task(child)?.trashed == true)
    #expect(try store.children(of: p).isEmpty)
    #expect(try store.allTasks().isEmpty && try store.allTasks(includeTrashed: true).count == 2)
    #expect(try store.children(of: p, includeTrashed: true).count == 1)
    try store.restore(task: p)
    #expect(try store.task(child)?.trashed == false)
    try store.delete(task: p)
    #expect(try store.task(p) == nil)
    #expect(try store.task(child)?.parent == nil, "children of a deleted parent show at the root")
}

@Test func tagsAttachDetachAndHideDeletedTags() throws {
    let store = try makeStore()
    let work = try store.createTag(title: "work")
    let home = try store.createTag(title: "home")
    var new = NewTask(title: "t"); new.tags = [work]
    let id = try store.createTask(new)
    try store.add(tag: home, to: id)
    #expect(try store.task(id)?.tags == [work, home])
    try store.remove(tag: work, from: id)
    #expect(try store.task(id)?.tags == [home])
    try store.delete(tag: home)
    #expect(try store.task(id)?.tags == [])
}

@Test func writesReportChangeSets() throws {
    let store = try makeStore()
    var seen: [ChangeSet] = []
    store.onChange = { seen.append($0) }
    let id = try store.createTask(NewTask(title: "t"))
    try store.update(task: id, [])
    #expect(seen.count == 1 && seen[0].tasks == [id])
}
```

`Tests/TodoCoreTests/TagTests.swift`:

```swift
import Testing
@testable import TodoCore

@Test func tagsNestOrderAndUpdate() throws {
    let store = try makeStore()
    let areas = try store.createTag(title: "Areas")
    let work = try store.createTag(title: "Work", parent: areas)
    let home = try store.createTag(title: "Home", parent: areas, at: .start)
    #expect(try store.tags().map(\.title) == ["Areas", "Home", "Work"])
    #expect(try store.tag(work)?.parent == areas)
    try store.update(tag: work, [.title("Office"), .parent(nil)])
    let office = try #require(try store.tag(work))
    #expect(office.title == "Office" && office.parent == nil)
    #expect(try store.tags().map(\.title) == ["Areas", "Home", "Office"], "Office moved to the root after Areas")
    try store.delete(tag: areas)
    #expect(try store.tags().map(\.title) == ["Home", "Office"], "Home keeps its earlier rank")
    #expect(try store.tag(home)?.parent == nil, "a deleted parent tag leaves its children at the root")
}

@Test func tagCyclesAfterAMergeShowAtTheRoot() throws {
    let store = try makeStore()
    let a = try store.createTag(title: "a")
    let b = try store.createTag(title: "b", parent: a)
    try store.apply([store.op(.tag, a.rawValue, "parent", .text(b.rawValue), HLC(millis: 9_999_999_999_999, counter: 0))])
    let tags = try store.tags()
    #expect(tags.allSatisfy { $0.parent == nil })
    #expect(tags.count == 2)
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
swift test --filter 'TaskTests|TagTests' 2>&1 | grep -E 'error:' | head -3
```

Expected: `cannot find 'NewTask' in scope`.

- [ ] **Step 3: Write `Entities.swift`**

```swift
// Sources/TodoCore/Model/Entities.swift

public enum TaskStatus: Int64, Sendable, CaseIterable {
    case open = 0
    case done = 1
    case canceled = 2
}

/// Where a created or moved item lands among its siblings.
public enum Placement: Sendable, Equatable {
    case end
    case start
    case after(EntityID)
}

/// A task as read from the store. `parent` and `trashed` are effective values from the task tree; notes are read separately.
public struct Task: Equatable, Sendable {
    public var id: TaskID
    public var title: String
    public var status: TaskStatus
    public var when: Day?
    public var deadline: Day?
    public var parent: TaskID?
    public var rank: String
    public var tags: Set<TagID>
    public var trashed: Bool
    public var createdAt: Int64
    public var updatedAt: Int64
    public var completedAt: Int64?
}

public struct NewTask: Sendable {
    public var title: String
    public var notes: String = ""
    public var when: Day? = nil
    public var deadline: Day? = nil
    public var parent: TaskID? = nil
    public var tags: Set<TagID> = []

    public init(title: String) { self.title = title }
}

public enum TaskChange: Sendable, Equatable {
    case title(String)
    case notes(String)
    case status(TaskStatus)
    case when(Day?)
    case deadline(Day?)
}

public struct Tag: Equatable, Sendable {
    public var id: TagID
    public var title: String
    public var parent: TagID?
    public var rank: String
    public var createdAt: Int64
    public var updatedAt: Int64
}

public enum TagChange: Sendable, Equatable {
    case title(String)
    case parent(TagID?)
}
```

- [ ] **Step 4: Write `Store+Tasks.swift`**

```swift
// Sources/TodoCore/Storage/Store+Tasks.swift
import SQLiteKit

extension Store {
    static let taskColumns = "t.id, t.title, t.status, t.when_day, t.deadline_day, tt.parent, t.rank, tt.trashed, t.created_at, t.updated_at, t.completed_at"

    // MARK: Writes

    @discardableResult
    public func createTask(_ new: NewTask, at placement: Placement = .end) throws(StoreError) -> TaskID {
        if let parent = new.parent { try requireTask(parent) }
        let id = TaskID.generate()
        let rank = try siblingRank(table: "tasks", parent: new.parent, placement: placement, excluding: nil)
        let stamp = clock.next()
        let fields: [(String, Value)] = [
            ("title", .text(new.title)), ("notes", .text(new.notes)), ("status", .integer(TaskStatus.open.rawValue)),
            ("when_day", Value(new.when?.daysSinceEpoch)), ("deadline_day", Value(new.deadline?.daysSinceEpoch)),
            ("parent", Value(new.parent?.rawValue)), ("rank", .text(rank)), ("trashed", Value(false)), ("deleted", Value(false)),
            ("created_at", .integer(stamp.millis)),
        ]
        var ops = fields.map { op(.task, id.rawValue, $0.0, $0.1, stamp) }
        for tag in new.tags { ops.append(op(.taskTag, Operation.pairID(id, tag), "present", Value(true), stamp)) }
        try apply(ops)
        return id
    }

    public func update(task id: TaskID, _ changes: [TaskChange]) throws(StoreError) {
        try requireTask(id)
        guard !changes.isEmpty else { return }
        let stamp = clock.next()
        var ops: [Operation] = []
        for change in changes {
            switch change {
            case .title(let title): ops.append(op(.task, id.rawValue, "title", .text(title), stamp))
            case .notes(let notes): ops.append(op(.task, id.rawValue, "notes", .text(notes), stamp))
            case .when(let day): ops.append(op(.task, id.rawValue, "when_day", Value(day?.daysSinceEpoch), stamp))
            case .deadline(let day): ops.append(op(.task, id.rawValue, "deadline_day", Value(day?.daysSinceEpoch), stamp))
            case .status(let status):
                ops.append(op(.task, id.rawValue, "status", .integer(status.rawValue), stamp))
                ops.append(op(.task, id.rawValue, "completed_at", status == .open ? .null : .integer(stamp.millis), stamp))
            }
        }
        try apply(ops)
    }

    public func trash(task id: TaskID) throws(StoreError) { try setFlag(.task, id, "trashed", true) }
    public func restore(task id: TaskID) throws(StoreError) { try setFlag(.task, id, "trashed", false) }
    /// Tombstones the task: the row stays for sync, nothing shows it again.
    public func delete(task id: TaskID) throws(StoreError) { try setFlag(.task, id, "deleted", true) }

    public func move(task id: TaskID, to parent: TaskID?, at placement: Placement) throws(StoreError) {
        try requireTask(id)
        if let parent {
            guard parent != id else { throw .invalid("a task cannot be its own parent") }
            try requireTask(parent)
        }
        let rank = try siblingRank(table: "tasks", parent: parent, placement: placement, excluding: id)
        let stamp = clock.next()
        try apply([op(.task, id.rawValue, "parent", Value(parent?.rawValue), stamp), op(.task, id.rawValue, "rank", .text(rank), stamp)])
    }

    public func add(tag: TagID, to task: TaskID) throws(StoreError) {
        try requireTask(task)
        try apply([op(.taskTag, Operation.pairID(task, tag), "present", Value(true), clock.next())])
    }

    public func remove(tag: TagID, from task: TaskID) throws(StoreError) {
        try apply([op(.taskTag, Operation.pairID(task, tag), "present", Value(false), clock.next())])
    }

    // MARK: Reads

    public func task(_ id: TaskID) throws(StoreError) -> Task? {
        try loadTasks(where: "t.id = ?", [.text(id.rawValue)], orderBy: "t.rank").first
    }

    public func notes(of id: TaskID) throws(StoreError) -> String {
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT notes FROM tasks WHERE id = ? AND deleted = 0", [.text(id.rawValue)]) }
        guard let row = rows.first else { throw .notFound(id) }
        return row[0].string ?? ""
    }

    /// Direct children by effective parent, in rank order. `nil` lists the root.
    public func children(of parent: TaskID?, includeTrashed: Bool = false) throws(StoreError) -> [Task] {
        try loadTasks(where: "tt.parent IS ? AND (? OR tt.trashed = 0)", [Value(parent?.rawValue), Value(includeTrashed)], orderBy: "t.rank, t.id")
    }

    /// Every task that is not deleted, oldest first. The CLI resolves id prefixes over this list.
    public func allTasks(includeTrashed: Bool = false) throws(StoreError) -> [Task] {
        try loadTasks(where: "(? OR tt.trashed = 0)", [Value(includeTrashed)], orderBy: "t.created_at, t.id")
    }

    // MARK: Shared helpers

    func requireTask(_ id: TaskID) throws(StoreError) {
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT 1 FROM tasks WHERE id = ? AND deleted = 0", [.text(id.rawValue)]) }
        if rows.isEmpty { throw .notFound(id) }
    }

    func setFlag(_ kind: EntityKind, _ id: EntityID, _ field: String, _ value: Bool) throws(StoreError) {
        if kind == .task { try requireTask(id) }
        try apply([op(kind, id.rawValue, field, Value(value), clock.next())])
    }

    /// A rank among the siblings of `parent` in `table` ("tasks" uses the effective parent from task_tree, "tags" and "views" the raw column).
    func siblingRank(table: String, parent: EntityID?, placement: Placement, excluding: EntityID?) throws(StoreError) -> String {
        let sql = table == "tasks"
            ? "SELECT t.id, t.rank FROM tasks t JOIN task_tree tt ON tt.id = t.id WHERE tt.parent IS ? AND t.id != ? ORDER BY t.rank, t.id"
            : "SELECT id, rank FROM \(table) WHERE parent IS ? AND deleted = 0 AND id != ? ORDER BY rank, id"
        let siblings = try self.sql { () throws(SQLiteError) in
            try db.rows(sql, [Value(parent?.rawValue), .text(excluding?.rawValue ?? "")]).map { ($0[0].string ?? "", $0[1].string ?? Rank.initial) }
        }
        switch placement {
        case .end: return Rank.between(siblings.last?.1, nil)
        case .start: return Rank.between(nil, siblings.first?.1)
        case .after(let anchor):
            guard let index = siblings.firstIndex(where: { $0.0 == anchor.rawValue }) else { throw .notFound(anchor) }
            let upper = index + 1 < siblings.count ? siblings[index + 1].1 : nil
            return Rank.between(siblings[index].1, upper)
        }
    }

    /// Loads tasks with their tags. `clause` may use aliases `t` (tasks) and `tt` (task_tree); `join` is appended after the tree join.
    func loadTasks(where clause: String, _ params: [Value], orderBy: String, join: String = "", limit: Int? = nil) throws(StoreError) -> [Task] {
        let limitClause = limit.map { " LIMIT \($0)" } ?? ""
        var tasks = try sql { () throws(SQLiteError) in
            try db.rows("SELECT \(Store.taskColumns) FROM tasks t JOIN task_tree tt ON tt.id = t.id \(join) WHERE t.deleted = 0 AND (\(clause)) ORDER BY \(orderBy)\(limitClause)", params).map(Store.task(from:))
        }
        try attachTags(&tasks)
        return tasks
    }

    static func task(from row: [Value]) -> Task {
        Task(
            id: TaskID(row[0].string ?? ""),
            title: row[1].string ?? "",
            status: TaskStatus(rawValue: row[2].int64 ?? 0) ?? .open,
            when: row[3].int64.map { Day(daysSinceEpoch: Int32($0)) },
            deadline: row[4].int64.map { Day(daysSinceEpoch: Int32($0)) },
            parent: row[5].string.map(TaskID.init),
            rank: row[6].string ?? Rank.initial,
            tags: [],
            trashed: row[7].bool,
            createdAt: row[8].int64 ?? 0,
            updatedAt: row[9].int64 ?? 0,
            completedAt: row[10].int64
        )
    }

    private func attachTags(_ tasks: inout [Task]) throws(StoreError) {
        guard !tasks.isEmpty else { return }
        var index: [TaskID: Int] = [:]
        for (i, task) in tasks.enumerated() { index[task.id] = i }
        let ids = Array(index.keys)
        for chunk in stride(from: 0, to: ids.count, by: 500).map({ Array(ids[$0..<min($0 + 500, ids.count)]) }) {
            let placeholders = Array(repeating: "?", count: chunk.count).joined(separator: ", ")
            let rows = try sql { () throws(SQLiteError) in
                try db.rows("SELECT x.task_id, x.tag_id FROM task_tags x JOIN tags g ON g.id = x.tag_id AND g.deleted = 0 WHERE x.present = 1 AND x.task_id IN (\(placeholders))", chunk.map { .text($0.rawValue) })
            }
            for row in rows {
                if let i = index[TaskID(row[0].string ?? "")] { tasks[i].tags.insert(TagID(row[1].string ?? "")) }
            }
        }
    }
}
```

- [ ] **Step 5: Write `Store+Tags.swift`**

```swift
// Sources/TodoCore/Storage/Store+Tags.swift
import SQLiteKit

extension Store {
    @discardableResult
    public func createTag(title: String, parent: TagID? = nil, at placement: Placement = .end) throws(StoreError) -> TagID {
        if let parent { try requireTag(parent) }
        let id = TagID.generate()
        let rank = try siblingRank(table: "tags", parent: parent, placement: placement, excluding: nil)
        let stamp = clock.next()
        try apply([
            op(.tag, id.rawValue, "title", .text(title), stamp),
            op(.tag, id.rawValue, "parent", Value(parent?.rawValue), stamp),
            op(.tag, id.rawValue, "rank", .text(rank), stamp),
            op(.tag, id.rawValue, "deleted", Value(false), stamp),
            op(.tag, id.rawValue, "created_at", .integer(stamp.millis), stamp),
        ])
        return id
    }

    public func update(tag id: TagID, _ changes: [TagChange]) throws(StoreError) {
        try requireTag(id)
        guard !changes.isEmpty else { return }
        let stamp = clock.next()
        var ops: [Operation] = []
        for change in changes {
            switch change {
            case .title(let title): ops.append(op(.tag, id.rawValue, "title", .text(title), stamp))
            case .parent(let parent):
                if let parent {
                    guard parent != id else { throw .invalid("a tag cannot be its own parent") }
                    try requireTag(parent)
                }
                let rank = try siblingRank(table: "tags", parent: parent, placement: .end, excluding: id)
                ops.append(op(.tag, id.rawValue, "parent", Value(parent?.rawValue), stamp))
                ops.append(op(.tag, id.rawValue, "rank", .text(rank), stamp))
            }
        }
        try apply(ops)
    }

    public func delete(tag id: TagID) throws(StoreError) {
        try requireTag(id)
        try setFlag(.tag, id, "deleted", true)
    }

    /// Every tag, parents before children, siblings by rank. `parent` is effective: missing, deleted or circular links read as root.
    public func tags() throws(StoreError) -> [Tag] {
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT id, title, parent, rank, created_at, updated_at, deleted FROM tags") }
        let nodes = rows.map { TreeRules.Node(id: $0[0].string ?? "", parent: $0[2].string, deleted: $0[6].bool) }
        let parents = TreeRules.effectiveParents(nodes)
        var byParent: [String?: [Tag]] = [:]
        for row in rows where !row[6].bool {
            let id = row[0].string ?? ""
            let tag = Tag(id: TagID(id), title: row[1].string ?? "", parent: (parents[id] ?? nil).map(TagID.init), rank: row[3].string ?? Rank.initial, createdAt: row[4].int64 ?? 0, updatedAt: row[5].int64 ?? 0)
            byParent[parents[id] ?? nil, default: []].append(tag)
        }
        var ordered: [Tag] = []
        func visit(_ parent: String?) {
            for tag in (byParent[parent] ?? []).sorted(by: { ($0.rank, $0.id.rawValue) < ($1.rank, $1.id.rawValue) }) {
                ordered.append(tag)
                visit(tag.id.rawValue)
            }
        }
        visit(nil)
        return ordered
    }

    public func tag(_ id: TagID) throws(StoreError) -> Tag? {
        try tags().first { $0.id == id }
    }

    func requireTag(_ id: TagID) throws(StoreError) {
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT 1 FROM tags WHERE id = ? AND deleted = 0", [.text(id.rawValue)]) }
        if rows.isEmpty { throw .notFound(id) }
    }
}
```

`tags()` loads the whole table: tags number in the tens, and the tree order needs every row anyway.

- [ ] **Step 6: Run the tests on both platforms**

```bash
swift test --filter 'TaskTests|TagTests' 2>&1 | tail -3
swift test --filter 'TaskTests|TagTests' --swift-sdk swift-6.3.3-RELEASE_wasm 2>&1 | tail -3
```

Expected: 9 tests pass on both.

- [ ] **Step 7: Commit**

```bash
git add Sources/TodoCore Tests/TodoCoreTests/TaskTests.swift Tests/TodoCoreTests/TagTests.swift
git commit -m "feat(core): add the task and tag write API and reads"
```

---

### Task 8: Filters: model, JSON codec, SQL compiler, sort keys

**Files:**
- Create: `Sources/TodoCore/Model/Filter.swift`, `Sources/TodoCore/Query/FilterCompiler.swift`
- Create: `Tests/TodoCoreTests/FilterTests.swift`

**Interfaces:**
- Consumes: `Day`, `EntityID` (Task 3); `TaskStatus` (Task 7); `Value` (Task 2); `JSONEncoder`, `JSONDecoder` from FoundationEssentials.
- Produces:
  - `public indirect enum Filter: Equatable, Sendable, Codable { case status([TaskStatus]); case when(DayCondition); case deadline(DayCondition); case hasTag(TagID); case parent(TaskID?); case listedIn(ViewID); case trashed(Bool); case and([Filter]); case or([Filter]); case not(Filter) }` with `func json() -> String` and `init(json: String) throws(FilterError)`.
  - `public enum DayCondition: Equatable, Sendable, Codable { case empty; case on(Int); case onOrBefore(Int); case onOrAfter(Int); case between(Int, Int) }` (offsets in days from today, inclusive).
  - `public enum FilterError: Error, Equatable, Sendable { case unsupported(kind: String); case malformed(String) }`
  - `public enum SortField: String, Sendable, Codable, CaseIterable { case when, deadline, title, created, updated, completed, rank }`, `public struct SortKey: Equatable, Sendable, Codable { public var field: SortField; public var descending: Bool; public init(_ field: SortField, descending: Bool = false); public static func json(_ keys: [SortKey]) -> String; public static func parse(json: String) throws(FilterError) -> [SortKey] }`, `public enum GroupBy: String, Sendable, Codable { case whenDay = "when_day", deadlineDay = "deadline_day", tag, parent, status }`.
  - `struct SQLFragment: Equatable { var sql: String; var params: [Value] }`, `enum FilterCompiler { static func whereClause(_ filter: Filter, today: Day) -> SQLFragment; static func compile(_ filter: Filter, today: Day) -> SQLFragment; static func mentionsTrashed(_ filter: Filter) -> Bool; static func orderBy(_ sort: [SortKey]) -> String }`. Fragments use the aliases `t` (tasks) and `tt` (task_tree) that `loadTasks` provides.

JSON shape, one object per node with a `kind` discriminator so an unknown kind is reported by name:

```json
{"kind":"and","filters":[{"kind":"status","statuses":[0]},{"kind":"when","day":{"kind":"on_or_before","offset":0}}]}
{"kind":"has_tag","tag":"<tag id>"}      {"kind":"parent","task":null}      {"kind":"listed_in","view":"<view id>"}
{"kind":"trashed","value":true}          {"kind":"not","filter":{...}}      {"kind":"or","filters":[...]}
```

- [ ] **Step 1: Write the failing tests**

`Tests/TodoCoreTests/FilterTests.swift`:

```swift
import Testing
@testable import TodoCore
@testable import SQLiteKit

private let today = Day(year: 2026, month: 9, day: 11)

@Test func filterRoundTripsThroughJSON() throws {
    let filter: Filter = .and([
        .status([.open, .done]),
        .or([.when(.between(-1, 7)), .deadline(.empty), .not(.hasTag(TagID("g1")))]),
        .parent(nil), .parent(TaskID("p1")), .listedIn(ViewID("v1")), .trashed(false),
        .when(.on(0)), .when(.onOrBefore(0)), .when(.onOrAfter(1)),
    ])
    let json = filter.json()
    #expect(json.hasPrefix("{\"filters\":[{\"kind\":\"status\",\"statuses\":[0,1]}"))
    #expect(try Filter(json: json) == filter)
    #expect(Filter.parent(nil).json() == "{\"kind\":\"parent\",\"task\":null}")
    #expect(Filter.when(.on(0)).json() == "{\"day\":{\"kind\":\"on\",\"offset\":0},\"kind\":\"when\"}")
}

@Test func unknownKindsAreReportedByName() {
    var caught: FilterError?
    do { _ = try Filter(json: "{\"kind\":\"reminder_soon\",\"minutes\":30}") } catch { caught = error }
    #expect(caught == .unsupported(kind: "reminder_soon"))
    do { _ = try Filter(json: "{\"kind\":\"and\",\"filters\":[{\"kind\":\"day\",\"day\":{\"kind\":\"next_week\"}}]}") } catch { caught = error }
    #expect(caught == .unsupported(kind: "day"))
    do { _ = try Filter(json: "{\"kind\":\"when\",\"day\":{\"kind\":\"next_week\"}}") } catch { caught = error }
    #expect(caught == .unsupported(kind: "next_week"))
    do { _ = try Filter(json: "not json") } catch { caught = error }
    if case .malformed = caught {} else { Issue.record("expected malformed, got \(String(describing: caught))") }
}

@Test func sortKeysRoundTripAndRejectUnknownFields() throws {
    let keys = [SortKey(.when), SortKey(.completed, descending: true)]
    let json = SortKey.json(keys)
    #expect(json == "[{\"descending\":false,\"field\":\"when\"},{\"descending\":true,\"field\":\"completed\"}]")
    #expect(try SortKey.parse(json: json) == keys)
    var caught: FilterError?
    do { _ = try SortKey.parse(json: "[{\"field\":\"priority\",\"descending\":false}]") } catch { caught = error }
    #expect(caught == .unsupported(kind: "sort"))
}

@Test func conditionsCompileToParameterisedSQL() {
    let day = Int64(today.daysSinceEpoch)
    #expect(FilterCompiler.compile(.status([.open, .done]), today: today) == SQLFragment(sql: "t.status IN (?, ?)", params: [.integer(0), .integer(1)]))
    #expect(FilterCompiler.compile(.status([]), today: today) == SQLFragment(sql: "0", params: []))
    #expect(FilterCompiler.compile(.when(.empty), today: today) == SQLFragment(sql: "t.when_day IS NULL", params: []))
    #expect(FilterCompiler.compile(.when(.on(2)), today: today) == SQLFragment(sql: "t.when_day = ?", params: [.integer(day + 2)]))
    #expect(FilterCompiler.compile(.deadline(.onOrBefore(0)), today: today) == SQLFragment(sql: "t.deadline_day <= ?", params: [.integer(day)]))
    #expect(FilterCompiler.compile(.when(.onOrAfter(1)), today: today) == SQLFragment(sql: "t.when_day >= ?", params: [.integer(day + 1)]))
    #expect(FilterCompiler.compile(.when(.between(-1, 7)), today: today) == SQLFragment(sql: "t.when_day BETWEEN ? AND ?", params: [.integer(day - 1), .integer(day + 7)]))
    #expect(FilterCompiler.compile(.hasTag(TagID("g")), today: today).sql.hasPrefix("EXISTS (SELECT 1 FROM task_tags x"))
    #expect(FilterCompiler.compile(.parent(nil), today: today) == SQLFragment(sql: "tt.parent IS NULL", params: []))
    #expect(FilterCompiler.compile(.parent(TaskID("p")), today: today) == SQLFragment(sql: "tt.parent = ?", params: [.text("p")]))
    #expect(FilterCompiler.compile(.listedIn(ViewID("v")), today: today).params == [.text("v")])
    #expect(FilterCompiler.compile(.trashed(true), today: today) == SQLFragment(sql: "tt.trashed = ?", params: [.integer(1)]))
    #expect(FilterCompiler.compile(.and([]), today: today).sql == "1")
    #expect(FilterCompiler.compile(.or([]), today: today).sql == "0")
    #expect(FilterCompiler.compile(.not(.trashed(true)), today: today) == SQLFragment(sql: "NOT (tt.trashed = ?)", params: [.integer(1)]))
    let combined = FilterCompiler.compile(.and([.status([.open]), .or([.when(.empty), .deadline(.empty)])]), today: today)
    #expect(combined == SQLFragment(sql: "(t.status IN (?) AND (t.when_day IS NULL OR t.deadline_day IS NULL))", params: [.integer(0)]))
}

@Test func trashIsExcludedUnlessTheFilterMentionsIt() {
    #expect(FilterCompiler.mentionsTrashed(.and([.status([.open]), .not(.trashed(false))])))
    #expect(!FilterCompiler.mentionsTrashed(.or([.status([.open]), .when(.empty)])))
    #expect(FilterCompiler.whereClause(.status([.open]), today: today) == SQLFragment(sql: "(t.status IN (?)) AND tt.trashed = 0", params: [.integer(0)]))
    #expect(FilterCompiler.whereClause(.trashed(true), today: today) == SQLFragment(sql: "tt.trashed = ?", params: [.integer(1)]))
}

@Test func orderByPutsEmptyDaysLastAndEndsWithRankAndID() {
    #expect(FilterCompiler.orderBy([]) == "t.rank, t.id")
    #expect(FilterCompiler.orderBy([SortKey(.when)]) == "(t.when_day IS NULL), t.when_day ASC, t.rank, t.id")
    #expect(FilterCompiler.orderBy([SortKey(.completed, descending: true), SortKey(.title)]) == "(t.completed_at IS NULL), t.completed_at DESC, t.title COLLATE NOCASE ASC, t.rank, t.id")
}

@Test func everyConditionKindProducesValidSQL() throws {
    let store = try makeStore()
    let kinds: [Filter] = [
        .status([.open]), .when(.empty), .when(.on(0)), .deadline(.onOrBefore(1)), .when(.onOrAfter(-1)), .when(.between(0, 3)),
        .hasTag(TagID("g")), .parent(nil), .parent(TaskID("p")), .listedIn(ViewID("v")), .trashed(true),
        .and([.status([.open]), .not(.when(.empty))]), .or([]), .not(.and([])),
    ]
    for filter in kinds {
        let clause = FilterCompiler.whereClause(filter, today: today)
        let rows = try store.sql { () throws(SQLiteError) in
            try store.db.rows("SELECT count(*) FROM tasks t JOIN task_tree tt ON tt.id = t.id WHERE t.deleted = 0 AND (\(clause.sql))", clause.params)
        }
        #expect(rows == [[.integer(0)]], "\(filter)")
    }
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
swift test --filter FilterTests 2>&1 | grep -E 'error:' | head -3
```

Expected: `cannot find type 'Filter' in scope`.

- [ ] **Step 3: Write `Filter.swift`**

```swift
// Sources/TodoCore/Model/Filter.swift
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum FilterError: Error, Equatable, Sendable {
    /// The stored definition uses a condition this version of the app does not know.
    case unsupported(kind: String)
    case malformed(String)
}

/// Offsets are days relative to "today" as passed with the query; bounds are inclusive.
public enum DayCondition: Equatable, Sendable {
    case empty
    case on(Int)
    case onOrBefore(Int)
    case onOrAfter(Int)
    case between(Int, Int)
}

/// A view's filter: a tree of conditions over tasks.
public indirect enum Filter: Equatable, Sendable {
    case status([TaskStatus])
    case when(DayCondition)
    case deadline(DayCondition)
    case hasTag(TagID)
    /// `nil` selects tasks at the root.
    case parent(TaskID?)
    /// Tasks in the manual list of a view; the way a heading holds its tasks.
    case listedIn(ViewID)
    case trashed(Bool)
    case and([Filter])
    case or([Filter])
    case not(Filter)
}

public enum SortField: String, Sendable, Codable, CaseIterable {
    case when, deadline, title, created, updated, completed, rank
}

public struct SortKey: Equatable, Sendable, Codable {
    public var field: SortField
    public var descending: Bool

    public init(_ field: SortField, descending: Bool = false) {
        self.field = field
        self.descending = descending
    }
}

public enum GroupBy: String, Sendable, Codable {
    case whenDay = "when_day"
    case deadlineDay = "deadline_day"
    case tag, parent, status
}

// MARK: - JSON

private func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return encoder
}

private func decode<T: Decodable>(_ type: T.Type, from json: String, unsupportedKind: String) throws(FilterError) -> T {
    do {
        return try JSONDecoder().decode(type, from: Data(json.utf8))
    } catch let error as FilterError {
        throw error
    } catch {
        throw .malformed(unsupportedKind == "filter" ? String(describing: error) : unsupportedKind)
    }
}

extension Filter {
    public func json() -> String {
        String(decoding: try! makeEncoder().encode(self), as: UTF8.self)
    }

    public init(json: String) throws(FilterError) {
        self = try decode(Filter.self, from: json, unsupportedKind: "filter")
    }
}

extension SortKey {
    public static func json(_ keys: [SortKey]) -> String {
        String(decoding: try! makeEncoder().encode(keys), as: UTF8.self)
    }

    /// An unknown sort field reads as `unsupported(kind: "sort")`.
    public static func parse(json: String) throws(FilterError) -> [SortKey] {
        do {
            return try JSONDecoder().decode([SortKey].self, from: Data(json.utf8))
        } catch {
            throw .unsupported(kind: "sort")
        }
    }
}

extension DayCondition: Codable {
    private enum Keys: String, CodingKey { case kind, offset, from, to }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "empty": self = .empty
        case "on": self = .on(try c.decode(Int.self, forKey: .offset))
        case "on_or_before": self = .onOrBefore(try c.decode(Int.self, forKey: .offset))
        case "on_or_after": self = .onOrAfter(try c.decode(Int.self, forKey: .offset))
        case "between": self = .between(try c.decode(Int.self, forKey: .from), try c.decode(Int.self, forKey: .to))
        default: throw FilterError.unsupported(kind: kind)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .empty: try c.encode("empty", forKey: .kind)
        case .on(let n): try c.encode("on", forKey: .kind); try c.encode(n, forKey: .offset)
        case .onOrBefore(let n): try c.encode("on_or_before", forKey: .kind); try c.encode(n, forKey: .offset)
        case .onOrAfter(let n): try c.encode("on_or_after", forKey: .kind); try c.encode(n, forKey: .offset)
        case .between(let a, let b): try c.encode("between", forKey: .kind); try c.encode(a, forKey: .from); try c.encode(b, forKey: .to)
        }
    }
}

extension Filter: Codable {
    private enum Keys: String, CodingKey { case kind, statuses, day, tag, task, view, value, filters, filter }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "status": self = .status(try c.decode([Int64].self, forKey: .statuses).compactMap(TaskStatus.init(rawValue:)))
        case "when": self = .when(try c.decode(DayCondition.self, forKey: .day))
        case "deadline": self = .deadline(try c.decode(DayCondition.self, forKey: .day))
        case "has_tag": self = .hasTag(TagID(try c.decode(String.self, forKey: .tag)))
        case "parent": self = .parent(try c.decodeIfPresent(String.self, forKey: .task).map(TaskID.init))
        case "listed_in": self = .listedIn(ViewID(try c.decode(String.self, forKey: .view)))
        case "trashed": self = .trashed(try c.decode(Bool.self, forKey: .value))
        case "and": self = .and(try c.decode([Filter].self, forKey: .filters))
        case "or": self = .or(try c.decode([Filter].self, forKey: .filters))
        case "not": self = .not(try c.decode(Filter.self, forKey: .filter))
        default: throw FilterError.unsupported(kind: kind)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .status(let statuses): try c.encode("status", forKey: .kind); try c.encode(statuses.map(\.rawValue), forKey: .statuses)
        case .when(let day): try c.encode("when", forKey: .kind); try c.encode(day, forKey: .day)
        case .deadline(let day): try c.encode("deadline", forKey: .kind); try c.encode(day, forKey: .day)
        case .hasTag(let tag): try c.encode("has_tag", forKey: .kind); try c.encode(tag.rawValue, forKey: .tag)
        case .parent(let task): try c.encode("parent", forKey: .kind); try c.encode(task?.rawValue, forKey: .task)
        case .listedIn(let view): try c.encode("listed_in", forKey: .kind); try c.encode(view.rawValue, forKey: .view)
        case .trashed(let flag): try c.encode("trashed", forKey: .kind); try c.encode(flag, forKey: .value)
        case .and(let filters): try c.encode("and", forKey: .kind); try c.encode(filters, forKey: .filters)
        case .or(let filters): try c.encode("or", forKey: .kind); try c.encode(filters, forKey: .filters)
        case .not(let filter): try c.encode("not", forKey: .kind); try c.encode(filter, forKey: .filter)
        }
    }
}
```

`try c.encode(task?.rawValue, forKey: .task)` writes `null` for a missing parent, so `{"kind":"parent","task":null}` and a decoder's `decodeIfPresent` reads it back as `nil`.

- [ ] **Step 4: Write `FilterCompiler.swift`**

```swift
// Sources/TodoCore/Query/FilterCompiler.swift
import SQLiteKit

struct SQLFragment: Equatable {
    var sql: String
    var params: [Value]
}

/// Turns a filter tree into one WHERE fragment over `tasks t JOIN task_tree tt`.
enum FilterCompiler {
    /// The fragment a view uses: the filter, plus `tt.trashed = 0` unless the filter mentions trash itself.
    static func whereClause(_ filter: Filter, today: Day) -> SQLFragment {
        let fragment = compile(filter, today: today)
        guard !mentionsTrashed(filter) else { return fragment }
        return SQLFragment(sql: "(\(fragment.sql)) AND tt.trashed = 0", params: fragment.params)
    }

    static func compile(_ filter: Filter, today: Day) -> SQLFragment {
        switch filter {
        case .status(let statuses):
            guard !statuses.isEmpty else { return SQLFragment(sql: "0", params: []) }
            let marks = Array(repeating: "?", count: statuses.count).joined(separator: ", ")
            return SQLFragment(sql: "t.status IN (\(marks))", params: statuses.map { .integer($0.rawValue) })
        case .when(let condition):
            return day("t.when_day", condition, today)
        case .deadline(let condition):
            return day("t.deadline_day", condition, today)
        case .hasTag(let tag):
            return SQLFragment(
                sql: "EXISTS (SELECT 1 FROM task_tags x JOIN tags g ON g.id = x.tag_id AND g.deleted = 0 WHERE x.task_id = t.id AND x.tag_id = ? AND x.present = 1)",
                params: [.text(tag.rawValue)]
            )
        case .parent(let parent):
            guard let parent else { return SQLFragment(sql: "tt.parent IS NULL", params: []) }
            return SQLFragment(sql: "tt.parent = ?", params: [.text(parent.rawValue)])
        case .listedIn(let view):
            return SQLFragment(sql: "EXISTS (SELECT 1 FROM view_items v WHERE v.view_id = ? AND v.task_id = t.id AND v.present = 1)", params: [.text(view.rawValue)])
        case .trashed(let flag):
            return SQLFragment(sql: "tt.trashed = ?", params: [Value(flag)])
        case .and(let parts):
            return combine(parts, separator: " AND ", empty: "1", today: today)
        case .or(let parts):
            return combine(parts, separator: " OR ", empty: "0", today: today)
        case .not(let inner):
            let f = compile(inner, today: today)
            return SQLFragment(sql: "NOT (\(f.sql))", params: f.params)
        }
    }

    static func mentionsTrashed(_ filter: Filter) -> Bool {
        switch filter {
        case .trashed: return true
        case .and(let parts), .or(let parts): return parts.contains(where: mentionsTrashed)
        case .not(let inner): return mentionsTrashed(inner)
        default: return false
        }
    }

    /// ORDER BY for a view: the requested keys, empty days last, then rank and id for a stable order.
    static func orderBy(_ sort: [SortKey]) -> String {
        var parts: [String] = []
        for key in sort {
            let direction = key.descending ? "DESC" : "ASC"
            switch key.field {
            case .when: parts += ["(t.when_day IS NULL)", "t.when_day \(direction)"]
            case .deadline: parts += ["(t.deadline_day IS NULL)", "t.deadline_day \(direction)"]
            case .completed: parts += ["(t.completed_at IS NULL)", "t.completed_at \(direction)"]
            case .title: parts.append("t.title COLLATE NOCASE \(direction)")
            case .created: parts.append("t.created_at \(direction)")
            case .updated: parts.append("t.updated_at \(direction)")
            case .rank: parts.append("t.rank \(direction)")
            }
        }
        parts += ["t.rank", "t.id"]
        return parts.joined(separator: ", ")
    }

    private static func day(_ column: String, _ condition: DayCondition, _ today: Day) -> SQLFragment {
        func at(_ offset: Int) -> Value { .integer(Int64(today.advanced(by: offset).daysSinceEpoch)) }
        switch condition {
        case .empty: return SQLFragment(sql: "\(column) IS NULL", params: [])
        case .on(let n): return SQLFragment(sql: "\(column) = ?", params: [at(n)])
        case .onOrBefore(let n): return SQLFragment(sql: "\(column) <= ?", params: [at(n)])
        case .onOrAfter(let n): return SQLFragment(sql: "\(column) >= ?", params: [at(n)])
        case .between(let a, let b): return SQLFragment(sql: "\(column) BETWEEN ? AND ?", params: [at(a), at(b)])
        }
    }

    private static func combine(_ parts: [Filter], separator: String, empty: String, today: Day) -> SQLFragment {
        guard !parts.isEmpty else { return SQLFragment(sql: empty, params: []) }
        let compiled = parts.map { compile($0, today: today) }
        return SQLFragment(sql: "(" + compiled.map(\.sql).joined(separator: separator) + ")", params: compiled.flatMap(\.params))
    }
}
```

- [ ] **Step 5: Run the tests on both platforms**

```bash
swift test --filter FilterTests 2>&1 | tail -3
swift test --filter FilterTests --swift-sdk swift-6.3.3-RELEASE_wasm 2>&1 | tail -3
```

Expected: 7 tests pass on both. If the JSON key order differs from the expectation, check that `.sortedKeys` is set; the test pins the exact strings because they are the on-disk and on-the-wire format.

- [ ] **Step 6: Commit**

```bash
git add Sources/TodoCore/Model/Filter.swift Sources/TodoCore/Query/FilterCompiler.swift Tests/TodoCoreTests/FilterTests.swift
git commit -m "feat(core): add the filter model with its JSON format and SQL compiler"
```

---

### Task 9: Views: nesting, built-in views, manual lists, pages with sections and groups

**Files:**
- Modify: `Sources/TodoCore/Model/Entities.swift` (add `View`, `NewView`, `ViewChange`, `BuiltInViews`)
- Create: `Sources/TodoCore/Storage/Store+Views.swift`, `Sources/TodoCore/Query/Store+Query.swift`
- Modify: `Sources/TodoCore/Storage/Store.swift` (replace the empty `seedBuiltInViews`)
- Modify: `docs/specs/core-storage-and-search.md` (Logbook row of the built-in views table, see Step 7)
- Create: `Tests/TodoCoreTests/ViewTests.swift`, `Tests/TodoCoreTests/QueryTests.swift`

**Interfaces:**
- Consumes: `Filter`, `SortKey`, `GroupBy`, `FilterCompiler` (Task 8); `loadTasks`, `siblingRank`, `setFlag`, `Placement` (Task 7); `TreeRules` (Task 6); `apply`, `op` (Task 5).
- Produces:
  - `public struct View: Equatable, Sendable { id, title, parent: ViewID? (effective), rank, filter: Filter? (nil: folder), sort: [SortKey], groupBy: GroupBy?, needsNewerApp: String? (the unsupported kind), createdAt, updatedAt }`
  - `public struct NewView: Sendable { title, parent: ViewID? = nil, filter: Filter? = nil, sort: [SortKey] = [], groupBy: GroupBy? = nil; init(title:) }`
  - `public enum ViewChange: Sendable, Equatable { case title(String), filter(Filter?), sort([SortKey]), groupBy(GroupBy?) }`
  - `public enum BuiltInViews { public static let inbox, today, upcoming, logbook, trash: ViewID; static let definitions: [(id: ViewID, title: String, rank: String, filter: Filter, sort: [SortKey], groupBy: GroupBy?)] }`
  - `extension Store`: `createView(_:at:) -> ViewID`, `update(view:_:)`, `delete(view:)`, `move(view:to:at:)`, `views() -> [View]` (tree order), `view(_:) -> View?`, `children(ofView:) -> [View]`, `pin(task:in:at:)`, `unpin(task:from:)`, `manualList(of:) -> [TaskID]`.
  - `public struct ViewPage: Equatable, Sendable { view: View; sections: [Section] }`, `public struct Section: Equatable, Sendable { view: View? (nil: the view's own remainder); groups: [TaskGroup] }`, `public struct TaskGroup: Equatable, Sendable { key: GroupKey?; tasks: [Task] }`, `public enum GroupKey: Hashable, Sendable { case day(Day?), tag(TagID?), parent(TaskID?), status(TaskStatus) }`.
  - `extension Store`: `tasks(in: ViewID, today: Day) -> [Task]` (flat, manual order first), `page(of: ViewID, today: Day) -> ViewPage`, internal `tasks(matching: View, today:)`, `group(_:by:)`.

Built-in definitions (fixed ids, seeded with clock zero by device `seed`, so any user edit wins and every device creates identical journal rows):

| View | Id suffix | Rank | Filter | Sort | Group |
| ---- | --------- | ---- | ------ | ---- | ----- |
| Inbox | `…0001` | `1` | open, `when` empty, parent empty | rank | none |
| Today | `…0002` | `2` | open, `when` on or before today | when | none |
| Upcoming | `…0003` | `3` | open, `when` on or after tomorrow | when | when day |
| Logbook | `…0004` | `4` | done or canceled | completed, newest first | none |
| Trash | `…0005` | `5` | trashed | updated, newest first | none |

- [ ] **Step 1: Write the failing tests**

`Tests/TodoCoreTests/ViewTests.swift`:

```swift
import Testing
@testable import TodoCore
@testable import SQLiteKit

@Test func builtInViewsAreSeededOnceAndUserEditsSurviveReopen() throws {
    let clock = TestClock()
    let store = try makeStore(clock: clock)
    #expect(try store.views().map(\.title) == ["Inbox", "Today", "Upcoming", "Logbook", "Trash"])
    #expect(try store.view(BuiltInViews.today)?.filter == .and([.status([.open]), .when(.onOrBefore(0))]))
    try store.update(view: BuiltInViews.today, [.title("Сегодня")])
    try store.delete(view: BuiltInViews.trash)
    let reopened = try Store.openInMemory(snapshot: try store.snapshot(), now: clock.now)
    #expect(try reopened.views().map(\.title) == ["Inbox", "Сегодня", "Upcoming", "Logbook"])
    let seeded = try reopened.sql { () throws(SQLiteError) in try reopened.db.rows("SELECT count(*) FROM ops WHERE device = 'seed'") }
    #expect(seeded == [[.integer(40)]], "eight fields for five views, journaled once")
}

@Test func viewsNestMoveAndReadBackTheirDefinition() throws {
    let store = try makeStore()
    let folder = try store.createView(NewView(title: "Work"))
    var new = NewView(title: "Reviews"); new.parent = folder
    new.filter = .hasTag(TagID("g1")); new.sort = [SortKey(.deadline)]; new.groupBy = .deadlineDay
    let reviews = try store.createView(new)
    let inside = try #require(try store.view(reviews))
    #expect(inside.parent == folder && inside.filter == .hasTag(TagID("g1")) && inside.sort == [SortKey(.deadline)] && inside.groupBy == .deadlineDay)
    #expect(try store.view(folder)?.filter == nil, "a view without a filter is a folder")
    #expect(try store.children(ofView: folder).map(\.id) == [reviews])
    try store.move(view: folder, to: nil, at: .start)
    #expect(try store.views().map(\.title).prefix(2) == ["Work", "Reviews"])
    try store.update(view: reviews, [.filter(nil), .sort([]), .groupBy(nil), .title("Folder now")])
    let changed = try #require(try store.view(reviews))
    #expect(changed.filter == nil && changed.sort.isEmpty && changed.groupBy == nil && changed.title == "Folder now")
    try store.delete(view: folder)
    #expect(try store.view(reviews)?.parent == nil)
}

@Test func aViewFromANewerAppIsReportedNotEvaluated() throws {
    let store = try makeStore()
    let id = ViewID("v-new")
    try store.apply([
        store.op(.view, id.rawValue, "title", .text("Soon"), HLC(millis: 5, counter: 0)),
        store.op(.view, id.rawValue, "filter", .text("{\"kind\":\"reminder_soon\"}"), HLC(millis: 5, counter: 0)),
    ])
    #expect(try store.view(id)?.needsNewerApp == "reminder_soon")
    var caught: StoreError?
    do { _ = try store.tasks(in: id, today: Day(daysSinceEpoch: 0)) } catch { caught = error }
    #expect(caught == .viewNeedsNewerApp(id, kind: "reminder_soon"))
}

@Test func manualListsPinAndOrderTasks() throws {
    let store = try makeStore()
    let a = try store.createTask(NewTask(title: "a"))
    let b = try store.createTask(NewTask(title: "b"))
    let c = try store.createTask(NewTask(title: "c"))
    let heading = try store.createView(NewView(title: "H"))
    try store.pin(task: a, in: heading)
    try store.pin(task: c, in: heading)
    try store.pin(task: b, in: heading, at: .after(a))
    #expect(try store.manualList(of: heading) == [a, b, c])
    try store.unpin(task: b, from: heading)
    #expect(try store.manualList(of: heading) == [a, c])
    try store.pin(task: b, in: heading, at: .start)
    #expect(try store.manualList(of: heading) == [b, a, c])
}
```

`Tests/TodoCoreTests/QueryTests.swift`:

```swift
import Testing
@testable import TodoCore

private let today = Day(year: 2026, month: 9, day: 11)

/// Inbox: "loose", "later" (dated) is not in Inbox. Today: "due", "overdue". Upcoming: "later". Logbook: "done". Trash: "binned".
private func seeded(_ store: Store) throws -> [String: TaskID] {
    var ids: [String: TaskID] = [:]
    ids["loose"] = try store.createTask(NewTask(title: "loose"))
    var t = NewTask(title: "due"); t.when = today; ids["due"] = try store.createTask(t)
    t = NewTask(title: "overdue"); t.when = today.advanced(by: -3); ids["overdue"] = try store.createTask(t)
    t = NewTask(title: "later"); t.when = today.advanced(by: 2); ids["later"] = try store.createTask(t)
    t = NewTask(title: "much later"); t.when = today.advanced(by: 9); ids["much later"] = try store.createTask(t)
    ids["done"] = try store.createTask(NewTask(title: "done")); try store.update(task: ids["done"]!, [.status(.done)])
    ids["binned"] = try store.createTask(NewTask(title: "binned")); try store.trash(task: ids["binned"]!)
    return ids
}

@Test func builtInViewsSelectTheExpectedTasks() throws {
    let store = try makeStore()
    _ = try seeded(store)
    func titles(_ view: ViewID) throws -> [String] { try store.tasks(in: view, today: today).map(\.title) }
    #expect(try titles(BuiltInViews.inbox) == ["loose"])
    #expect(try titles(BuiltInViews.today) == ["overdue", "due"])
    #expect(try titles(BuiltInViews.upcoming) == ["later", "much later"])
    #expect(try titles(BuiltInViews.logbook) == ["done"])
    #expect(try titles(BuiltInViews.trash) == ["binned"])
    #expect(try store.tasks(in: BuiltInViews.today, today: today.advanced(by: 2)).map(\.title) == ["overdue", "due", "later"])
}

@Test func manualOrderComesFirstThenTheSort() throws {
    let store = try makeStore()
    let ids = try seeded(store)
    try store.pin(task: ids["due"]!, in: BuiltInViews.today)
    #expect(try store.tasks(in: BuiltInViews.today, today: today).map(\.title) == ["due", "overdue"])
    try store.unpin(task: ids["due"]!, from: BuiltInViews.today)
    #expect(try store.tasks(in: BuiltInViews.today, today: today).map(\.title) == ["overdue", "due"])
}

@Test func pagesRenderChildViewsAsSectionsThenTheRemainder() throws {
    let store = try makeStore()
    let project = try store.createTask(NewTask(title: "Project"))
    var child = NewTask(title: "design"); child.parent = project; let design = try store.createTask(child)
    child.title = "build"; let build = try store.createTask(child)
    child.title = "ship"; let ship = try store.createTask(child)
    var projectView = NewView(title: "Project"); projectView.filter = .parent(project)
    let view = try store.createView(projectView)
    var heading = NewView(title: "Phase 1"); heading.parent = view
    let phase1 = try store.createView(heading)
    try store.update(view: phase1, [.filter(.listedIn(phase1))])
    try store.pin(task: design, in: phase1)
    try store.pin(task: build, in: phase1)

    let page = try store.page(of: view, today: today)
    #expect(page.view.id == view)
    #expect(page.sections.count == 2)
    #expect(page.sections[0].view?.id == phase1)
    #expect(page.sections[0].groups.flatMap(\.tasks).map(\.id) == [design, build])
    #expect(page.sections[1].view == nil)
    #expect(page.sections[1].groups.flatMap(\.tasks).map(\.id) == [ship])

    let folder = try store.createView(NewView(title: "Folder"))
    try store.move(view: view, to: folder, at: .end)
    let folderPage = try store.page(of: folder, today: today)
    #expect(folderPage.sections.count == 1 && folderPage.sections[0].view?.id == view, "a folder shows only its children")
    #expect(folderPage.sections[0].groups.flatMap(\.tasks).map(\.id) == [design, build, ship], "one level of sections: the child's own headings flatten into it")
}

@Test func groupingByDayAndByTag() throws {
    let store = try makeStore()
    let ids = try seeded(store)
    let upcoming = try store.page(of: BuiltInViews.upcoming, today: today)
    #expect(upcoming.sections[0].groups.map(\.key) == [.day(today.advanced(by: 2)), .day(today.advanced(by: 9))])
    let work = try store.createTag(title: "work")
    try store.add(tag: work, to: ids["due"]!)
    var byTag = NewView(title: "By tag"); byTag.filter = .status([.open]); byTag.groupBy = .tag; byTag.sort = [SortKey(.title)]
    let view = try store.createView(byTag)
    let page = try store.page(of: view, today: today)
    #expect(page.sections[0].groups.map(\.key) == [.tag(work), .tag(nil)])
    #expect(page.sections[0].groups[0].tasks.map(\.title) == ["due"])
    #expect(page.sections[0].groups[1].tasks.map(\.title) == ["later", "loose", "much later", "overdue"])
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
swift test --filter 'ViewTests|QueryTests' 2>&1 | grep -E 'error:' | head -3
```

Expected: `cannot find 'NewView' in scope`.

- [ ] **Step 3: Add the view types to `Entities.swift`**

```swift
/// A view as read from the store. `parent` is effective; `needsNewerApp` carries the kind an older app could not read.
public struct View: Equatable, Sendable {
    public var id: ViewID
    public var title: String
    public var parent: ViewID?
    public var rank: String
    public var filter: Filter?
    public var sort: [SortKey]
    public var groupBy: GroupBy?
    public var needsNewerApp: String?
    public var createdAt: Int64
    public var updatedAt: Int64
}

public struct NewView: Sendable {
    public var title: String
    public var parent: ViewID? = nil
    public var filter: Filter? = nil
    public var sort: [SortKey] = []
    public var groupBy: GroupBy? = nil

    public init(title: String) { self.title = title }
}

public enum ViewChange: Sendable, Equatable {
    case title(String)
    case filter(Filter?)
    case sort([SortKey])
    case groupBy(GroupBy?)
}

/// Fixed ids so every device seeds the same rows; the seed uses clock zero so any user edit wins.
public enum BuiltInViews {
    public static let inbox = ViewID("00000000-0000-4000-8000-000000000001")
    public static let today = ViewID("00000000-0000-4000-8000-000000000002")
    public static let upcoming = ViewID("00000000-0000-4000-8000-000000000003")
    public static let logbook = ViewID("00000000-0000-4000-8000-000000000004")
    public static let trash = ViewID("00000000-0000-4000-8000-000000000005")

    static let definitions: [(id: ViewID, title: String, rank: String, filter: Filter, sort: [SortKey], groupBy: GroupBy?)] = [
        (inbox, "Inbox", "1", .and([.status([.open]), .when(.empty), .parent(nil)]), [SortKey(.rank)], nil),
        (today, "Today", "2", .and([.status([.open]), .when(.onOrBefore(0))]), [SortKey(.when)], nil),
        (upcoming, "Upcoming", "3", .and([.status([.open]), .when(.onOrAfter(1))]), [SortKey(.when)], .whenDay),
        (logbook, "Logbook", "4", .status([.done, .canceled]), [SortKey(.completed, descending: true)], nil),
        (trash, "Trash", "5", .trashed(true), [SortKey(.updated, descending: true)], nil),
    ]
}
```

- [ ] **Step 4: Write `Store+Views.swift` and replace the seed stub in `Store.swift`**

```swift
// Sources/TodoCore/Storage/Store+Views.swift
import SQLiteKit

extension Store {
    // MARK: Writes

    @discardableResult
    public func createView(_ new: NewView, at placement: Placement = .end) throws(StoreError) -> ViewID {
        if let parent = new.parent { try requireView(parent) }
        let id = ViewID.generate()
        let rank = try siblingRank(table: "views", parent: new.parent, placement: placement, excluding: nil)
        let stamp = clock.next()
        try apply([
            op(.view, id.rawValue, "title", .text(new.title), stamp),
            op(.view, id.rawValue, "parent", Value(new.parent?.rawValue), stamp),
            op(.view, id.rawValue, "rank", .text(rank), stamp),
            op(.view, id.rawValue, "filter", Value(new.filter?.json()), stamp),
            op(.view, id.rawValue, "sort", .text(SortKey.json(new.sort)), stamp),
            op(.view, id.rawValue, "group_by", Value(new.groupBy?.rawValue), stamp),
            op(.view, id.rawValue, "deleted", Value(false), stamp),
            op(.view, id.rawValue, "created_at", .integer(stamp.millis), stamp),
        ])
        return id
    }

    public func update(view id: ViewID, _ changes: [ViewChange]) throws(StoreError) {
        try requireView(id)
        guard !changes.isEmpty else { return }
        let stamp = clock.next()
        let ops: [Operation] = changes.map { change in
            switch change {
            case .title(let title): return op(.view, id.rawValue, "title", .text(title), stamp)
            case .filter(let filter): return op(.view, id.rawValue, "filter", Value(filter?.json()), stamp)
            case .sort(let sort): return op(.view, id.rawValue, "sort", .text(SortKey.json(sort)), stamp)
            case .groupBy(let group): return op(.view, id.rawValue, "group_by", Value(group?.rawValue), stamp)
            }
        }
        try apply(ops)
    }

    public func delete(view id: ViewID) throws(StoreError) {
        try requireView(id)
        try setFlag(.view, id, "deleted", true)
    }

    public func move(view id: ViewID, to parent: ViewID?, at placement: Placement) throws(StoreError) {
        try requireView(id)
        if let parent {
            guard parent != id else { throw .invalid("a view cannot be its own parent") }
            try requireView(parent)
        }
        let rank = try siblingRank(table: "views", parent: parent, placement: placement, excluding: id)
        let stamp = clock.next()
        try apply([op(.view, id.rawValue, "parent", Value(parent?.rawValue), stamp), op(.view, id.rawValue, "rank", .text(rank), stamp)])
    }

    // MARK: Manual lists

    public func pin(task: TaskID, in view: ViewID, at placement: Placement = .end) throws(StoreError) {
        try requireTask(task)
        try requireView(view)
        let rank = try pinRank(view: view, placement: placement, excluding: task)
        let stamp = clock.next()
        let id = Operation.pairID(view, task)
        try apply([op(.viewItem, id, "present", Value(true), stamp), op(.viewItem, id, "rank", .text(rank), stamp)])
    }

    public func unpin(task: TaskID, from view: ViewID) throws(StoreError) {
        try apply([op(.viewItem, Operation.pairID(view, task), "present", Value(false), clock.next())])
    }

    /// The pinned tasks of a view in their manual order; deleted tasks are skipped.
    public func manualList(of view: ViewID) throws(StoreError) -> [TaskID] {
        try sql { () throws(SQLiteError) in
            try db.rows("SELECT v.task_id FROM view_items v JOIN tasks t ON t.id = v.task_id AND t.deleted = 0 WHERE v.view_id = ? AND v.present = 1 ORDER BY v.rank, v.task_id", [.text(view.rawValue)]).map { TaskID($0[0].string ?? "") }
        }
    }

    private func pinRank(view: ViewID, placement: Placement, excluding: TaskID) throws(StoreError) -> String {
        let items = try sql { () throws(SQLiteError) in
            try db.rows("SELECT task_id, rank FROM view_items WHERE view_id = ? AND present = 1 AND task_id != ? ORDER BY rank, task_id", [.text(view.rawValue), .text(excluding.rawValue)]).map { ($0[0].string ?? "", $0[1].string ?? Rank.initial) }
        }
        switch placement {
        case .end: return Rank.between(items.last?.1, nil)
        case .start: return Rank.between(nil, items.first?.1)
        case .after(let anchor):
            guard let index = items.firstIndex(where: { $0.0 == anchor.rawValue }) else { throw .notFound(anchor) }
            return Rank.between(items[index].1, index + 1 < items.count ? items[index + 1].1 : nil)
        }
    }

    // MARK: Reads

    /// Every view, parents before children, siblings by rank.
    public func views() throws(StoreError) -> [View] {
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT id, title, parent, rank, filter, sort, group_by, created_at, updated_at, deleted FROM views") }
        let parents = TreeRules.effectiveParents(rows.map { TreeRules.Node(id: $0[0].string ?? "", parent: $0[2].string, deleted: $0[9].bool) })
        var byParent: [String?: [View]] = [:]
        for row in rows where !row[9].bool {
            let id = row[0].string ?? ""
            var view = View(id: ViewID(id), title: row[1].string ?? "", parent: (parents[id] ?? nil).map(ViewID.init), rank: row[3].string ?? Rank.initial,
                            filter: nil, sort: [], groupBy: nil, needsNewerApp: nil, createdAt: row[7].int64 ?? 0, updatedAt: row[8].int64 ?? 0)
            do {
                if let json = row[4].string { view.filter = try Filter(json: json) }
                view.sort = try SortKey.parse(json: row[5].string ?? "[]")
                if let raw = row[6].string {
                    guard let group = GroupBy(rawValue: raw) else { throw FilterError.unsupported(kind: "group_by") }
                    view.groupBy = group
                }
            } catch {
                view.needsNewerApp = { if case .unsupported(let kind) = error { return kind } else { return "filter" } }()
            }
            byParent[parents[id] ?? nil, default: []].append(view)
        }
        var ordered: [View] = []
        func visit(_ parent: String?) {
            for view in (byParent[parent] ?? []).sorted(by: { ($0.rank, $0.id.rawValue) < ($1.rank, $1.id.rawValue) }) {
                ordered.append(view)
                visit(view.id.rawValue)
            }
        }
        visit(nil)
        return ordered
    }

    public func view(_ id: ViewID) throws(StoreError) -> View? {
        try views().first { $0.id == id }
    }

    public func children(ofView parent: ViewID?) throws(StoreError) -> [View] {
        try views().filter { $0.parent == parent }
    }

    func requireView(_ id: ViewID) throws(StoreError) {
        let rows = try sql { () throws(SQLiteError) in try db.rows("SELECT 1 FROM views WHERE id = ? AND deleted = 0", [.text(id.rawValue)]) }
        if rows.isEmpty { throw .notFound(id) }
    }

    /// Inserts the built-in views with clock zero from device "seed". Runs at every open; the journal's unique index
    /// and the field clocks make it a no-op after the first time, and any user edit outranks clock zero.
    func seedBuiltInViews() throws(StoreError) {
        let zero = HLC(millis: 0, counter: 0)
        var ops: [Operation] = []
        for d in BuiltInViews.definitions {
            let fields: [(String, Value)] = [
                ("title", .text(d.title)), ("parent", .null), ("rank", .text(d.rank)), ("filter", .text(d.filter.json())),
                ("sort", .text(SortKey.json(d.sort))), ("group_by", Value(d.groupBy?.rawValue)), ("deleted", Value(false)), ("created_at", .integer(0)),
            ]
            ops += fields.map { Operation(entity: .view, entityID: d.id.rawValue, field: $0.0, value: $0.1, clock: zero, device: "seed") }
        }
        try apply(ops)
    }
}
```

Delete the empty `seedBuiltInViews` from `Store.swift`. Note that `views()` reads the whole table on every call; views number in the tens, and the tree order needs all rows. `apply` in the seed runs before `onChange` can be set, so opening never notifies.

- [ ] **Step 5: Write `Store+Query.swift`**

```swift
// Sources/TodoCore/Query/Store+Query.swift
import SQLiteKit

public enum GroupKey: Hashable, Sendable {
    case day(Day?)
    case tag(TagID?)
    case parent(TaskID?)
    case status(TaskStatus)
}

public struct TaskGroup: Equatable, Sendable {
    public var key: GroupKey?
    public var tasks: [Task]
}

/// One section of a page: a child view's tasks, or (`view == nil`) the page's own remainder.
public struct Section: Equatable, Sendable {
    public var view: View?
    public var groups: [TaskGroup]
}

public struct ViewPage: Equatable, Sendable {
    public var view: View
    public var sections: [Section]
}

extension Store {
    /// The tasks a view selects: pinned ones first in manual order, then the view's sort. Sections are ignored.
    public func tasks(in viewID: ViewID, today: Day) throws(StoreError) -> [Task] {
        guard let view = try view(viewID) else { throw .notFound(viewID) }
        return try tasks(matching: view, today: today)
    }

    /// A page: each child view as a section in rank order, then the view's own results that no child claimed.
    /// One level deep: a child's own children flatten into the child's section when it is opened, not here.
    public func page(of viewID: ViewID, today: Day) throws(StoreError) -> ViewPage {
        guard let view = try view(viewID) else { throw .notFound(viewID) }
        var sections: [Section] = []
        var claimed: Set<TaskID> = []
        for child in try children(ofView: viewID) {
            let tasks = try tasks(matching: child, today: today)
            claimed.formUnion(tasks.map(\.id))
            sections.append(Section(view: child, groups: group(tasks, by: child.groupBy)))
        }
        let own = try tasks(matching: view, today: today).filter { !claimed.contains($0.id) }
        if !own.isEmpty || sections.isEmpty {
            sections.append(Section(view: nil, groups: group(own, by: view.groupBy)))
        }
        return ViewPage(view: view, sections: sections)
    }

    func tasks(matching view: View, today: Day) throws(StoreError) -> [Task] {
        if let kind = view.needsNewerApp { throw .viewNeedsNewerApp(view.id, kind: kind) }
        guard let filter = view.filter else { return [] }
        let clause = FilterCompiler.whereClause(filter, today: today)
        let join = "LEFT JOIN view_items vi ON vi.view_id = ? AND vi.task_id = t.id AND vi.present = 1"
        let order = "(vi.rank IS NULL), vi.rank, " + FilterCompiler.orderBy(view.sort)
        return try loadTasks(where: clause.sql, [.text(view.id.rawValue)] + clause.params, orderBy: order, join: join)
    }

    /// Stable partition: groups appear in the order their first task appears.
    func group(_ tasks: [Task], by groupBy: GroupBy?) -> [TaskGroup] {
        guard let groupBy else { return [TaskGroup(key: nil, tasks: tasks)] }
        var order: [GroupKey] = []
        var buckets: [GroupKey: [Task]] = [:]
        for task in tasks {
            let key: GroupKey
            switch groupBy {
            case .whenDay: key = .day(task.when)
            case .deadlineDay: key = .day(task.deadline)
            case .parent: key = .parent(task.parent)
            case .status: key = .status(task.status)
            case .tag: key = .tag(task.tags.min())
            }
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(task)
        }
        return order.map { TaskGroup(key: $0, tasks: buckets[$0] ?? []) }
    }
}
```

The `LEFT JOIN view_items` parameter comes before the WHERE parameters in the SQL that `loadTasks` assembles, which is why the view id leads the parameter array. A task with several tags is grouped under its smallest tag id; the UI may regroup, the core only promises determinism.

- [ ] **Step 6: Run the tests on both platforms**

```bash
swift test --filter 'ViewTests|QueryTests' 2>&1 | tail -3
swift test --filter 'ViewTests|QueryTests' --swift-sdk swift-6.3.3-RELEASE_wasm 2>&1 | tail -3
```

Expected: 8 tests pass on both.

- [ ] **Step 7: Align the spec's Logbook row**

The spec's built-in table says Logbook is "grouped by day", but the core has no time zone and cannot turn a completion timestamp into a day; grouping keys are `when` day and `deadline` day only. In `docs/specs/core-storage-and-search.md`, change the Logbook row to `| Logbook | done or canceled | completed, newest first; the UI groups by local day |` and add one sentence after the table: "Grouping by the day of completion happens in the UI, which knows the time zone; the core groups only by the calendar-day fields."

- [ ] **Step 8: Commit**

```bash
git add Sources/TodoCore Tests/TodoCoreTests/ViewTests.swift Tests/TodoCoreTests/QueryTests.swift docs/specs/core-storage-and-search.md
git commit -m "feat(core): add nested views, built-in views, manual lists and page queries"
```

---

### Task 10: Search: quick find over titles, ranked search in notes

**Files:**
- Create: `Sources/TodoCore/Search/Store+Search.swift`
- Create: `Tests/TodoCoreTests/SearchTests.swift`

**Interfaces:**
- Consumes: the FTS5 tables and triggers (Task 4); `loadTasks(where:_:orderBy:join:limit:)`, `tags()`, `views()` (Tasks 7 and 9).
- Produces:
  - `public enum QuickFindHit: Equatable, Sendable { case task(Task); case tag(Tag); case view(View) }`
  - `public struct NoteHit: Equatable, Sendable { public var task: Task; public var snippet: String; public var score: Double }`
  - `extension Store { public func quickFind(_ query: String, limit: Int = 20) throws(StoreError) -> [QuickFindHit]; public func searchNotes(_ query: String, limit: Int = 20) throws(StoreError) -> [NoteHit]; static func trigramQuery(_ text: String) -> String?; static func wordsQuery(_ text: String) -> String? }`

Quick find returns tasks first, then tags, then views, each alphabetically by title; trashed and deleted tasks never appear. Queries shorter than three characters cannot use the trigram index and scan titles in Swift instead. Notes search is word-based with the last word as a prefix, ranked by `bm25`, with the matched words in square brackets in a twelve-token snippet.

- [ ] **Step 1: Write the failing tests**

`Tests/TodoCoreTests/SearchTests.swift`:

```swift
import Testing
@testable import TodoCore

private func titles(_ hits: [QuickFindHit]) -> [String] {
    hits.map { hit in
        switch hit {
        case .task(let t): return "task:" + t.title
        case .tag(let g): return "tag:" + g.title
        case .view(let v): return "view:" + v.title
        }
    }
}

@Test func quickFindMatchesSubstringsInAnyCaseAcrossTasksTagsAndViews() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "Квартальный отчёт"))
    _ = try store.createTask(NewTask(title: "Buy Milk"))
    _ = try store.createTag(title: "Отчётность")
    _ = try store.createView(NewView(title: "Reports"))
    #expect(titles(try store.quickFind("ОТЧ")) == ["task:Квартальный отчёт", "tag:Отчётность"])
    #expect(titles(try store.quickFind("milk")) == ["task:Buy Milk"])
    #expect(titles(try store.quickFind("por")) == ["view:Reports"])
    #expect(try store.quickFind("zzz").isEmpty)
    #expect(try store.quickFind("   ").isEmpty)
}

@Test func shortQueriesFallBackToAScan() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "Åsa calls"))
    _ = try store.createTag(title: "as-is")
    #expect(titles(try store.quickFind("as")) == ["tag:as-is"], "two characters: plain case folding, no diacritic folding")
    #expect(titles(try store.quickFind("ås")) == ["task:Åsa calls"])
}

@Test func diacriticsAreFoldedByTheIndex() throws {
    let store = try makeStore()
    _ = try store.createTask(NewTask(title: "Café run"))
    #expect(titles(try store.quickFind("cafe")) == ["task:Café run"])
    var withNotes = NewTask(title: "n"); withNotes.notes = "Rendezvous at the café tomorrow"
    _ = try store.createTask(withNotes)
    #expect(try store.searchNotes("cafe").map(\.task.title) == ["n"])
}

@Test func quickFindHidesTrashedAndDeletedTasks() throws {
    let store = try makeStore()
    let gone = try store.createTask(NewTask(title: "gone fishing"))
    let binned = try store.createTask(NewTask(title: "binned fishing"))
    _ = try store.createTask(NewTask(title: "still fishing"))
    try store.delete(task: gone)
    try store.trash(task: binned)
    #expect(titles(try store.quickFind("fishing")) == ["task:still fishing"])
}

@Test func indexFollowsRenamesAndNoteEdits() throws {
    let store = try makeStore()
    let id = try store.createTask(NewTask(title: "alpha"))
    try store.update(task: id, [.title("bravo"), .notes("charlie delta")])
    #expect(try store.quickFind("alpha").isEmpty)
    #expect(titles(try store.quickFind("bravo")) == ["task:bravo"])
    #expect(try store.searchNotes("charlie").map(\.task.id) == [id])
    try store.update(task: id, [.notes("echo")])
    #expect(try store.searchNotes("charlie").isEmpty)
}

@Test func notesSearchRanksPrefixesAndSnippets() throws {
    let store = try makeStore()
    var a = NewTask(title: "a"); a.notes = "Планирование спринта: планы, планёрка, ещё раз планирование."
    var b = NewTask(title: "b"); b.notes = "Один план на неделю."
    var c = NewTask(title: "c"); c.notes = "Ничего общего."
    _ = try store.createTask(a); _ = try store.createTask(b); _ = try store.createTask(c)
    let hits = try store.searchNotes("план")
    #expect(hits.map(\.task.title) == ["a", "b"])
    #expect(hits[0].snippet.contains("[План") || hits[0].snippet.contains("[план"))
    #expect(hits[0].score <= hits[1].score, "bm25 is smaller for better matches")
    #expect(try store.searchNotes("планы спринт").map(\.task.title) == ["a"], "whole word plus a prefix on the last word")
    #expect(try store.searchNotes("").isEmpty)
}

@Test func queryEscapingTreatsOperatorsAndQuotesLiterally() throws {
    let store = try makeStore()
    var t = NewTask(title: "say \"hi\" OR not"); t.notes = "NOT a NEAR b AND \"quoted\""
    _ = try store.createTask(t)
    #expect(titles(try store.quickFind("\"hi\" OR")) == ["task:say \"hi\" OR not"])
    #expect(try store.searchNotes("\"quoted\" AND").count == 1)
    #expect(try store.searchNotes("NOT").count == 1)
    #expect(Store.trigramQuery("ab") == nil)
    #expect(Store.trigramQuery(" a\"b\"c ") == "\"a\"\"b\"\"c\"")
    #expect(Store.wordsQuery("  один  два ") == "\"один\" \"два\"*")
    #expect(Store.wordsQuery(" ") == nil)
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
swift test --filter SearchTests 2>&1 | grep -E 'error:' | head -3
```

Expected: `value of type 'Store' has no member 'quickFind'`.

- [ ] **Step 3: Write `Store+Search.swift`**

```swift
// Sources/TodoCore/Search/Store+Search.swift
import SQLiteKit

public enum QuickFindHit: Equatable, Sendable {
    case task(Task)
    case tag(Tag)
    case view(View)
}

public struct NoteHit: Equatable, Sendable {
    public var task: Task
    public var snippet: String
    /// bm25 score: lower is a better match.
    public var score: Double
}

extension Store {
    /// Substring match over titles, case- and diacritic-insensitive. Tasks, then tags, then views, alphabetically.
    public func quickFind(_ query: String, limit: Int = 20) throws(StoreError) -> [QuickFindHit] {
        let needle = Store.normalized(query)
        guard !needle.isEmpty, limit > 0 else { return [] }
        var hits: [QuickFindHit] = []
        if let match = Store.trigramQuery(needle) {
            let tasks = try loadTasks(
                where: "tt.trashed = 0 AND t.rid IN (SELECT rowid FROM tasks_title_fts WHERE tasks_title_fts MATCH ?)",
                [.text(match)], orderBy: "t.title COLLATE NOCASE, t.id", limit: limit)
            hits += tasks.map(QuickFindHit.task)
            let tagIDs = try matchingIDs("SELECT id FROM tags WHERE deleted = 0 AND rid IN (SELECT rowid FROM tags_title_fts WHERE tags_title_fts MATCH ?)", match)
            hits += try tags().filter { tagIDs.contains($0.id) }.sorted(by: Store.byTitle).map(QuickFindHit.tag)
            let viewIDs = try matchingIDs("SELECT id FROM views WHERE deleted = 0 AND rid IN (SELECT rowid FROM views_title_fts WHERE views_title_fts MATCH ?)", match)
            hits += try views().filter { viewIDs.contains($0.id) }.sorted(by: Store.byTitle).map(QuickFindHit.view)
        } else {
            // Under three characters the trigram index cannot answer; scan titles with plain case folding.
            let folded = needle.lowercased()
            func contains(_ title: String) -> Bool { title.lowercased().contains(folded) }
            let tasks = try loadTasks(where: "tt.trashed = 0", [], orderBy: "t.title COLLATE NOCASE, t.id").filter { contains($0.title) }
            hits += tasks.prefix(limit).map(QuickFindHit.task)
            hits += try tags().filter { contains($0.title) }.sorted(by: Store.byTitle).map(QuickFindHit.tag)
            hits += try views().filter { contains($0.title) }.sorted(by: Store.byTitle).map(QuickFindHit.view)
        }
        return Array(hits.prefix(limit))
    }

    /// Word and prefix search over notes, best matches first, with a snippet that brackets the matched words.
    public func searchNotes(_ query: String, limit: Int = 20) throws(StoreError) -> [NoteHit] {
        guard let match = Store.wordsQuery(query), limit > 0 else { return [] }
        let rows = try sql { () throws(SQLiteError) in
            try db.rows("""
                SELECT t.id, snippet(tasks_notes_fts, 0, '[', ']', '…', 12), bm25(tasks_notes_fts)
                FROM tasks_notes_fts f
                JOIN tasks t ON t.rid = f.rowid
                JOIN task_tree tt ON tt.id = t.id
                WHERE tasks_notes_fts MATCH ? AND t.deleted = 0 AND tt.trashed = 0
                ORDER BY bm25(tasks_notes_fts), t.id
                LIMIT ?
                """, [.text(match), .integer(Int64(limit))])
        }
        guard !rows.isEmpty else { return [] }
        let ids = rows.map { TaskID($0[0].string ?? "") }
        let marks = Array(repeating: "?", count: ids.count).joined(separator: ", ")
        let tasks = try loadTasks(where: "t.id IN (\(marks))", ids.map { .text($0.rawValue) }, orderBy: "t.id")
        var byID: [TaskID: Task] = [:]
        for task in tasks { byID[task.id] = task }
        return rows.compactMap { row in
            guard let task = byID[TaskID(row[0].string ?? "")] else { return nil }
            return NoteHit(task: task, snippet: row[1].string ?? "", score: row[2].double ?? 0)
        }
    }

    // MARK: Query building

    /// A trigram phrase: the whole text as one quoted string, or nil when shorter than three characters.
    static func trigramQuery(_ text: String) -> String? {
        let needle = normalized(text)
        guard needle.count >= 3 else { return nil }
        return quoted(needle)
    }

    /// One quoted token per word, the last one as a prefix; nil when there are no words.
    static func wordsQuery(_ text: String) -> String? {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return nil }
        var parts = words.map(quoted)
        parts[parts.count - 1] += "*"
        return parts.joined(separator: " ")
    }

    /// Collapses runs of whitespace and trims the ends.
    static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// FTS5 string syntax: double quotes around, inner quotes doubled. Operators inside quotes are literal text.
    private static func quoted(_ text: String) -> String {
        "\"" + text.replacing("\"", with: "\"\"") + "\""
    }

    private func matchingIDs(_ sql: String, _ match: String) throws(StoreError) -> Set<EntityID> {
        try self.sql { () throws(SQLiteError) in Set(try db.rows(sql, [.text(match)]).map { EntityID($0[0].string ?? "") }) }
    }

    private static func byTitle(_ a: Tag, _ b: Tag) -> Bool { (a.title.lowercased(), a.id.rawValue) < (b.title.lowercased(), b.id.rawValue) }
    private static func byTitle(_ a: View, _ b: View) -> Bool { (a.title.lowercased(), a.id.rawValue) < (b.title.lowercased(), b.id.rawValue) }
}
```

- [ ] **Step 4: Run the tests on both platforms**

```bash
swift test --filter SearchTests 2>&1 | tail -3
swift test --filter SearchTests --swift-sdk swift-6.3.3-RELEASE_wasm 2>&1 | tail -3
```

Expected: 7 tests pass on both. The `shortQueriesFallBackToAScan` expectation is deliberately literal about what two characters can and cannot match; if `Åsa` matches `as` on one platform and not the other, `String.lowercased()` differs and the assertion must be relaxed to the tag only, with a note in the PR.

- [ ] **Step 5: Commit**

```bash
git add Sources/TodoCore/Search Tests/TodoCoreTests/SearchTests.swift
git commit -m "feat(core): add quick find over titles and ranked search in notes"
```

---

### Task 11: Sync skeleton: journal export, receive, in-memory relay, convergence

**Files:**
- Create: `Sources/TodoCore/Sync/Sync.swift`
- Create: `Tests/TodoCoreTests/SyncTests.swift`

**Interfaces:**
- Consumes: `apply`, `Operation`, `EntityKind` (Task 5); `meta`, `setMeta`, `clock` (Task 4).
- Produces:
  - `public struct JournalEntry: Equatable, Sendable { public var seq: Int64; public var op: Operation }`
  - `public enum SyncError: Error, Equatable, Sendable { case store(StoreError); case transport(String) }`
  - `public protocol SyncTransport: AnyObject { func push(_ ops: [Operation]) throws(SyncError); func pull(after cursor: Int64) throws(SyncError) -> (ops: [Operation], cursor: Int64) }`
  - `public final class InMemoryRelay: SyncTransport` for tests and demos.
  - `extension Store { public func journal(after seq: Int64, limit: Int = 1_000) throws(StoreError) -> [JournalEntry]; @discardableResult public func receive(_ ops: [Operation]) throws(StoreError) -> ChangeSet; public func syncCursors() throws(StoreError) -> (pushed: Int64, pulled: Int64); public func setSyncCursors(pushed: Int64, pulled: Int64) throws(StoreError) }`
  - `public enum SyncEngine { @discardableResult public static func sync(_ store: Store, via transport: any SyncTransport) throws(SyncError) -> ChangeSet }`: push this device's journal rows the relay has not seen, then pull and receive everything after the pull cursor.

- [ ] **Step 1: Write the failing tests**

`Tests/TodoCoreTests/SyncTests.swift`:

```swift
import Testing
@testable import TodoCore

private let day = Day(year: 2026, month: 9, day: 12)

private func pair() throws -> (a: Store, b: Store, relay: InMemoryRelay) {
    let relay = InMemoryRelay()
    let a = try makeStore(clock: TestClock(start: 1_757_500_000_000))
    let b = try makeStore(clock: TestClock(start: 1_757_500_000_000 - 5_000))   // B's wall clock runs five seconds behind
    return (a, b, relay)
}

private func exchange(_ a: Store, _ b: Store, _ relay: InMemoryRelay) throws {
    for _ in 0..<2 {
        try SyncEngine.sync(a, via: relay)
        try SyncEngine.sync(b, via: relay)
    }
}

@Test func twoStoresConvergeAfterConcurrentEditsAndLaterEditsWin() throws {
    let (a, b, relay) = try pair()
    #expect(a.deviceID != b.deviceID)
    let id = try a.createTask(NewTask(title: "draft"))
    try exchange(a, b, relay)
    #expect(try b.task(id)?.title == "draft")

    try b.update(task: id, [.title("from B")])                 // earlier wall clock
    try a.update(task: id, [.when(day)])                        // a different field
    try a.update(task: id, [.title("from A")])                  // later wall clock
    try exchange(a, b, relay)
    let ta = try #require(try a.task(id)), tb = try #require(try b.task(id))
    #expect(ta == tb)
    #expect(ta.title == "from A" && ta.when == day)

    try b.update(task: id, [.title("B after sync")])           // B's clock jumped past A's during receive
    try exchange(a, b, relay)
    #expect(try a.task(id)?.title == "B after sync")
    #expect(try a.tasks(in: BuiltInViews.today, today: day).map(\.id) == [id])
}

@Test func structureTagsViewsAndPinsPropagate() throws {
    let (a, b, relay) = try pair()
    let project = try a.createTask(NewTask(title: "Project"))
    var child = NewTask(title: "child"); child.parent = project
    let kid = try a.createTask(child)
    let tag = try a.createTag(title: "work")
    try a.add(tag: tag, to: kid)
    var heading = NewView(title: "H"); heading.filter = nil
    let view = try a.createView(heading)
    try a.update(view: view, [.filter(.listedIn(view))])
    try a.pin(task: kid, in: view)
    try exchange(a, b, relay)
    #expect(try b.children(of: project).map(\.id) == [kid])
    #expect(try b.task(kid)?.tags == [tag])
    #expect(try b.tags().map(\.title) == ["work"])
    #expect(try b.tasks(in: view, today: day).map(\.id) == [kid])
    try b.trash(task: project)
    try a.delete(task: kid)
    try exchange(a, b, relay)
    #expect(try a.task(project)?.trashed == true)
    #expect(try b.task(kid) == nil)
}

@Test func receiveSkipsOwnOperationsAndDuplicates() throws {
    let (a, _, _) = try pair()
    let id = try a.createTask(NewTask(title: "mine"))
    let own = try a.journal(after: 0).map(\.op).filter { $0.device == a.deviceID }
    var calls = 0
    a.onChange = { _ in calls += 1 }
    #expect(try a.receive(own).isEmpty)
    #expect(calls == 0)
    var foreign = own.first { $0.field == "title" }!
    foreign.device = "other"
    foreign.clock = HLC(millis: foreign.clock.millis + 10, counter: 0)
    foreign.value = .text("theirs")
    #expect(try a.receive([foreign]).tasks == [id])
    #expect(try a.receive([foreign]).isEmpty, "a duplicate is dropped by the journal index and the field clock")
    #expect(try a.task(id)?.title == "theirs")
}

@Test func journalExportIsOrderedAndCursorsPersist() throws {
    let (a, _, relay) = try pair()
    _ = try a.createTask(NewTask(title: "one"))
    let entries = try a.journal(after: 0)
    #expect(entries.map(\.seq) == entries.map(\.seq).sorted())
    #expect(entries.contains { $0.op.device == "seed" }, "seed rows are in the journal but never pushed")
    try SyncEngine.sync(a, via: relay)
    #expect(relay.log.allSatisfy { $0.device == a.deviceID })
    let cursors = try a.syncCursors()
    #expect(cursors.pushed == entries.last?.seq && cursors.pulled == Int64(relay.log.count))
    try SyncEngine.sync(a, via: relay)
    #expect(relay.log.count == 10, "ten fields of one task, pushed once")
}
```

- [ ] **Step 2: Run the tests to see them fail**

```bash
swift test --filter SyncTests 2>&1 | grep -E 'error:' | head -3
```

Expected: `cannot find 'InMemoryRelay' in scope`.

- [ ] **Step 3: Write `Sync.swift`**

```swift
// Sources/TodoCore/Sync/Sync.swift
import SQLiteKit

public struct JournalEntry: Equatable, Sendable {
    public var seq: Int64
    public var op: Operation
}

public enum SyncError: Error, Equatable, Sendable {
    case store(StoreError)
    case transport(String)
}

/// Moves journal rows between devices. Two actions, as the spec says; everything else is the store's.
public protocol SyncTransport: AnyObject {
    func push(_ ops: [Operation]) throws(SyncError)
    func pull(after cursor: Int64) throws(SyncError) -> (ops: [Operation], cursor: Int64)
}

/// A relay in memory: every device's pushes in arrival order. The only transport in M1; tests and demos share one.
public final class InMemoryRelay: SyncTransport {
    public private(set) var log: [Operation] = []

    public init() {}

    public func push(_ ops: [Operation]) throws(SyncError) {
        log += ops
    }

    public func pull(after cursor: Int64) throws(SyncError) -> (ops: [Operation], cursor: Int64) {
        let start = Int(min(max(cursor, 0), Int64(log.count)))
        return (Array(log[start...]), Int64(log.count))
    }
}

extension Store {
    /// Journal rows after a local sequence number, oldest first, this device's and others' alike.
    public func journal(after seq: Int64, limit: Int = 1_000) throws(StoreError) -> [JournalEntry] {
        try sql { () throws(SQLiteError) in
            try db.rows("SELECT seq, entity, entity_id, field, value, clock, device FROM ops WHERE seq > ? ORDER BY seq LIMIT ?", [.integer(seq), .integer(Int64(limit))])
                .compactMap { row in
                    guard let kind = EntityKind(rawValue: row[1].string ?? "") else { return nil }
                    let op = Operation(entity: kind, entityID: row[2].string ?? "", field: row[3].string ?? "", value: row[4], clock: HLC(raw: row[5].int64 ?? 0), device: row[6].string ?? "")
                    return JournalEntry(seq: row[0].int64 ?? 0, op: op)
                }
        }
    }

    /// Applies operations from other devices through the same path as local edits, after advancing this device's clock past theirs.
    @discardableResult
    public func receive(_ ops: [Operation]) throws(StoreError) -> ChangeSet {
        let foreign = ops.filter { $0.device != deviceID }
        for op in foreign { clock.observe(op.clock) }
        return try apply(foreign)
    }

    public func syncCursors() throws(StoreError) -> (pushed: Int64, pulled: Int64) {
        (try meta("sync.pushed_seq").int64 ?? 0, try meta("sync.pull_cursor").int64 ?? 0)
    }

    public func setSyncCursors(pushed: Int64, pulled: Int64) throws(StoreError) {
        try setMeta("sync.pushed_seq", .integer(pushed))
        try setMeta("sync.pull_cursor", .integer(pulled))
    }
}

public enum SyncEngine {
    /// One round: push this device's journal rows the transport has not seen, then pull and receive what others pushed.
    @discardableResult
    public static func sync(_ store: Store, via transport: any SyncTransport) throws(SyncError) -> ChangeSet {
        do {
            let cursors = try store.syncCursors()
            var lastSeq = cursors.pushed
            while true {
                let entries = try store.journal(after: lastSeq)
                guard let last = entries.last else { break }
                let own = entries.filter { $0.op.device == store.deviceID }.map(\.op)
                if !own.isEmpty { try transport.push(own) }
                lastSeq = last.seq
            }
            let pulled = try transport.pull(after: cursors.pulled)
            let changes = try store.receive(pulled.ops)
            try store.setSyncCursors(pushed: lastSeq, pulled: pulled.cursor)
            return changes
        } catch let error as StoreError {
            throw .store(error)
        } catch let error as SyncError {
            throw error
        } catch {
            throw .transport(String(describing: error))
        }
    }
}
```

The pushed cursor is the local `seq`, so rows this device received from others are skipped by the device filter and never re-pushed; the pull cursor is the transport's. Both live in `meta`, so a restart resumes where it stopped.

- [ ] **Step 4: Run the tests on both platforms**

```bash
swift test --filter SyncTests 2>&1 | tail -3
swift test --filter SyncTests --swift-sdk swift-6.3.3-RELEASE_wasm 2>&1 | tail -3
```

Expected: 4 tests pass on both. Then run the whole suite once on both platforms; every earlier test must still pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/TodoCore/Sync Tests/TodoCoreTests/SyncTests.swift
git commit -m "feat(core): add the sync skeleton with journal export, receive and an in-memory relay"
```

---

### Task 12: The `todo` command-line demo

The runnable deliverable of M1 and the seed of a future CLI client. Commands live in a library target so they are tested like the core; the executable is one line.

**Files:**
- Modify: `Package.swift` (add the `TodoCLI` library target and `TodoCLITests`)
- Create: `Sources/TodoCLI/CLI.swift`, `Sources/TodoCLI/Format.swift`
- Replace: `Sources/todo/main.swift`
- Create: `Tests/TodoCLITests/CLITests.swift`
- Modify: `README.md` (usage)

**Interfaces:**
- Consumes: the public API of `TodoCore`.
- Produces: `public enum CLI { public static let usage: String; public static func main(_ arguments: [String], environment: [String: String]) -> Int32; public static func run(_ args: [String], store: Store, today: Day) throws -> String; public static func currentDay() -> Day }` and `public struct CLIError: Error, CustomStringConvertible`.

Commands (`todo [--db PATH] <command>`; `TODO_DB` and `TODO_TODAY=YYYY-MM-DD` in the environment override the database path and today):

| Command | Effect |
| ------- | ------ |
| `add TITLE [--when D] [--deadline D] [--parent ID] [--tag NAME]... [--notes TEXT]` | creates a task; `D` is `YYYY-MM-DD` |
| `list [VIEW]` | the page of a view by title or id prefix, default Inbox: sections, groups, tasks |
| `views` | the view tree |
| `view add TITLE [--filter JSON] [--parent VIEW] [--sort FIELD[:desc]]... [--group KEY]` | creates a view; no filter makes a folder |
| `show ID` | one task with its notes |
| `done ID`, `cancel ID`, `reopen ID` | status changes |
| `edit ID [--title T] [--when D or none] [--deadline D or none] [--notes TEXT]` | field changes |
| `move ID --parent PID or none [--after ID]` | reparent and reorder |
| `tag ID NAME`, `untag ID NAME` | tags, created on first use |
| `pin ID VIEW`, `unpin ID VIEW` | manual lists |
| `trash ID`, `restore ID`, `delete ID` | trash and tombstone |
| `find QUERY` | quick find over titles and ranked hits in notes |

`ID` is a task id or any unique prefix of one. Output is one fact per line so scripts can consume it.

- [ ] **Step 1: Write the failing tests**

`Tests/TodoCLITests/CLITests.swift`:

```swift
import Testing
import TodoCore
@testable import TodoCLI

private let today = Day(year: 2026, month: 9, day: 11)

private func store() throws -> Store {
    var millis: Int64 = 1_757_500_000_000
    return try Store.openInMemory(now: { millis += 1; return millis })
}

private func run(_ store: Store, _ line: String) throws -> String {
    try CLI.run(line.split(separator: " ").map(String.init), store: store, today: today)
}

@Test func addListAndDone() throws {
    let s = try store()
    let added = try run(s, "add Buy milk")
    #expect(added.hasPrefix("added "))
    let id = String(added.split(separator: " ")[1])
    #expect(try run(s, "list").contains("Buy milk"))
    #expect(try run(s, "list Inbox").contains(id.prefix(8)))
    let done = try run(s, "done \(id.prefix(8))")
    #expect(done == "done \(id)")
    #expect(!(try run(s, "list Inbox")).contains("Buy milk"))
    #expect(try run(s, "list Logbook").contains("[x] Buy milk"))
}

@Test func datesTagsAndTodayView() throws {
    let s = try store()
    let out = try CLI.run(["add", "Call mom", "--when", "2026-09-11", "--tag", "family", "--notes", "after 6"], store: s, today: today)
    let id = String(out.split(separator: " ")[1])
    let today = try run(s, "list Today")
    #expect(today.contains("[ ] Call mom") && today.contains("when 2026-09-11") && today.contains("#family"))
    #expect(try run(s, "show \(id)").hasSuffix("after 6"))
    #expect(try run(s, "find mom").contains("Call mom"))
    #expect(try run(s, "find after").contains("[after] 6"))
}

@Test func viewsFoldersAndPins() throws {
    let s = try store()
    #expect(try run(s, "views").split(separator: "\n").count == 5)
    let folder = try run(s, "view add Work")
    let folderID = String(folder.split(separator: " ")[2])
    let filtered = try CLI.run(["view", "add", "Open", "--parent", String(folderID.prefix(8)), "--filter", "{\"kind\":\"status\",\"statuses\":[0]}", "--sort", "title"], store: s, today: today)
    #expect(filtered.hasPrefix("added view "))
    let views = try run(s, "views")
    #expect(views.contains("- Work") && views.contains("  - Open"))
    let a = String(try run(s, "add alpha").split(separator: " ")[1])
    _ = try run(s, "add beta")
    #expect(try run(s, "pin \(a.prefix(8)) Open") == "pinned \(a) in Open")
    let page = try run(s, "list Open")
    #expect(page.range(of: "alpha")!.lowerBound < page.range(of: "beta")!.lowerBound)
}

@Test func errorsAreExplicit() throws {
    let s = try store()
    _ = try run(s, "add one")
    _ = try run(s, "add two")
    #expect(throws: CLIError.self) { try run(s, "done zzz") }
    #expect(throws: CLIError.self) { try run(s, "frobnicate") }
    var message = ""
    do { _ = try run(s, "list Nowhere") } catch let error as CLIError { message = error.description }
    #expect(message == "no view matches \"Nowhere\"")
    #expect(CLI.usage.contains("todo [--db PATH] <command>"))
}
```

- [ ] **Step 2: Add the targets and run the tests to see them fail**

In `Package.swift`, add `.target(name: "TodoCLI", dependencies: ["TodoCore"])` before the `todo` executable, change the executable's dependencies to `["TodoCLI"]`, and add `.testTarget(name: "TodoCLITests", dependencies: ["TodoCLI"])`.

```bash
swift test --filter TodoCLITests 2>&1 | grep -E 'error:' | head -3
```

Expected: `cannot find 'CLI' in scope`.

- [ ] **Step 3: Write `Format.swift`**

```swift
// Sources/TodoCLI/Format.swift
import TodoCore

enum Format {
    static func short(_ id: EntityID) -> String { String(id.rawValue.prefix(8)) }

    static func line(_ task: Task, tagsByID: [TagID: Tag]) -> String {
        let box: String
        switch task.status {
        case .open: box = "[ ]"
        case .done: box = "[x]"
        case .canceled: box = "[-]"
        }
        var parts = ["\(box) \(task.title)"]
        if let when = task.when { parts.append("when \(when)") }
        if let deadline = task.deadline { parts.append("due \(deadline)") }
        for tag in task.tags.sorted() { parts.append("#" + (tagsByID[tag]?.title ?? tag.rawValue)) }
        if task.trashed { parts.append("(trashed)") }
        parts.append("(\(short(task.id)))")
        return parts.joined(separator: "  ")
    }

    static func page(_ page: ViewPage, tagsByID: [TagID: Tag]) -> String {
        var lines: [String] = ["\(page.view.title) (\(page.sections.flatMap(\.groups).flatMap(\.tasks).count) tasks)"]
        for section in page.sections {
            if let view = section.view { lines.append("## \(view.title)") }
            for group in section.groups {
                if let key = group.key { lines.append("# \(label(key, tagsByID: tagsByID))") }
                for task in group.tasks { lines.append("  " + line(task, tagsByID: tagsByID)) }
            }
        }
        return lines.joined(separator: "\n")
    }

    static func label(_ key: GroupKey, tagsByID: [TagID: Tag]) -> String {
        switch key {
        case .day(let day): return day.map { "\($0)" } ?? "no date"
        case .tag(let tag): return tag.flatMap { tagsByID[$0]?.title } ?? "no tag"
        case .parent(let parent): return parent.map { "in \(short($0))" } ?? "at the root"
        case .status(let status): return String(describing: status)
        }
    }

    static func views(_ views: [View]) -> String {
        var depth: [ViewID: Int] = [:]
        return views.map { view in
            let level = view.parent.flatMap { depth[$0] }.map { $0 + 1 } ?? 0
            depth[view.id] = level
            let kind = view.needsNewerApp != nil ? " (needs a newer app)" : (view.filter == nil ? " (folder)" : "")
            return String(repeating: "  ", count: level) + "- \(view.title)\(kind)  (\(short(view.id)))"
        }.joined(separator: "\n")
    }
}
```

- [ ] **Step 4: Write `CLI.swift`**

```swift
// Sources/TodoCLI/CLI.swift
import TodoCore
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct CLIError: Error, CustomStringConvertible {
    public let description: String
    init(_ description: String) { self.description = description }
}

public enum CLI {
    public static let usage = """
    usage: todo [--db PATH] <command>
      add TITLE [--when D] [--deadline D] [--parent ID] [--tag NAME]... [--notes TEXT]
      list [VIEW]            views                view add TITLE [--filter JSON] [--parent VIEW] [--sort FIELD[:desc]]... [--group KEY]
      show ID                done | cancel | reopen ID
      edit ID [--title T] [--when D|none] [--deadline D|none] [--notes TEXT]
      move ID --parent PID|none [--after ID]
      tag | untag ID NAME    pin | unpin ID VIEW    trash | restore | delete ID
      find QUERY
    D is YYYY-MM-DD. ID is a task id or a unique prefix. TODO_DB and TODO_TODAY override the database and today.
    """

    /// Entry point for main.swift. Prints the result or the error and returns the exit code.
    public static func main(_ arguments: [String], environment: [String: String]) -> Int32 {
        var args = Array(arguments.dropFirst())
        var path = environment["TODO_DB"] ?? "todo.sqlite"
        if let i = args.firstIndex(of: "--db"), i + 1 < args.count {
            path = args[i + 1]
            args.removeSubrange(i...(i + 1))
        }
        do {
            let today = try environment["TODO_TODAY"].map(Day.init) ?? currentDay()
            let store = try Store.open(path: path, now: Store.systemNow)
            print(try run(args, store: store, today: today))
            return 0
        } catch let error as CLIError {
            print(error.description)
            return 2
        } catch {
            print("error: \(error)")
            return 1
        }
    }

    /// Today in the local time zone. The only place in the demo that asks the platform for the date.
    public static func currentDay() -> Day {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let parts = calendar.dateComponents([.year, .month, .day], from: Date())
        return Day(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    public static func run(_ args: [String], store: Store, today: Day) throws -> String {
        guard let command = args.first else { throw CLIError(usage) }
        let (positionals, options) = parse(Array(args.dropFirst()))
        let tagsByID = try tagIndex(store)
        switch command {
        case "add":
            let title = positionals.joined(separator: " ")
            guard !title.isEmpty else { throw CLIError("add needs a title") }
            var new = NewTask(title: title)
            new.when = try day(options["when"]?.last)
            new.deadline = try day(options["deadline"]?.last)
            new.notes = options["notes"]?.joined(separator: " ") ?? ""
            if let parent = options["parent"]?.last { new.parent = try resolveTask(parent, store).id }
            for name in options["tag"] ?? [] { new.tags.insert(try tag(named: name, store, create: true)) }
            let id = try store.createTask(new)
            return "added \(id) \(title)"
        case "list":
            let view = try resolveView(positionals.first ?? "Inbox", store)
            return Format.page(try store.page(of: view.id, today: today), tagsByID: tagsByID)
        case "views":
            return Format.views(try store.views())
        case "view":
            guard positionals.first == "add" else { throw CLIError("view supports: add") }
            let title = positionals.dropFirst().joined(separator: " ")
            guard !title.isEmpty else { throw CLIError("view add needs a title") }
            var new = NewView(title: title)
            if let json = options["filter"]?.last { new.filter = try Filter(json: json) }
            if let parent = options["parent"]?.last { new.parent = try resolveView(parent, store).id }
            new.sort = try (options["sort"] ?? []).map(sortKey)
            if let group = options["group"]?.last {
                guard let key = GroupBy(rawValue: group) else { throw CLIError("unknown group key \(group)") }
                new.groupBy = key
            }
            let id = try store.createView(new)
            return "added view \(id) \(title)"
        case "show":
            let task = try resolveTask(positionals.first, store)
            return Format.line(task, tagsByID: tagsByID) + "\n" + (try store.notes(of: task.id))
        case "done", "cancel", "reopen":
            let task = try resolveTask(positionals.first, store)
            let status: TaskStatus = command == "done" ? .done : (command == "cancel" ? .canceled : .open)
            try store.update(task: task.id, [.status(status)])
            return "\(command) \(task.id)"
        case "edit":
            let task = try resolveTask(positionals.first, store)
            var changes: [TaskChange] = []
            if let title = options["title"] { changes.append(.title(title.joined(separator: " "))) }
            if let when = options["when"]?.last { changes.append(.when(when == "none" ? nil : try day(when))) }
            if let deadline = options["deadline"]?.last { changes.append(.deadline(deadline == "none" ? nil : try day(deadline))) }
            if let notes = options["notes"] { changes.append(.notes(notes.joined(separator: " "))) }
            try store.update(task: task.id, changes)
            return "updated \(task.id)"
        case "move":
            let task = try resolveTask(positionals.first, store)
            guard let target = options["parent"]?.last else { throw CLIError("move needs --parent PID or none") }
            let parent = target == "none" ? nil : try resolveTask(target, store).id
            let placement: Placement = try options["after"]?.last.map { Placement.after(try resolveTask($0, store).id) } ?? .end
            try store.move(task: task.id, to: parent, at: placement)
            return "moved \(task.id)"
        case "tag", "untag":
            let task = try resolveTask(positionals.first, store)
            guard positionals.count >= 2 else { throw CLIError("\(command) needs ID and NAME") }
            let name = positionals[1...].joined(separator: " ")
            let tagID = try tag(named: name, store, create: command == "tag")
            if command == "tag" { try store.add(tag: tagID, to: task.id) } else { try store.remove(tag: tagID, from: task.id) }
            return "\(command == "tag" ? "tagged" : "untagged") \(task.id) \(name)"
        case "pin", "unpin":
            let task = try resolveTask(positionals.first, store)
            guard positionals.count >= 2 else { throw CLIError("\(command) needs ID and VIEW") }
            let view = try resolveView(positionals[1...].joined(separator: " "), store)
            if command == "pin" { try store.pin(task: task.id, in: view.id) } else { try store.unpin(task: task.id, from: view.id) }
            return "\(command == "pin" ? "pinned" : "unpinned") \(task.id) in \(view.title)"
        case "trash", "restore", "delete":
            let task = try resolveTask(positionals.first, store, includeTrashed: true)
            switch command {
            case "trash": try store.trash(task: task.id)
            case "restore": try store.restore(task: task.id)
            default: try store.delete(task: task.id)
            }
            let past = ["trash": "trashed", "restore": "restored", "delete": "deleted"][command] ?? command
            return "\(past) \(task.id)"
        case "find":
            let query = positionals.joined(separator: " ")
            var lines: [String] = []
            for hit in try store.quickFind(query) {
                switch hit {
                case .task(let task): lines.append("task  " + Format.line(task, tagsByID: tagsByID))
                case .tag(let tag): lines.append("tag   #\(tag.title)  (\(Format.short(tag.id)))")
                case .view(let view): lines.append("view  \(view.title)  (\(Format.short(view.id)))")
                }
            }
            for hit in try store.searchNotes(query) { lines.append("notes \(hit.task.title): \(hit.snippet)  (\(Format.short(hit.task.id)))") }
            return lines.isEmpty ? "nothing found" : lines.joined(separator: "\n")
        case "help", "--help", "-h":
            return usage
        default:
            throw CLIError("unknown command \(command)\n" + usage)
        }
    }

    // MARK: Parsing and resolution

    /// `--name value` pairs collect into options (repeatable); everything else is positional.
    static func parse(_ args: [String]) -> (positionals: [String], options: [String: [String]]) {
        var positionals: [String] = []
        var options: [String: [String]] = [:]
        var i = 0
        while i < args.count {
            let arg = args[i]
            if arg.hasPrefix("--"), i + 1 < args.count {
                options[String(arg.dropFirst(2)), default: []].append(args[i + 1])
                i += 2
            } else {
                positionals.append(arg)
                i += 1
            }
        }
        return (positionals, options)
    }

    static func day(_ text: String?) throws -> Day? {
        guard let text else { return nil }
        do { return try Day(text) } catch { throw CLIError(error.description) }
    }

    static func sortKey(_ text: String) throws -> SortKey {
        let parts = text.split(separator: ":")
        guard let field = SortField(rawValue: String(parts[0])) else { throw CLIError("unknown sort field \(parts[0])") }
        return SortKey(field, descending: parts.count > 1 && parts[1] == "desc")
    }

    static func resolveTask(_ prefix: String?, _ store: Store, includeTrashed: Bool = false) throws -> Task {
        guard let prefix, !prefix.isEmpty else { throw CLIError("a task ID is required") }
        let matches = try store.allTasks(includeTrashed: includeTrashed).filter { $0.id.rawValue.hasPrefix(prefix.lowercased()) }
        switch matches.count {
        case 1: return matches[0]
        case 0: throw CLIError("no task matches \"\(prefix)\"")
        default: throw CLIError("\"\(prefix)\" matches \(matches.count) tasks, add more characters")
        }
    }

    static func resolveView(_ text: String, _ store: Store) throws -> View {
        let views = try store.views()
        if let byTitle = views.first(where: { $0.title.lowercased() == text.lowercased() }) { return byTitle }
        let byPrefix = views.filter { $0.id.rawValue.hasPrefix(text.lowercased()) }
        guard byPrefix.count == 1 else { throw CLIError("no view matches \"\(text)\"") }
        return byPrefix[0]
    }

    static func tag(named name: String, _ store: Store, create: Bool) throws -> TagID {
        if let existing = try store.tags().first(where: { $0.title.lowercased() == name.lowercased() }) { return existing.id }
        guard create else { throw CLIError("no tag named \"\(name)\"") }
        return try store.createTag(title: name)
    }

    static func tagIndex(_ store: Store) throws -> [TagID: Tag] {
        var index: [TagID: Tag] = [:]
        for tag in try store.tags() { index[tag.id] = tag }
        return index
    }
}
```

`Sources/todo/main.swift`:

```swift
import TodoCLI
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#endif

exit(CLI.main(CommandLine.arguments, environment: ProcessInfo.processInfo.environment))
```

`exit` is a libc symbol, hence the second import block; `ProcessInfo` and `CommandLine` come from FoundationEssentials and the standard library.

- [ ] **Step 5: Run the tests, then the demo by hand**

```bash
swift test --filter TodoCLITests 2>&1 | tail -3
swift test --filter TodoCLITests --swift-sdk swift-6.3.3-RELEASE_wasm 2>&1 | tail -3
swift run todo --db /tmp/demo.sqlite add "Write the plan" --when 2026-09-11 --tag work
swift run todo --db /tmp/demo.sqlite list Today
swift run todo --db /tmp/demo.sqlite find plan
```

Expected: 4 tests pass on both platforms; the three commands print `added ...`, a Today page with the task, and a find hit. `swift run todo` uses the host build; on wasm32 the CLI is only built, for the size budget.

- [ ] **Step 6: Document the demo in the README**

Under `## Building`, add a `## Trying the core` section with the three commands above and the note that `TODO_DB` and `TODO_TODAY` override the database path and today.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources/TodoCLI Sources/todo Tests/TodoCLITests README.md
git commit -m "feat(core): add the todo command-line demo"
```

---

### Task 13: The wasm size budget, the macOS compile job, and the documentation that closes the epic

**Files:**
- Create: `scripts/wasm-size.sh`
- Modify: `.github/workflows/ci.yml` (from Task 1), `README.md`, `docs/process.md` (section 10), `CLAUDE.md` (toolchain note), `CHANGELOG.md`

**Interfaces:**
- Consumes: the whole package and the `core` job from Task 1.
- Produces: the wasm size as a number in every run, failing the job over budget; Apple SDK compile checks on pushes to `main` and manual runs.

- [ ] **Step 1: Write the size script and check it locally**

`scripts/wasm-size.sh`:

```sh
#!/bin/sh
# Builds the command-line demo for wasm32 in release mode and checks the gzip size against the M1 budget (spec, Testing and CI).
set -eu
BUDGET_BYTES=4718592   # 4.5 MiB
SDK="${WASM_SDK:-swift-6.3.3-RELEASE_wasm}"
swift build -c release --swift-sdk "$SDK" --product todo
WASM=.build/wasm32-unknown-wasip1/release/todo.wasm
RAW=$(wc -c < "$WASM" | tr -d ' ')
GZ=$(gzip -9 -c "$WASM" | wc -c | tr -d ' ')
echo "todo.wasm: $RAW bytes raw, $GZ bytes after gzip -9, budget $BUDGET_BYTES bytes"
if [ "$GZ" -gt "$BUDGET_BYTES" ]; then
  echo "wasm size is over budget"
  exit 1
fi
```

```bash
chmod +x scripts/wasm-size.sh
scripts/wasm-size.sh
```

Expected: a line with the sizes and exit code 0. The measured value on 2026-09-11 for the smoke executable was 3,743,306 bytes after gzip; the full core should land near 4 MB.

- [ ] **Step 2: Extend the workflow**

Two additions to `.github/workflows/ci.yml` from Task 1. First, a last step in the `core` job:

```yaml
      - name: Release wasm build and size budget
        run: scripts/wasm-size.sh
```

Second, a new job after `core`:

```yaml
  apple:
    # macOS minutes cost tenfold, so this job runs on main and on demand, not on every pull request.
    name: Compile for the iOS and watchOS SDKs
    if: github.event_name != 'pull_request'
    runs-on: macos-26
    steps:
      - uses: actions/checkout@v4

      - name: Cache the toolchain
        uses: actions/cache@v4
        with:
          path: |
            ~/.swiftly
            ~/Library/Developer/Toolchains
          key: swiftly-${{ runner.os }}-${{ hashFiles('.swift-version') }}-v1

      - name: Install swiftly and the pinned toolchain
        run: |
          set -eu
          if [ ! -x "$HOME/.swiftly/bin/swiftly" ]; then
            curl -fsSL -O https://download.swift.org/swiftly/darwin/swiftly.pkg
            installer -pkg swiftly.pkg -target CurrentUserHomeDirectory
            "$HOME/.swiftly/bin/swiftly" init --quiet-shell-followup --assume-yes --skip-install --no-modify-profile
          fi
          . "$HOME/.swiftly/env.sh"
          swiftly install
          echo "$HOME/.swiftly/bin" >> "$GITHUB_PATH"

      - name: Compile the core for iOS
        run: swift build --target TodoCore --triple arm64-apple-ios17.0 --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"

      - name: Compile the core for watchOS
        run: swift build --target TodoCore --triple arm64_32-apple-watchos10.0 --sdk "$(xcrun --sdk watchos --show-sdk-path)"
```

Rename the `core` job to `Build, test, wasm32, size budget`. If the `macos-26` label is not available when the workflow first runs, use the newest macOS image that ships Xcode 26.3 and add `sudo xcode-select -s /Applications/Xcode_26.3.app` before the compile steps. The job is not on the PR path, so a wrong label cannot block merges; fix it in the same PR once the first `main` run shows the available images.

- [ ] **Step 3: Update the documents**

- `README.md`: a `## Continuous integration` section: what the Linux job does on every PR (build, tests, wasm32 tests, size budget), that the macOS job runs on `main` and on demand, and the wasm budget line.
- `docs/process.md` section 10: replace the first paragraph with the split between the Linux job (build, host tests, wasm tests, size budget, every PR) and the macOS job (Apple SDK compile checks, `main` and manual runs), keep the cost constraint paragraph.
- `CLAUDE.md`, toolchain notes: replace "CI runs on macOS runners, which cost 10x minutes on a private repository. Keep CI lean." with "CI: the Linux job (build, tests, wasm32 tests, wasm size budget) runs on every PR; the macOS job (iOS and watchOS SDK compile checks) runs only on `main` and on demand because macOS minutes cost tenfold."
- `CHANGELOG.md`, `[Unreleased]`: one line for the size budget and the macOS job; check that every earlier task added its line.

- [ ] **Step 4: Open the PR and watch the first run**

```bash
git add scripts/wasm-size.sh .github/workflows/ci.yml README.md docs/process.md CLAUDE.md CHANGELOG.md
git commit -m "ci: add the wasm size budget and macOS compile checks on main"
git push -u origin ci/23-size-budget-and-macos
gh pr create --label infra --title "ci: add the wasm size budget and macOS compile checks" --body "<per the PR template, ending with Closes #23>"
gh run watch
```

Expected: the `core` job green on the PR; after the squash merge, the `apple` job green on `main`. Paste the size line from the run into the PR body.

---

## Sub-issues for the epic

Approved by the owner on 2026-09-11. Each row is a sub-issue of epic #4 in milestone `M1 Core architecture`, in this order; a task's PR ends with `Closes #<issue>`.

| # | Issue | Title | Labels | Depends on |
| - | ----- | ----- | ------ | ---------- |
| 1 | #11 | Package skeleton with vendored SQLite, wasm32 smoke tests and the Linux CI job | `infra`, `core` | |
| 2 | #12 | SQLiteKit: typed wrapper over the vendored SQLite | `feature`, `core` | 1 |
| 3 | #13 | Value types: identifiers, calendar days, hybrid logical clocks, order keys | `feature`, `core` | 1 |
| 4 | #14 | Schema version 1, migrations, store opening and snapshots | `feature`, `core` | 2, 3 |
| 5 | #15 | Operation journal and last-write-wins apply | `feature`, `core` | 4 |
| 6 | #16 | Task tree: effective parent and inherited trash | `feature`, `core` | 5 |
| 7 | #17 | Task and tag write API and reads | `feature`, `core` | 6 |
| 8 | #18 | Filters: model, JSON format, SQL compiler, sort keys | `feature`, `core` | 7 |
| 9 | #19 | Views: nesting, built-in views, manual lists, pages | `feature`, `core` | 8 |
| 10 | #20 | Search: quick find over titles, ranked search in notes | `feature`, `core` | 9 |
| 11 | #21 | Sync skeleton: journal export, receive, in-memory relay, convergence test | `feature`, `core` | 9 |
| 12 | #22 | The todo command-line demo | `feature`, `core` | 10, 11 |
| 13 | #23 | Wasm size budget, macOS compile checks and closing documentation | `infra`, `core` | 12 |

Tasks 10 and 11 are independent of each other and can run in parallel after 9.

## Self-review against the spec

Coverage, section by section of `docs/specs/core-storage-and-search.md`:

- Sync model, journal, clocks, apply rule, unknown fields, sync skeleton: Tasks 3, 5, 11. The two-store convergence test is `twoStoresConvergeAfterConcurrentEditsAndLaterEditsWin`.
- Storage engine, vendored amalgamation, compile flags, the only C dependency: Task 1. Persistence per platform: file with WAL and in-memory with `serialize`/`deserialize` in Tasks 2 and 4; the browser-side delay and IndexedDB write belong to the web UI, outside this plan, and the core's `snapshot()` plus the change set are the whole interface it needs.
- Search, two indexes, tokenizers, short-query fallback, ranking, snippets: Tasks 4 (DDL) and 10.
- Data model, flat tasks with parent, tags, views nested to any depth, manual lists, built-in views with fixed ids, days as day counts, order keys, parent links after a merge: Tasks 3, 6, 7, 9.
- Filters, sorting, grouping, implicit trash exclusion, "view needs a newer app": Tasks 8 and 9.
- Trash and hierarchy computed at read time: Task 6.
- Platform boundary: `now` injected (Task 4), `today` per query (Tasks 8 and 9), no timers, observer after commit (Task 5).
- Migrations with `user_version` and replay: Tasks 4 and 5.
- Concurrency and API shape, typed errors, no Swift concurrency: every task; `StoreError` in Task 4.
- Testing on host and wasm32 and the Linux CI job: Task 1; CLI demo: Task 12; size budget and the macOS job: Task 13.
- Risks: FoundationEssentials on WASI and SQLite on wasm32 in full mode were verified by hand on 2026-09-11 and are re-verified by Task 1; the fake clock under WasmKit is a global constraint.

Deviations from the spec, each small and stated where it happens:

- Logbook is not grouped by day in the core (Task 9, Step 7 edits the spec): the core has no time zone to turn a completion timestamp into a day.
- Pages nest one level: a child view's own children flatten into its section (Task 9). Deeper nesting is visible when the child is opened.
- A task with several tags is grouped under its smallest tag id (Task 9); the UI may regroup.
- The "Cost" paragraph's `EXPLAIN QUERY PLAN` test for built-in views is not a separate task: add it to `QueryTests` in Task 9 as `builtInViewsUseIndexes`, asserting that the plan of each built-in view's SQL contains no `SCAN tasks` line, once the queries exist. If a plan does scan, add the composite index the plan names, in the same PR.

Type and name consistency checked across tasks: `Store.op(_:_:_:_:_:)` (Task 5) is used unchanged in Tasks 6, 7, 9 and 11; `loadTasks(where:_:orderBy:join:limit:)` (Task 7) in Tasks 9 and 10; `siblingRank(table:parent:placement:excluding:)` (Task 7) in Task 9; `TreeRules.effectiveParents` (Task 6) in Tasks 7 and 9; `FilterCompiler.whereClause` and `orderBy` (Task 8) in Task 9; `BuiltInViews` ids (Task 9) in Tasks 10 to 12; `SortKey.json`/`parse` (Task 8) in Task 9.
