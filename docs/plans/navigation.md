# Plan: Navigation

- Status: Approved 2026-10-14
- Spec: `docs/specs/navigation.md`, approved 2026-10-14
- Epic: #67

Written for the engineer and derived from the approved spec. The plan
fixes what the tasks are, in what order, and what each one promises to
the next. It does not carry the implementation: code appears only where
it already ran. A task section is 50 to 100 lines. Once a task ships its
section is history; a departure is stated in the task's pull request and
fixed forward into the sections that depend on it, never back into the
shipped one (`docs/process.md`, sections 6 and 7).

> Written by hand from `docs/plans/TEMPLATE.md`, its second use. Executed
> task by task, one sub-issue per branch and pull request, with
> superpowers:subagent-driven-development, each implementing and
> reviewing agent briefed with the spec, `docs/style.md`, ADR-0006 to
> ADR-0009 and the task's section, and with the shipped code of the
> tasks it depends on rather than their sections.

## Global constraints

The rules every task obeys, each with the spec section or ADR it comes
from.

- Toolchain: until Task 1 merges, Swift 6.3.3 as `.swift-version` pins it; from Task 1 on, the Swift 6.4 the owner's installed Xcode 27 prints, pinned there, with the wasm SDK of the same version, and Xcode's toolchain is that version too, so one toolchain builds everything (spec section 9, ADR-0008 amendment of 2026-10-14). Always the swiftly-managed `swift`; every command assumes `export PATH="$HOME/.swiftly/bin:$PATH"`. A `.build` made by the other version is deleted before building.
- A feature target imports `TodoCore`, `FeatureModule`, the standard library and FoundationEssentials under `#if canImport(FoundationEssentials)`, and beside them only the features it opens, its children, which it depends on and imports (ADR-0009), never a sibling or the root (Task 3); no SwiftUI, no Observation, no Foundation proper in the root package. The wasm32 build in CI is the enforcement (ADR-0001, ADR-0007). The `FeatureModule` target imports nothing: a seat is handed the way to make its child by its parent, so the contract names no dependency (ADR-0007 amendment of 2026-10-15, which withdraws the dependency on `TodoCore` the amendment of 2026-10-14 gave it, in the owner's review of #100).
- A module is a `final class` conforming to `FeatureModule`: `Model`, `UserAction`, `Event` and `Output` nested, all `Equatable & Sendable`, no `Codable`; `send` is synchronous and never throws, and what the store refuses becomes part of the model (ADR-0006). A module that can be opened conforms to `Routable` as well: a `Route` with a head and a tail, `var route`, and `.route(_:)` and `.created` in its `Event` (spec section 4, ADR-0009). It is made by an `init` of its own from its route and the dependencies it needs, `init(store:route:)` for a screen that reads the store, which throws `StoreError` where the screen can refuse to be made; the protocol requires no `init` (owner's review of #100).
- A parent holds each child in a `Seat<Child, Failure>`, which it builds once, where it creates the seat, with the way to make the child: a closure over the child's own `init` that captures the child's dependencies and never the parent, and names its thrown type, `{ route throws(StoreError) in try TaskList(store: store, route: route) }`, or throws nothing, so that `Failure` is `Never` and `apply` takes no `try`; the parent's state declares each seat with its failure type, `Seat<TaskList, StoreError>`, so that a factory missing its annotation fails to compile instead of widening to `Seat<TaskList, any Error>`. The seat creates the child from a route with it, sends it `.created` and hands the answer back, and reconciles by head on `.route`. What a parent writes per child is its `Model` field, its `UserAction` case, one line forwarding the child's actions, one forwarding `.changed`, and its reaction to the child's `Output` in a `switch` with no `default` (spec section 4). A parent learns a child's choice only through its output (ADR-0006 amendment of 2026-10-03). A request a parent cannot serve it re-emits under its own name (spec section 4).
- Inside a module navigation has one entrance, apply a route: a tap, a link, a relaunch and the way back are each a route applied, and applying reconciles by head; the head of a live module never changes, and a module that receives `.route` looks at the tail alone (spec section 3). A route carries no session state; an argument a screen opens with sits in the tail, read once in the screen's `init` and never written back (spec section 2). No screen in this epic takes one.
- A module never writes to the store in answer to `.changed` (spec section 5, ADR-0009); a module publishes nothing and subscribes to nothing; the fan-out of a `ChangeSet` is the composition root's.
- A screen whose subject is gone asks to be closed through its output, and its parent drops it (spec section 3). A screen that cannot be made leaves the one that was open, and the parent says so with a sentence in its own model (spec section 3).
- A view holds no condition over a domain value and formats nothing: every `if` in a view is over a `Bool` or an optional of the model (`docs/style.md`, "Views"). Every binding keeps the shape `TextField` has: read from the model, set only by sending an action; the item of `navigationDestination(item:)` is the child's head, never its model (spec section 6). No SwiftUI container reaches the core, and the containers are the epic's choice (spec section 6).
- A user action is named for the control and the gesture, never for the operation it triggers (ADR-0006, the reviews of #66 and #101, `docs/style.md`): the module decides what the gesture means. The way back from a pushed screen is `backButtonTapped`, which the swipe back sends too, since SwiftUI reports both as one write through the binding. Quick entry's sheet closes on `cancelButtonTapped`, quick entry's own action: its Cancel button sends it, and the swipe down and Esc send it too, through the sheet's binding, and quick entry answers it with `.closeRequested` (the owner's ruling on #101; Tasks 4, 5, 7).
- A module's model is computed from its state, `public var model: Model { state.model }`, and never stored beside it and assigned after every event (owner's review of #101, `docs/style.md`). The sections of Tasks 2 and 3, written before the rule, keep `private(set) var model` and the model assembled after every event; Task 2 shipped so, and #101 departs from Task 3's.
- The host takes one event at a time; the world's entrance is the composition root's and never a view's; a view gets `model`, `route` and `send(UserAction)`, and the window's view installs the handler for the root's output (spec section 5).
- Every exported name was probed unqualified in a file importing SwiftUI and Foundation on 2026-10-14 with Xcode 26.3's compiler: `Route`, `Seat`, `Addressed`, `Routed`, `RouteValue`, `RoutedEvent`, `RouteCodec`, `RouteError`, `NoHead`, `TaskList`, `TaskListFeature`, `TaskScreen`, `QuickEntry`, `TaskListView`, `TaskScreenView`, `QuickEntryView`, `TodoIOS`, `Head`, `Tail`, `Segment` are all free, and the control names `List`, `Task`, `URL`, `App`, `State` are taken, which is the probe working. `Routable` was probed on 2026-10-15 with Xcode 27.1 (swiftlang-6.4.0.34.1), in a file importing SwiftUI, Foundation and Observation typechecked for macOS 14, iOS 17 and watchOS 10, and is free on all three, against a control file in which `URL`, `State<Int>`, `Text` and `Identifiable` resolve. A name a task adds beyond these gets the same probe before it is fixed (`docs/style.md`).
- Tests are swift-testing. A module test opens `Store.openInMemory(device:now:)` through `makeStore` with a deterministic clock, sends events and compares the model whole; the root package's suite runs on the host with `swift test` and on wasm32 with `swift test --swift-sdk swift-<pin>-RELEASE_wasm --disable-xctest`, both green before a PR. From Task 1 on, the wall clock on wasm32 under the test runner is the real one, and the sentinel that said otherwise is flipped there.
- `Apps/Apple` is a package of its own, built and tested from its directory with the pinned toolchain; the macOS job builds and tests it on `main` and on demand, and from Task 10 builds the iOS app for the simulator too.
- Branch per task `<type>/<issue>-<slug>`, PR title in Conventional Commits with scope `core`, `apple`, `ci`, `infra` or `docs`, body per template, `Closes #<sub-issue>`; squash merge; one line under `[Unreleased]` in `CHANGELOG.md` per task; commits end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Everything in English. No `TODO` without a linked issue.

## File map

| File | Task | Holds |
| ---- | ---- | ----- |
| `.swift-version` | 1 | the pin, Swift 6.4.x |
| `.github/workflows/ci.yml` | 1, 10 | the wasm SDK of the pin and its checksum; the macOS job on `xcode-27` with the one toolchain (1); the iOS simulator build (10) |
| `scripts/wasm-size.sh` | 1, 5 | the SDK name and the product path of SwiftPM 6.4; the ceiling, re-measured (1), and again when the root grows (5) |
| `Sources/TodoCore/Storage/Store.swift` | 1 | the note on `Store.systemNow` without the test runner's lie |
| `Sources/TodoCore/Model/Day.swift` | 3 | `Day.init(millisSinceEpoch:)`, the UTC day of a clock reading |
| `Tests/TodoCoreTests/StoreOpenTests.swift` | 1 | the wall-clock test, one assertion on every target |
| `Package.swift` | 2, 3, 4, 5 | `FeatureModule` gains `FeatureModuleTests` and depends on nothing (2); targets `TaskScreenFeature`, `TaskListFeature` (3), `QuickEntryFeature` (4) with their tests and products; `AppFeature` depends on all three (5) |
| `Sources/FeatureModule/Routable.swift` | 2 | `RouteValue`, `RoutedEvent`, `Routable`, `NoHead` |
| `Sources/FeatureModule/Seat.swift` | 2 | `Seat` |
| `Tests/FeatureModuleTests/SeatTests.swift` | 2 | the seat over a stub child |
| `Sources/Features/TaskViewList/TaskViewList.swift` | 2 | `TaskViewList.Route`, `init(store:route:)`, `route`, `.route`, `openInNewWindowMenuItemChosen` and `.openInWindow` |
| `Tests/TaskViewListFeatureTests/TaskViewListTests.swift` | 2 | the sidebar's route and the window request |
| `Sources/Features/TaskScreen/TaskScreen.swift` | 3 | `TaskScreen` |
| `Sources/Features/TaskList/TaskList.swift` | 3 | `TaskList` with its seat for the task screen |
| `Tests/TaskScreenFeatureTests/TaskScreenTests.swift` | 3 | the task screen's tests |
| `Tests/TaskListFeatureTests/TaskListTests.swift` | 3 | the list's tests, the push and the pop included |
| `Sources/Features/QuickEntry/QuickEntry.swift` | 4 | `QuickEntry` |
| `Tests/QuickEntryFeatureTests/QuickEntryTests.swift` | 4 | quick entry's tests |
| `Sources/Features/App/AppModule.swift` | 2, 5 | the sidebar created from a route (2); the seats, `Route`, the four flows, `.openWindow`, `problem` (5) |
| `Sources/Features/App/Route.swift` | 5 | `AppModule.Route`'s text form and `RouteError` |
| `Tests/AppFeatureTests/AppModuleTests.swift` | 2, 5 | the root's flows |
| `Tests/AppFeatureTests/RouteTests.swift` | 5 | the codec, every row of the spec's table and every refusal |
| `Sources/WasmSizeProbe/main.swift` | 2, 5 | drives the root through its new entrance (2) and through a link, a push and quick entry (5) |
| `Apps/Apple/Package.swift` | 9 | `ProjectFileTests` and the dependency on `xcode-project-format` |
| `Apps/Apple/Sources/TodoAppleUI/ModuleHost.swift` | 6 | `ModuleHost` over a routable module, with `route`, `deliver` and the output handler |
| `Apps/Apple/Sources/TodoAppleUI/TodoApp.swift` | 6, 8 | the composition root: one store, a host per window, the fan-out (6); a route from a URL and `TODO_ROUTE` (8) |
| `Apps/Apple/Tests/TodoAppleUITests/ModuleHostTests.swift` | 6 | the host's new duties |
| `Apps/Apple/Tests/TodoAppleUITests/TodoAppTests.swift` | 6, 8 | two hosts over one store; a route from a URL; the launch route |
| `Apps/Apple/Sources/TodoAppleUI/RootView.swift` | 7, 8 | the split view, the stack in the detail column, the sheet (7); the window's value, links and the output handler (8) |
| `Apps/Apple/Sources/TodoAppleUI/TaskViewListView.swift` | 7 | the "Open in New Window" menu item |
| `Apps/Apple/Sources/TodoAppleUI/TaskListView.swift` | 7 | `TaskListView` |
| `Apps/Apple/Sources/TodoAppleUI/TaskScreenView.swift` | 7 | `TaskScreenView` |
| `Apps/Apple/Sources/TodoAppleUI/QuickEntryView.swift` | 7 | `QuickEntryView` |
| `Apps/Apple/Sources/TodoAppleUI/AppScene.swift` | 7, 8 | `WindowGroup(for:)` on macOS and iOS, a plain `WindowGroup` on the watch (7); the link handling (8) |
| `Apps/Apple/Sources/todo-mac/TodoMac.swift` | 8 | unchanged in shape; the launch route reaches it through the composition root |
| `Apps/Apple/Todo.xcodeproj/project.xcproj` | 9 | the one iOS app target, by hand, canonical |
| `Apps/Apple/Sources/todo-ios/TodoIOS.swift`, `Info.plist` | 9 | the `@main` over `AppScene`; the `todo` scheme and multiple scenes |
| `Apps/Apple/Signing.xcconfig.example`, `.gitignore` | 9 | the owner's team outside the repository |
| `Apps/Apple/Tests/ProjectFileTests/ProjectFileTests.swift` | 9 | the project file decoded, checked and held canonical |
| `README.md`, `CLAUDE.md`, `docs/process.md` | 1, 10 | the toolchain notes (1); running the iPhone app, the macOS job's new step (10) |
| `docs/adr/0009-*.md` | 10 | Status to Accepted, with the amendments' PRs merged |

## Tasks

| # | Issue | Title | Labels | Depends on |
| - | ----- | ----- | ------ | ---------- |
| 1 | #88 | The toolchain moves to Swift 6.4 and Xcode 27 | `infra` | |
| 2 | #89 | The shared form of a parent, and the sidebar becomes addressed | `feature`, `core` | 1 |
| 3 | #90 | The task screen and the task list | `feature`, `core` | 2 |
| 4 | #91 | Quick entry | `feature`, `core` | 2 |
| 5 | #92 | The root: seats, the window's route and its text form | `feature`, `core` | 3, 4 |
| 6 | #93 | A host per window, and the composition root fans out | `feature`, `ui-apple` | 5 |
| 7 | #94 | The views and the stack | `feature`, `ui-apple` | 6 |
| 8 | #95 | Windows, links and restoration | `feature`, `ui-apple` | 7 |
| 9 | #96 | The Xcode shell and the first iPhone build | `feature`, `ui-apple` | 8 |
| 10 | #97 | CI for the iPhone build, and the documentation that closes the epic | `infra`, `ui-apple` | 9 |

The owner reviews this table and the interface of every task below.

### Task 1: The toolchain moves to Swift 6.4 and Xcode 27

**Goal.** One toolchain builds everything: the pin in `.swift-version` is the Swift 6.4 the owner's Xcode 27 ships, the wasm SDK is that version's, CI's Linux and macOS jobs use it, the size script measures what SwiftPM 6.4 builds, and the test that held that the wasm32 test runner's clock lies says the opposite, because it stopped lying.

**Files.** `.swift-version`; `.github/workflows/ci.yml`; `scripts/wasm-size.sh`; `Tests/TodoCoreTests/StoreOpenTests.swift`; `Sources/TodoCore/Storage/Store.swift`, the comment on `systemNow`; `README.md`, `CLAUDE.md`, `docs/process.md` section 10, the toolchain sentences; `CHANGELOG.md`.

**Interface.** None: nothing the code exports changes. What later tasks consume is the pin itself, read from `.swift-version` by swiftly and by the commands in every task.

**Rules.**

- The task starts on the owner's machine with macOS 26.6 and Xcode 27 installed, which is the owner's part; `xcrun swift --version` there prints the version the pin becomes, and nothing in the task guesses it. Xcode 27 requires macOS 26.6 (its release notes, read 2026-10-14) and the owner's machine was on 26.5 that day (ADR-0008 amendment).
- The Linux job's `WASM_SDK_URL` and `WASM_SDK_SHA256` move to the pin's SDK, the checksum computed from the downloaded archive and written into the workflow; `swiftly install` reads `.swift-version` and needs no change. The macOS job moves to `runs-on: xcode-27` and its `DEVELOPER_DIR` steps to the Xcode on that image whose Swift is the pin; those steps stay, because they are what shows the two toolchains are one, and their comment says so instead of saying they wait for the Xcode project. The toolchain cache key already hashes `.swift-version`.
- `scripts/wasm-size.sh` names the pin's SDK and measures `.build/out/Products/Release-webassembly-wasm32/wasm-size-probe.wasm`, the layout SwiftPM 6.4 builds into; the ceiling becomes 6,553,600 bytes, the 6,276,015 the probe measured plus four percent rounded up to a whole 64 KiB, by the rule the script's comment states. Moving that number is a decision, and this plan is where the owner sees it.
- The sentinel `theWallClockIsTheHostsOwnAndTheOneHostThatLiesIsTheTestRunner` loses its `#if arch(wasm32)` branch and asserts on every target that `Store.systemNow()` is past 2025-09-10; it is renamed `theWallClockIsTheHostsOwnOnEveryTarget`. The note on `Store.systemNow` and the global constraint of `docs/plans/feature-module-architecture.md` that forbade asserting a wall-clock value on wasm32 are history now: the PR says so in its body and names #53 and #59, whose closing is the owner's.
- The rule of ADR-0008 that every commit builds with both toolchains ends here, since they are one; the documents that stated it, `README.md`, `CLAUDE.md` and `docs/process.md` section 10, say what is true from this task on.

**Tests.**

- The whole suite on the host and on wasm32 with the pin, green, which is the test of the move.
- `theWallClockIsTheHostsOwnOnEveryTarget`: on the host and on wasm32 under WasmKit, `Store.systemNow()` is past 2025-09-10.
- `scripts/wasm-size.sh` passes under the new ceiling and prints the reading.
- The macOS job, run on demand on the branch, green: the compile checks, the Apple package's build and tests, and the builds with Xcode's toolchain printing the pin's version.

**Verified facts and traps.**

- 2026-10-14, Swift 6.4.1 from swift.org on the owner's Mac, from the spec's branch: the core builds, every host test passes, and on wasm32 every test passes but the sentinel, which fails as it was written to; Swift 6.4.1 bundles WasmKit 0.3.1, whose clock is the real one, where 6.3.3 bundled 0.1.6. The release wasm bundle gzips to 6,276,015 bytes against 6,595,141 with 6.3.3.
- 2026-10-14: swift.org publishes the wasm SDK for 6.4.0 and 6.4.1 at `https://download.swift.org/swift-<v>-release/wasm-sdk/swift-<v>-RELEASE/swift-<v>-RELEASE_wasm.artifactbundle.tar.gz`, both answering 200.
- 2026-10-14: GitHub's `xcode-27` runner image is a public preview with Xcode 27.0 (27A266a) as default, 27.1 beta and 27.2 beta 2; the `macos-26` image carries Xcode 26.0.1 to 26.6 and no 27. Apple's releases page lists Xcode 27 released on 2026-09-14 and 27.1 at its release candidate on 2026-10-05. Xcode 27 includes Swift 6.4.
- Trap: SwiftPM 6.4 builds into `.build/out/Products/<Configuration>-<platform>/`, and the `.build/wasm32-unknown-wasip1/release/` path the script measured does not exist there; the script fails loudly on a missing file, which is what showed it.
- Trap: a preview image can change under the job; the macOS job runs on `main` and on demand only, so a flaky image blocks no PR.

### Task 2: The shared form of a parent, and the sidebar becomes addressed

**Goal.** The protocols of an addressed module and the generic seat exist beside the contract, in the `FeatureModule` target, which now depends on `TodoCore`; the sidebar is the first addressed module, with an empty head and its selection as its tail, so that a `.route` moves its highlight and a link to a view highlights it; and it can ask for a view in a new window.

**Files.** `Package.swift`; `Sources/FeatureModule/Addressed.swift`; `Sources/FeatureModule/Seat.swift`; `Tests/FeatureModuleTests/SeatTests.swift`; `Sources/Features/TaskViewList/TaskViewList.swift`; `Tests/TaskViewListFeatureTests/TaskViewListTests.swift`; `Sources/Features/App/AppModule.swift` and `Sources/WasmSizeProbe/main.swift`, which call the new `init` and are otherwise untouched until Task 5.

**Interface.**

```swift
// FeatureModule
public protocol RouteValue: Equatable, Sendable {
    associatedtype Head: Equatable & Sendable
    var head: Head { get }
}

public protocol RoutedEvent: FeatureEvent {
    associatedtype Route: RouteValue
    static func route(_ route: Route) -> Self
    static var created: Self { get }
}

public protocol Addressed: FeatureModule where Event: RoutedEvent {
    init(store: Store, route: Event.Route) throws(StoreError)
    var route: Event.Route { get }
}

public struct NoHead: Hashable, Sendable {
    public init()
}

public struct Seat<Child: Addressed> {
    public init()
    public var route: Child.Event.Route? { get }
    public var model: Child.Model? { get }
    public mutating func apply(_ route: Child.Event.Route?, store: Store) throws(StoreError) -> Child.Output?
    public func send(_ event: Child.Event) -> Child.Output?
    public mutating func drop()
}

// TaskViewListFeature, added to what Task 1 to 5 of the feature-module plan shipped
public final class TaskViewList: Addressed {
    public struct Route: RouteValue {
        public var head: NoHead { get }
        public let selection: ViewID?
        public init(selection: ViewID?)
    }
    public enum UserAction: Equatable, Sendable {
        // the seven cases of M2, and
        case openInNewWindowMenuItemChosen(ViewID)
    }
    public enum Event: RoutedEvent {
        case action(UserAction)
        case changed(ChangeSet)
        case created
        case route(Route)
    }
    public enum Output: Equatable, Sendable {
        case selected(ViewID)
        case openInWindow(ViewID)
    }
    public private(set) var route: Route { get }
    public init(store: Store, route: Route) throws(StoreError)
}
```

**Rules.**

- `Seat.apply` reconciles: a nil route drops the child; the same head keeps the child and hands it `.route`, returning what the child answers; a different head, or an empty seat, makes a new child with `Child(store:route:)`, sends it `.created` and returns that answer. The new child is made before the old one is let go, so a `Child.init` that throws leaves the seat as it was: the parent catches, writes its sentence and keeps what was open (spec section 3).
- `Seat.send` forwards any event to the child and answers nil from an empty seat; the parent spells the child's cases, `seat.send(.changed(changes))`, so the seat needs no knowledge of `ChangeSet`.
- `.created` keeps its meaning from ADR-0006: the sidebar created from a route whose selection is nil answers `.selected(inbox)`, its own first choice; created from a route with a selection, it answers `.selected` with that view, the choice the route carries, when the view exists, and nothing when it does not (spec section 4).
- `.route` with a selection the rows hold moves the highlight and answers nothing: it is the route's choice, not a person's, and the root already knows it; with a selection the rows do not hold, nothing moves. A `.route` whose selection is nil leaves the highlight alone: the default window chooses Inbox itself at creation and never again. `route` reports the current highlight as the tail.
- `init(store:)` goes; `init(store:route:)` is the one way to make the sidebar, and `AppModule.init` calls it with `Route(selection: nil)` until Task 5 gives the root a route of its own.
- `.openInNewWindowMenuItemChosen(id)` answers `.openInWindow(id)` and moves nothing: what happens is the root's to decide, by the rule of bubbling (spec section 4). A view that is not in the rows answers nothing.
- The test target `FeatureModuleTests` holds a stub child, a `final class` whose route's head is a `TaskID` and whose `init` throws `.notFound` for an id the store has no task for, so that the seat's rules are tested without a feature module.

**Tests.**

- `anEmptySeatHasNoRouteAndNoModel`.
- `applyingARouteToAnEmptySeatMakesTheChildAndAnswersItsCreatedAnswer`: the stub answers `.created` with a known output and the seat returns it.
- `applyingTheSameHeadKeepsTheChildAndHandsItTheRoute`: the same instance, by identity, receives `.route` with the new tail.
- `applyingADifferentHeadReplacesTheChild`: a new instance, `.created` sent again.
- `applyingNilDropsTheChild`.
- `aChildThatCannotBeMadeLeavesTheSeatAsItWas`: `apply` throws `.notFound` and the previous child is still there.
- `sendOnAnEmptySeatAnswersNothing`.
- `theSidebarCreatedFromNoSelectionStartsOnInboxAndSaysSo`: `.created` answers `.selected(inbox)`.
- `theSidebarCreatedFromASelectionStartsThereAndSaysSo`: `.created` answers `.selected(today)` and Today is highlighted.
- `theSidebarCreatedFromAGoneSelectionAnswersNothing`.
- `aRouteMovesTheHighlightAndAnswersNothing`; `aRouteToAViewNotInTheRowsMovesNothing`; `aRouteWithNoSelectionLeavesTheHighlight`.
- `theRouteReportsTheHighlight`: after `.rowSelected(today)`, `route.selection == today`.
- `openInNewWindowAsksTheRootAndMovesNothing`; `openInNewWindowForAViewNotInTheRowsAnswersNothing`.
- Every test of M2's sidebar, unchanged but for the `init`, still passes on the host and on wasm32.

**Verified facts and traps.**

- 2026-10-14: a package depending on `FeatureModule` and `TodoCore` with exactly the protocols and the seat above, a stub child with an enum event and a struct route, a child whose head is `NoHead`, and a parent holding two seats, builds under Swift 6.3.3 and 6.4.1 in language mode 6. An enum case with a payload witnesses `static func route(_:)` and a case without one witnesses `static var created`, the way `case action(_:)` already witnesses `FeatureEvent`'s requirement. A typed-throws `init` requirement in a protocol is called as `try Child(store:route:)` from a `throws(StoreError)` method without a cast.
- The names `RouteValue`, `RoutedEvent`, `Addressed`, `Seat`, `NoHead` and `Route` are free (Global constraints). The spec's working names were `Addressed` and `Seat`; the probe kept them.
- Trap: a `Seat` is a struct holding a class; a parent keeps it in a `var` of its `State` and calls `apply` through `state.detail.apply(...)`, which is a mutation of `state`; the model is assembled afterwards in one place as `AppModule` does today.
- Trap: `FeatureModule` depending on `TodoCore` means `TestSupport` and `FeatureModuleTests` depend on `TodoCore` too; `wasm-size-probe` already links it.

### Task 3: The task screen and the task list

**Goal.** Two routable modules exist as skeletal screens: the task screen, whose head is a task id and which shows the task's title and nothing editable, and the task list, whose head is a view id, which lists the view's tasks by title, opens the task screen in its seat on a tap, closes it on the way back, and asks to be closed when its view is gone.

**Files.** `Package.swift`, targets `TaskScreenFeature` at `Sources/Features/TaskScreen` and `TaskListFeature` at `Sources/Features/TaskList`, their test targets, and library products for both; `Sources/Features/TaskScreen/TaskScreen.swift`; `Sources/Features/TaskList/TaskList.swift`; `Sources/TodoCore/Model/Day.swift`; `Tests/TaskScreenFeatureTests/TaskScreenTests.swift`; `Tests/TaskListFeatureTests/TaskListTests.swift`.

**Interface.**

```swift
// TodoCore
extension Day {
    /// The UTC day a clock reading falls on, for a client with no time zone of its own.
    public init(millisSinceEpoch: Int64)
}

// TaskScreenFeature
public final class TaskScreen: Routable {
    public struct Route: RouteValue {
        public let head: TaskID
        public init(head: TaskID)
    }
    public struct Model: Equatable, Sendable {
        public let title: String
    }
    public enum UserAction: Equatable, Sendable {}
    public enum Event: RoutedEvent {
        case action(UserAction)
        case changed(ChangeSet)
        case created
        case route(Route)
    }
    public enum Output: Equatable, Sendable {
        case closeRequested
    }
    public private(set) var model: Model { get }
    public private(set) var route: Route { get }
    public init(store: Store, route: Route) throws(StoreError)
    public func send(_ event: Event) -> Output?
}

// TaskListFeature
public final class TaskList: Routable {
    public struct Route: RouteValue {
        public let head: ViewID
        public let task: TaskScreen.Route?
        public init(head: ViewID, task: TaskScreen.Route? = nil)
    }
    public struct Model: Equatable, Sendable {
        public struct Row: Equatable, Sendable, Identifiable {
            public let id: TaskID
            public let title: String
        }
        public let rows: [Row]
        public let task: TaskScreen.Model?
        public let problem: String?
    }
    public enum UserAction: Equatable, Sendable {
        case rowTapped(TaskID)
        case taskScreenDismissed
    }
    public enum Event: RoutedEvent {
        case action(UserAction)
        case changed(ChangeSet)
        case created
        case route(Route)
    }
    public enum Output: Equatable, Sendable {
        case closeRequested
    }
    public private(set) var model: Model { get }
    public var route: Route { get }
    public init(store: Store, route: Route) throws(StoreError)
    public func send(_ event: Event) -> Output?
}
```

**Rules.**

- `TaskScreen.init` reads `store.task(route.head)` and throws `StoreError.notFound(route.head)` when it answers nil: a screen on a task that is gone is not made (spec section 3). `.changed` naming its task rereads it; a reread that finds no task answers `.closeRequested`; a reread that fails keeps the title. `.created`, `.route` and `.action` answer nothing, since the screen has no tail and no actions.
- `TaskList.init` reads `store.tasks(in: route.head, today:)` for the rows, builds its seat, a `Seat<TaskScreen, StoreError>` made with `{ route throws(StoreError) in try TaskScreen(store: store, route: route) }`, which captures the store and never the list, and applies `route.task` to it; the seat's `.created` answer is dropped, since the task screen answers nothing. A `route.task` the store cannot make, a task that is gone, leaves no child and a sentence in `problem`, "The task is gone", and the list is still made: the link opened what still exists (spec section 3, fourth flow).
- `.rowTapped(id)` applies `Route(head: head, task: TaskScreen.Route(head: id))`; `.taskScreenDismissed` applies `Route(head: head)`; `.route` applies the tail, which is `task`, to the seat: one entrance, four occasions (spec section 3). A tap on a row that is not in the rows applies nothing.
- `.changed` naming the list's view reads `store.view(head)` and answers `.closeRequested` when the view is gone; naming any task, it rereads the rows, since which tasks a view holds is the query's to say; in either case it is forwarded to the seat, and `.closeRequested` from the task screen drops it. A reread that fails keeps the rows and writes "The list could not be read" into `problem`; the next action clears the sentence, as the sidebar's rule has it.
- `today` is the UTC day of `Store.systemNow()` through `Day(millisSinceEpoch:)`, read once in `init` and again on every reread, until M4's change of the day arrives as an event of the world with the platform's day; the deviation is stated in the self-review. `Day` keeps its civil conversion in one place: the new `init` divides by the milliseconds of a day and clamps a reading before the epoch to day zero, and nothing traps (`docs/style.md`).
- `route` is assembled: the head and the seat's route as the tail.

**Tests.**

- `aTaskScreenShowsTheTitle`; `aTaskScreenOnAGoneTaskIsNotMade`: `init` throws `.notFound(id)`.
- `aChangeNamingTheTaskRereadsTheTitle`; `aChangeNamingAnotherTaskReadsNothing`; `aTaskDeletedUnderTheScreenAsksToClose`.
- `aListShowsTheViewsTasksInQueryOrder`: three tasks in Inbox, rows in the order `tasks(in:today:)` gives.
- `aListCreatedWithATaskOpensIt`: `model.task` holds the title and `route.task` the id.
- `aListCreatedWithAGoneTaskOpensTheListAndSaysSo`: no child, `problem` set.
- `aTapOpensTheTaskAndTheRouteSaysSo`; `aTapOnARowNotInTheListOpensNothing`; `dismissingTheTaskScreenClosesIt`.
- `aRouteWithAnotherTaskReplacesTheOpenOne`; `aRouteWithNoTaskClosesIt`.
- `aChangeNamingATaskRereadsTheRows`; `aChangeNamingOnlyATagReadsNothing`; `aViewDeletedUnderTheListAsksToClose`; `aTaskDeletedUnderTheOpenScreenClosesItAndKeepsTheList`.
- `theDayOfAReadingIsItsUTCDay`: `Day(millisSinceEpoch:)` of 2026-10-14T23:59:59Z and of the next millisecond differ by one; a negative reading is day zero.

**Verified facts and traps.**

- `Store.tasks(in:today:)` and `Store.task(_:)` exist with those signatures and typed throws; `task(_:)` answers nil for an unknown id and throws only on a failed read (`Store+Tasks.swift`, `Store+Query.swift`, read 2026-10-14). `StoreError.notFound(EntityID)` is the case to throw.
- `Day`'s `daysSinceEpoch` is an `Int32` and its `init(daysSinceEpoch:)` is internal, which is why the new `init` lives in `TodoCore` and not in the feature (`Day.swift`, read 2026-10-14). The command line computes the local day with `Calendar` and `TimeZone` from Foundation proper, which a feature target may not import (`CLI.swift`, ADR-0001).
- Trap: `ChangeSet.tasks` names the task a change touched, not its descendants, and a structure change is sized for redrawing the view (`Store.swift`); rereading the whole list on any task is the rule that follows, and views number in the tens of tasks in this epic.
- Trap: an empty `UserAction` enum still needs `case action(UserAction)` in `Event` for the contract; `send`'s `switch` over it has no `.action` arm to write and the compiler accepts the exhaustive switch without one.

### Task 4: Quick entry

**Goal.** The quick entry module exists: a field and a button, creating a task in the Inbox from the field, refusing a blank title with a sentence, and asking to be closed once the task exists or when a person cancels.

**Files.** `Package.swift`, target `QuickEntryFeature` at `Sources/Features/QuickEntry`, its test target and product; `Sources/Features/QuickEntry/QuickEntry.swift`; `Tests/QuickEntryFeatureTests/QuickEntryTests.swift`.

**Interface.**

```swift
public final class QuickEntry: Routable {
    public struct Route: RouteValue {
        public var head: NoHead { get }
        public init()
    }
    public struct Model: Equatable, Sendable {
        public let draft: String
        public let problem: String?
    }
    public enum UserAction: Equatable, Sendable {
        case titleFieldChanged(String)
        case titleFieldSubmitted
        case addButtonTapped
        case cancelButtonTapped
    }
    public enum Event: RoutedEvent {
        case action(UserAction)
        case changed(ChangeSet)
        case created
        case route(Route)
    }
    public enum Output: Equatable, Sendable {
        case closeRequested
    }
    public var model: Model { get }
    public var route: Route { get }
    public init(store: Store, route: Route)
    public func send(_ event: Event) -> Output?
}
```

**Rules.**

- The draft lives in the model and every keystroke is a round trip, as the sidebar's rename is (ADR-0006); `.titleFieldChanged` with the draft's own text moves nothing, the echo rule of #81.
- `.titleFieldSubmitted` and `.addButtonTapped` settle into one line: the draft trimmed at both ends goes to `store.createTask(NewTask(title:))`, which lands in the Inbox by the Inbox's own filter; an empty trim is refused with "A title cannot be empty" and the field keeps the raw text; a store that refuses the write becomes "The task could not be saved"; a write that succeeds answers `.closeRequested`, the modal's own half of the way back (spec section 5).
- `.cancelButtonTapped` answers `.closeRequested` and writes nothing: the draft goes with the module, which its parent drops. The sheet's Cancel button sends it, and the swipe down and Esc arrive as it too, through the sheet's binding (Task 7); what it means, closing, is the module's to decide (the owner's ruling on #101, `docs/style.md`).
- `.changed` does nothing: quick entry reads nothing from the store, and a change elsewhere is no answer to what a person is typing. `.route` does nothing, since the tail is empty and no argument exists in this epic (spec section 2); `.created` answers nothing.
- `init` does not throw, since it reads nothing: the plan kept it throwing only for the protocol, which requires no `init` since the owner's review of #100. Its parent's seat is a `Seat<QuickEntry, Never>`, applied without `try`. `route` is `Route()`.
- No sentence survives the next action the module acts on, as the sidebar's rule has it.

**Tests.**

- `quickEntryStartsEmpty`.
- `typingMovesTheDraft`; `anEchoOfTheDraftMovesNothing`.
- `submittingCreatesTheTaskInTheInboxAndAsksToClose`: `store.tasks(in: BuiltInTaskViews.inbox, today:)` holds the title; the output is `.closeRequested`.
- `theAddButtonTakesTheSameRoadAsReturn`: the same model and output as the test above.
- `aBlankTitleIsRefusedWithASentenceAndKeepsTheText`: `"   "` submitted, no task created, `problem` set, `draft` unchanged.
- `theTitleIsTrimmedOnTheWayToTheStore`; `aRefusedWriteBecomesASentence`: a store that cannot write, closed or over a read-only file through `makeStore`'s options, gives "The task could not be saved".
- `theCancelButtonAsksToCloseAndWritesNothing`: a title typed, `.cancelButtonTapped` answers `.closeRequested`, and the Inbox holds no new task.
- `aChangeMovesNothing`; `aRouteMovesNothing`.

**Verified facts and traps.**

- `NewTask.init(title:notes:when:deadline:parent:tags:)` has defaults for everything but the title and `createTask(_:at:)` places at `.end` by default (`TodoTask.swift`, `Store+Tasks.swift`, read 2026-10-14). The wasm size probe creates a task with no `when` and reads it back from the Inbox page, which is the fact that a dateless task is an Inbox task.
- Trap: the sidebar's `trimmed` is private to it; the one shape rule of `docs/style.md` asks for one trim, so the task either moves it to a place both reach or states in its PR why two one-liners are better than a shared one.

### Task 5: The root: seats, the window's route and its text form

**Goal.** `AppModule` is routable: it holds the sidebar, the task list and quick entry in seats, its route is the window's route, that route has the one text form with the codec in the core, the four flows of the spec run end to end through one entrance, "open in new window" climbs to the root's first output, and the size probe drives all of it.

**Files.** `Package.swift`, `AppFeature` depending on the three new features; `Sources/Features/App/AppModule.swift`; `Sources/Features/App/Route.swift`; `Tests/AppFeatureTests/AppModuleTests.swift`; `Tests/AppFeatureTests/RouteTests.swift`; `Sources/WasmSizeProbe/main.swift`; `scripts/wasm-size.sh`.

**Interface.**

```swift
public final class AppModule: Routable {
    public struct Route: RouteValue {
        public var head: NoHead { get }
        public let sidebar: TaskViewList.Route
        public let detail: TaskList.Route?
        public let quickEntry: QuickEntry.Route?
        public init(sidebar: TaskViewList.Route, detail: TaskList.Route?, quickEntry: QuickEntry.Route?)
        /// The default window: no selection, no pane, no quick entry; the sidebar chooses Inbox itself.
        public static let `default`: Route
        /// The text form: `/`, `/view/<id>`, `/view/<id>/task/<id>`, with `?quick-entry` when it is up.
        public init(text: String) throws(RouteError)
        public var text: String { get }
    }
    public struct Model: Equatable, Sendable {
        public let taskViewList: TaskViewList.Model
        public let taskList: TaskList.Model?
        public let quickEntry: QuickEntry.Model?
        public let problem: String?
    }
    public enum UserAction: Equatable, Sendable {
        case taskViewList(TaskViewList.UserAction)
        case taskList(TaskList.UserAction)
        case quickEntry(QuickEntry.UserAction)
        case quickEntryButtonTapped
    }
    public enum Event: RoutedEvent {
        case action(UserAction)
        case changed(ChangeSet)
        case created
        case route(Route)
    }
    public enum Output: Equatable, Sendable {
        case openWindow(Route)
    }
    public var model: Model { get }
    public var route: Route { get }
    public init(store: Store, route: Route) throws(StoreError)
    public func send(_ event: Event) -> Output?
}

/// Why a string is not a route, naming the segment.
public enum RouteError: Error, Equatable, Sendable {
    case unknownSegment(String)
    case segmentOutOfPlace(String)
    case notAnID(String)
    case unknownQuery(String)
}
```

**Rules.**

- `init(store:route:)` builds the three seats with their factories, each capturing the store and never the root: `Seat<TaskViewList, StoreError>` over `TaskViewList(store:route:)`, `Seat<TaskList, StoreError>` over `TaskList(store:route:)` and `Seat<QuickEntry, Never>` over `QuickEntry(store:route:)`. It applies the route to them in order, sidebar, pane, quick entry, and reacts to each answer on the one line a click's answer takes: a sidebar created from no selection answers `.selected(inbox)`, the root applies `TaskList.Route(head: inbox)` to the pane and finds, when the route carried the same pane, that the head is already there (spec section 4). A sidebar the store cannot read throws, as today: the launch is the composition root's to refuse. A pane that cannot be made leaves its seat as it was and writes a sentence into `problem`, "The list could not be opened." (spec section 3); quick entry cannot fail to be made.
- `react(to:)` exists per child, each a `switch` with no `default`: the sidebar's `.selected(id)` applies the pane to `id`, its `.openInWindow(id)` answers `.openWindow(Route(sidebar: .init(selection: id), detail: .init(head: id), quickEntry: nil))`; the list's `.closeRequested` drops the pane; quick entry's `.closeRequested` drops it. `send` returns the one output `react` collected, which is the bubbling rule in code (spec section 4).
- `.quickEntryButtonTapped` applies `QuickEntry.Route()` to its seat. `.quickEntry(.cancelButtonTapped)` is forwarded like every quick entry action, and quick entry's `.closeRequested` drops it; with no quick entry open the empty seat answers nothing, which is where the sheet's binding lands when it writes false after a close the model drove. `.taskList(.backButtonTapped)` is forwarded like every list action. `.route(route)` applies each part to its seat, which is what a link does and what restoration does. A route with no quick entry drops a live one and its draft with it, a link from outside included, since a half-typed quick entry is session state that no route carries (spec section 2); the owner chose this on #102.
- `.changed` goes to each seat in one line each, and a `.closeRequested` from any of them drops that child; the root reads the store for nothing of its own any more (spec section 3, ADR-0006 amendment of 2026-10-14). The next action clears `problem`.
- `route` is assembled from the seats: `Route(sidebar: sidebar.route, detail: detail.route, quickEntry: quickEntry.route)`; the text form writes the pane's head as `/view/<id>` and its task as `/task/<id>`, nothing for a sidebar selection with no pane, since the sidebar's selection is the pane's view whenever a pane is open, and `?quick-entry` when quick entry is up. Reading is the exact inverse: `/` is the default; `/view/<id>` sets the sidebar's selection and the pane; `/view/<id>/task/<id>` opens the task in it; `?quick-entry` with no value adds quick entry. Anything else refuses the whole route with the segment named: `task` without `view` is `.segmentOutOfPlace("task")`, a segment that is neither is `.unknownSegment`, an id that is not a lowercase UUID string is `.notAnID`, a query item that is not `quick-entry` is `.unknownQuery`. The scheme and the site are stripped by the caller, never here (spec section 2).
- Ids are written as `EntityID.description` prints them and read through `UUID(uuidString:)` from FoundationEssentials, then lowercased, which is the form the command line prints; a route is data from outside and nothing traps (`docs/style.md`).
- The size probe drives the root as a web client will: through `.route` from a text, a tap that pushes, a dismissal, quick entry creating a task, a `.changed` delivered after the `send` that wrote; the ceiling in `scripts/wasm-size.sh` moves to the reading plus four percent rounded up to a whole 64 KiB, as it did in M2.

**Tests.**

- Codec: `everyRowOfTheTableWritesAndReadsBack`, the four rows of the spec's table plus `/view/<id>?quick-entry`; `aRouteReadsBackToTheSameValue` for each.
- Codec refusals: `taskWithoutViewIsOutOfPlace`, `anUnknownSegmentIsRefused`, `anUppercaseIDIsReadLowercased`, `aStringThatIsNotAnIDIsRefused`, `anUnknownQueryItemIsRefused`, `aTrailingSlashIsRefused`, `anEmptyStringIsRefused`, `aQuickEntryWithAValueIsRefused`.
- `aTapOnATaskOpensItAndTheRouteSaysSo`: `.taskList(.rowTapped(id))`, `model.taskList?.task` holds the title, `route.text == "/view/<inbox>/task/<id>"`.
- `theBackButtonClosesTheTaskScreenAndTheRouteSaysSo`.
- `aLinkToATaskInAnotherViewMovesTheSidebarAndReplacesThePane`: a task from a third view open, `.route` into another view's task, the sidebar highlights that view, the pane is a new list, the task is open.
- `aLinkToADeletedTaskOpensTheListAndASentence`.
- `aLinkIntoTheOpenListKeepsItsSessionState`: a rename field open in the sidebar survives a `.route` into a task of the same view, by the same list instance.
- `aViewDeletedUnderThePaneClosesItThroughTheChild`: `.changed` naming the deleted view, `model.taskList == nil`; the root's own read of the pane's view, `readDetail`, is gone from the code, which the reviewer checks.
- `quickEntryOpensDrawsAndClosesWhenItAsks`: `.quickEntryButtonTapped`, a title typed, `.quickEntry(.addButtonTapped)`, `model.quickEntry == nil` and the task in the Inbox.
- `quickEntrysCancelButtonClosesIt`; `aCancelWithNoQuickEntryOpenMovesNothing`; `aLinkWithoutQuickEntryClosesTheOpenOne`: quick entry up with a title typed, a `.route` to `/view/<inbox>`, `model.quickEntry == nil`, and the Inbox holds no new task; `openInNewWindowClimbsToTheRoot`: `.taskViewList(.openInNewWindowMenuItemChosen(today))` answers `.openWindow` whose text is `/view/<today>`.
- `theRootCreatedFromALinkFindsThePaneAlreadyThere`: created from `/view/<today>/task/<id>`, one list instance, the task open, `problem` nil.
- `aPaneThatCannotBeOpenedLeavesTheOldOneAndASentence`: a `.route` into a view that is gone keeps the pane and sets `problem`.
- `theRootNeverWritesOnChanged`: a `.changed` leaves the journal's row count unchanged.
- The size probe runs on the host and on wasm32 and the budget script passes.

**Verified facts and traps.**

- `EntityID.init(_:)` defaults to `UUID().uuidString.lowercased()` and `description` is the raw value; `TodoCore` imports FoundationEssentials, which holds `UUID` (`EntityID.swift`, read 2026-10-14). `BuiltInTaskViews.inbox` is a fixed id (`TaskView.swift`).
- `Store.onChange` is called after the transaction commits (`Store.swift`), and the size probe already delivers each change set after the `send` that wrote (`WasmSizeProbe/main.swift`).
- Trap: the sidebar's `.selected` answers twice on a route that carries both a selection and a pane, once from `.created` and once from `.route` if the latter moved the highlight; the sidebar answers nothing to `.route` (Task 2), which is what keeps the pane from being applied twice.
- Trap: a `Seat` holds a class and `AppModule.State` is a struct; `react` mutating two seats in one event is two mutations of `state`, which the model, computed from the state, shows at its next read, the shape #77 and #101 settled.

**Open before the task starts.** Three questions the final review of #100 found in this section, for the owner to settle before the task is dispatched; nothing here decides them.

- A seat cannot hold a child that is always there as this section types it: `Seat.route` and `Seat.model` are optional, while `Route.sidebar` and `Model.taskViewList` are not, and `TaskViewList.Model` has no public initializer to fall back on. The candidates: the sidebar held outside a seat, those two fields optional, or a holder for a child that is always there, added in this task by the rule of no API without a caller.
- What a nil `detail` means at creation. In the order the rules give, sidebar then pane, the default route's sidebar answers `.selected(inbox)`, the root opens the pane on Inbox, and applying `detail: nil` then drops it, so the default window starts with no pane. The reverse order closes a task a link opened: `.selected(v)` applies `TaskList.Route(head: v)` with no task to the same head. One candidate rule: at creation, a nil `detail` means the pane follows the sidebar's choice. The same reaction pops an open task on a live click too: the sidebar's `.selected(id)` on the highlighted row applies `TaskList.Route(head: id)`, whose nil `task` closes the open task (Task 3: a `.route` with no task closes it), so the rule settled here covers a live click as well.
- `/` applied to a live window: the sidebar keeps its highlight on a nil selection (Task 2), and `detail: nil` drops the pane, which leaves a highlighted view beside an empty pane.

### Task 6: A host per window, and the composition root fans out

**Goal.** The host serves a routable module whose output goes somewhere: it publishes `route` beside `model`, takes the root's output to a handler the window's view installs, and keeps its queue; the composition root holds one store per process, makes a host per window from a route text, and hands every change set to every live host.

**Files.** `Apps/Apple/Sources/TodoAppleUI/ModuleHost.swift`; `Apps/Apple/Sources/TodoAppleUI/TodoApp.swift`; `Apps/Apple/Tests/TodoAppleUITests/ModuleHostTests.swift`; `Apps/Apple/Tests/TodoAppleUITests/TodoAppTests.swift`; `Apps/Apple/Sources/TodoAppleUI/RootView.swift` and `AppScene.swift` only as far as they must compile against the new host until Task 7.

**Interface.**

```swift
@MainActor @Observable
final class ModuleHost<M: Routable> {
    private(set) var model: M.Model
    private(set) var route: M.Event.Route
    /// Installed by the window's view; an output with no handler is dropped and said so in a test.
    var onOutput: ((M.Output) -> Void)?
    init(_ module: M, world: (@escaping @MainActor (M.Event) -> Void) -> Void)
    func send(_ action: M.Event.UserAction)
}

@MainActor
final class TodoApp {
    /// Once per process, from the environment: the store and the device identity, as today.
    static let shared: TodoApp
    static func launch(environment: [String: String]) throws -> TodoApp
    /// A host for a window: the root made from the text, or from the default route when the text is nil or does not read.
    func makeHost(route text: String?) throws -> ModuleHost<AppModule>
}
// Every host made here and still alive receives the change set a commit reports; how they are held is private.
```

**Rules.**

- The host stays the one `@Observable` object a view observes and keeps one event at a time; after every event it publishes `model` and `route`, and hands the output, if any, to `onOutput` after the model is published, so a handler that opens a window sees the state the output came from (spec section 5).
- `ModuleHost` loses `where M.Output == Never` and gains `M: Routable`, which the root and a future `ModuleHost<QuickEntry>` satisfy; `route` is `module.route` read after each event.
- The composition root becomes an instance made once per launch, holding the store; `makeHost` creates the root with `AppModule(store:route:)`, registers the host's world entrance for fan-out, and returns it. A text that does not read is the default route, silently (spec section 7); a root the store cannot make throws, as `launch` does today.
- Fan-out: `store.onChange` iterates the live hosts and delivers `.changed`; a host whose event is in flight queues it; an idle host processes it inside the other window's event, which the rule that no module writes in answer to `.changed` makes sound (spec section 5). The task's probe: the test `anIdleHostTakesAChangeInsideAnotherHostsEvent` passes as written; if it cannot, the composition root hands the change set to every other host on the next turn of the main actor and the test says so, which is the spec's named alternative.
- Dead hosts are pruned on each fan-out; the host is created once per window and held by the window's view, in the form Task 7 settles, never in the initial value of a `@State`.
- `TODO_DB` and `TODO_DEVICE` keep their meaning; the default database under Application Support is unchanged.

**Tests.**

- `theHostPublishesTheRouteAfterEachEvent`; `anOutputReachesTheHandlerAfterTheModel`: the handler sees `host.route` already moved.
- `anOutputWithNoHandlerIsDropped`.
- `aHostMadeFromNoTextIsTheDefaultWindow`; `aHostMadeFromATextOpensIt`; `aHostMadeFromAnUnreadableTextIsTheDefaultWindow`.
- `twoHostsOverOneStoreBothReceiveAChange`: a write through the first window's action reaches the second host's model.
- `anIdleHostTakesAChangeInsideAnotherHostsEvent`: proven by order, the second host's model moves before the first host's `send` returns, or the test states the deferred alternative.
- `aHostInFlightQueuesTheChange`: the change set from its own write arrives after its `send` returned, as today.
- `aClosedWindowsHostIsReleasedAndReceivesNothing`: weak reference nil after the host is dropped, and the next fan-out does not fail.
- M2's host tests, unchanged in meaning.

**Verified facts and traps.**

- `Store.onChange` is called after the transaction commits (`Store.swift`, line 43, read 2026-10-14), so an idle host reads a store in which the write is done.
- The `@Observable` macro's setter does not notify on an equal value under both toolchains (#80), so a host whose model did not change tells no view.
- Trap: a closure stored by the composition root that captures the host strongly keeps a closed window's module alive; the host's world entrance already captures `self` weakly, and the composition root holds hosts weakly, so the chain breaks when the view lets go.
- Trap: two hosts over one store means two roots and two sidebars reading the same views table on every `.changed` that names a view; nothing to do in this epic, measured when the first large list arrives.

### Task 7: The views and the stack

**Goal.** One tree of views serves macOS, iPhone and iPad: a split view whose detail column holds a stack rooted at the task list with the task screen pushed in it, quick entry as a sheet, the "Open in New Window" item in the sidebar, and every binding read from the model and set only through an action.

**Files.** `Apps/Apple/Sources/TodoAppleUI/RootView.swift`; `TaskViewListView.swift`; `TaskListView.swift`; `TaskScreenView.swift`; `QuickEntryView.swift`; `AppScene.swift`; the hand-check script in the session, not in the repository.

**Interface.**

```swift
struct TaskListView: View {
    init(model: TaskList.Model, send: @escaping (TaskList.UserAction) -> Void)
}
struct TaskScreenView: View {
    init(model: TaskScreen.Model)
}
struct QuickEntryView: View {
    init(model: QuickEntry.Model, send: @escaping (QuickEntry.UserAction) -> Void)
}
struct RootView: View {
    init(host: ModuleHost<AppModule>)
}
public struct AppScene: Scene {
    public init()
}
```

**Rules.**

- `RootView` draws `NavigationSplitView` with the sidebar and a `NavigationStack` in the detail column whose root is `TaskListView` when `model.taskList` is there and a placeholder otherwise; `navigationDestination(item:)` binds to the head of the open task, `host.route.detail?.task?.head`, and its destination draws `TaskScreenView` from `host.model.taskList?.task` with one `if let`; the binding's set to nil sends `.taskList(.backButtonTapped)` and a set to a value sends nothing, since only the module opens (spec section 6). With no screen open that action moves nothing in the list, so the nil SwiftUI writes after a pop the model drove changes nothing, and it leaves the list's sentence, so a sentence the list wrote while the screen covered it shows when the screen is popped (Task 3). `.sheet` binds to `model.quickEntry != nil`, and a set to false, the swipe down or Esc, sends `.quickEntry(.cancelButtonTapped)`, the action `QuickEntryView`'s Cancel button sends. The quick entry button sits on the toolbar and sends `.quickEntryButtonTapped`.
- The item is the head, a `TaskID`, which is `Hashable`; never the model (spec section 6). The head the view binds to is read from `host.route.detail?.task?.head`, which is why the host publishes the route.
- `TaskViewListView` gains a context menu item "Open in New Window" sending `.openInNewWindowMenuItemChosen(id)`, behind `#if !os(watchOS)`, which is the only platform condition in a view and is about a menu the watch does not have.
- `AppScene` is `WindowGroup(for: String.self)` on macOS and iOS, with the window's value the route text and a `RootView` over a host made once per window; on watchOS it is a plain `WindowGroup` over a host made from nil, because `WindowGroup(for:)`, `openWindow` and `handlesExternalEvents` are unavailable there (deviation, self-review). Where the host is held is this task's probe: a `@State` wrapper whose value is set in `.task` or `.onAppear` when nil, or an object created in the scene's content closure, whichever the probe shows creates one host per window and never two; the test is a counter in `TodoApp.makeHost` read after the window appeared and after it redrew.
- The two-level push in one update is the task's second probe: a route text with a task set at window creation and a `.route` into a task of another view while a task is open must both show the list and the task screen pushed, in order, with no runtime warning; the fallback is a view that maps the route's chain into a `path` for `NavigationStack(path:)`, which is a map and not a decision (spec, Risks).
- Every `if` in a view is over a `Bool` or an optional of the model; the reviewing agent reads every view for the rule (`docs/style.md`, "Views").

**Tests.**

- The Apple package builds for macOS, iOS 17 and watchOS 10 with the pinned toolchain, the macOS job's commands; the watch build is the compile check the spec keeps the watch at.
- `aWindowMakesOneHost`: the counter after the window appeared and after a redraw forced by a `.changed`.
- By hand on the Mac with the accessibility driver, each over a scratch `TODO_DB`: a tap on a task pushes it in the column and the back button pops it; a second tap on another task replaces it; quick entry opens as a sheet, Return creates the task in the Inbox and the sheet closes; Esc closes it with nothing created; a blank title shows the sentence and keeps the field. A task or a view deleted under an open screen cannot be done by hand in this epic, since nothing deletes on screen and another process's write fires no `onChange` here; the tests of Tasks 3 and 5 hold that path.

**Verified facts and traps.**

- 2026-10-14, typechecked with Xcode 26.3's compiler against the macOS 14 and iOS 17 SDKs: `WindowGroup(for: String.self)` with a `Binding<String?>`, `openWindow(value:)`, `handlesExternalEvents(preferring:allowing:)`, `onOpenURL`, `@SceneStorage`, `NavigationSplitView` with a `NavigationStack` in the detail column, `navigationDestination(item:)` and `.sheet(isPresented:)` compile together in one file. Against the watchOS 10 SDK the same file fails on `openWindow`, `WindowGroup(for:)` and `handlesExternalEvents`, each "unavailable in watchOS".
- `navigationDestination(item:)` is available from iOS 17, macOS 14 and watchOS 10, the package's minimums, and `D: Hashable` (macOS 26.2 SDK interface, read 2026-10-14).
- Trap: a `TextField` echoes the text it holds through its binding (#81); quick entry's module ignores the echo (Task 4), so the view sends every change as it comes.
- Trap, unverified: the root drops quick entry in the same event that answers `.closeRequested`, Return's answer and Cancel's alike (Task 4's module, Task 5's `react`), so a `.sheet(isPresented:)` whose content reads `model.quickEntry` through `if let` has nothing to draw while the sheet slides away; the hand check looks for an empty sheet on the way down. `.sheet(item:)` keeps its last item while it dismisses, but needs an `Identifiable` item, which `NoHead` is not.
- Trap: `List(selection:)` in the sidebar cannot be left without a highlight; the M2 rule holds and the sidebar view is unchanged in that respect.

### Task 8: Windows, links and restoration

**Goal.** A second window on the Mac and the iPad, "open in new window" from the sidebar, a link into the running app, restoration after a relaunch from the same string, and a route fed at launch to the Mac executable, all through the one entrance.

**Files.** `Apps/Apple/Sources/TodoAppleUI/AppScene.swift`; `RootView.swift`; `TodoApp.swift`; `Apps/Apple/Tests/TodoAppleUITests/TodoAppTests.swift`; `README.md`, the running section.

**Interface.**

```swift
extension TodoApp {
    /// The route a URL the system opened carries, with the scheme stripped, or nil when it does not read: ignored silently in this epic.
    func route(from url: URL) -> AppModule.Route?
    /// The route named at launch by `TODO_ROUTE`, for the executable without a bundle; nil when unset or unreadable.
    var launchRoute: AppModule.Route? { get }
}
```

**Rules.**

- The window's value is the route text; the window creates its host from it and writes `host.route.text` back into the value after every event, which is what restoration reads at the next launch on macOS; on iPhone the same string lives in `@SceneStorage("route")` and is read at scene creation (spec section 7). The probe: if setting the group's value binding re-identifies the window or recreates its view, the write-back goes to `@SceneStorage` on every platform and the window's value stays what it was created with (spec, Risks).
- Cmd-N opens a window with the default route; `.openWindow(route)` from the host reaches the handler the window's view installed, which calls `openWindow(value: route.text)` (spec section 5). On iPadOS this needs the Info.plist of Task 9; on the Mac executable it works as soon as the scene is a group.
- A link: `onOpenURL` on the window's content hands the URL to `TodoApp.shared.route(from:)`, which strips the scheme and reads the path and query with the codec; a route is delivered to that window's host as `.route` through the world's entrance, and nil is ignored. On the Mac the key window takes the link when there is one and a new window opens only when none; `handlesExternalEvents(preferring:allowing:)` on the window's content is the lever, and which sets give "the key window if any, else a new one" is this task's probe, recorded in its PR.
- The Mac executable has no URL scheme: `TODO_ROUTE` names the route at launch, read in `launch(environment:)` like `TODO_DB`, and the first window is created from it; a running `todo-mac` is not reachable by a link until Task 9's app exists (spec section 7).
- Two windows on one route are allowed to coexist or to bring the first forward, whichever `WindowGroup(for:)` does; the task records which (spec, Open questions).

**Tests.**

- `aURLWithTheSchemeReadsAsARoute`: `todo:///view/<id>/task/<id>` gives the route; `aURLWithTheQueryReadsAsARoute`: `todo:///view/<id>?quick-entry` opens quick entry.
- `anUnreadableURLGivesNil`; `aLaunchRouteIsReadFromTheEnvironment`; `anEmptyLaunchRouteIsNil`.
- By hand on the Mac with the accessibility driver: Cmd-N opens Inbox in a second window; "Open in New Window" on Today opens Today; a rename in one window appears in the other; closing one window leaves the other working; quit and relaunch restores both windows with their routes; `TODO_ROUTE=/view/<today>/task/<id> swift run todo-mac` opens the task; an unreadable `TODO_ROUTE` opens the default window.

**Verified facts and traps.**

- `WindowGroup(for:)` requires `D: Codable & Hashable`, which `String` is; `handlesExternalEvents(preferring:allowing:)` is unavailable only on watchOS and tvOS; `onOpenURL` and `SceneStorage` exist on every Apple platform (macOS 26.2 SDK interface, read 2026-10-14).
- Trap: SwiftUI's default for a `WindowGroup` is a new window for every URL (spec section 7); a probe that forgets the modifier passes its own test on a fresh launch and fails on the second link.
- Trap: `@SceneStorage` is per scene and survives a relaunch only when the system restores the scene; a test of restoration is by hand.

### Task 9: The Xcode shell and the first iPhone build

**Goal.** The iPhone app exists: one iOS app target in a committed `project.xcproj` over `TodoAppleUI`, registering the `todo` scheme and multiple scenes, signed automatically under the owner's team on a device and unsigned for the simulator, decoded and held canonical by a test; the app runs in the simulator and on a device with the stack, links and restoration.

**Files.** `Apps/Apple/Todo.xcodeproj/project.xcproj`; `Apps/Apple/Sources/todo-ios/TodoIOS.swift`; `Apps/Apple/Sources/todo-ios/Info.plist`; `Apps/Apple/Signing.xcconfig.example` and `.gitignore`; `Apps/Apple/Package.swift`; `Apps/Apple/Tests/ProjectFileTests/ProjectFileTests.swift`; `README.md`, running on iPhone.

**Interface.**

```swift
// todo-ios
@main struct TodoIOS: App { var body: some Scene { AppScene() } }

// Apps/Apple/Package.swift: a test target depending on the library product "XcodeProjectFormat" of
// https://github.com/apple/xcode-project-format at exact "0.1.0", and nothing else new.
```

**Rules.**

- The project is written by hand as JSON in the schema `xcode-project-format` models: one target, product type an application, bundle identifier `dev.maldrakar.todo` unless the owner names another in review, deployment target iOS 17, Swift 6 language mode, the local package `Apps/Apple` as its one package reference with the `TodoAppleUI` product, the `Info.plist` referenced and not generated, and object ids that are the names of what they identify, so that the file never changes under a reformat (ADR-0008 amendment of 2026-10-14). The file is canonical: what `swift run xcprojformatter --update Todo.xcodeproj` writes, run from `Apps/Apple`, which depends on the library.
- `Info.plist` registers `CFBundleURLTypes` with the `todo` scheme and `UIApplicationSceneManifest` with `UIApplicationSupportsMultipleScenes` true (spec section 9).
- Signing: the target sets `CODE_SIGN_STYLE = Automatic` and takes `DEVELOPMENT_TEAM` from `Signing.xcconfig`, which is gitignored, with `Signing.xcconfig.example` committed; the simulator build in CI passes `CODE_SIGNING_ALLOWED=NO` and needs no team. If the format has no base configuration reference, the team is set in the project and the task says so.
- `ProjectFileTests` decodes the file with `XCSchema.Project(jsonRepresentation:)`, asserts the one target, its product type, bundle identifier, the URL scheme and the scenes flag read from the plist, and asserts the file equals its own canonical encoding, so a hand edit that is not canonical fails before Xcode sees it; the failure message names the command that reformats.
- The watch stays at the compile check; the Mac stays on `todo-mac` through SwiftPM.

**Tests.**

- `theProjectFileDecodes`; `theProjectHasOneApplicationTargetOverTheLibrary`; `theInfoPlistRegistersTheSchemeAndMultipleScenes`; `theProjectFileIsCanonical`.
- `xcodebuild -project Apps/Apple/Todo.xcodeproj -target Todo -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build` on the owner's Mac, which Task 10 puts into CI.
- By hand in the simulator and on a device: the collapsed stack, sidebar to list to task and back by swipe; quick entry as a sheet; `xcrun simctl openurl booted todo:///view/<id>/task/<id>` into the running app opens the task in the one window; a relaunch restores the stack; on the iPad, "Open in New Window" opens a second scene.

**Verified facts and traps.**

- 2026-10-14: `project.xcproj` is Xcode 27's JSON project configuration file inside `.xcodeproj`, the default from 27.2, readable by Xcode 27 and later and not by 26 (Apple's "Updating your Xcode project configuration file format"); Xcode 26.3's binaries carry no `project.xcproj` string. `xcprojformatter` takes the outer `.xcodeproj` or the inner file (its help text).
- 2026-10-14: `apple/xcode-project-format` 0.1.0 builds with Swift 6.3.3 and 6.4.1; a package depending on its library product runs `swift run xcprojformatter` and `swift build --product xcprojformatter` with 6.4.1, building the dependency's executable. `XCSchema.Target.objectID` is required and `XCSchema.Project.objectID` optional; an `ObjectID` is any string (`ObjectID.swift`).
- Trap: the library's decoder has open bugs on malformed input (issues #3, #6, #7 of the repository on 2026-10-14); the file here is small and hand-written, and a trap in the test is a bug to report upstream, not to work around.
- Trap: Xcode 27.2's inspector writes the file in its own canonical form; the test holds the library's, and the two are expected to agree, since the tool is Apple's for that purpose; if they differ, the task records which wins.

### Task 10: CI for the iPhone build, and the documentation that closes the epic

**Goal.** The macOS job builds the iPhone app for the simulator after its existing steps; the documents say what M3 built and how to run it; the ADRs the epic proposed are accepted.

**Files.** `.github/workflows/ci.yml`; `README.md`; `docs/process.md` section 10; `CLAUDE.md`; `docs/adr/0009-*.md`; `CHANGELOG.md`.

**Interface.** None.

**Rules.**

- The step runs the `xcodebuild` command of Task 9 with `DEVELOPER_DIR` naming the image's Xcode 27, unsigned, after the Apple package's tests, and prints `xcodebuild -version` first so the log names what built. It runs on `main` and on demand only, as the whole job does.
- `README.md` gains running the iPhone app from Xcode and the simulator command, the `todo://` link form, `TODO_ROUTE` for the Mac, and what the window holds now; the status paragraph says M3 shipped and M4 is next; `docs/process.md` section 10 and `CLAUDE.md`'s toolchain and CI notes follow.
- ADR-0009's status moves to Accepted, with the amendments of ADR-0006 to ADR-0008 already carrying their merged PR numbers.

**Tests.**

- The macOS job, run on demand on the branch, green with the new step.
- The closing of the milestone is not a task: `CHANGELOG.md` moves Unreleased into `[0.3.0]` and the tag and release follow `docs/process.md` section 9, on the owner's OK.

**Verified facts and traps.**

- The macOS job's existing shape: compile checks for iOS and watchOS, the Apple package's build and tests, the builds with Xcode's toolchain (`ci.yml`, read 2026-10-14).
- Trap: an `xcodebuild` without `-destination` and without `-scheme` builds the target for the SDK named; a scheme is not committed unless the project format needs one, which Task 9 finds out.

## Self-review against the spec

| Spec section | Task |
| ------------ | ---- |
| 1. Every screen is a child of the screen that opened it | 2 (the seat), 3 (the list holds the task screen), 5 (the root holds three) |
| 2. A route is the address of a screen | 2 (`RouteValue`, the sidebar's route), 3 and 4 (the screens' routes), 5 (the window's route and the text form); the argument in the tail is a rule and no screen takes one |
| 3. One entrance: apply a route; the four flows; a screen whose subject is gone | 2 (`Seat.apply`), 3 (the list's tap, pop and `.route`), 5 (the four flows end to end), 3 and 5 (`closeRequested`) |
| 4. The shared form of a parent | 2 (`Routable`, `Seat`, the sidebar), 5 (what the root still writes per child, bubbling); names probed before any task |
| 5. A window is a tree of modules; a process is one store; quick entry | 6 (host per window, fan-out, the output handler), 4 (quick entry), 7 and 8 (the sheet, Cmd-N, "open in new window") |
| 6. One tree of views on every Apple platform | 7 |
| 7. Deep links and restoration | 5 (the codec), 8 (a link into the running app, restoration, `TODO_ROUTE`), 9 (the scheme in the plist) |
| 8. The web and the watch, on paper | none builds them, as the spec says; the watch stays at the compile check of 7 and 10 |
| 9. The Xcode shell and the first iPhone build; the toolchain | 1 (the toolchain first), 9 (the shell), 10 (CI) |
| 10. The screens the epic builds | 3 (task list, task screen), 4 (quick entry) |
| Testing, CI and the deliverable | tests per task; the size probe in 5; the hand checks in 7, 8 and 9; CI in 1 and 10; the deliverable is Task 9's app and the Mac of Task 8 |
| Open questions | the fan-out form in 6, two windows on one route and `handlesExternalEvents` in 8, where the host is held and the two-level push in 7, which 6.4 in 1; the unreadable link stays ignored, as the spec's default |
| Decisions to record as ADRs | recorded in #86 before this plan; Task 10 accepts them |

Deviations, each stated where it happens:

- The watch's scene is a plain `WindowGroup` behind `#if os(watchOS)` (Task 7): `WindowGroup(for:)`, `openWindow` and `handlesExternalEvents` are unavailable on watchOS, typechecked 2026-10-14, and the spec's "no `#if` for the shape of the interface" cannot hold for the scene; the views hold to it.
- `today` for the task list is the UTC day of the clock the store reads, through a new `Day.init(millisSinceEpoch:)` (Task 3): the spec hands the list a day at creation, the way the command-line demo passes it, and the list reads the UTC day itself instead, at every read, because a feature target may not import `Calendar` and so has no time zone, and the change of the day is M4's event of the world, which brings the platform's day.
- The way back from a pushed screen is `backButtonTapped` and not the spec's `taskClosed` (Tasks 3, 5, 7): the owner's review of #101 names the control and the gesture, and the swipe back sends the same action, since SwiftUI reports both alike. Task 3's section keeps `taskScreenDismissed`, the name it was written with.
- Quick entry's sheet closes on quick entry's own `cancelButtonTapped`, answered with `.closeRequested`, and not on the spec's root action `.quickEntryDismissed` (Tasks 4, 5, 7): the owner's ruling on #101 names the control, the swipe down and Esc send the same action through the sheet's binding, and the module decides that it means closing.
- The project file's canonical form is held by a test (Task 9) beside the formatter the spec names, so that a hand edit fails in `swift test` and not in review.
- `Signing.xcconfig` keeps the owner's team out of the repository (Task 9); the spec says automatic signing and nothing about where the team is written.
- The size budget moves twice, in Task 1 by the toolchain and in Task 5 by the root (spec, Risks); both readings go into `scripts/wasm-size.sh` by its own rule.
