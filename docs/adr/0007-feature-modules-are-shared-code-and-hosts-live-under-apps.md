# ADR-0007: Keep feature modules in the root package as shared code, and every platform host in a package under `Apps/`

- Status: Accepted
- Date: 2026-09-20
- Related: `docs/specs/feature-module-architecture.md` (approved 2026-09-20), `docs/specs/navigation.md` (approved 2026-10-14), `docs/specs/navigation-state.md` (approved 2026-10-22), `docs/specs/lists-screen.md` (approved 2026-10-25), #63, #67, #100, #117, #142, #151, ADR-0001, ADR-0006, ADR-0009
- Amended: 2026-10-14, after the approval of the navigation spec, 2026-10-15, after the owner's review of #100, 2026-10-22, after the approval of the navigation state spec, and 2026-10-26, after the owner's review of #151 (see the end)

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

## Amendment, 2026-10-15

Made in the owner's review of #100, the pull request that built the shared form of a parent. The dependency on `TodoCore` that the amendment of 2026-10-14 gave the `FeatureModule` target is withdrawn. A seat is created by its parent with the way to make its child, a closure over the child's own `init` that takes the route and whatever that child needs, so the contract names no dependency, and a screen that needs none, or needs others than the store, needs nothing from it. A module's `init` is no longer a requirement of the contract; it stays where a screen that cannot read what it shows refuses to be made, and the seat throws what that refusal throws. The target holds the module protocols and the seat, and depends on nothing. The amendment of 2026-10-14 stays as it was written, and the rest of the decision holds.

## Amendment, 2026-10-22

Made with the approval of `docs/specs/navigation-state.md` (#117), which ADR-0009's amendment of the same day records. The amendment of 2026-10-15 left the `FeatureModule` target the module protocols and the seat. Beside them it now holds `ScreenStack`, the flat stack a flow holds the screens open over its base in, the id of an element of it, and the protocol of a flow's enum of screens: what every flow needs and nothing of any one screen. None of them names a screen, and the target still depends on nothing. The rest of the decision holds.

## Amendment, 2026-10-26

Made in the owner's review of #151, the pull request that built the look of the Lists screen for every screen after it (#142). Section 9 of `docs/specs/lists-screen.md` put the look into `TodoAppleUI`, and the plan's first task built it there as SwiftUI constants. The owner's point was that nothing about the look is a platform's except turning it into pixels: the palette, the rule that shades a list's colour and the type are the same values on the web, and the decision above already says a platform package never holds logic that a shared module could hold.

The root package therefore holds a `DesignSystem` target with the look's values and rules behind one entry point, `DesignSystem.color`, `DesignSystem.font` and `DesignSystem.motion`: the palette, with the bases of the list colours and the rule that derives a list's tile and glyph from its base; the type as text styles, a weight and a face, so that it follows the size a person sets; the motion; and the icon set by the names the store keeps. It imports nothing but the standard library and `TodoCore`, and `TodoCore` for `TaskViewColor` alone, so that the table of shades is keyed by the core's own names; a design system that depends on nothing, with its own copy of the eleven names and a mapping between the two, lost because the two lists would agree by discipline only. It is built and tested on the host and on wasm32 like every target of the root package, and stays outside the wasm size probe until a web host draws with it.

A platform package holds only the renderers that turn the design system's values into the platform's, on Apple initializers of `Color`, `Font`, `Animation` and `Image`, and the views that draw with them, such as a list's tile; a view takes every colour, font and animation it draws with from the design system through them. Feature modules do not import it: a module carries a list's colour and icon as the core names them, and the platform's view draws them. The rest of the decision holds.
