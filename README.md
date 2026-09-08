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

Nothing to build yet. Build instructions arrive with the first core package in M1.
