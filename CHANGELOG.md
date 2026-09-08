# Changelog

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Version numbers follow the milestone numbering described in `docs/process.md`.

## [Unreleased]

### Added

- ADR-0001: the core is full Swift on the standard library and FoundationEssentials, replacing the brief's Embedded Swift requirement after the toolchain spike (#3). `.swift-version` pins Swift 6.3.3 for swiftly.

### Changed

- `docs/process.md` status set to Approved v1 after the owner's review.
- README, `CLAUDE.md`, the process document's M1 examples and the M1 milestone description follow ADR-0001.

## [0.0.0] - 2026-09-07

### Added

- Project process in `docs/process.md`: roles, backlog in GitHub Issues and Milestones, task lifecycle, spec review flow, ADRs, increment closing, CI constraints.
- Repository bootstrap: README, `CLAUDE.md`, ADR and spec templates, issue and PR templates.
- GitHub setup: labels, milestones M0 to M3, first M1 issues.
