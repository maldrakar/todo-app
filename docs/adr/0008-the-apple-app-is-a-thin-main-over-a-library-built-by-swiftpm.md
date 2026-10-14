# ADR-0008: Build the Apple app as a two-line `@main` over a library with SwiftPM alone, until the store needs an Xcode project

- Status: Accepted
- Date: 2026-09-20
- Related: `docs/specs/feature-module-architecture.md` (approved 2026-09-20), `docs/specs/navigation.md` (approved 2026-10-14), #63, #67, #81, ADR-0001, ADR-0007, ADR-0009
- Amended: 2026-10-13, after the owner's review of #81, and 2026-10-14, after the approval of the navigation spec (see the end)

## Context

The core has no Xcode project and is built by SwiftPM with the swift.org toolchain pinned in `.swift-version` (ADR-0001). M2 needs a runnable macOS app to prove the module contract, and later milestones need iOS, watchOS and App Store builds, which only an Xcode project with an app target can produce, and which Apple accepts from Xcode's own toolchain. Verified on 2026-09-20: a SwiftUI app builds and launches from a bare SwiftPM executable target whose `Scene` lives in a library target; the root package builds with Xcode 26.3's Swift 6.2.4 without a change; swiftly honours `.swift-version` from a parent directory. The spec's section 6 holds the discussion.

## Decision

The Apple app is built by SwiftPM alone. The executable target is a `@main` structure of two lines whose scene comes from the `TodoAppleUI` library, and everything else, the views, the host, the composition root and the scene, lives in that library. An Xcode project arrives when iOS, watchOS or the store needs a bundle, and it is a thin shell: an app target with `@main`, Info.plist, assets, entitlements and signing, importing the same library, while development stays in the packages. Until that project arrives the code builds with both the pinned toolchain and Xcode's, and the macOS job checks the second on `main`; when it arrives, the pinned version and Xcode's are brought to one so that a single toolchain builds everything.

Alternatives. An Xcode project from M2 lost because it puts a second build system into the milestone whose point is the module contract. iOS first lost because SwiftPM cannot produce an iOS bundle, so it is the project first.

## Consequences

Easier: `swift run todo-mac` opens the app; the macOS job builds and tests it with the commands a laptop runs; the executable and the future app target differ by nothing but their shell.

Harder: without a bundle there is no icon, no Info.plist, no App Group and no sandbox, and the window may need the application activated at launch to take focus; a language feature of the pinned toolchain that Xcode's lacks breaks the store build, which the job on `main` is there to catch; the composition has to be held once per launch by something other than a SwiftUI `@State`, whose initial value is evaluated on every creation of its struct.

Constrained: nothing in `TodoAppleUI` may depend on being inside a bundle until the project exists; every commit builds with both toolchains. Reversing this decision is adding the project earlier, which is cheap and changes nothing in the library.

## Amendment, 2026-10-13

Made in the owner's review of #81, where the executable first ran. The decision above gave the executable two lines and everything else to `TodoAppleUI`. Running it showed that an executable without a bundle starts as a background application and stays behind the terminal that launched it. It has to make itself a regular application and activate itself once its launch has finished, which the executable does from an application delegate. That code answers how `todo-mac` is packaged, not what the app does: an app target with a bundle needs none of it. So it lives in the executable, and the library that the iOS and watchOS app targets will import carries none of it. The rule that follows: `TodoAppleUI` holds nothing that only one target's packaging needs, and the executable holds its `@main` and what its missing bundle costs, and nothing else.

What SwiftUI offers on macOS but not on iOS or watchOS stays in the library behind `#if os(macOS)`: today the `Window` scene and Esc on a text field. What iOS and watchOS show in their place is decided when the Xcode project brings them. `Apps/Apple/Package.swift` declares iOS 17 and watchOS 10 beside macOS 14, and the macOS job compiles `TodoAppleUI` for both, so the library still builds for them when that project arrives.

## Amendment, 2026-10-14

Made with the approval of the navigation spec, `docs/specs/navigation.md`, whose section 9 brings the Xcode project the decision above foresaw, because the epic's deliverable is the first iPhone build. Two things the decision left open are settled.

1. **The shell is one committed `project.xcproj`, and nothing generates it.** The project is `Todo.xcodeproj` with one iOS app target whose `@main` opens the scene from `TodoAppleUI`, an Info.plist that registers the `todo` scheme and allows multiple scenes, automatic signing and no entitlements; the Mac stays on `todo-mac` through SwiftPM. Its configuration file is `project.xcproj`, the JSON project file Xcode 27 reads and Xcode 27.2 writes by default (Apple's "Updating your Xcode project configuration file format", read 2026-10-14), which is text that reads in a diff, so the file itself is committed: written once by hand, kept canonical with `xcprojformatter` from Apple's `xcode-project-format` run through `swift run`, and decoded by that library in a test so a malformed file fails before Xcode sees it. XcodeGen, which the spec's first revision chose for the property-list format no diff reads, lost because the JSON file is already the readable form and the tool would be a Homebrew dependency for a format the project leaves within months; a generator script over Apple's library lost because there is nothing to generate from, and a script would be a second description of the same one target, kept in step with the first.
2. **The pinned toolchain and Xcode's are one version from Xcode 27 on.** Xcode 27 ships Swift 6.4 and needs macOS 26.6; Xcode 26 cannot open `project.xcproj`. So the pin in `.swift-version` moves from 6.3.3 to the exact 6.4 the owner's installed Xcode 27 prints, with the wasm SDK of that version, as an `infra` task at the start of the navigation plan and before any Apple task; the CI macOS job moves to GitHub's `xcode-27` image; and the rule that every commit builds with both toolchains ends with the task that makes them one. A probe on 2026-10-14 with Swift 6.4.1 built the core, passed every host test, found on wasm32 only the wall-clock sentinel firing as designed, since the WasmKit of 6.4 tells the time, and measured a smaller release bundle; that task flips the sentinel and the note on `Store.systemNow`, and changes the path `scripts/wasm-size.sh` measures, since SwiftPM 6.4 builds into `out/Products/`.
