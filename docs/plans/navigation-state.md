# Plan: Navigation state the view only reads

- Status: Draft
- Spec: `docs/specs/navigation-state.md`, approved 2026-10-22
- Epic: #117

Written for the engineer and derived from the approved spec. The plan
fixes what the tasks are, in what order, and what each one promises to
the next. It does not carry the implementation: code appears only where
it already ran. A task section is 50 to 100 lines. Once a task ships its
section is history; a departure is stated in the task's pull request and
fixed forward into the sections that depend on it, never back into the
shipped one (`docs/process.md`, sections 6 and 7).

> Written by hand from `docs/plans/TEMPLATE.md`, its third use. Executed
> task by task, one sub-issue per branch and pull request, with
> superpowers:subagent-driven-development, each implementing and
> reviewing agent briefed with the spec, `docs/style.md`, ADR-0006,
> ADR-0007 and ADR-0009 with their amendments of 2026-10-22, and the
> task's section, and with the shipped code of the tasks it depends on
> rather than their sections.

## Global constraints

The rules every task obeys, each with the spec section or ADR it comes
from.

- Toolchain: Swift 6.4.0 as `.swift-version` pins it, through swiftly (`export PATH="$HOME/.swiftly/bin:$PATH"`), with the wasm SDK `swift-6.4.0-RELEASE_wasm`; Xcode 27.1's toolchain is the same version (ADR-0008). A directory without the pin gets swiftly's default, 6.2.1 on this machine, which cannot import the 6.4 wasm SDK's modules: every command runs from the repository or a package inside it.
- The `FeatureModule` target depends on nothing and names no screen: it holds the module protocols, `Seat`, and from Task 1 the destination, the stack, its element id, the protocol of a flow's enum of screens and the notice the stack sends (ADR-0007, amendments of 2026-10-15 and 2026-10-22). A feature target imports `TodoCore`, `FeatureModule` and the features whose routes its destination holds, never a sibling or the root. `AppFeature` depends on every kind of screen its window's stack can hold, `TaskListFeature` and `TaskScreenFeature` from Task 2 (ADR-0009, amendment of 2026-10-22, point 3). No SwiftUI, Observation or Foundation proper in the root package; the wasm32 build in CI enforces it (ADR-0001).
- A module is a `final class` conforming to `FeatureModule`, its model computed from its state, `send` synchronous and never throwing, what the store refuses written into the model as a sentence (ADR-0006, `docs/style.md`). A screen that can be opened conforms to `Routable`; its `init(store:route:)` throws `StoreError` where it can refuse to be made.
- The spec and the ADRs call the place a screen declares what is open over it its slot. In code it is `Destination`, held in a screen's `destination`, a name the owner chose on 2026-10-23 because "slot" does not say what it holds.
- A screen says what is open over it only in its destination, and no module creates, holds or drops a screen of its flow's stack but the stack (ADR-0009, amendment of 2026-10-22, "Constrained"). Navigation inside a module is a write of its destination, by its own gesture, by `.uncovered` or by `.route`; the stack's walk after the event is the one reconciliation for all of them (point 4). A seat stays for a child a parent holds alone: the window's quick entry.
- What a screen asks for reaches the screen right below it, its opener, and the base's answers reach the flow's owner; an opener keeps only its reaction to its child's `Output`, in a `switch` with no `default` (ADR-0009 amendment, point 2; ADR-0006, amendment of 2026-10-03).
- The text form of a window's route does not change, and neither do `RouteTests` and the route types it reads into (spec section 3).
- A module never writes to the store in answer to `.changed`, and the host takes one event at a time (`docs/specs/navigation.md`, section 5).
- A view holds no condition over a domain value. It may switch over two enums of its model and no others, the layout shape and the screens of a stack, the latter in one place per stack, every case drawn with no `default`. It reports the width of its window and decides nothing by it. Every binding is read from the model and set only by sending an action; a stack's path is set only by `.wentBack(to:)` (`docs/style.md`, "Views"; ADR-0006, amendment of 2026-10-22).
- A user action names the control and the gesture (`docs/style.md`); events of the world are named for what happened, `.created`, `.changed`, `.route`, and the stack's notices beside them.
- The five type names Task 1 exports were probed on 2026-10-23 (Verified facts of Task 1). The names Tasks 2 and 3 add are nested in `AppModule`: `Screen`, `ScreenModel`, `ScreenAction`, `Width` and `Layout`, declared so in a file importing SwiftUI, Foundation and Observation, typechecked the same day for macOS 14, iOS 17 and watchOS 10 in a view that switches over the layout and reports the width, and SwiftUI's own `Layout` protocol still resolved unqualified beside them. A name a task adds beyond these gets the same probe before it is fixed (`docs/style.md`).
- Tests are swift-testing. A module test opens `makeStore` with the test clock, sends events and compares the model whole. The root package's suite runs green on the host with `swift test` and on wasm32 with `swift test --swift-sdk swift-6.4.0-RELEASE_wasm --disable-xctest`, and `scripts/wasm-size.sh` passes, before every PR.
- `Apps/Apple` is built and tested from its directory with the pinned toolchain. A task that changes it starts the macOS job from the Actions tab on its branch before asking for the merge (`docs/process.md`, section 10), and is checked by hand in the iOS 26.3 simulator on an iPhone 17, an iPhone 17 Pro Max and an iPad Pro 11-inch (M5), and on the Mac.
- Branch per task `<type>/<issue>-<slug>`, PR title in Conventional Commits with scope `core` or `apple`, body per template, `Closes #<sub-issue>`; squash merge; one line under `[Unreleased]` in `CHANGELOG.md` per task; commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Everything in English. No `TODO` without a linked issue.

