# Plan: Feature-module architecture

- Status: Draft
- Spec: `docs/specs/feature-module-architecture.md`, approved 2026-09-20
- Epic: #63

Written for the engineer and derived from the approved spec. The plan
fixes what the tasks are, in what order, and what each one promises to
the next. It does not carry the implementation: code appears only where
it already ran. A task section is 50 to 100 lines. Once a task ships its
section is history; a departure is stated in the task's pull request and
fixed forward into the sections that depend on it, never back into the
shipped one (`docs/process.md`, sections 6 and 7).

> Written by hand from `docs/plans/TEMPLATE.md`, its first use. Executed
> task by task, one sub-issue per branch and pull request, with
> superpowers:subagent-driven-development, each implementing and
> reviewing agent briefed with the spec, `docs/style.md`, ADR-0006 to
> ADR-0008 and the task's section, and with the shipped code of the
> tasks it depends on rather than their sections.

## Global constraints

The rules every task obeys, each with the spec section or ADR it comes
from.

- A feature target imports `TodoCore`, `FeatureModule`, the standard library and FoundationEssentials under `#if canImport(FoundationEssentials)`, and nothing else; no SwiftUI, no Observation, no Foundation proper in the root package. The wasm32 build in CI is the enforcement (ADR-0001, ADR-0007).
- A module is a `final class` conforming to `FeatureModule`: `Model`, `UserAction`, `Event` and `Output` nested, all `Equatable & Sendable`, no `Codable`; `send` is synchronous and never throws, and what the store refuses becomes part of the model (spec section 2, ADR-0006).
- A module publishes nothing and subscribes to nothing. It rereads the store after its own write and on `.changed`; the fan-out of a `ChangeSet` is the composition root's (spec section 2).
- A view holds no condition over a domain value and formats nothing: every `if` in a view is over a `Bool` or an optional of the model; a button's title or a placeholder is the view's vocabulary (spec section 2). A reviewing agent reads every view for this rule.
- A user action is named for the control and the gesture, `createFolderButtonTapped`, `titleFieldSubmitted`, never for the operation it triggers: what a gesture means is the module's, and a view that could spell `commitRename` would know that a rename exists (spec section 2, settled in the review of #66).
- The host takes one event at a time; the world's entrance is handed to the composition root in `init` and is private otherwise; views get `send(UserAction)` and `model` and nothing else (spec section 5).
- Every exported name was probed unqualified in a file importing SwiftUI and Foundation: on 2026-09-20 `FeatureModule`, `FeatureEvent`, `Sidebar`, `AppModule`, `ModuleHost` and the nested `Model`, `Row`, `Event`, `Output`, on 2026-09-21 `UserAction` and `TodoApp`, on 2026-09-22 `TaskViewList`, which replaces `Sidebar` (#75); all compile, and `List`, `State`, `WindowGroup`, `Operation` and `Task` still resolve to SwiftUI's and Foundation's. `App` failed the probe: a library exporting it makes the executable's `TodoMac: App` ambiguous. A name a task adds beyond these gets the same probe before it is fixed (`docs/style.md`).
- Tests are swift-testing. A module test opens `Store.openInMemory(device:now:)` through `makeStore` with a deterministic clock, sends events and compares the model whole; the root package's suite runs on the host with `swift test` and on wasm32 with `swift test --swift-sdk swift-6.3.3-RELEASE_wasm`, both green before a PR; no test asserts a wall-clock value on wasm32 (#53).
- `Apps/Apple` is a package of its own, built and tested from its directory with the pinned toolchain, which swiftly finds through the parent's `.swift-version`; it must also build with Xcode's toolchain, `/usr/bin/swift build`, which the macOS job runs on `main` from Task 6 on (ADR-0008).
- Toolchain: always the swiftly-managed `swift`; every command assumes `export PATH="$HOME/.swiftly/bin:$PATH"`. A `.build` produced by Xcode's toolchain in the same directory has to be deleted before the pinned one builds there again.
- Branch per task `<type>/<issue>-<slug>`, PR title in Conventional Commits with scope `core`, `apple`, `ci` or `docs`, body per template, `Closes #<sub-issue>`; squash merge; one line under `[Unreleased]` in `CHANGELOG.md` per task; commits end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Everything in English. No `TODO` without a linked issue.

## File map

| File | Task | Holds |
| ---- | ---- | ----- |
| `Package.swift` | 1, 3 | targets `FeatureModule`, `TaskViewListFeature`, `AppFeature`, `TestSupport`, the feature test targets; `WasmSizeProbe` depends on `AppFeature` |
| `Sources/FeatureModule/FeatureModule.swift` | 1 | `FeatureEvent`, `FeatureModule` |
| `Sources/Features/TaskViewList/TaskViewList.swift` | 1, 2, 5 | `TaskViewList` with `Model`, `Row`, `UserAction`, `Event`, `Output`, `send` |
| `Sources/Features/App/AppModule.swift` | 3 | `AppModule` with `Model`, `Detail`, `UserAction`, `Event`, `send` |
| `Sources/WasmSizeProbe/main.swift` | 3 | drives `AppModule` as a web client will |
| `scripts/wasm-size.sh` | 3 | the ceiling, re-measured |
| `Tests/Support/TestSupport.swift` | 1 | `TestClock`, `makeStore`, moved out of `TodoCoreTests` |
| `Tests/TaskViewListFeatureTests/TaskViewListTests.swift` | 1, 2 | the list module's tests |
| `Tests/AppFeatureTests/AppModuleTests.swift` | 3 | the root's tests |
| `Sources/DeviceFile/DeviceFile.swift` | 4 | the identity file beside a database, shared by the demo and the app |
| `Sources/TodoCLI/CLI.swift` | 4 | calls `DeviceFile` instead of its own copy |
| `Apps/Apple/Package.swift` | 4, 5 | `TodoAppleUI`, `TodoAppleUITests`, `todo-mac` |
| `Apps/Apple/Sources/TodoAppleUI/ModuleHost.swift` | 4 | `ModuleHost` |
| `Apps/Apple/Sources/TodoAppleUI/TodoApp.swift` | 4, 5 | `TodoApp.launch`, `TodoApp.host` |
| `Apps/Apple/Sources/TodoAppleUI/TaskViewListView.swift` | 5 | `TaskViewListView` |
| `Apps/Apple/Sources/TodoAppleUI/RootView.swift` | 5 | `RootView` |
| `Apps/Apple/Sources/TodoAppleUI/AppScene.swift` | 5 | `AppScene` |
| `Apps/Apple/Sources/todo-mac/TodoMac.swift` | 5 | `@main` |
| `Apps/Apple/Tests/TodoAppleUITests/ModuleHostTests.swift`, `TodoAppTests.swift` | 4 | the host's queue and the launch |
| `.github/workflows/ci.yml` | 6 | the macOS job builds and tests `Apps/Apple`, and builds with Xcode's toolchain |
| `README.md`, `docs/style.md`, `CHANGELOG.md` | 6 | how to run the app; the view rule; the epic's summary |

## Tasks

| # | Issue | Title | Labels | Depends on |
| - | ----- | ----- | ------ | ---------- |
| 1 | #68 | The module contract and the sidebar's read path | `feature`, `core` | |
| 2 | #69 | The sidebar's writes: rename and a new folder | `feature`, `core` | 1 |
| 3 | #70 | The root module, and the size probe drives it | `feature`, `core` | 2 |
| 4 | #71 | The Apple package: the host and the composition root | `feature`, `ui-apple` | 3 |
| 5 | #72 | The views, the scene and the executable | `feature`, `ui-apple` | 4 |
| 6 | #73 | CI for the Apple package, and the documentation that closes the epic | `infra`, `ui-apple` | 5 |

The owner reviews this table and the interface of every task below.

### Task 1: The module contract and the sidebar's read path

**Goal.** The two protocols exist in a target of their own, and the sidebar module reads the tree of views out of the store into rows a view can draw, highlights a selection and reports it. The shared test helpers move into a target every feature's tests can import.

**Files.** `Package.swift`; `Sources/FeatureModule/FeatureModule.swift`; `Sources/Features/Sidebar/Sidebar.swift`; `Tests/Support/TestSupport.swift`, moved from `Tests/TodoCoreTests/TestSupport.swift` with `TodoCoreTests` now depending on `TestSupport`; `Tests/SidebarFeatureTests/SidebarTests.swift`.

**Interface.**

```swift
// FeatureModule
public protocol FeatureEvent: Equatable, Sendable {
    associatedtype UserAction: Equatable & Sendable
    static func action(_ action: UserAction) -> Self
}

public protocol FeatureModule: AnyObject {
    associatedtype Model: Equatable & Sendable
    associatedtype Event: FeatureEvent
    associatedtype Output: Equatable & Sendable
    var model: Model { get }
    func send(_ event: Event) -> Output?
}

// SidebarFeature
public final class Sidebar: FeatureModule {
    public struct Model: Equatable, Sendable {
        public struct Row: Equatable, Sendable {
            public let id: ViewID
            public let title: String
            public let depth: Int
            public let isSelected: Bool
        }
        public let rows: [Row]
        public let problem: String?
    }
    public enum UserAction: Equatable, Sendable {
        case rowSelected(ViewID)
    }
    public enum Event: FeatureEvent {
        case action(UserAction)
        case changed(ChangeSet)
    }
    public enum Output: Equatable, Sendable {
        case selected(ViewID)
    }
    public private(set) var model: Model
    public init(store: Store) throws(StoreError)
    public func send(_ event: Event) -> Output?
}

// TestSupport, public now that three test targets import it
public final class TestClock { public init(start: Int64 = 1_757_500_000_000); public func now() -> Int64; public func jump(by ms: Int64) }
public func makeStore(device: String = Store.newDeviceID(), clock: TestClock = TestClock()) throws(StoreError) -> Store
```

**Rules.**

- The rows are `store.views()` flattened: it already answers in tree order with effective parents, so the depth of a row is its parent's depth plus one, kept in a dictionary as the walk goes; no recursion, and a chain a thousand deep from sync reads like a flat list (`docs/style.md`, "No recursion over data-shaped depth").
- The Inbox is selected at first, by `BuiltInTaskViews.inbox`. A `.rowSelected` sets the highlight and answers `.selected(id)` every time, since choosing the row already chosen is still a choice the root may act on. When `.changed` finds the selected view gone, no row is selected and nothing is answered: it was not a choice.
- `.changed` whose `views` is empty does nothing at all, not even a read; one that names a view rereads the whole tree, because views number in the tens and the order needs every row (spec, "The sidebar in M2").
- `init` throws, because a store that cannot be read at launch is the composition root's to refuse (spec section 5); `send` never throws, and a read that fails inside it keeps the rows it has and writes the failure into `problem`, which Task 2 gives its first test through a refused write and this task names in its PR.
- `TestSupport` is an ordinary target under `Tests/Support` so that `TodoCoreTests`, `SidebarFeatureTests` and later `AppFeatureTests` share one `makeStore`; it is in no product and builds for wasm32 like the core.

**Tests.**

- `initialModelListsTheBuiltInViewsInRankOrderWithInboxSelected`: five rows at depth 0, Inbox `isSelected`, `problem` nil.
- `nestedViewsGetTheirDepthInTreeOrder`: a folder with two children and a grandchild reads as parent, children in rank order, grandchild at depth 2.
- `selectionMovesTheHighlightAndReportsTheChoice`: `.rowSelected(today)` answers `.selected(today)`, exactly one row `isSelected`.
- `changedWithAViewRereadsTheTree`: a view created through the store appears after `.changed` naming it.
- `changedWithoutAViewLeavesTheModelAlone`: a view created through the store does not appear after `.changed` naming only a task, which is the proof that no read happened.
- `theSelectionIsDroppedWhenTheSelectedViewDisappears`: delete the selected view through the store, send `.changed`, no row selected, no output.
- `aThousandNestedFoldersReadWithoutRecursion`: a chain of 1,000 views journaled straight into the store reads as 1,000 rows with depths 0 to 999.

**Verified facts and traps.**

- 2026-09-20: the contract as written compiles under Swift 6.3.3 and under Xcode 26.3's 6.2.4 in language mode 6, and an enum case `case action(_:)` is accepted as the witness of the static requirement (SE-0280); the associated type was then spelled `Action`, and its rename changes nothing the compiler sees.
- 2026-09-20: an ordinary target declared with `path: "Tests/Support"` and depended on by a test target builds and its test passes with `swift test`.
- `store.views()` returns every undeleted view in tree order with the effective parent already resolved (`Store+Views.swift`); `children(ofView:)` is a filter over it, so calling it per level would read the table once per level.
- Trap: `TestSupport` becoming `public` widens `TestClock` and `makeStore`; nothing else in it may widen, and `@testable import TodoCore` stays in `TodoCoreTests` only.

### Task 2: The sidebar's writes: rename and a new folder

**Goal.** An action from a person goes the whole way: through the module into the store and back into the model, with the draft of a text field living in the model, an empty title refused by the module, a folder created through the store, and a refusal of the store shown instead of thrown.

**Files.** `Sources/Features/TaskViewList/TaskViewList.swift`; `Tests/TaskViewListFeatureTests/TaskViewListTests.swift`.

**Interface.** `Row` gains `draft`, `UserAction` gains five cases; the rest of Task 1's interface is unchanged.

```swift
public struct Row: Equatable, Sendable {
    public let id: ViewID
    public let title: String
    public let depth: Int
    public let isSelected: Bool
    public let draft: String?          // the rename in progress on this row, nil on every other
}

public enum UserAction: Equatable, Sendable {
    case rowSelected(ViewID)            // the list's selection changed
    case renameMenuItemChosen(ViewID)   // the row's Rename menu item
    case titleFieldChanged(String)      // the text of the open field
    case titleFieldSubmitted            // Return in the open field
    case titleFieldCancelled            // Esc in the open field
    case createFolderButtonTapped       // the toolbar button
}
```

**Rules.**

- `.renameMenuItemChosen(id)` opens the field on that row with the current title as the draft; `.titleFieldChanged(text)` replaces the draft; `.titleFieldCancelled` closes the field and changes nothing; `.titleFieldSubmitted` with a draft that is empty after trimming whitespace sets `problem` to the sentence of `Problem.emptyTitle` ("A title cannot be empty.") and leaves the field open, without touching the store, which a count of journal rows proves; otherwise it writes `update(view: id, [.title(draft)])`, closes the field and rereads (spec, "The sidebar in M2"). The three field actions are ignored when no field is open: what a gesture means is the module's, and the view does not know whether a rename exists.
- `.createFolderButtonTapped` writes `createView(NewTaskView(title: "New folder"))` at the end of the root level, rereads, selects the new row and opens its rename, so that the person types the name straight away. The default title is a constant of the module; its localisation belongs with the formatting service question of M3 and is raised in chat, not decided here.
- A write that the store refuses, `StoreError.notFound` when a peer deleted the view underneath the rename, lands in `problem` as the sentence of `Problem.viewIsGone(title:)`, which names the view the rename was on, closes the field and rereads. The store's error does not travel: `Problem` is the module's own private enum, added in Task 1 with `couldNotRead` and gaining these two cases here, and what reaches the model is always its finished sentence, because a view spells nothing (owner's review of #75). `problem` is cleared by the next action of any kind and survives `.changed`.
- One rename at a time: `.renameMenuItemChosen` on another row moves the field there and drops the old draft.

**Tests.**

- `renameGoesThroughTheDraftIntoTheStore`: begin, three drafts, commit; the store's view carries the last draft, the row shows it, no field is open.
- `cancelRenameLeavesTheTitleAndClosesTheField`.
- `anEmptyTitleIsRefusedByTheModuleAndTheFieldStaysOpen`: `problem` set, the journal's row count unchanged, `draft` still there.
- `createFolderAddsARowAtTheEndSelectsItAndOpensItsRename`.
- `aStoreRefusalLandsInTheProblemAndTheNextActionClearsIt`: delete the view through the store during the rename, commit, `problem` is the sentence of `.viewIsGone` and names the view; `.rowSelected` clears it.
- `fieldActionsWithoutAnOpenRenameAreIgnored`: `.titleFieldChanged`, `.titleFieldSubmitted` and `.titleFieldCancelled` with no field open leave the model and the journal's row count unchanged.
- `problemSurvivesAChangedEvent`.

**Verified facts and traps.**

- `update(view:_:)` throws `.notFound` for a deleted view before it stamps anything (`requireView` in `Store+Views.swift`), so a refusal leaves no journal row.
- `createView` places at `.end` by default and returns the new id, which is what the selection and the rename need.
- Trap from #40: two changes to one field in one `update` call keep only the last; a rename sends one `.title` and nothing else.

### Task 3: The root module, and the size probe drives it

**Goal.** The root composes the sidebar, creates the detail screen from the sidebar's output, fans the world's events out, and is what the wasm size job measures from now on.

**Files.** `Package.swift`; `Sources/Features/App/AppModule.swift`; `Tests/AppFeatureTests/AppModuleTests.swift`; `Sources/WasmSizeProbe/main.swift`; `scripts/wasm-size.sh`.

**Interface.**

```swift
public final class AppModule: FeatureModule {
    public struct Model: Equatable, Sendable {
        public struct Detail: Equatable, Sendable {
            public let title: String
        }
        public let taskViewList: TaskViewList.Model
        public let detail: Detail?
    }
    public enum UserAction: Equatable, Sendable {
        case taskViewList(TaskViewList.UserAction)
    }
    public enum Event: FeatureEvent {
        case action(UserAction)
        case changed(ChangeSet)
    }
    public typealias Output = Never
    public private(set) var model: Model
    public init(store: Store) throws(StoreError)
    public func send(_ event: Event) -> Never?
}
```

**Rules.**

- `.action(.taskViewList(a))` becomes `taskViewList.send(.action(a))`; `.changed(c)` becomes `taskViewList.send(.changed(c))` and a refresh of the detail; after either the root's model is rebuilt from `taskViewList.model` (spec section 3).
- `Detail` is the placeholder for the screen M3's list module will be: it is created from the output `.selected(id)` by reading `store.view(id)`, which is the root's own read and not the child's model, so that the M3 module slots in where a `Detail` is made today (spec section 4). On `.changed` naming a view the detail is read again and dropped when the view is gone; at launch the detail is the Inbox, since the sidebar starts on it.
- The root reads through the same store the children hold; a read that fails keeps the detail it has, since the root has no `problem` of its own in M2 and the sidebar shows the store's state.
- The size probe drives the root as a web client will: open a store in memory, build an `AppModule`, send a selection, a full rename, a folder and a `.changed`, and print the model, since a result nobody reads is a call the linker drops (#23). The ceiling in `scripts/wasm-size.sh` is re-measured on the probe's release build and set with the same four percent of headroom, and the number and both readings go into the PR.

**Tests.**

- `theDetailFollowsTheSelection`: `.taskViewList(.rowSelected(today))` gives a detail titled "Today".
- `theDetailFollowsARenameOfTheSelectedView`: rename through the sidebar's actions, detail title follows.
- `theDetailIsDroppedWhenTheSelectedViewDisappears`: delete through the store, `.changed`, detail nil.
- `changedReachesTheTaskViewList`: a view created through the store appears in `model.taskViewList` after `.changed`.
- `theRootModelIsRebuiltAfterEveryEvent`: `model.taskViewList == taskViewList.model` after each of the events above.

**Verified facts and traps.**

- The probe as it stands (`Sources/WasmSizeProbe/main.swift`) measures 6,541,190 bytes after `gzip -9` against a ceiling of 6,815,744; the sidebar and the root add code and the difference is the number to report.
- Trap: `WasmSizeProbe` builds for wasm32 in release; a `print` of a value the optimiser can fold is not a call kept, so the probe prints values that depend on the store's answers.

### Task 4: The Apple package: the host and the composition root

**Goal.** `Apps/Apple` exists with the host that views observe, tested for the one rule it holds, and the composition root that opens the database, keeps the device identity beside it and wires the store to the host.

**Files.** `Apps/Apple/Package.swift`; `Apps/Apple/Sources/TodoAppleUI/ModuleHost.swift`, `TodoApp.swift`; `Apps/Apple/Tests/TodoAppleUITests/ModuleHostTests.swift`, `TodoAppTests.swift`; `Package.swift` and `Sources/DeviceFile/DeviceFile.swift` in the root package; `Sources/TodoCLI/CLI.swift`.

**Interface.**

```swift
// TodoAppleUI
@MainActor @Observable
public final class ModuleHost<M: FeatureModule> {
    public private(set) var model: M.Model
    public init(_ module: M, world: (@escaping @MainActor (M.Event) -> Void) -> Void)
    public func send(_ action: M.Event.UserAction)
}

@MainActor
public enum TodoApp {
    /// The store at its path, the root module, the host, and the store's onChange wired to the host.
    public static func launch(environment: [String: String]) throws -> ModuleHost<AppModule>
}

// DeviceFile, root package, the demo's rule shared with the app
public enum DeviceFile {
    /// The identity kept beside the database, or nil when nothing keeps one.
    public static func read(beside database: String) -> String?
    public static func keep(_ device: String, beside database: String) throws
}
```

**Rules.**

- The host's `send(UserAction)` lifts into `.action` and `deliver(Event)`, which is private: whatever arrives while an event is in flight waits in an array and is sent after the current one returns, on one thread, so a module never sees its own write in the middle of its own update (spec section 5). `world` runs inside `init` after every property is set and receives `deliver` once; the composition root is its only caller.
- `TodoApp.launch` reads `TODO_DB` and `TODO_DEVICE` the way the demo does, so one machine runs two copies as two devices; without them the database is `todo.sqlite` under Application Support in a `todo` directory created if missing, and the identity is `DeviceFile.read` beside it or a minted one kept there (ADR-0005). It opens the store with `Store.systemNow`, builds `AppModule`, the host, and assigns `store.onChange` to deliver `.changed`. It throws whatever the store or the file system throws; the scene decides that this is fatal (Task 5).
- `DeviceFile` is the demo's `device(for:)` and `keep` written once and called from both, so that the app and the demo agree on where an identity lives; `TodoCLI` keeps `TODO_DEVICE` and `:memory:` as its own concerns.
- `TodoAppleUI` depends on `AppFeature`, `FeatureModule`, `TodoCore` and `DeviceFile` by the local package path `../..`; the manifest pins `macOS(.v14)`; the executable comes in Task 5.

**Tests.**

- `sendLiftsAnActionIntoAnEventAndCopiesTheModel`: a stub module in the test target records the events it gets.
- `anEventDeliveredDuringASendWaitsForItToReturn`: the stub calls the world entrance from inside its `send`; the recorded order is the first event complete, then the second.
- `theWorldEntranceReachesTheModuleAsAnEvent`.
- `launchOpensTheDatabaseAtTheGivenPathAndKeepsTheDeviceBesideIt`: `TODO_DB` at a temporary path, a second launch reads the same identity, `TODO_DEVICE` outranks the file.
- `launchRefusesAPathThatCannotBeOpened`.
- In the root package: `DeviceFile` round-trips an identity and reads nothing where there is no file; the demo's tests stay green.

**Verified facts and traps.**

- 2026-09-20: the host as written compiles under 6.3.3 and Xcode's 6.2.4 in language mode 6 as a `@MainActor @Observable` generic class holding a non-`Sendable` module, and the run shows a change set fired inside a write delivered after the send that caused it.
- 2026-09-20: assigning a closure that calls the host to `Store.onChange`, whose type is not actor-isolated, compiled from main-actor top-level code; `TodoApp.launch` is `@MainActor` and is expected to be the same case, checked first thing.
- Trap: the demo writes the device file non-atomically on purpose (`CLI.keep`, FoundationEssentials on WASI refuses the atomic write); `DeviceFile` keeps that and its comment, since it builds for wasm32 with the rest of the root package.

### Task 5: The views, the scene and the executable

**Goal.** `swift run todo-mac` opens a window with the sidebar over a real database: selecting shows the title in the detail pane, renaming goes through the module, a folder is created, and a problem is shown. The views hold no logic.

**Files.** `Sources/Features/TaskViewList/TaskViewList.swift` and its tests; `Apps/Apple/Package.swift`; `Apps/Apple/Sources/TodoAppleUI/TaskViewListView.swift`, `RootView.swift`, `AppScene.swift`, `TodoApp.swift`; `Apps/Apple/Sources/todo-mac/TodoMac.swift`.

**Interface.**

```swift
// TaskViewListFeature: what List needs, added with its first caller
extension TaskViewList.Model { public let selection: ViewID? }     // a stored field: the id of the selected row
extension TaskViewList.Model.Row: Identifiable {}

// TodoAppleUI
struct TaskViewListView: View { init(model: TaskViewList.Model, send: @escaping (TaskViewList.UserAction) -> Void) }
struct RootView: View { init(host: ModuleHost<AppModule>) }
public struct AppScene: Scene { public init(); public var body: some Scene }
extension TodoApp { public static let host: ModuleHost<AppModule> }   // launched once; fatal with the reason if it cannot

// todo-mac
@main struct TodoMac: App { var body: some Scene { AppScene() } }
```

**Rules.**

- `TaskViewListView` draws `List(model.rows, selection:)` with a binding whose get is `model.selection` and whose set sends `.rowSelected`; a row with a `draft` draws a `TextField` whose binding gets the draft and sets `.titleFieldChanged`, whose `onSubmit` sends `.titleFieldSubmitted` and whose `onExitCommand` sends `.titleFieldCancelled`; a context menu item sends `.renameMenuItemChosen`; a toolbar button sends `.createFolderButtonTapped`; `problem` draws below the list when present. Every `if` is over a `Bool` or an optional of the model, and the only strings the view owns are its labels (spec section 2).
- `RootView` gives `TaskViewListView` `host.model.taskViewList` and `{ host.send(.taskViewList($0)) }`, and draws `detail` in the second column of a `NavigationSplitView`, with a placeholder label when it is nil (spec sections 3 and 4).
- `TodoApp.host` is a `@MainActor static let`, initialised once by the runtime on first use, which is how the composition happens once per launch without a `@State` whose initial value is evaluated on every creation of its struct (spec, Risks); a failed launch is `fatalError` with the store's message, the recovery flow being M3's.
- The executable is `@main` and one line of body; nothing else may live in its target (ADR-0008).
- Checked by hand and reported in the PR: the window opens and takes keyboard focus, or the activation the risk names is added; a rename with a Russian layout and with an input method that composes text; two instances under two `TODO_DB` paths.

**Tests.**

- `selectionNamesTheSelectedRow` in `TaskViewListFeatureTests`: `model.selection` equals the id of the one row with `isSelected`, and is nil after the selected view disappears.
- No view tests: by the rule there is nothing in them to test; the reviewing agent reads them for the rule instead.

**Verified facts and traps.**

- 2026-09-20: a SwiftUI app whose `Scene` lives in a library target builds and launches from a two-line executable of a bare SwiftPM package, with the pinned toolchain.
- 2026-09-20: `TaskViewListView` and `RootView` as sketched above compile against the contract in language mode 6 under both toolchains.
- Trap: a `@State` in a `Scene` or `App` evaluates its initial value on every creation of the struct, and a composition held that way opens the store twice over one file, which is two stores over one journal (ADR-0005).
- Trap: a bare executable has no bundle, so `Bundle.main` has no resources and no Info.plist; nothing in `TodoAppleUI` may rely on either.

### Task 6: CI for the Apple package, and the documentation that closes the epic

**Goal.** The macOS job builds and tests `Apps/Apple` and builds the root package with Xcode's toolchain, the README says how to run the app, `docs/style.md` points at the view rule, and the changelog holds the epic's summary.

**Files.** `.github/workflows/ci.yml`; `README.md`; `docs/style.md`; `CHANGELOG.md`; `docs/adr/0006`, `0007`, `0008` (status Accepted).

**Interface.** None: no code.

**Rules.**

- The macOS job keeps running on `main` and on demand only (`docs/process.md`, section 10). It adds, after the SDK compile checks: `swift build` and `swift test` in `Apps/Apple`, and `/usr/bin/swift build` in the repository root and in `Apps/Apple`, each into its own scratch path so that the two toolchains never share a `.build`. The added minutes are reported in the PR against the 200 a month.
- The Linux job is not touched: the root package's new targets are already in its build, its host run and its WasmKit run.
- `docs/style.md` gains one entry under a new "Views" heading that states the view rule and points at ADR-0006; the owner edits the file directly, so the entry is proposed in the PR and the wording is theirs.
- The three ADRs move from Proposed to Accepted, since the PR that proposed them has merged by then.
- `README.md` gains a section on running the app: from `Apps/Apple`, `swift run todo-mac`, the two environment variables, where the database and the identity file live.

**Tests.** The CI run on `main` after the merge is the test: both jobs green, the macOS job's new steps present in its log.

**Verified facts and traps.**

- The macOS job takes about 1.7 minutes today and `macos-26` runners carry Xcode 26; a build of the Apple package with SwiftUI is expected to add a few minutes, to be read off the first run.
- Trap: `actions/checkout@v4` and `actions/cache@v4` warn about Node 20; not this task's to fix, and not to be silenced by an upgrade without reading the changelog.

## Self-review against the spec

| Spec section | Task |
| ------------ | ---- |
| 1. Logic lives in the shared core | 1, 2 (the sidebar), 3 (the root) |
| 2. The module contract | 1 (the protocols, the sidebar's types), 2 (the writes), 5 (`selection` and `Identifiable`, with their callers) |
| 3. Composition | 3 |
| 4. Navigation | 3 (`Detail` created from the output, where M3's list module goes); the mechanics, a stack or sheets, are the navigation epic's #67 and no task builds them, as the spec says |
| 5. Hosting on Apple: the host, one event at a time, the composition root, the thread | 4; `TodoApp.host` once per launch in 5 |
| 5. Formatting, Today | not built, as the spec says; no task touches them |
| 6. Two packages, one target per feature, ADR-0001 extended, names, toolchains | 1 (targets), 4 (`Apps/Apple`), 6 (the toolchain check in CI) |
| The sidebar in M2 | 1 (read, select, world), 2 (rename, create, refusal) |
| Changes to the core | none, as the spec says; `DeviceFile` in Task 4 is a new target beside the core, not a change to it |
| Testing, CI and the deliverable | tests per task; the size probe in 3; the host test in 4; CI in 6; the deliverable in 5 |

Deviations, each stated where it happens:

- `TaskViewList.Model` carries `selection` beside the rows' `isSelected` (Task 5): SwiftUI's `List` binds to an id and a row draws from a flag, and computing one from the other in the view would be the view searching the model.
- `AppModule.Model.Detail` is a struct with a title rather than a bare string (Task 3): it is the seat of M3's list module and is created from the output, as section 4 says a screen is.
- `DeviceFile` (Task 4) is a target the spec does not name: the demo already keeps an identity beside the database and the app needs the same rule, and `docs/style.md` asks for one shape where two would otherwise exist.
- The default title of a new folder is a constant of the sidebar module (Task 2), which is a string a module writes about the data; its localisation is a question for the formatting service in M3, raised in chat.
