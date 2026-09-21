# ADR-0008: Build the Apple app as a two-line `@main` over a library with SwiftPM alone, until the store needs an Xcode project

- Status: Proposed
- Date: 2026-09-20
- Related: `docs/specs/feature-module-architecture.md` (approved 2026-09-20), #63, ADR-0001, ADR-0007

## Context

The core has no Xcode project and is built by SwiftPM with the swift.org toolchain pinned in `.swift-version` (ADR-0001). M2 needs a runnable macOS app to prove the module contract, and later milestones need iOS, watchOS and App Store builds, which only an Xcode project with an app target can produce, and which Apple accepts from Xcode's own toolchain. Verified on 2026-09-20: a SwiftUI app builds and launches from a bare SwiftPM executable target whose `Scene` lives in a library target; the root package builds with Xcode 26.3's Swift 6.2.4 without a change; swiftly honours `.swift-version` from a parent directory. The spec's section 6 holds the discussion.

## Decision

The Apple app is built by SwiftPM alone. The executable target is a `@main` structure of two lines whose scene comes from the `TodoAppleUI` library, and everything else, the views, the host, the composition root and the scene, lives in that library. An Xcode project arrives when iOS, watchOS or the store needs a bundle, and it is a thin shell: an app target with `@main`, Info.plist, assets, entitlements and signing, importing the same library, while development stays in the packages. Until that project arrives the code builds with both the pinned toolchain and Xcode's, and the macOS job checks the second on `main`; when it arrives, the pinned version and Xcode's are brought to one so that a single toolchain builds everything.

Alternatives. An Xcode project from M2 lost because it puts a second build system into the milestone whose point is the module contract. iOS first lost because SwiftPM cannot produce an iOS bundle, so it is the project first.

## Consequences

Easier: `swift run todo-mac` opens the app; the macOS job builds and tests it with the commands a laptop runs; the executable and the future app target differ by nothing but their shell.

Harder: without a bundle there is no icon, no Info.plist, no App Group and no sandbox, and the window may need the application activated at launch to take focus; a language feature of the pinned toolchain that Xcode's lacks breaks the store build, which the job on `main` is there to catch; the composition has to be held once per launch by something other than a SwiftUI `@State`, whose initial value is evaluated on every creation of its struct.

Constrained: nothing in `TodoAppleUI` may depend on being inside a bundle until the project exists; every commit builds with both toolchains. Reversing this decision is adding the project earlier, which is cheap and changes nothing in the library.