## File map

| File | Task | Holds |
| ---- | ---- | ----- |
| `Sources/FeatureModule/Destination.swift` | 1 | `Destination`, its `Declared` enum and the write mark |
| `Sources/FeatureModule/StackScreen.swift` | 1 | `StackScreen`, `StackNotice` |
| `Sources/FeatureModule/ScreenStack.swift` | 1 | `ScreenStack`, `StackElementID`, the walk |
| `Tests/FeatureModuleTests/ScreenStackTests.swift` | 1 | the stack over a stub base and two stub screens |
| `Package.swift` | 1, 2 | the comment on the `FeatureModule` target (1); `AppFeature` depends on `TaskListFeature` and `TaskScreenFeature`, and the comments on the feature targets (2) |
| `Sources/FeatureModule/Routable.swift` | 2 | the comment on `route`, assembled from the head and the declaration |
| `Sources/Features/TaskViewList/TaskViewList.swift` | 2 | the destination as the highlight; the seat, the selection, `listBackButtonTapped` and `.taskList` go |
| `Sources/Features/TaskList/TaskList.swift` | 2 | the destination; the seat, `backButtonTapped` and `Model.task` go |
| `Sources/Features/App/AppModule.swift` | 2, 3 | the stack, `.screen`, `.wentBack(to:)`, the model by id (2); the width and the layout (3) |
| `Sources/Features/App/Screen.swift` | 2 | `AppModule.Screen`, `ScreenModel`, `ScreenAction` and the mappings |
| `Tests/TaskViewListFeatureTests/TaskViewListTests.swift` | 2 | the sidebar's destination |
| `Tests/TaskListFeatureTests/TaskListTests.swift` | 2 | the list's destination |
| `Tests/AppFeatureTests/AppModuleTests.swift` | 2, 3 | the spec's three flows and every flow M3 shipped, through the stack (2); the layout (3) |
| `Sources/WasmSizeProbe/main.swift`, `scripts/wasm-size.sh` | 2, 3 | the probe drives the stack (2) and the width (3); the budget re-measured |
| `Apps/Apple/Sources/TodoAppleUI/RootView.swift` | 2, 3 | the one switch over the screens and the bound path (2); the switch over the layout (3) |
| `Apps/Apple/Sources/TodoAppleUI/TaskListView.swift` | 2 | its `navigationDestination` goes |
| `Apps/Apple/Sources/TodoAppleUI/TodoApp.swift`, `WindowView.swift` | 3 | the window made with its width, and the width reported |
| `Apps/Apple/Tests/TodoAppleUITests/TodoAppTests.swift` | 2, 3 | the model's new shape (2); the width (3) |
| `docs/style.md` | 2 | the action example `backButtonTapped` replaced |
| `docs/adr/0006-*.md` | 3 | a further amendment, only if a probe's fallback is taken |
| `README.md`, `CHANGELOG.md` | 1, 2, 3 | the changelog line; the README where behaviour a person sees changes |

