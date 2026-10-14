# todo-app

A reminders app in the spirit of Things 3, with one shared core and native UI per platform.

- Target platforms: iOS, macOS, iPadOS, watchOS, and the web via WASM.
- The shared core is written in Swift and restricted to the standard library and FoundationEssentials, so that it compiles for every target above (ADR-0001).
- UI is platform-specific: SwiftUI is the likely choice for Apple platforms, React for the web. Both are decided during implementation.

## Status

Milestones `M0 Process` and `M1 Core architecture` are complete, the second released as `v0.1.0`. The core
stores tasks, tags and views, resolves the tree their parent links describe, filters, sorts and groups them
into pages, searches titles and notes, and exchanges a journal with another copy of itself; it builds and
passes its suite on the host and on wasm32, and `todo` drives all of it from a command line.
`M2 Feature-module architecture`, not yet released, has built the module contract in the shared core, the list
of views and the root module over it, which pass their suites on the host and on wasm32 as the core does, and
the macOS app in `Apps/Apple` that hosts them.

## Documents

- [`docs/brief.md`](docs/brief.md): the original project brief.
- [`docs/process.md`](docs/process.md): how the project is run, from backlog to release.
- [`docs/adr/`](docs/adr/): architecture decision records.
- [`docs/specs/`](docs/specs/): design specs. [`docs/plans/`](docs/plans/): implementation plans.
- [`CHANGELOG.md`](CHANGELOG.md): what changed in each version.

## Building

The core is a SwiftPM package built with the swift.org toolchain pinned in `.swift-version` and installed through [swiftly](https://www.swift.org/install/); Xcode only supplies the Apple SDKs.

```sh
swiftly install                      # reads .swift-version
swift build
swift test                           # host
swift test --swift-sdk swift-6.3.3-RELEASE_wasm --disable-xctest   # the same suite on wasm32 under WasmKit
swift run todo --help                # command-line demo
scripts/wasm-size.sh                 # release wasm build, measured against the size budget
```

The WebAssembly SDK is installed once with `swift sdk install <url> --checksum <sha256>`; the URL and checksum are in `.github/workflows/ci.yml`.

`--disable-xctest` skips nothing, since every test here is swift-testing. It keeps the wasm32 run working on macOS when `--filter` is added: to filter, SwiftPM there lists the XCTest cases through Xcode's `swiftpm-xctest-helper`, which cannot load a bundle built for wasm32 (#76).

## Trying the core

`todo` is the command-line demo of the core and the runnable part of `M1`: every command goes through the
public API of `TodoCore` and prints one fact per line.

```sh
export TODO_DB=/tmp/demo.sqlite
swift run todo add "Write the plan" --when 2026-09-11 --tag work --notes "before the review"
swift run todo list Today
swift run todo find plan
swift run todo --help                # every command, with its options
```

A task is named by any prefix of its id that names a single task and a view by its title or by a prefix of
its id, and every line that names one of them ends with the id to type next; a tag is named by its name. An
option a command does not take, one with no value, and a word left over from a value that lost its quotes
are all refused by name rather than folded into a title. `TODO_DB` says which database to open and
`--db PATH` outranks it; without either, the demo opens `todo.sqlite` in the working directory.
`TODO_TODAY=YYYY-MM-DD` says what day the query is made on, so that `Today` and `Upcoming` answer the same
thing when the demo is run again tomorrow. A command the demo refuses exits 2, one the core refuses exits 1.

Beside the database the demo keeps one more file, `<database>.device`, holding the device this copy writes
under. It is not in the database on purpose: a database carries its contents to every machine it is copied
to, and the journal needs two copies of one database to be two devices, or they stop seeing each other's
edits. So copy `demo.sqlite` on its own and the copy becomes a device of its own; copy the pair and both
machines claim one identity. `TODO_DEVICE` names it instead, which is how one machine plays two.

## Running the app

`todo-mac` is the macOS app and the runnable part of `M2`. It lives in `Apps/Apple`, a package of its own beside
the root one, because the root package is built on Linux and for wasm32, where there is no SwiftUI (ADR-0007);
swiftly finds the root's `.swift-version` from there, so it builds with the same pinned toolchain.

```sh
cd Apps/Apple
swift run todo-mac
# in a second terminal, also in Apps/Apple: another database, another device
TODO_DB=/tmp/second.sqlite swift run todo-mac
```

It opens one window: the list of views in a sidebar, and beside it the title of the view chosen there. Rename,
in a row's context menu, opens a field on the row: Return or a click away keeps the new title, a blank one is
refused with a sentence under the list, and Esc keeps the old title. New Folder, on the toolbar, adds a folder at
the end of the top level, chosen and with its field open.

`TODO_DB` is the database's whole path and `TODO_DEVICE` the device it is written under, each read as unset when
it is exported empty. Without `TODO_DB` the app opens `~/Library/Application Support/todo/todo.sqlite`, and the
first launch creates the directory and the database; the directory is named for the app because the app has no
bundle whose identifier could name it. Without `TODO_DEVICE` the device is the one kept in `<database>.device`
beside the database, the same file the demo keeps, and a launch that finds none there mints one and keeps it. So
two copies of the app on one machine, each over a database of its own as above, are two devices. A launch that
fails, for example over a path that cannot be opened, stops the process with "The app could not launch:" and the
reason.

## Continuous integration

Every pull request runs one Linux job: build, the suite on the host, the same suite on wasm32 under WasmKit,
and a release wasm build measured against a size budget.

What that last step measures is `wasm-size-probe`, an executable that exists to be measured and is no part of
the product. The budget is about what a web client downloads, and the `todo` demo is the wrong stand-in for
one: it carries an argument parser, a formatter and a usage text no browser will ever load. The probe instead
does what a web entry point will: it builds the root module over a store in memory and drives it — choose a
view, rename it, make a folder — and beside it calls the public API of `TodoCore` directly — write through a
store, read a page, search, exchange a journal, take a snapshot — because the linker keeps what a client calls,
and a number measured on calls that were dead-stripped is a number for a binary nobody ships.

The budget is 6.5625 MiB after `gzip -9` and lives in one place, `scripts/wasm-size.sh`, which is the command
CI runs and the command to run locally. It is the root module and the core as they stand with four percent to
spare, rounded up to a whole 64 KiB: a guard against growing sideways, not a target to shrink towards. The
4.5 MiB the spec first named was never measured — it is the floor measured in the toolchain spike, 3,743,306
bytes of standard library, FoundationEssentials and SQLite with no core code reachable, plus half a megabyte of
slack for the code the core would add. That code, with the JSON coding it pulls in, costs 2.8 MB instead, and
SQLite and FoundationEssentials are inside the floor on both sides of the comparison rather than the difference
between them. The ceiling that means something arrives with the web client, measured on its bundle.

A second job, on a macOS runner, compiles `TodoCore`, and `TodoAppleUI` from `Apps/Apple`, against the iOS and
watchOS SDKs, and builds and tests `Apps/Apple` with the pinned toolchain. It then builds the root package and
`Apps/Apple` with the toolchain of Xcode 26.3 too, the Xcode the app is built with and the one Apple accepts
store builds from, and keeps doing so until the Xcode project brings the two to one (ADR-0008). It runs on
`main` and on demand, never on a pull request, because macOS minutes cost tenfold on a private repository.
