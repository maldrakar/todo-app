# ADR-0007: Keep feature modules in the root package as shared code, and every platform host in a package under `Apps/`

- Status: Accepted
- Date: 2026-09-20
- Related: `docs/specs/feature-module-architecture.md` (approved 2026-09-20), `docs/specs/navigation.md` (approved 2026-10-14), #63, #67, ADR-0001, ADR-0006, ADR-0009
- Amended: 2026-10-14, after the approval of the navigation spec (see the end)

## Context

Feature modules (ADR-0006) are pure Swift and have to build and test wherever the core does, on the host, on wasm32 under WasmKit and against the Apple SDKs. The Apple app imports SwiftUI, which builds neither on the Linux job nor for wasm32, and `swift test` builds every target of a package, so one Apple target in the root package would break both checks M1 set up. The spec's section 6 holds the discussion.

## Decision

Everything that runs everywhere lives in the root package: `TodoCore`, the `FeatureModule` target holding the module protocols and nothing else, one SwiftPM target per feature module under `Sources/Features/`, the root module, and one test target per feature, all obeying ADR-0001: a feature imports `TodoCore`, the standard library and FoundationEssentials under the `canImport` guard, and nothing else, with the wasm build in CI as the enforcement. Children depend neither on each other nor on the root; the dependency graph is written in the manifest. Everything that runs on one platform lives in a package under `Apps/` that depends on the root by a local path: `Apps/Apple` holds the SwiftUI views, the host, the composition root and the executables, and the web host will live in `Apps/Web` in the same arrangement. The wasm size probe drives the root module, since a web client ships it with the core.

Alternatives. One package holding the Apple targets too lost because a SwiftUI import fails on the Linux job and under wasm32. One `TodoFeatures` target for every module lost because the boundary between features would hold by discipline instead of by the manifest.

## Consequences

Easier: `internal` means "inside this feature"; the Linux job and the WasmKit run pick new features up unchanged; the future Xcode project and the web host each sit beside the package they belong to.

Harder: two targets per feature in the manifest; `swift test` in `Apps/Apple` builds the root package's targets a second time into its own `.build`; the size ceiling moves whenever a module joins the probe.

Constrained: no UI import in the root package, ever; no feature target reaches another feature's internals; a platform package never holds logic that a module could hold. Reversing this decision is a move of files and manifest entries, cheap at any time.

## Amendment, 2026-10-14

Made with the approval of the navigation spec, `docs/specs/navigation.md`, section 4, which ADR-0009 records. The decision above gave the `FeatureModule` target the module protocols and nothing else. The shared form of a parent now lives beside them: the protocol of an addressed module and the generic seat a parent holds each child in, which create a child from a route with the store and so need `Store` and `StoreError`. The target therefore depends on `TodoCore`, which every feature depends on already, and holds what every parent needs and nothing of any one feature. The rest of the decision holds: one target per feature, children that depend neither on each other nor on the root, and the hosts under `Apps/`.