## Tasks

| # | Issue | Title | Labels | Depends on |
| - | ----- | ----- | ------ | ---------- |
| 1 | | The destination and the screen stack | `feature`, `core` | |
| 2 | | The window's screens stand in one stack | `feature`, `core`, `ui-apple` | 1 |
| 3 | | The module decides the layout | `feature`, `core`, `ui-apple` | 2 |

The owner reviews this table and the interface of every task below.

The split leaves `main` working after every merge. The modules, the root
and the root view change together in Task 2, because the root's model
and actions are what the root view draws and sends, and a root view left
behind would not compile. Task 3 then moves the one decision Task 2
leaves in the view, which tree a width gets, into the module. Between
the two merges the view cuts the stack's path into a column and a path
by its own width class, the spec's rejected alternative, for one task.

### Task 1: The destination and the screen stack

**Goal.** `FeatureModule` holds what every flow needs and nothing of any one screen: the destination a screen declares in, the protocol of a flow's enum of screens, and the stack that follows the declarations after every event by the seat's rule, hands each answer to the opener, and gives every element an id (spec section 2). Nothing in the product uses them yet; Task 2 is their caller.

**Files.** `Sources/FeatureModule/Destination.swift`, `StackScreen.swift`, `ScreenStack.swift`; `Tests/FeatureModuleTests/ScreenStackTests.swift`; `Package.swift`, the comment on the `FeatureModule` target; `CHANGELOG.md`.

**Interface.**

```swift
public struct Destination<Pushed: RouteValue> {
    public enum Declared: Equatable, Sendable { case pushed(Pushed) }
    public var pushed: Pushed? { get }
    public init()
    public mutating func declare(_ declared: Declared?)
    public func map<Mapped: RouteValue>(_ transform: (Pushed) -> Mapped) -> Destination<Mapped>
    // internal: what is declared, and the write mark every `declare` moves; the stack reads both
}

public struct StackElementID: Hashable, Sendable {}   // opaque, handed out in order

public enum StackNotice<Screen: StackScreen> {
    case created
    case declared(Screen.Route)
    case answered(Screen.Output)
    case uncovered
    case notOpened(Screen.Failure, stillOpen: Screen.Route?)
}

public protocol StackScreen {
    associatedtype Base: Routable
    associatedtype Route: RouteValue
    associatedtype Model: Equatable & Sendable
    associatedtype Event
    associatedtype Output
    associatedtype Failure: Error
    var route: Route { get }
    var model: Model { get }
    var destination: Destination<Route> { get }
    func send(_ event: Event) -> Output?
    func take(_ notice: StackNotice<Self>) -> Output?
    func route(over above: Route?) -> Route
    static func destination(of base: Base) -> Destination<Route>
    static func take(_ notice: StackNotice<Self>, base: Base) -> Base.Output?
    static func route(of base: Base, over above: Route?) -> Base.Event.Route
}

public struct ScreenStack<Screen: StackScreen> {
    public init(base: Screen.Base, make: @escaping (Screen.Route) throws(Screen.Failure) -> Screen)
    public var baseModel: Screen.Base.Model { get }
    public var path: [StackElementID] { get }
    public var models: [StackElementID: Screen.Model] { get }
    public var route: Screen.Base.Event.Route { get }
    public mutating func send(_ event: Screen.Base.Event) -> Screen.Base.Output?
    public mutating func send(_ event: Screen.Event, to id: StackElementID) -> Screen.Base.Output?
    public mutating func wentBack(to path: [StackElementID]) -> Screen.Base.Output?
}
```

**Rules.**

