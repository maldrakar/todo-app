# Changelog

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Version numbers follow the milestone numbering described in `docs/process.md`.

## [Unreleased]

### Added

- The core value types in `TodoCore`: `EntityID`, which mints a lowercase UUID when constructed without an argument, with its `TaskID`/`TagID`/`ViewID` aliases; `Day`, a time-zone-free calendar day in plain integer arithmetic that parses strict `YYYY-MM-DD` and throws `DayParseError` on anything else; `HLC` with `HybridClock`, whose stamps never go backwards on a device, never fall behind a device they have seen, and borrow the next millisecond instead of overflowing the counter; and `Rank`, fractional order keys that insert without renumbering and read a neighbour they cannot use as no neighbour, the way a merge's leftovers are tolerated elsewhere. The `CoreSmoke` placeholder is gone: its SQLite version pin and its Cyrillic trigram check moved to `SQLiteKitTests`, and the rest of what it proved is exercised by the schema from Task 4 on.
- `SQLiteKit`, a typed wrapper over the vendored SQLite: `Connection`, `Statement`, `Value` and `SQLiteError` with typed throws, transactions, user version, `lastInsertRowID`, `changes` and the snapshot pair `serialize`/`deserialize`. Because the vendored build has threads off, the wrapper also performs SQLite's one-time library initialization once before the first connection opens, and the `TodoCore` placeholder now goes through the wrapper instead of the C API.
- Package skeleton for the `TodoCore` SwiftPM package: vendored SQLite 3.53.4 amalgamation as the `CSQLite` target with its provenance and upgrade steps recorded in `Sources/CSQLite/README.md`, placeholder `SQLiteKit`/`TodoCore`/`todo` targets, smoke tests proving UUID, timers and FTS5 trigram search work on both the host and wasm32 under WasmKit, and the Linux CI job that runs them.
- Implementation plan `docs/plans/core-storage-and-search.md`: thirteen tasks that became sub-issues #11 to #23 of epic #4. ADR-0002 (vendored SQLite), ADR-0003 (operation journal with last-write-wins per field) and ADR-0004 (flat model with filter-defined views) extracted from the spec.
- Spec `docs/specs/core-storage-and-search.md`, approved by the owner on 2026-09-11: local-first core with an operation journal for a future sync, vendored SQLite on every platform, a flat model of tasks, tags and nested views with filters, FTS5 search over titles and notes.
- ADR-0001: the core is full Swift on the standard library and FoundationEssentials, replacing the brief's Embedded Swift requirement after the toolchain spike (#3). `.swift-version` pins Swift 6.3.3 for swiftly.

### Changed

- `docs/process.md` and `CLAUDE.md` record when the full process document is read instead of the digest: only `CLAUDE.md` is in the engineer's context by default, so the document is opened before architectural work, a spec review or the close of an increment, and whenever the digest is thin. A rule is never written in the digest alone.
- `docs/process.md` and `CLAUDE.md` record how reactions triage review comments: the reaction is left by the comment's recipient, the engineer now reacts to the owner's comments as well, 👀 marks a thread that is still being argued, and only 👍 threads are implemented.
- ADR-0002 records what threads-off SQLite costs at startup: the mutex around the library's one-time initialization is compiled out with the rest, so `SQLiteKit` performs that initialization once before any connection opens and nothing outside it may call the C API.
- `docs/process.md` status set to Approved v1 after the owner's review.
- README, `CLAUDE.md`, the process document's M1 examples and the M1 milestone description follow ADR-0001.

## [0.0.0] - 2026-09-07

### Added

- Project process in `docs/process.md`: roles, backlog in GitHub Issues and Milestones, task lifecycle, spec review flow, ADRs, increment closing, CI constraints.
- Repository bootstrap: README, `CLAUDE.md`, ADR and spec templates, issue and PR templates.
- GitHub setup: labels, milestones M0 to M3, first M1 issues.
