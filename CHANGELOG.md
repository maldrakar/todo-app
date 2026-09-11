# Changelog

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Version numbers follow the milestone numbering described in `docs/process.md`.

## [Unreleased]

### Added

- Implementation plan `docs/plans/core-storage-and-search.md`: thirteen tasks that became sub-issues #11 to #23 of epic #4. ADR-0002 (vendored SQLite), ADR-0003 (operation journal with last-write-wins per field) and ADR-0004 (flat model with filter-defined views) extracted from the spec.
- Spec `docs/specs/core-storage-and-search.md`, approved by the owner on 2026-09-11: local-first core with an operation journal for a future sync, vendored SQLite on every platform, a flat model of tasks, tags and nested views with filters, FTS5 search over titles and notes.
- ADR-0001: the core is full Swift on the standard library and FoundationEssentials, replacing the brief's Embedded Swift requirement after the toolchain spike (#3). `.swift-version` pins Swift 6.3.3 for swiftly.

### Changed

- `docs/process.md` status set to Approved v1 after the owner's review.
- README, `CLAUDE.md`, the process document's M1 examples and the M1 milestone description follow ADR-0001.

## [0.0.0] - 2026-09-07

### Added

- Project process in `docs/process.md`: roles, backlog in GitHub Issues and Milestones, task lifecycle, spec review flow, ADRs, increment closing, CI constraints.
- Repository bootstrap: README, `CLAUDE.md`, ADR and spec templates, issue and PR templates.
- GitHub setup: labels, milestones M0 to M3, first M1 issues.