- The destination is the owner's optional enum. `presented` is on paper (spec section 5, "Built in this epic") and joins `Declared` with the first screen that declares a modal, as a second generic parameter; until then a destination holds a push or nothing. `pushed` is the one public read, the declared route, which a module's `route` and the sidebar's highlight are read from; the declaration as a whole is internal, read by the stack alone.
- Every `declare` is a new write, the same value written again included, and moves the write mark; the mark is internal, so only the stack reads it. That is how a destination tells a new write from an old one (spec section 2, the engineer's call the spec left to the plan): the stack records, per opener, the mark it last followed, and a mark it has followed is never followed again. `map` keeps the mark.
- The base is not an element. It is the flow owner's typed module, made by the owner and handed to the stack, which keeps it private: the owner reads its model through `baseModel` and reaches it only through `send(_:)`, so no event reaches the base without the walk after it. The stack reaches it through the protocol's three static requirements, and its answers come back out of every mutating call. The elements over it are the protocol's cases, in `path`, bottom up. Ids are handed out in order and never reused within a stack, so the same kind of screen can stand twice.
- The stack's `init` does not walk: an `init` has nowhere to put the base's answers. The owner's first call, `send(.created)` to the base, makes the first walk, so the base hears `.created` before any notice, and a screen the stack makes hears `.created` before anything else (ADR-0006, amendment of 2026-10-03).
- The walk runs after every call, from the base up: an opener whose mark the stack has followed is passed over; a new write declaring nothing drops everything above; a new write with the head of the screen above hands it `.declared(route)` once; another head makes the screen, before anything is let go, replaces everything above with it and hands it `.created`. A screen that cannot be made leaves what stands, and its opener takes `.notOpened(error, stillOpen:)` with the route of what still stands over it, and takes that back as its destination; the stack records that write as followed, so the declaration is tried once (spec, "Risks"). After any notice that drew an answer the walk starts again from the base, so a lower destination an answer moved is followed before anything above it.
- An answer goes down: the element's opener takes `.answered(output)`, its answer goes to its own opener, and the base's goes out. When one call draws more than one answer from the base, the first in the order drawn is returned, the base's answer to the event itself before any the walk draws; the window's base answers only a gesture made on it, so it answers at most once. (The probe returned the walk's first; the plan fixes the order.)
- `wentBack(to:)` moves only a strict prefix of `path`: an id the stack never gave, a path that is not a prefix, the same path and a longer one move nothing (spec section 3, "A pop the model drove"). Otherwise the stack drops everything above the prefix, then tells the screen now on top, or the base, `.uncovered`, and walks; a screen cannot keep a destination the person closed, since what was over it is already gone (spec section 3, the engineer's call).
- `route` is written from the top down: each element's route with its declaration replaced by the route of what actually stands over it, then the base's, so an aged declaration never reaches the text (spec section 3).
- `send(_:to:)` for an id the stack does not hold moves nothing and answers nothing.

**Tests.** Over a stub base declaring a stub list by number, and stub lists declaring stub tasks; a head of 99 cannot be made.

- `theStackMakesWhatTheBaseDeclaresAndTellsItItWasCreated`: a base made on a list with a task gives two elements, each told `.created` once, and the base heard `.created` before any notice.
- `aMadeScreensAnswerToCreatedReachesItsOpener`.
- `anAnswerThatEmptiesALowerDestinationDropsWhatStandsOverItInTheSameWalk`: a task the walk makes, answering `.created` with a request to close, is gone when the call returns.
- `aNewWriteWithTheSameHeadKeepsTheScreenAndHandsItTheDeclarationOnce`: the element's identity holds; it was handed `.declared` once.
- `aDeclarationAlreadyFollowedIsNeverHandedAgain`: after the list declares a task, an event on the base hands the list nothing.
- `anotherHeadReplacesEverythingAbove` and `anEmptyDeclarationDropsEverythingAbove`.
- `aScreenThatCannotBeMadeLeavesWhatStandsAndItsOpenerTakesItBackOnce`: `.notOpened` with the route of what stands; a later event does not try again.
- `anAnswerGoesToTheOpenerAndTheBasesAnswerToTheOwner`, and `aScreenAskingToCloseIsDroppedThroughItsOpener`.
- `wentBackDropsWhatWasAboveAndTellsTheScreenNowOnTop`, to the base included.
- `wentBackToAPathTheStackDoesNotHoldMovesNothing`: a foreign id, a non-prefix, the same path, a longer one.
- `theSameKindOfScreenCanStandTwice`: a task over a task, two ids, two models.
- `theRouteIsWrittenFromWhatStands`: the base's aged declaration does not reach the route.
- `anEventForAnIDTheStackDoesNotHoldMovesNothing`.

**Verified facts and traps.**

- 2026-10-23, Swift 6.4.0, a throwaway package with the real `FeatureModule` sources, these signatures with a working walk, and a stub sidebar, list and task: a link made two elements and wrote `/view/1/task/7`; a tap replaced the task and kept the list; a click on the highlighted view kept the list and dropped the task; back once, then the same path again, moved what it should; a task asking to close was dropped through the list; a task and a list that could not be made left what stood, the highlight back on the open list; back to the base emptied it; a foreign path moved nothing. It built for wasm32 with the 6.4.0 SDK.
- Trap: Swift 6.4 does not infer `Base` or `Failure` from the static requirements or from the stack's `make`: the conforming enum spells `typealias Base` and `typealias Failure`, or fails with "protocol requires nested type 'Base'".
- Trap: one case's payload out of an optional route enum does not typecheck as an inline `if case` expression in an argument ("type of expression is ambiguous"); the screens' route enum carries one accessor per case. A `switch` expression whose arms are optional calls and `nil` does not typecheck either; its arms `return`.
- Names: `ScreenStack`, `StackElementID`, `StackScreen`, `StackNotice` and `Destination`, each alone in a file importing SwiftUI, Foundation and Observation, are unresolved for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 (swiftlang-6.4.0.34.1), so free; `List`, `Text` and `State` resolve, the control.

### Task 2: The window's screens stand in one stack

**Goal.** The sidebar and the list declare what is open over them in destinations and hold no screen; the root holds the window's stack, with the sidebar as its base, and an enum of the two kinds of screen that stand over it; the root view binds a path of ids the model gives it, draws each element through one switch, and sends a pop back whole as `.wentBack(to:)`. `stackPath`, `narrowPath`, `PushedList`, every read of `host.route` in the views, the list view's `navigationDestination`, `listBackButtonTapped` and `backButtonTapped` are gone (spec sections 1 to 3, 6 and 7). The highlight is the sidebar's destination, so after a list that could not be opened the highlight stays on the list that is open (spec, "Open questions").

**Files.** `Package.swift`; `Sources/Features/TaskViewList/TaskViewList.swift`, `TaskList/TaskList.swift`, `App/AppModule.swift`, new `App/Screen.swift`; their tests; `Sources/FeatureModule/Routable.swift`, whose comment on `route` says it is assembled from the children's routes; `Sources/WasmSizeProbe/main.swift`, `scripts/wasm-size.sh`; `Apps/Apple/Sources/TodoAppleUI/RootView.swift`, `TaskListView.swift`; `Apps/Apple/Tests/TodoAppleUITests/TodoAppTests.swift`; `docs/style.md`; `CHANGELOG.md`.

**Interface.** Consumes Task 1's interface whole. Produces:

```swift
// TaskViewList: Model loses `taskList`; UserAction loses `listBackButtonTapped` and `.taskList`.
public var destination: Destination<TaskList.Route> { get }
public enum Event: RoutedEvent {
    case action(UserAction), changed(ChangeSet), created, route(Route)
    case answered(TaskList.Output), uncovered, notOpened(StoreError, stillOpen: TaskList.Route?)
}

// TaskList: Model loses `task`; UserAction loses `backButtonTapped`.
public var destination: Destination<TaskScreen.Route> { get }
public enum Event: RoutedEvent {
    case action(UserAction), changed(ChangeSet), created, route(Route)
    case answered(TaskScreen.Output), uncovered, notOpened(StoreError, stillOpen: TaskScreen.Route?)
}

extension AppModule {
    public struct Model: Equatable, Sendable {
        public let taskViewList: TaskViewList.Model
        public let path: [StackElementID]            // Task 3 replaces it with `layout`
        public let screens: [StackElementID: ScreenModel]
        public let quickEntry: QuickEntry.Model?
        public let problem: String?
    }
    public enum ScreenModel: Equatable, Sendable { case list(TaskList.Model), task(TaskScreen.Model) }
    public enum ScreenAction: Equatable, Sendable { case list(TaskList.UserAction) }
    public enum UserAction: Equatable, Sendable {
        case taskViewList(TaskViewList.UserAction), screen(StackElementID, ScreenAction)
        case wentBack(to: [StackElementID]), quickEntry(QuickEntry.UserAction), quickEntryButtonTapped
    }
    enum Screen: StackScreen { case list(TaskList), task(TaskScreen) }   // internal, in Screen.swift
}
```

**Rules.**

- The sidebar's destination is the highlight: `selection` and `Row.isSelected` are its declared head when a row holds it. A click declares the view's list every time, so a click on the highlighted view is a new write that closes the task (owner, 2026-10-16); `createFolder` declares the folder's list where it moved the highlight; `.route` declares the route's list when it names one and leaves the destination alone when it names none; `.uncovered` and `.answered(.closeRequested)` empty it; `.notOpened` takes back what stays and says "The list could not be opened." A reread leaves the destination alone: a list whose view is gone asks to be closed on its own `.changed`, and the highlight goes with its row by computation. The sentence rules of each gesture stay as they shipped, `.uncovered` taking those of `listBackButtonTapped`.
- The list: a tap on a row it holds declares the task; `.route` declares the route's task and takes the sentence; `.uncovered` and `.answered(.closeRequested)` empty the destination and leave the sentence; `.notOpened` takes back what stays and writes "The task is gone." for `.notFound` and "The task could not be read." otherwise. `.changed` no longer reaches the task through the list.
- `AppModule.Screen` is internal and holds the modules; `ScreenModel` and `ScreenAction` are what the view switches over and sends. `ScreenAction` has no `task` case, since the task screen's actions are an empty enum. Its `Route` is an enum of the two routes with a head enum and one accessor per case; its `Event` is `.action(ScreenAction)` and `.changed(ChangeSet)`; every mapping is a `switch` with no `default`, and a pairing that cannot occur answers nothing.
- The root keeps quick entry's seat, its sentence and `.unreadableLink` as they are. It reaches the sidebar only through the stack: `.created` in its `init`, `.route`, `.changed` and the sidebar's actions through `send(_:)`, and its model through `baseModel`. `.changed` goes to the base and then to every element of a snapshot of `path`, base first (spec section 8, the third flow); `route` is `Route(sidebar: stack.route, quickEntry: ...)`.
- `RootView`: the narrow window binds `model.path`; the wide window draws `path.first` as the detail's root, or the placeholder, and binds the rest, sending `[column] + written` back. That cut is the interim Task 3 removes. The sidebar is drawn from `model.taskViewList`. The sidebar's sentence moves onto the narrow stack's `navigationDestination`, so it shows under a pushed task too, the iPhone half of #110; the wide window's stays as it is.
- `docs/style.md`'s action example `backButtonTapped` becomes `quickEntryButtonTapped` and `.wentBack(to:)`, in the PR that removes it.
- The wasm probe drives `.screen`, `.wentBack(to:)` and a link through the stack; the budget is re-measured, and moving it is the owner's call, asked in chat before the PR.

**Tests.**

- `TaskViewListTests`: `aClickDeclaresTheViewsListAndHighlightsIt`, `uncoveredTakesTheHighlightAndTheSentenceExceptAnOpenFieldsOne`, `theListsAnswerToCloseTakesTheHighlight`, `aListThatCouldNotBeOpenedTakesBackTheHighlightAndSaysSo`, `theSidebarCreatedFromNoListDeclaresInbox`, `theSidebarCreatedWithNoInboxDeclaresNothing`; the tests of the list's actions and changes handed on go.
- `TaskListTests`: `aTapDeclaresTheTaskAndTheRouteSaysSo`, `uncoveredEmptiesTheDestinationAndLeavesTheSentence`, `aRouteDeclaresItsTaskAndTakesTheSentenceAway`, `theTasksAnswerToCloseEmptiesTheDestination`, `aTaskThatCouldNotBeOpenedSaysWhyAndTakesBackWhatStays`, `aListCreatedWithATaskDeclaresIt`.
- `AppModuleTests`, every test of M3 kept through the stack, and the spec's three flows: `aTapOnATaskPushesItOverTheList`, `backTwiceClosesTheTaskThenTheListAndTheHighlight`, `aTaskDeletedUnderItsScreenIsDroppedAndTheWriteAfterwardsMovesNothing`; beside them `aListThatCannotBeOpenedLeavesTheOpenOneHighlighted`, `aLinkToAViewNotYetHereStaysUnhighlightedWhenItArrives`, `anActionForAScreenThatIsGoneMovesNothing`, `theRouteIsWrittenFromWhatStands`.
- Every other test of the three suites adapts to the destination and to the model by id, and `TodoAppTests` reads a window's list through `screens`.
- `RouteTests` unchanged and green.

**Verified facts and traps.**

- 2026-10-23: the view sketch of spec section 6, with stand-ins for the model, typechecks for macOS 14, iOS 17 and watchOS 10: `NavigationStack(path: Binding<[StackElementID]>)`, `navigationDestination(for: StackElementID.self, destination: screen)` over a `@ViewBuilder` method, and `Binding(get:set:)` sending `.wentBack(to: $0)`.
- Trap: SwiftUI writes a path after a pop the model drove (`RootView`, #106); with the new binding that write is a prefix the stack holds, the same path, and moves nothing. To check by hand: delete a task under its screen on iPhone and watch that the list stays.
- Trap: a test reads an element's model through `model.path` and `model.screens`, with `#require`, never a force unwrap.

### Task 3: The module decides the layout

**Goal.** The view reports its width class as an event of the world, the window is made with the class it opens with, and the model carries the ready layout: narrow, every screen over the sidebar in one path; wide, the first screen over the sidebar as the column, or none, and the rest as the path. The view switches over the layout and keeps no width of its own; a window that narrows or widens keeps its screens and their state (spec section 4).

**Files.** `Sources/Features/App/AppModule.swift`; `Tests/AppFeatureTests/AppModuleTests.swift`; `Sources/WasmSizeProbe/main.swift`, `scripts/wasm-size.sh`; `Apps/Apple/Sources/TodoAppleUI/RootView.swift`, `WindowView.swift`, `TodoApp.swift`; `Apps/Apple/Tests/TodoAppleUITests/TodoAppTests.swift`; `CHANGELOG.md`; `docs/adr/0006-*.md` only if a fallback is taken (Rules).

**Interface.** Consumes Task 2's `AppModule`. Produces:

```swift
extension AppModule {
    public enum Width: Equatable, Sendable { case narrow, wide }
    public enum Layout: Equatable, Sendable {
        case narrow(path: [StackElementID])
        case wide(column: StackElementID?, path: [StackElementID])
    }
    // Model: `path` becomes `public let layout: Layout`
    // Event gains: case widthChanged(Width)
    public init(store: Store, route: Route = .default, width: Width) throws(StoreError)
}

// Apps/Apple
func makeWindow(path: String?, width: AppModule.Width) throws -> TodoApp.Window
struct Window { let host; let open: @MainActor (URL) -> Void; let widthChanged: @MainActor (AppModule.Width) -> Void }
```

**Rules.**

- The width is an event of the world, not a user action: nobody pressed anything, and a view's closure cannot spell it. It reaches the host through the composition root's entrance, as a link does, through `Window.widthChanged` (spec section 4; the owner, 2026-10-20, on the window's way in).
- `widthChanged` moves the layout and nothing else: no screen is made or dropped, no sentence moves, and the same width again moves nothing.
- `.wentBack(to:)` reads its path against the layout: narrow, the whole path; wide, the path after the column, so the column is never popped and "in a wide window the highlight cannot be removed" holds by construction (spec section 4).
- The root's `init` takes the width with no default: the window is made with the class it opens with (spec section 4). Made wide and told otherwise on the first frame is the spec's fallback for a class not known at creation, and a default in the core would make the host's fallback a rule of the core (`docs/style.md`).
- If a probe below fails and a fallback is taken, that is the further amendment to ADR-0006 its amendment of 2026-10-22 names: it is put to the owner in chat, and the task's PR carries the amendment.
- `WindowView` reads `horizontalSizeClass`, compact as narrow and anything else as wide, makes the window with it, and reports a change with `onChange`. `RootView` loses its `horizontalSizeClass` and the interim cut of Task 2.
- `makeWindow` takes the width with no default either: its caller in the product, the window's view, always has one, and the twenty-five calls in `TodoAppTests` spell it.
- The wasm probe sends `.widthChanged(.narrow)` and prints the layout, so the cut is in the measurement; the budget is re-measured, as in Task 2.

**Tests.**

- `aNarrowWindowPutsEveryScreenInOnePath`, `aWideWindowPutsTheFirstScreenInTheColumn`, `aWideWindowWithNothingOverTheSidebarHasNoColumn`.
- `aWindowThatNarrowsOrWidensKeepsItsScreensAndTheirState`: ids, models and the route the same after both events.
- `backInAWideWindowNeverPopsTheColumn`: `.wentBack(to: [])` with a task open drops the task and keeps the list highlighted.
- `theSameWidthAgainMovesNothing`.
- Task 2's `AppModuleTests` spell their width: the flows that send `.wentBack(to:)` with the whole stack are built narrow, where the view sends the whole stack, and every other test wide; each read of `model.path` becomes a read of the layout, through one private helper of the test file that lists the ids over the sidebar whichever the layout.
- `TodoAppTests`: `aWindowMadeNarrowIsLaidOutNarrow`, `theWindowsWidthReachesItsHost`.

**Verified facts and traps.**

- First step, before the code: two probes in the simulator (spec, "Risks"). Whether `horizontalSizeClass` already holds the window's class when the placeholder's `onAppear` makes the window, on an iPhone 17 in portrait and an iPad in a narrow Split View; and whether rotating an iPhone 17 Pro Max with a task open draws a frame of the old tree at the new width. If either fails, the fallback is the spec's: the view chooses the tree from the width it has, and the module keeps the path; the PR states it.
- From `RootView`'s comment (2026-10-21, iOS 26.3): rotating between the narrow stack and the split view wrote neither path, and the screen on top stayed on top. With the binding sending `.wentBack(to:)`, a write during the change of tree would close screens: the rotation probe watches for one.
- The Mac's `horizontalSizeClass` is nil (`RootView` draws the split view there today), so the Mac is wide.

## Self-review against the spec

- Problem and goals: Task 2 takes the module tree out of the view; Task 3 the width.
- Section 1, the destination: Task 1's `Destination`, Task 2's two openers. Section 2, the stack, the walk, a destination written again, answers to the opener, ids, the screens enum: Task 1, then Task 2's `Screen`. Section 3, Back, a pop the model drove, links and the text form: Task 1's `wentBack(to:)` and `route`, Task 2's root, `RouteTests` unchanged. Section 4: Task 3. Section 5: built as the spec's "Built in this epic" says, the window's modal is quick entry's seat, unchanged; `presented` and a modal flow stay on paper. Section 6: Task 2's switch over the screens and bound path, Task 3's switch over the layout. Section 7: every row has a task. Section 8: the three flows are Task 2's tests. Open question: Task 2. Risks: the rotation and the width at creation are Task 3's probes, and a fallback taken is the ADR-0006 amendment that amendment names; a declaration that cannot be met is Task 1's test; the enum's growth is Task 2's `Screen`; the wasm budget is measured in Tasks 2 and 3.
- Deviations, each the engineer's call, for the owner's review:
  - Two types the ADR-0007 amendment of 2026-10-22 does not list: `Destination`, which carries the write mark that tells a new write from an old one, the mechanism the spec left to the plan, and `StackNotice`, what the stack tells a screen. Both name no screen and depend on nothing.
  - The base is a typed module beside the stack's elements and not a case of the screens enum, reached through three static requirements, so the view's switch has the two kinds the spec's sketch has, and the root reads the sidebar's model without a cast.
  - The stack's events reach a module as three new events of its own, `.answered`, `.uncovered` and `.notOpened(_:stillOpen:)`, working names like `.wentBack(to:)`.
  - Between Tasks 2 and 3 the view cuts the stack by its width, the spec's rejected alternative, so that each task merges with the app working.
