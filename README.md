# todo-app

A reminders app in the spirit of Things 3, with one shared core and native UI per platform.

- Target platforms: iOS, macOS, iPadOS, watchOS, and the web via WASM.
- The shared core is written in Swift and restricted to the standard library and FoundationEssentials, so that it compiles for every target above (ADR-0001).
- UI is platform-specific: SwiftUI is the likely choice for Apple platforms, React for the web. Both are decided during implementation.

## Status

Milestone `M0 Process` is complete: the project process is defined and the repository is set up. There is no product code yet; `M1 Core architecture` is next.

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
swift test --swift-sdk swift-6.3.3-RELEASE_wasm   # the same suite on wasm32 under WasmKit
swift run todo --help                # command-line demo
```

The WebAssembly SDK is installed once with `swift sdk install <url> --checksum <sha256>`; the URL and checksum are in `.github/workflows/ci.yml`.

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
