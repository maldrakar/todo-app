# ADR-0001: Build the core in full Swift on the standard library and FoundationEssentials

- Status: Proposed
- Date: 2026-09-08
- Related: #3 (toolchain spike, with the measurements), #4 (core architecture)

## Context

The brief requires the shared core to be Embedded Swift compiled for iOS, macOS, iPadOS, watchOS and WASM. The toolchain spike (#3) showed that this cannot be done as written and that it costs more than it returns:

- No released toolchain (6.2.x, 6.3.3, `main`) ships an embedded standard library for watchOS or for any simulator, and Xcode's toolchain ships none at all.
- A module built in embedded mode cannot be imported by full Swift, so SwiftUI would reach the core only through a C ABI, for no size benefit on Apple platforms, where the app links the full runtime anyway.
- The embedded subset removes what a reminders core needs most: `Date`, `Calendar` and `TimeZone`, `Codable`, existentials and untyped errors, float formatting, string processing, and in Swift 6.2.1 any usable concurrency.
- Measured WASM sizes after gzip: embedded 88 KB, full standard library 1.6 MB, standard library plus FoundationEssentials 3.4 MB, full Foundation with ICU 18.5 MB.

The owner agreed in chat on 2026-09-08 to replace the Embedded Swift requirement of the brief with the decision below.

## Decision

The core is an ordinary SwiftPM package in full Swift. Apple targets are built with the Xcode toolchain; the web target is built for `wasm32-unknown-wasip1` with the swift.org toolchain and its Swift SDK, both pinned through swiftly. Core modules depend only on the standard library and the FoundationEssentials API surface: on Apple platforms they import `Foundation`, on WASM `FoundationEssentials`, selected with `#if canImport(FoundationEssentials)`. Nothing from FoundationInternationalization or any other ICU-backed API is used in the core; locale-aware formatting belongs to the UI layers. The WASM build in CI is the enforcement: an API outside FoundationEssentials does not compile there.

Alternatives considered. Embedded Swift on every platform, as in the brief, lost because it is not buildable for watchOS and the simulators and forces a C boundary on Apple platforms. Embedded Swift for WASM only, with full mode elsewhere, lost because the source would still have to satisfy the embedded subset, so the cost stays the same while the win shrinks to the web bundle size. Full Foundation lost because its ICU data makes the web build 18.5 MB.

## Consequences

Easier: SwiftUI imports the core directly; watchOS and the simulators are ordinary targets; `Codable`, `Date`, `Calendar`, `UUID` and JSON are available; swift-testing runs the same suite on macOS and, through WasmKit, on wasm32; Xcode alone builds everything except the web target.

Harder: the web bundle is 1.6 to 3.4 MB after gzip instead of under 100 KB; the WASM Swift SDK must match the swift.org toolchain version exactly; `Int` is 32-bit on wasm32, so identifiers and timestamps are `Int64` explicitly.

Constrained: no `import Foundation` in core modules without the `canImport` guard, no ICU-backed API in the core, and the M1 plan sets a size budget for the WASM build that CI reports against. Reversing this decision towards Embedded Swift would mean rewriting date and calendar logic, serialisation and error handling, and adding a C ABI layer; nothing else in the design prevents it.
