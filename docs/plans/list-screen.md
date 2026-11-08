# Plan: The list screen

- Status: Approved 2026-11-02, after three threads on #169: the flags as fields of `TodoTask`, a group's row living and dying with its list, where the notes live; amended 2026-11-02 by #182: a group opened as a screen is no row
- Spec: `docs/specs/list-screen.md`, approved 2026-11-01 (#167)
- Epic: #166

Written for the engineer and derived from the approved spec. The plan
fixes what the tasks are, in what order, and what each one promises to
the next. It does not carry the implementation: code appears only where
it already ran. A task section is 50 to 100 lines. Once a task ships its
section is history; a departure is stated in the task's pull request and
fixed forward into the sections that depend on it, never back into the
shipped one (`docs/process.md`, sections 6 and 7).

> Written by hand from `docs/plans/TEMPLATE.md`, its fifth use. Executed
> task by task, one sub-issue per branch and pull request, with
> superpowers:subagent-driven-development, each implementing and
> reviewing agent briefed with the spec, `docs/style.md`, ADR-0003,
> ADR-0004, ADR-0006, ADR-0009 and ADR-0010 with their amendments of
> 2026-11-01 (#168), the task's section, and the shipped code of the
> tasks it depends on rather than their sections. The canvas is the
> mockup, page "List screen" of
> https://claude.ai/artifact/WWLXn8c4CcV8VKHXwpMqtU; the numbers the Apple
> tasks need are carried below, read from the canvas's `Phone.dc.html` on
> 2026-11-01 and from `Mac.dc.html`, which predates the brainstorm's
> boards, so an agent without the canvas has what it needs. The facts
> about the store, the modules and the Apple package were read from the
> code on `main` at `3313b6f` on 2026-11-01.

## Global constraints

The rules every task obeys, each with the spec section or ADR it comes
from.

- Toolchain: Swift 6.4.0 as `.swift-version` pins it, through swiftly (`export PATH="$HOME/.swiftly/bin:$PATH"`), with the wasm SDK `swift-6.4.0-RELEASE_wasm`; Xcode 27.1's toolchain is the same version (ADR-0008), at `/Applications/Xcode_27_1.app` on the owner's Mac while `xcode-select` points at 26.3, so Apple commands set `DEVELOPER_DIR`. Every command runs from the repository or a package inside it.
- The core is full Swift on the standard library and FoundationEssentials, built and tested with SwiftPM for the host and wasm32; no SwiftUI, Observation or Foundation proper in the root package (ADR-0001). A feature target imports `TodoCore`, `FeatureModule`, the features whose routes its destination holds, and the design system's two targets when it builds a component's model, never a sibling or the root (ADR-0007); `TaskListFeature` gains the two in Task 6.
- The core has three entities and no containers; a view's kind is `list` or `area`, and a kind this app does not know reads as `list` (ADR-0004, amendments of 2026-10-25 and 2026-11-02). A group opened as a screen is no row: the module derives it from its list's page and the group's key, and nothing stores it or writes when it opens (ADR-0004, amendment of 2026-11-02). Task 2 built a row of kind `group` and #182 removed it before any module called it.
- A page is one level deep and its own section comes first; a list inside is one section of its rule's results, a folder inside the union of its lists' rules, as its count is; the screen is the store's one answer drawn, and the module decides nothing about which task is in which block that the store did not decide first (spec sections 1 and 2; ADR-0004, amendment of 2026-11-01).
- A rule is read as one edit per condition, for adding and for dropping alike: a day condition gives the day nearest today it allows or no day, a tag the tag, a manual list a pin, a negation the removal, a conjunction each of its conditions; a rule of alternatives or a condition no edit satisfies refuses, and the block shows no "+ Add task" and takes no drop (spec sections 4 and 6).
- "Today" is the device's day, handed in as an event of the world with the instant it began, at the window's start and on every change; no module reads a clock for a day, and the core takes `today` as an argument as it always has (spec section 8; ADR-0006, amendment of 2026-11-01). Tests use fixed days.
- A list's layout and its folded blocks live in the store's `device_state` under the list module's keys, one per list, never synced, their writes reporting no change set; the open card, its drafts, the picked tags and the list being named are session state a relaunch loses (ADR-0010, amendment of 2026-11-01; ADR-0009, amendments of 2026-10-25 and 2026-11-01).
- A module is a `final class` conforming to `FeatureModule`, its model computed from its state, `send` synchronous and never throwing, what the store refuses written into the model as a sentence (ADR-0006, `docs/style.md`). `TaskList` stays `Routable`; its head becomes the view's id and, on a group's screen, the group's key, and its tail an enum of two cases, the task screen or another list; the window route's text form gains `view/…` after `view/<id>` and a group's word and key, `day/+1`, and nothing else (spec section 9; ADR-0009, amendments of 2026-11-01 and 2026-11-02). A module writes to the store in answer to an action and never in answer to `.changed` (ADR-0009).
- A view holds no condition over a domain value. It may switch over three enums of its model, the layout, the screens of a stack and the kind of a row, and over the four component enums `docs/style.md` names, every case drawn with no `default`; the list's `Layout` is its layout's shape and a block's `Row` is the kind of a row. A task that needs a view to switch over one more enum edits `docs/style.md`, "Views", in the same pull request (ADR-0006, amendments of 2026-10-22 and 2026-10-25). A platform condition, `#if os(...)`, is allowed in a view where the platforms' APIs differ, each one named in a comment; a view decides nothing by the width, which the root's layout decides.
- A user action names the control and the gesture, never what the module does about it (`docs/style.md`); events of the world are named for what happened.
- Everything from the store is data from outside: no trap, no recursion over data-shaped depth (`docs/style.md`). A walk over a `Filter` may recurse, because the store refuses a filter deeper than 32 levels (`maximumDepth`, `Sources/TodoCore/Model/Filter.swift:85`) and nothing else about it is data-shaped; every other walk is one pass. An id a view sends is checked against the model, never trusted. A day offset from a filter is `Int64` and is clamped before it becomes a `Day`, since `Day.advanced(by:)` traps outside `Int32`.
- The names the tasks add were probed on 2026-11-01 against SwiftUI, Foundation and Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1 and are free (Verified facts of Tasks 4 and 6); a name a task adds beyond these gets the same probe before it is fixed. The probe that tells a taken name from a free one is a file that imports the three and reads `Name.self` without declaring it: a free name fails with "cannot find", a taken one compiles.
- The look is the canvas's; where the canvas and the spec differ, the canvas is right about the look and the spec about the behaviour (spec, introduction). The sizes in Tasks 4, 8 and 9 are the canvas's; the type is text styles, whose sizes at the default text size are nearest the canvas's pixels, as the Lists screen's are. Every string a person reads arrives finished from the module, in English, until the formatting service arrives (spec section 8).
- Every merge leaves `main` working on every platform: a task that changes a module's model or actions adapts `Apps/Apple` in the same pull request, minimally where the look is a later task's (Tasks 6 and 7), and CI's macOS job runs on the pull request (`docs/process.md`, section 10).
- Tests are swift-testing. A module test opens `makeStore` with the test clock, sends events and compares the model whole with a module made anew. The root package's suite runs green on the host with `swift test` and on wasm32 with `swift test --swift-sdk swift-6.4.0-RELEASE_wasm --disable-xctest`, and `scripts/wasm-size.sh` passes, before every PR; `Sources/WasmSizeProbe/main.swift` drives every new public API, or the optimizer strips it from the measurement; the budget is re-measured where the probe's code moves (Tasks 1, 2, 6 and 7).
- `Apps/Apple` is built and tested from its directory with the pinned toolchain, and each screen is checked by hand in the iOS 26.3 simulator on an iPhone 17, an iPhone 17 Pro Max turned sideways and an iPad Pro 11-inch (M5), and on the Mac, in both appearances, with screenshots in the pull request (spec, "Testing"). CI builds the iPhone app for a generic simulator and runs no UI test.
- Branch per task `<type>/<issue>-<slug>`, PR title in Conventional Commits with scope `core` or `apple`, body per template, `Closes #<sub-issue>`; squash merge; one line under `[Unreleased]` in `CHANGELOG.md` per task, naming every public type touched and the probe's bytes where the size moved; commits end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Everything in English. No `TODO` without a linked issue.

## File map

| File | Task | Holds |
| ---- | ---- | ----- |
| `Sources/TodoCore/Query/Store+Query.swift` | 1, 2, #182, 7 | `page(of:today:)` with the own section first, a folder's section as the union of its lists (1); children of kind `list` alone, Task 2's guard in `childSections(of:among:)` (2), gone with the kind (#182); `GroupKey(of:by:)`, the key a task is grouped under (7) |
| `Sources/TodoCore/Model/TodoTask.swift` | 1 | `TodoTask.hasNotes`, `subtasks`, `subtasksDone` |
| `Sources/TodoCore/Storage/Store+Tasks.swift` | 1 | `taskColumns` with the notes flag; `loadTasks(sql:)` reading the subtask counts beside the tags |
| `Sources/TodoCore/Query/Store+Counts.swift` | 1 | the gathering of a folder's rules shared with the page |
| `Sources/TodoCore/Query/Store+Done.swift` | 1 | `doneTasks(in:since:today:)`: the page's rules with their status conditions lifted, completed since an instant |
| `Sources/TodoCore/Storage/Schema.swift`, `Migrations.swift` | 1 | `version6`: the partial index on `completed_at` |
| `Sources/TodoCore/Model/Day.swift` | 1 | `Weekday`, `Day.weekday` |
| `Sources/TodoCore/Model/TaskView.swift` | 2, #182 | `TaskViewKind.group` (2), removed (#182) |
| `Sources/TodoCore/Model/EntityID.swift` | 2, #182 | `EntityID.derived(from:_:)`, the FNV-1a digest written as a UUID (2), removed with its one caller (#182) |
| `Sources/TodoCore/Storage/Store+Views.swift` | 2, #182 | `viewKind` passing `group` through; `views()` reading an orphan group as deleted; `createView` refusing a group; the internal create that takes an id; `createManualList(_:in:color:)`; `groupView(of:condition:titled:)` taking the row with the derived id back; `move(view:)` refusing a group; `delete(view:)` taking a list's groups (2); every part of it that exists for a group's row removed, the internal create that takes an id and `createManualList` kept (#182) |
| `docs/adr/0004-flat-model-of-tasks-tags-and-filter-defined-views.md` | 2, #182 | the amendment's sentence on a group's row living and dying with its list (2); the amendment of 2026-11-02, a group opened as a screen is no row (#182) |
| `docs/adr/0009-every-screen-is-a-child-of-its-opener-addressed-by-a-route.md`, `docs/specs/list-screen.md` | #182 | the amendment of 2026-11-02, a group's address; the spec amended the same day |
| `Sources/TodoCore/Model/DeviceDay.swift` | 3 | `DeviceDay`, the device's day and the instant it began |
| `Sources/Features/App/AppModule.swift`, `AppModule+Routing.swift` | 3, 6 | `init(store:route:width:day:capabilities:)`, `Event.dayChanged`, forwarded to the base and every element (3); `Screen.destination`, `take` and `route(over:)` over `TaskList.Route.Tail` (6) |
| `Sources/Features/TaskViewList/TaskViewList.swift`, `TaskViewList+Rows.swift` | 2, 3, #182 | rows of kind `group` skipped, the row's own two-case kind (2), the skip gone with the kind (#182); `init(…day:)`, `Event.dayChanged`, counts by the device's day (3) |
| `Sources/Features/TaskList/TaskList.swift` | 3, 6, 7 | `init(store:route:day:)`, `Event.dayChanged` (3); the module's events, outputs, actions and state (6, 7) |
| `Sources/Features/TaskList/TaskList+Routing.swift` | 6 | `Route`, its `Head` with a group, `Route.Group` and its spelling, `Route.Tail` (moved out of `TaskList.swift` in the owner's review of #188) |
| `Sources/Features/TaskList/TaskList+Model.swift` | 6, 7 | `Model`, `Layout`, `Block`, `Row`, `BlockID` |
| `Sources/Features/TaskList/TaskList+Page.swift` | 6 | the page read into blocks, the tag bar's chips and filter, the folds and the layout, a group's screen read from its list's page, the lists inside |
| `Sources/Features/TaskList/TaskList+Day.swift` | 6 | the day's formats: titles, dates, "Tomorrow", "Due Tue", a group's screen's title |
| `Sources/Features/TaskList/TaskList+Components.swift` | 6, 7, 8, 9 | the builders of the rows, the blocks and the columns, the header, the tag bar, the empty state |
| `Sources/Features/TaskList/TaskList+Metrics.swift` | 7 (moved out of `+Components`), #190, 8, 9 | `Metrics` per width and layout: the components' styles per layout (`CheckStyle` for `CheckModel` and so on), and a struct of its own only for a number that feeds a model nested in a component (#190) |
| `Sources/Features/TaskList/TaskList+Card.swift`, `TaskList+Controls.swift` | 7 | the builders of the open card; of the rows that add, the floating "+", the strip's capsule, the swipe and the menu |
| `Sources/Features/TaskList/TaskList+Rule.swift` | 7 | `TaskList.TaskEdit`: a rule read as an edit, and the drop table |
| `Sources/Features/TaskList/TaskList+Edits.swift`, `TaskList+CardEdits.swift`, `TaskList+Drop.swift` | 7 | completing and the strip, adding a task and a list, deleting; the card and its drafts; the reorder and the drop |
| `Sources/TodoCore/Storage/Store+Views.swift` | 7 | `pin(tasks:in:at:)`, several pins in one transaction |
| `Package.swift` | 6 | `TaskListFeature` and its tests depend on `DesignSystem` and `DesignSystemComponents` |
| `Sources/DesignSystem/Color.swift`, `Color+Components.swift` | 4 | `Color.glass`, `glassLine`, `fresh`; `Color.Components.Check` per tile colour, ring, fill and mark, the mark written down per tile; `Tile.dropTint` |
| `Sources/DesignSystem/Font.swift`, `Animation.swift`, `Icon.swift`, `Shadow.swift` | 4 | `Font.addRow`, `notes`, `pill`, `emptyScreenTitle`, and `Font.TextStyle.title3`; `Animation.cardOpens`, `drop`, `swipe`, `fold`, `fresh`; `Icon.flag`, `hash`, `note`, `expand`, `columns`, `chevronLeft`, the pills' sun being the existing `Icon.sun`; `Shadow.resting`, a column's card at rest |
| `Sources/DesignSystemComponents/CheckModel.swift`, `TaskRowModel.swift`, `MetaItemModel.swift`, `SwipeModel.swift`, `TaskLiftModel.swift`, `DropIndicatorModel.swift`, `DragModel.swift`, `CardModel.swift`, `SubtaskRowModel.swift`, `PillModel.swift`, `BlockHeaderModel.swift`, `TagChipModel.swift`, `TagBarModel.swift`, `AddRowModel.swift`, `DoneStripModel.swift`, `ColumnModel.swift`, `EmptyScreenModel.swift`, `GlassButtonModel.swift`, `FloatingButtonModel.swift`, `ScreenHeaderModel.swift`, `MenuModel.swift` | 4 | the screen's component models; `MenuModel.Item.isDisabled` and `subtitle`; the Finder's mark of a drop, `DropIndicatorModel`, which `TaskLiftModel` holds and `DragModel.Look.indicator` holds beside its `DragModel.IndicatorCard` |
| `Sources/Features/TaskViewList/TaskViewList+Components.swift`, `Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsDragGesture.swift`, `Sources/WasmSizeProbe/main.swift`, `Tests/TaskViewListFeatureTests/TaskViewListComponentsTests.swift`, `Apps/Apple/Tests/TodoAppleUITests/ListsDragTests.swift` | 4 | the sidebar's drag builds, draws and reads its mark as a `DropIndicatorModel` beside its `DragModel.IndicatorCard`; what it draws does not change |
| `Apps/Apple/Sources/TodoAppleUI/DesignSystem/Image+DesignSystem.swift`, `Font+DesignSystem.swift`, `MenuItems.swift` | 4 | the new icons' symbols and the third title rendered; a menu item's subtitle and its disabled state drawn |
| `Apps/Apple/Sources/TodoAppleUI/TodoApp.swift`, `WindowView.swift` | 3 | `Window.dayChanged`; the day read from `Calendar.current` at the window's start, on the day's change, on a time zone change and on waking |
| `Apps/Apple/Sources/TodoAppleUI/TaskListView.swift` | 6, 7 | adapted to the model, minimally; Task 8 keeps it for the wide tree and Task 9 deletes it |
| `Apps/Apple/Sources/TodoAppleUI/RootView.swift` | 8, 9 | the `.list` case draws `ListScreen` in the narrow tree (8) and `ListPane` in the wide one (9); the list's toolbar button goes with `TaskListView` (9) |
| `Apps/Apple/Sources/TodoAppleUI/ListScreen/ListScreen.swift`, `BlockView.swift`, `TaskRowView.swift`, `TaskCardView.swift`, `TagBarView.swift`, `DoneStripView.swift`, `BoardView.swift`, `ColumnView.swift`, `GlassButton.swift`, `FloatingButton.swift`, `EmptyScreenView.swift`, `RowLift.swift`, `RowDrag.swift`, `RowDragState.swift`, `RowSwipe.swift`, `SwipeToDelete.swift`, and the parts beside them | 8 | the phone's screen and its parts, drawn from the component models |
| `Apps/Apple/Sources/TodoAppleUI/ListScreen/ListPane.swift` | 9 | the Mac's and the iPad's pane |
| `Sources/WasmSizeProbe/main.swift`, `scripts/wasm-size.sh` | 1, 2, 3, 6, 7 | the probe drives the new reads, writes, events and models; the budget re-measured |
| `Tests/TodoCoreTests/QueryTests.swift`, `TaskTests.swift`, `CountTests.swift`, `DayTests.swift`, `StoreOpenTests.swift`, new `DoneTests.swift` | 1 | the page's order, the folder's section, the notes flag and the subtask counts, the done read and its index, the weekday, the migration |
| `Tests/TodoCoreTests/ViewTests.swift`, `EntityIDTests.swift`, `SyncTests.swift` | 2, #182 | the kind, the derived id, the two one-call constructors, two devices making one row (2); all but the manual list's removed (#182) |
| `Tests/AppFeatureTests/AppModuleTests.swift`, `RouteTests.swift` | 3, 6 | the day handed down (3); a list over a list, a group over its list and their text form (6) |
| `Tests/TaskViewListFeatureTests/*` | 2, 3, #182 | no group row (2), removed with the kind (#182); counts by the day (3) |
| `Tests/TaskListFeatureTests/TaskListTests.swift`, new `TaskListPageTests.swift`, `TaskListDayTests.swift`, `TaskListComponentsTests.swift` | 6 | adapted; the blocks; the formats; the models |
| `Tests/TaskListFeatureTests/TaskListRuleTests.swift`, `TaskListEditsTests.swift` | 7 | a rule as edits and the drop table; every write |
| `Tests/DesignSystemTests/CheckColorTests.swift`, `IconTests.swift`, `FontTests.swift`, `AnimationTests.swift`, `ShadowTests.swift`; `Tests/DesignSystemComponentsTests/ClassModelEqualityTests.swift`, new `MenuModelTests.swift` | 4 | the check's colours and the drop tint against the canvas, the written-down marks against the contrast rule, the glass, line and fresh shades; the icons' count and names; the new fonts, motions and shadow; a menu item's two new fields and their defaults; every class model's `==`, a task's row, its card and a block's header among them. A model whose `init` only stores its arguments gets no read-back test |
| `Apps/Apple/Tests/TodoAppleUITests/TodoAppTests.swift`, `DesignSystemRenderersTests.swift`, new `RowLiftTests.swift` | 3, 4, 8 | the day reaching the host (3); the new symbols and their names, the fonts and the motions (4); the lift's reading on the host (8) |
| `README.md`, `CHANGELOG.md` | every task | the changelog line; the README where behaviour a person sees changes (8, 9) |

## Tasks

| # | Issue | Title | Labels | Depends on |
| - | ----- | ----- | ------ | ---------- |
| 1 | #170 | The page's order, a folder's lists, a task's flags, the done read and the weekday | `feature`, `core` | |
| 2 | #171 | A group's view and a manual list, each in one call | `feature`, `core` | |
| 2b | #182 | A group opened as a screen is a view the module derives, not a row | `arch`, `core` | 2 |
| 3 | #172 | The device's day as an event of the world | `feature`, `core`, `ui-apple` | |
| 4 | #173 | The design system's tokens and the screen's component models | `feature`, `core`, `ui-apple` | |
| 5 | #174 | Spike: three drags on one screen | `spike`, `ui-apple` | |
| 6 | #175 | The module's page: blocks, rows, the tag bar, a list over a list, a group's screen | `feature`, `core` | 1, 2, 2b, 3, 4 |
| 7 | #176 | The module's edits: completing, the card, adding, deleting, the reorder and the drop | `feature`, `core` | 6 |
| 8 | #177 | The list screen on iPhone | `feature`, `ui-apple` | 4, 5, 7 |
| 9 | #178 | The list pane on the Mac and the iPad | `feature`, `ui-apple` | 8 |

The owner reviews this table and the interface of every task below.

Task 2b was added on 2026-11-02, after the plan's approval and Task 2's merge, when the owner took the group's row back (#182): it amends the spec, ADR-0004 and ADR-0009 and this plan, and removes the row Task 2 built and nothing else of it. It has no section of its own; its issue holds its acceptance criteria, and the sections of Tasks 6 and 7 below carry what it changes for them.

The split leaves `main` working after every merge. Tasks 1 to 5 touch no
screen and can run beside each other; Task 4 is the largest and has no
caller until Task 6, which the pull request says. Task 6 changes the
module's model wholesale and adapts `TaskListView` in the same pull
request just far enough that the app compiles and the list still opens
its tasks, with today's look; Task 7 adds the writes behind plain
controls the same way; the look arrives in Task 8 for the phone and in
Task 9 for the Mac and the iPad, where the adapted view goes. Task 5
answers the one question the spec names as its first risk before Task 8
builds on it.

### Task 1: The page's order, a folder's lists, a task's flags, the done read and the weekday

**Goal.** The store reads a view's page in the product's order, the own section first, with a folder inside reading as the union of its lists, as its count does; every task read carries whether it has notes and how many subtasks it has, done over all, so that the page's rows and the strip's have their meta line from the one read; the store answers which tasks a page's rules completed since an instant; and a day knows its weekday (spec sections 2, 3, 8 and 12).

**Files.** `Sources/TodoCore/Query/Store+Query.swift`, `Store+Counts.swift`; new `Store+Done.swift`; `Sources/TodoCore/Model/TodoTask.swift`, `Day.swift`; `Sources/TodoCore/Storage/Store+Tasks.swift`, `Schema.swift`, `Migrations.swift`; `Sources/WasmSizeProbe/main.swift`; `Tests/TodoCoreTests/QueryTests.swift`, `TaskTests.swift`, `CountTests.swift`, `DayTests.swift`, `StoreOpenTests.swift`, new `DoneTests.swift`; `CHANGELOG.md`.

**Interface.** Consumed by Tasks 6 and 7.

```swift
public struct TodoTask: Equatable, Sendable {
    // the eleven fields as today, then what the notes column and the tree say of the task, read with it
    /// Whether the task has notes. The notes stay where they are, the last column of `tasks`, read on their
    /// own by `notes(of:)` and written by `TaskChange.notes`; no read of a list loads them (ADR-0002).
    public let hasNotes: Bool
    /// The task's children that are not deleted and not in the Trash, and the ones among them no longer open.
    public let subtasks: Int
    public let subtasksDone: Int
}
extension Store {
    public func page(of viewID: ViewID, today: Day) throws(StoreError) -> TaskViewPage   // the signature and `Group.tasks` stay; the order changes
    /// The tasks the page's rules select once their status conditions are lifted, no longer open and completed at
    /// or after `since`, the clock's milliseconds; newest first. Empty for a view with no rule and no lists.
    public func done(in viewID: ViewID, since: Int64, today: Day) throws(StoreError) -> [TodoTask]
}
public enum Weekday: Int, Equatable, Sendable, CaseIterable {
    case sunday = 0, monday, tuesday, wednesday, thursday, friday, saturday
}
extension Day {
    public var weekday: Weekday
}
```

**Rules.**

- The page's sections: the view's own section first, present whenever the view has a rule, empty or not, so that a list with a rule and nothing in it has a block to add into; absent for a folder, which has no own tasks (spec section 2). Then one section per child of kind `.list`, in `children(ofView:)` order; a child of another kind is skipped and claims nothing, which today excludes nothing, since an area is never a child in a read, and from Task 2 on excludes a group's row. A child with a rule holds its rule's results as today; a child with no rule, a folder, holds the union of the rules gathered from the lists under it to any depth, the same gathering `taskCounts(today:)` does (`countStatements`, `Store+Counts.swift:36-45`), extracted into one internal helper both call, ordered by the folder's own sort, which is the default tail `t.rank, t.id` since a folder has none; a folder with nothing to count holds an empty section. A child's `needsNewerApp` still gives an empty section. The own section is the view's results minus every child's claim, as today; nothing dedups between siblings.
- The flags are fields of `TodoTask`, read by every reader through the one loader, as the tags are (owner's review of the plan, 2026-11-02). The notes themselves are stored as today and nothing about them changes: the last column of `tasks`, `notes TEXT NOT NULL DEFAULT ''`, written by `createTask` and `TaskChange.notes` as a journal field, indexed for search by the FTS5 triggers, and read on their own by `notes(of:)`, which the command line's `show` uses and the card uses in Task 7. `hasNotes` is `length(t.notes) > 0` as one more column of `taskColumns`, which SQLite answers from the record's header without loading the text from its overflow pages, so a list still never reads the notes (ADR-0002). The counts come from one statement per chunk of the loaded ids beside the tags' (`tagsByTask`, `Store+Tasks.swift:303-315`): `SELECT tt.parent, count(*), sum(t.status != 0) FROM tasks t JOIN task_tree tt ON tt.id = t.id WHERE t.deleted = 0 AND tt.trashed = 0 AND tt.parent IN (…) GROUP BY tt.parent`, over `task_tree_parent`; a task with no children reads 0 over 0. `TaskViewPage.Group.tasks`, `tasks(in:today:)`, the CLI and the probe keep their shape, and the strip's rows, which `done(in:since:today:)` returns as the same type, carry their meta line with no second read.
- `done(in:since:today:)` gathers the page's rules, the view's own and each list child's, a folder child contributing its lists' union, and lifts every `.status(_)` out of each: a status condition becomes `.and([])`, which compiles to true (`FilterCompiler.swift:79`), inside a `.not` too, which makes that branch false, accepted and tested. The lifted rules are joined by `.or`, compiled bare with `FilterCompiler.compile`, and the statement adds `AND t.status != 0 AND t.completed_at >= ?` and `tt.trashed = 0` unless a rule mentions the Trash, ordered `t.completed_at DESC, t.id`. A view with no rule and no lists answers `[]` without a statement. Logbook's rule lifted is every task, which the module never asks for, since the strip is not drawn there (spec section 3).
- `version6` adds `CREATE INDEX tasks_completed ON tasks(completed_at) WHERE completed_at IS NOT NULL`; the done statement's plan is `SEARCH t USING INDEX tasks_completed` for a rule whose own conditions drive nothing narrower, which the EXPLAIN test holds as `QueryTests` holds the view statement's.
- `Day.weekday` is `(daysSinceEpoch + 4) mod 7` with a floor modulo, since day zero, 1970-01-01, was a Thursday and a day before the epoch is negative; the names of the days are the module's, not the core's (spec section 12).
- The CLI does not change; the probe reads `page` and `done` so both stay in the measurement.
- Cost: every read of tasks now runs one statement more per chunk of ids, the page's per section and the done read's per strip among them, `task(_:)` one more for its one id; the card's `children(of:)` in Task 7 counts grandchildren nobody draws, accepted for one shape; measured in a release build at 50,000 tasks with the harness of #153 (`TreePerformanceTests`), the numbers in the pull request; the remedy the spec names, a narrower read for the rows a screen can show, is not built here (spec, "Risks").

**Tests.**

- `QueryTests`: `theOwnSectionComesFirstAndTheListsInsideFollow`; `aListWithARuleAndNothingInItHasAnEmptyOwnSection`; `aFolderHasNoOwnSection`; `aFolderInsideReadsTheUnionOfItsListsOnce`, two lists sharing a task; `aFolderInsideWithNothingToCountIsAnEmptySection`; `aChildOfAKindOtherThanListIsNotASection`, by a view whose stored kind Task 2 will make `group`, written as a journal op.
- `TaskTests`: `aTaskSaysWhetherItHasNotes`, read back by `task(_:)`, `children(of:)` and the page alike; `aTaskCountsItsSubtasksDoneOverAll`, a cancelled one counted as done, a trashed and a deleted child not counted; `aTaskWithNoChildrenReadsZeroOverZero`; `theNotesFlagLoadsNoNotes`, by `EXPLAIN` of `taskQuery`, the `Column` read for the flag carrying the length-only flag in P5.
- `CountTests`: `theCountAndThePageGatherAFoldersRulesAlike`, the same union through both.
- `DoneTests`: `doneReadsTheTasksTheRulesCompletedSinceAnInstant`, a task completed before `since` left out; `doneLiftsEveryStatusConditionOfTheRules`, Today's rule finds a done task; `doneReadsTheListsInsideAndTheirFolders`; `doneOfAViewWithNoRuleAndNoListsIsEmpty`; `doneLeavesTheTrashOutUnlessARuleNamesIt`; `theDoneStatementUsesTheCompletedIndex`, by EXPLAIN QUERY PLAN.
- `StoreOpenTests`: `aStoreOpensAtVersionSixWithTheCompletedIndex`, from a version 5 snapshot.
- `DayTests`: `aDayKnowsItsWeekday`, 1970-01-01 a Thursday, 2026-10-26 a Monday, 1969-12-28 a Sunday.

**Verified facts and traps.**

- `page` today appends the own section only when `!own.isEmpty || sections.isEmpty` (`Store+Query.swift:67-69`), so a view with lists inside and no own tasks has no own section; the rule above changes that to "present whenever the view has a rule", and the CLI's printing is the only other reader.
- A folder child contributes `[]` because `tasks(matching:)` returns `[]` for `filter == nil` (`Store+Query.swift:82`); `countStatements` gathers `childRules` by parent in one pass over `views().reversed()` (`Store+Counts.swift:36-45`), leaf-up, so grandchildren fold into the outer folder; the page reuses that gathering rather than recursing.
- `TodoTask` has eleven fields and no notes or subtask count (`Sources/TodoCore/Model/TodoTask.swift:13-26`), and its doc comment says why the notes stay out, which a flag keeps true; `parent` and `trashed` are already values the tree says of a task. Every reader goes through `loadTasks(sql:)`, which runs the select and then `tagsByTask` over the loaded ids in chunks (`Store+Tasks.swift:282-286`, `303-315`), the shape the counts take; no test constructs a `TodoTask`, so three fields more break no expected value. Notes are `notes TEXT NOT NULL DEFAULT ''`, the last column (`Schema.swift:24`); children live in `task_tree(parent)` with the status in `tasks`, indexed by `task_tree_parent` and `tasks_parent(parent, rank)`.
- Notes live in `tasks.notes`, the last column (`Schema.swift:24`), written by `createTask` (`Store+Tasks.swift:22`) and `.notes(String)` (`:56`), mirrored into `tasks_notes_fts` by the triggers (`Schema.swift:236-246`), and read on their own by `notes(of:)` (`:133-139`), which throws `.notFound` for a task that is gone; the command line's `show` reads them so (`CLI.swift:202`), and no other reader does today.
- `length(notes)` loads no notes: SQLite's `EXPLAIN` of `SELECT length(notes) > 0 FROM tasks` shows the `Column` opcode with P5 = 64, `OPFLAG_LENGTHARG`, which reads the length from the record header and skips the overflow pages, and of `SELECT notes != ''` with P5 = 0, which loads the text (checked 2026-11-02 on the system's 3.51.0; the vendored amalgamation is 3.53.4 and the flag is older than both).
- `completed_at` is written only when the status crosses open and not-open, `stamp.millis` on leaving open and null on returning (`Store+Tasks.swift:59-63`); there is no index on it and no `Filter` condition over it (`Filter.swift:27-40`), which is why the done read is a core statement and not a stored rule: a new JSON kind would read as `needsNewerApp` on an older app.
- `FilterCompiler.compile` yields the bare fragment and `whereClause` adds `tt.trashed = 0` unless the filter mentions trash (`FilterCompiler.swift:30-34`); `.and([])` compiles to `1` and `.or([])` to `0` (`:79-82`); `.not` is `NOT COALESCE((…), 0)` (`:83-89`).
- The wide `OR` trap on wasm32 (#152) is SQLite's code generation over many alternatives; the done read joins the page's rules by `.or`, which for the seeded lists is one or two; a folder of many lists is the case to measure, and the issue stays open for it.
- Schema `user_version` is 5; a step is `(6, Schema.version6)` in `Migrations.steps`, run once in its own transaction (`Migrations.swift:5-24`). An index adds no column, so `FieldMapTests` does not change.
- `Day.daysSinceEpoch` is internal `Int32`; `advanced(by:)` traps outside `Int32` (`Day.swift:90-96`), so the weekday is computed on the stored count and never by advancing.

### Task 2: A group's view and a manual list, each in one call

**Goal.** A view's kind may be `group`; the store makes the view of one group of a list in one call, with an id every device derives alike, and brings it up to date when the list changed; and the store makes a manual list, a view whose rule lists itself, in one call (spec sections 2 and 4; ADR-0004, amendment of 2026-11-01).

**Files.** `Sources/TodoCore/Model/TaskView.swift`, `EntityID.swift`; `Sources/TodoCore/Storage/Store+Views.swift`; `Sources/TodoCore/Query/Store+Query.swift`; `Sources/Features/TaskViewList/TaskViewList+Rows.swift`; `Sources/WasmSizeProbe/main.swift`; `Tests/TodoCoreTests/ViewTests.swift`, `QueryTests.swift`, `EntityIDTests.swift`, `SyncTests.swift`, `CountTests.swift`; `Tests/TaskViewListFeatureTests/TaskViewListRowsTests.swift`; `docs/adr/0004-flat-model-of-tasks-tags-and-filter-defined-views.md`; `CHANGELOG.md`.

**Interface.** Consumed by Tasks 6 and 7.

```swift
public enum TaskViewKind: String, Equatable, Sendable {
    case list, area, group
}
extension EntityID {
    /// An id derived from another and a name, the same on every device and every platform: FNV-1a 64 over the
    /// UTF-8 of "<base>\u{0}<name>", once from the standard basis and once more from the first result, the two
    /// words written as a UUID with version 8 and the RFC 4122 variant. Two devices that derive the same id write
    /// one row, and the journal merges their writes (ADR-0003).
    public static func derived(from base: EntityID, _ name: String) -> EntityID
}
extension Store {
    /// A view whose rule lists itself, the heading of ADR-0004, made with its title, parent and colour and the
    /// `list` icon in one transaction: the id is minted first, so the filter can name it.
    @discardableResult
    public func createManualList(_ title: String, in parent: ViewID, color: TaskViewColor?) throws(StoreError) -> ViewID
    /// The view of one group of a list, kind `group`: the list's rule and `condition` written out as its filter,
    /// the list's colour, icon and sort copied, its parent the list, its id derived from the list's id and the
    /// condition. Made when missing; when present, only the fields that differ are written, and nothing when none
    /// does. One transaction or none.
    @discardableResult
    public func groupView(of list: ViewID, condition: Filter, titled title: String) throws(StoreError) -> ViewID
}
```

**Rules.**

- A stored `group` reads as `.group` when its stored parent names a view that is not deleted and its filter is present, and otherwise reads as deleted: in `views()` the row's `TreeRules.Node` is marked deleted before `effectiveParents` runs, so the row is left out as a tombstoned one is, and `view(_:)`, `children(ofView:)`, the page, the counts, the sidebar and the routes never see it; an orphan never reads as a list (owner's review of the plan, 2026-11-02). A group is never demoted the way a stored `area` with a parent or a filter is (`viewKind`, `Store+Views.swift:258-260`): the reading rule lifts a child of a deleted parent to the root (`TreeRules.effectiveParents`, `TreeRules.swift:35-38`), which for a group's row would put a list named "Tomorrow" at the root of the sidebar. A kind this app does not know still reads as `.list` (`storedViewKind`, `:264-266`). The kind is written once, as every kind is.
- `createView` refuses `kind: .group` with `.invalid("a group's view is made from its list")`: `groupView` is the one way to make one, so that the id is always the derived one. `move(view:)` refuses a group as the moved view and as the new parent with `.invalid`, as it refuses an area. A group's row lives and dies with its list: `delete(view:)` of a list tombstones the list and every group's row whose parent it is, in one `apply`, as `delete(viewTree:)` already does by walking `views()` in tree order (`Store+Views.swift:103-125`), so neither delete leaves a group behind and both change sets name the groups. A group's row deleted alone, by `delete(view:)` or by an older app that read it as a list, is not refused, since the same tombstone can arrive from a peer whatever this app refuses; `groupView` brings the row back, below.
- `groupView` requires the list to exist and be `.list` with a rule (`.notFound`, or `.invalid("a folder has no groups")`); its id is `EntityID.derived(from: list, condition's JSON)`, the JSON from the sorted-keys encoder the store already writes filters with, so two devices spell one condition in one string; its filter is `.and([list.filter, condition])`, refused with `.invalidFilter` past `maximumDepth` as every filter is. The row with the derived id is the group's row whatever it holds, tombstoned or moved by an older app that read it as a list, or made by a peer: its kind, parent, title, filter, sort, colour, icon and `deleted` are compared with what a fresh make would write and only the fields that differ are written under one stamp, so a deleted row comes back and a moved one returns under its list; when none differs, no `apply` runs and no change set is reported.
- `createManualList` mints the id, builds the creation fields with `filter: .listedIn(id)`, `kind: .list`, `icon: "list"`, the given colour and parent, ranks the row last among the parent's children, and applies once; the parent must exist and not be a group.
- The derived id is a function the core keeps stable for ever (ADR-0004, amendment of 2026-11-01): the digest, the separator and the UUID layout are fixed by a test vector pinned in the first run, and the test states the input that produced it. The five seeds' shape `00000000-0000-4000-8000-00000000000N` cannot collide with it, since version 8 sets the thirteenth hex digit to `8`.
- The counts skip the new kind with no change: `countedRules` guards `view.kind == .list` (`Store+Counts.swift:105`). Task 2 adds the guard to `page(of:today:)`: a child of a kind other than `.list` is skipped and claims nothing, so a group's row is not a section of its list's page. Task 1 shipped the page without it, since `viewKind` reads every child as `.list` until `.group` exists (`Store+Views.swift:258-260`) and nothing stored could make it bite; it goes in `childSections(of:among:)` (`Store+Query.swift:96`), which the page and `doneTasks(in:since:today:)` both read, so the one guard keeps a group's row out of its list's sections and its strip's rules alike. `children(ofView:)` and `views()` still return it, and the sidebar skips it in Task 6. The probe makes a manual list and a group's view twice, so both calls and the derivation stay in the measurement.

**Tests.**

- `EntityIDTests`: `aDerivedIDIsTheSameForTheSameBaseAndName`; `aDerivedIDDiffersByNameAndByBase`; `aDerivedIDReadsAsAUUIDAndCarriesVersionEight`, through `EntityID(uuidString:)`; `aDerivedIDIsTheOneThePlanPinned`, the vector.
- `ViewTests`: `aStoredGroupWithAParentAndAFilterReadsAsAGroup`; `anOrphanGroupReadsAsDeleted`, its list tombstoned by a journal op as a peer's would arrive, so no cascade ran: not in `views()`, `view(_:)` nil, not among the root's children; `aGroupWithoutAFilterReadsAsDeleted`; `createViewRefusesAGroup`; `aGroupIsNotMovedAndTakesNoChild`; `aManualListIsMadeInOneTransactionWithItsOwnIDInItsRule`, one change set, the filter `.listedIn(id)`, ranked last; `aGroupViewIsMadeFromItsListInOneTransaction`, the filter, the look, the parent, the id; `aGroupViewMadeAgainWritesNothing`, no change set, the journal unchanged; `aGroupViewFollowsItsListsRuleAndLook`, after `update(view:)` of the list; `aGroupViewOfAFolderIsRefused`; `aListsTreeDeleteTakesItsGroups`; `aListsDeleteTakesItsGroups`, through `delete(view:)`, one change set naming both; `aDeletedGroupRowComesBackWhenItsGroupIsOpened`; `aGroupRowMovedByAPeerReturnsUnderItsList`, the parent written back by `groupView`.
- `QueryTests`: `aChildOfAKindOtherThanListIsNotASection`, a group's row under a list is not a section of the list's page.
- `SyncTests`: `twoDevicesOpeningOneGroupMakeOneRow`, both call `groupView`, sync both ways, one row with one id on each.
- `CountTests`: `aGroupCountsNothingAndAddsNothingToItsList`.

**Verified facts and traps.**

- `createView` mints `let id = ViewID()` inside (`Store+Views.swift:73`); the seed is the only chosen-id writer, building `JournalOperation`s from the private `creationFields(of:rank:createdAt:)` (`:229-241`), which is the seam both new calls share through an internal create that takes an id.
- `TaskViewChange` has `title`, `filter`, `sort`, `groupBy` and no kind, colour or icon (`TaskView.swift:85-90`); `groupView` writes the colour and icon fields directly as the seed does, so no change case is added without a caller.
- The core has no digest: no SHA, no FNV, and `Hasher` is randomly seeded per process (grep over `Sources/TodoCore` and `Sources/Features`); FNV-1a 64 is twenty lines of `UInt64` wrapping arithmetic, identical on wasm32.
- Every route parses an id with `EntityID(uuidString:)`, which accepts only what `UUID(uuidString:)` reads whole (`EntityID.swift:38-43`), so the derived id must be UUID-shaped or `view/<id>` would not parse.
- One `apply` is one `BEGIN IMMEDIATE` transaction and one `onChange` (`Store+Apply.swift:22-26`); last write wins per field by `(clock, device)`, ties to the larger device id (`:98-104`); two creates of one id merge field by field (`writeEntityRow`, `:150-159`). Two devices writing identical fields converge to one row with no conflict.
- The sorted-keys encoder (`makeEncoder`, `Filter.swift:88-95`) is what makes the condition's JSON one string on every device; the derivation must use `Filter.json()`, internal to the core, and never a description.
- `delete(view:)` is one `setFlag` and leaves the children to the reading rule (`Store+Views.swift:100-105`), which lifts them to the root; `delete(viewTree:)` walks `views()` once, parents before children, one op per view under one stamp in one `apply` (`:107-125`). The Lists screen deletes a list through the tree delete (`TaskViewList.swift:376`) and an area, emptied first, through `delete(view:)` (`:735`); the probe deletes a folder through `delete(view:)` (`main.swift:87`); the command line deletes no view.
- `views()` builds a `TreeRules.Node` per row from the stored `deleted`, resolves the parents, then drops the deleted rows (`Store+Views.swift:184-203`); `view(_:)` and `children(ofView:)` read through it (`:206-213`), so one guard in `views()` holds for every read. `requireView` reads the row directly with `deleted = 0` (`:273-277`) and guards the writes, not a read.
- A tombstone is a field: `deleted` is written as any field is, by `writeEntityRow` (`Store+Apply.swift:150-159`) under the per-field clock, so a later `deleted = false` under a later clock brings the row back, which is what lets `groupView` revive a row an older app deleted; `creationFields` already writes `("deleted", Value(false))` (`Store+Views.swift:246`).

### Task 3: The device's day as an event of the world

**Goal.** Every module that draws a day draws the device's own, handed in by the window's view at the window's start and on every change of the day, and no module reads a clock for it any more (spec section 8; ADR-0006, amendment of 2026-11-01).

**Files.** New `Sources/TodoCore/Model/DeviceDay.swift`; `Sources/Features/App/AppModule.swift`, `AppModule+Routing.swift`; `Sources/Features/TaskViewList/TaskViewList.swift`, `TaskViewList+Rows.swift`; `Sources/Features/TaskList/TaskList.swift`; `Sources/WasmSizeProbe/main.swift`; `Apps/Apple/Sources/TodoAppleUI/TodoApp.swift`, `WindowView.swift`; `Tests/AppFeatureTests/AppModuleTests.swift`, `Tests/TaskViewListFeatureTests/*`, `Tests/TaskListFeatureTests/TaskListTests.swift`, `Apps/Apple/Tests/TodoAppleUITests/TodoAppTests.swift`; `CHANGELOG.md`.

**Interface.** Consumed by Tasks 6 and 7, which read the page and the strip by it.

```swift
// TodoCore
/// The device's calendar day and the instant it began, in the clock's milliseconds: the platform's reading,
/// which reaches a module as an event of the world and the core as an argument (ADR-0006, amendment of 2026-11-01).
public struct DeviceDay: Equatable, Sendable {
    public let day: Day
    public let began: Int64
    public init(day: Day, began: Int64)
}
// AppModule
public init(store: Store, route: Route = .default, width: WindowWidth, day: DeviceDay, capabilities: WindowCapabilities) throws(StoreError)
public enum Event: RoutedEvent { /* as today, and */ case dayChanged(DeviceDay) }
// AppModule.Screen (internal)
enum Event { case action(ScreenAction); case changed(ChangeSet); case dayChanged(DeviceDay) }
// TaskViewList
public init(store: Store, route: Route, width: WindowWidth, day: DeviceDay, capabilities: WindowCapabilities) throws(StoreError)
public enum Event: RoutedEvent { /* as today, and */ case dayChanged(DeviceDay) }
// TaskList
public init(store: Store, route: Route, day: DeviceDay) throws(StoreError)
public enum Event: RoutedEvent { /* as today, and */ case dayChanged(DeviceDay) }
// TodoAppleUI (internal)
struct Window { let host: ModuleHost<AppModule>; let open: @MainActor (URL) -> Void; let widthChanged: @MainActor (WindowWidth) -> Void; let dayChanged: @MainActor (DeviceDay) -> Void }
func makeWindow(path: String?, width: WindowWidth, day: DeviceDay, capabilities: WindowCapabilities) throws -> Window
extension DeviceDay { init(at now: Date, in calendar: Calendar) }
```

**Rules.**

- The root keeps the day in its state beside the width and, on `.dayChanged`, hands it to the base and then to every element of its stack by the path read before, as it hands `.changed` (`AppModule.swift:245-251`); the stack's `make` closure reads the root's current day when it makes a `TaskList`, so a screen made after midnight starts on the new day. The width still goes to the base alone.
- A module that receives the same day again reads nothing; a new day rereads what depends on it, the sidebar its counts, the list its page, in Task 6 its strip too. `TaskList.rows(of:in:)` and `TaskViewList.counts(of:)` stop computing `Day(millisSinceEpoch: Store.systemNow())` and take `day.day`; the two doc comments that named the departure from the spec go with it. `TaskScreen` draws no day and does not change.
- The view reads the day with `Calendar.current` from `Date()`: `day` from the calendar's year, month and day components through `Day(year:month:day:)`, `began` from `startOfDay(for:)` in milliseconds. It reports it at the window's start, beside the width, and again when `scenePhase` becomes active, on `NSCalendarDayChanged` and on `NSSystemTimeZoneDidChange`, through `Window.dayChanged`, a closure over the host's entrance built as `widthChanged` is (`TodoApp.swift:132`). The view keeps no day of its own and decides nothing by it (`docs/style.md`, "Views"). The platform conditions, if the notifications' names differ per platform, are each named in a comment.
- The probe passes a fixed `DeviceDay` to the root, as it passes a fixed clock, and sends one `.dayChanged`.

**Tests.**

- `AppModuleTests`: `theDayReachesTheSidebarAndEveryScreen`, a list and a task over the sidebar, a new day, the sidebar's counts and the list's rows read by it; `theSameDayAgainReadsNothing`, compared with a root made anew; `aScreenMadeAfterTheDayChangedStartsOnTheNewDay`.
- `TaskViewListTests`: `theCountsAreByTheDayTheSidebarIsGiven`, a task due today under one day and tomorrow under another.
- `TaskListTests`: `aListReadsItsTasksByTheDayItIsGiven`; `aNewDayRereadsTheTasks`.
- `TodoAppTests`: `theWindowsDayReachesItsHost`, as `theWindowsWidthReachesItsHost` (`:277`); `aDeviceDayIsTheCalendarsDayAndItsStart`, a fixed date in a fixed time zone against the expected `Day` and millisecond.

**Verified facts and traps.**

- Today both modules compute `Day(millisSinceEpoch: Store.systemNow())` at every read, the UTC day (`TaskList.swift:273`, `TaskViewList+Rows.swift:172`); `Day(millisSinceEpoch:)` is `package` (`Day.swift:34`), so `Apps/Apple` could not call it even if it wanted to, and `Day(year:month:day:)` is the public way in (`Day.swift:46`).
- The width's path: `WindowView` `.onChange(of: width, initial: true) { window.widthChanged($0) }` (`WindowView.swift:113`) → `Window.widthChanged` over the host's entrance (`TodoApp.swift:132`, `:184`) → `ModuleHost.deliver`'s queue (`ModuleHost.swift:95-107`) → `AppModule.send(.widthChanged)` to the base alone (`AppModule.swift:273-280`); `Screen.Event` has `.action` and `.changed` only (`AppModule+Routing.swift:80-83`), so the day needs its case there and the loop over the path.
- There is no `Date`, `Calendar`, `scenePhase` or notification anywhere in `TodoAppleUI` today; the view is the only layer with a time zone (ADR-0001), and the CLI alone uses `Calendar` (`Sources/TodoCLI/CLI.swift:145-150`).
- `WindowCapabilities` is not `Equatable`, which is why the module compares models and never state; `DeviceDay` is `Equatable` so that "the same day again" is one comparison.
- The stack's `make` closure is `@escaping` and set once in `init` (`AppModule.swift:194-199`); it reads the day through `self`, since `AppModule` is a class, and never captures a value.

### Task 4: The design system's tokens and the screen's component models

**Goal.** Everything the list screen draws has a model in `DesignSystemComponents` and its tokens in `DesignSystem`: the check in a list's colour, the row and its meta line, the swipe, the card and its subtasks and pills, the block header, the tag bar, the add rows, the Done strip, the column, the empty state, the glass buttons and the floating button, with the icons, fonts, motions and colours they need; nothing on screen changes in this task, and Task 6 is the caller, which the pull request says (spec section 11; ADR-0007, amendment of 2026-10-30).

**Files.** `Sources/DesignSystem/Color.swift`, `Color+Components.swift`, `Font.swift`, `Animation.swift`, `Icon.swift`; new `Sources/DesignSystemComponents/CheckModel.swift`, `TaskRowModel.swift`, `MetaItemModel.swift`, `SwipeModel.swift`, `LiftModel.swift`, `CardModel.swift`, `SubtaskRowModel.swift`, `PillModel.swift`, `BlockHeaderModel.swift`, `TagChipModel.swift`, `TagBarModel.swift`, `AddRowModel.swift`, `DoneStripModel.swift`, `ColumnModel.swift`, `EmptyStateModel.swift`, `GlassButtonModel.swift`, `FloatingButtonModel.swift`, `ScreenHeaderModel.swift`; `MenuModel.swift`; `Apps/Apple/Sources/TodoAppleUI/DesignSystem/Image+DesignSystem.swift`, `Font+DesignSystem.swift`, `Animation+DesignSystem.swift`, `MenuItems.swift`; tests named in the file map; `CHANGELOG.md`.

**Interface.** Every model is `public`, `Equatable`, `Sendable`, with a memberwise `public init`; the generic ones take `Action: Equatable & Sendable`. `TaskRowModel` and `CardModel` are `final class` with a hand-written `==`, as `ListRowModel` is.

```swift
extension DesignSystem.Color {
    public static let glass: Color          // white at .72 / 32 2F 2B at .72
    public static let glassLine: Color      // ink at .08 / white at .08
    public static let fresh: Color          // accent at .12 / white at .08
}
extension DesignSystem.Color.Components {
    /// A task's check in a list's colour, by the canvas's rule: the ring of an open check, the fill of a
    /// checked one, and the mark drawn on the fill, white unless its contrast on the fill is under 3 (amber).
    public struct Check: Equatable, Sendable { public let ring, fill, mark: DesignSystem.Color }
}
extension DesignSystem.Color.Components.Tile { public var check: DesignSystem.Color.Components.Check }
extension DesignSystem.Font {
    public static let addRow: Font      // subheadline medium: "Add task", "Add list"
    public static let notes: Font       // subheadline regular: the card's notes and subtasks
    public static let pill: Font        // footnote semibold: the card's pills
}
extension DesignSystem.Animation {
    public static let cardOpens: Animation   // bezier(.2,.8,.2,1), 0.26 s
    public static let drop: Animation        // spring, 0.32 s: a card landing, a row's fresh highlight
    public static let swipe: Animation       // bezier(.2,.8,.2,1), 0.25 s: the row sliding
    public static let fold: Animation        // bezier(.42,0,.58,1), 0.22 s: a chevron turning, a strip opening
}
public enum Icon { /* as today, and */ case flag, hash, note, expand, columns, chevronLeft, sun }

public struct CheckModel<Action> { let diameter, ringWidth, markSize, hit: Double; let colors: Check; let isChecked: Bool; let animation: Animation; let accessibilityLabel: String; let action: Action }
public struct MetaItemModel { let icon: IconModel?; let text: TextModel }
public struct SwipeModel<Action> { let threshold, shift, buttonWidth, buttonInset, buttonCornerRadius: Double; let button: TextModel; let background: Color; let animation: Animation; let action: Action }
public struct LiftModel { let scale, cornerRadius: Double; let background: Color; let shadow: Shadow; let slot: StrokeModel; let slotDot, slotHeight, slotLeading, slotTrailing: Double }
public final class TaskRowModel<Action> { let check: CheckModel<Action>; let title: TextModel; let isStruck: Bool; let meta: [MetaItemModel]; let metaSpacing, verticalPadding, leading, trailing: Double; let swipe: SwipeModel<Action>?; let lift: LiftModel?; let fresh: Color?; let tap: Action; let menu: MenuModel<Action>? }
public struct SubtaskRowModel<Action> { let check: CheckModel<Action>; let title: TextModel; let isStruck: Bool; let height: Double }
public struct PillModel { let icon: IconModel; let text: TextModel; let background: Color; let height, cornerRadius, padding, spacing: Double }
public final class CardModel<Action> { let check: CheckModel<Action>; let title: TextFieldModel<Action>; let notes: TextFieldModel<Action>; let subtasks: [SubtaskRowModel<Action>]; let subtaskField: TextFieldModel<Action>?; let addSubtask: AddRowModel<Action>; let pills: [PillModel]; let expand: ButtonModel<Action>; let background: Color; let cornerRadius, margin, bodyLeading, pillSpacing: Double; let shadow: Shadow; let animation: Animation; let backgroundTapped: Action }
public struct BlockHeaderModel<Action> { let title: TextModel; let date: TextModel?; let field: TextFieldModel<Action>?; let chevron: AccessoryModel<Action>.Chevron; let rule: StrokeModel; let height: Double; let titleTapped: Action }
public struct TagChipModel<Action> { let icon: IconModel; let title: TextModel; let background: Color; let height, cornerRadius, padding, hit: Double; let isLit: Bool; let action: Action }
public struct TagBarModel<Action> { let chips: [TagChipModel<Action>]; let spacing, fadeIn, fadeOut: Double }
public struct AddRowModel<Action> { let icon: IconModel; let title: TextModel; let height, cornerRadius: Double; let dash: StrokeModel?; let action: Action }
public struct DoneStripModel<Action> { let icon: IconModel; let label: TextModel; let chevron: AccessoryModel<Action>.Chevron; let background: Color; let height, cornerRadius: Double; let isOpen: Bool; let rows: [TaskRowModel<Action>]; let action: Action }
public struct ColumnModel<Action> { let header: BlockHeaderModel<Action>; let width, cornerRadius, cardSpacing, padding: Double; let fill, dropTint: Color; let isDropTarget: Bool; let dropRing: StrokeModel }
public struct EmptyStateModel { let tile: TileModel; let title: TextModel; let text: TextModel; let topPadding, maxWidth: Double }
public struct GlassButtonModel<Action> { let icon: IconModel; let diameter: Double; let surface: Color; let line: StrokeModel; let shadow: Shadow; let accessibilityLabel: String; let action: Action }
public struct FloatingButtonModel<Action> { let icon: IconModel; let diameter: Double; let fill: Color; let shadow: Shadow; let accessibilityLabel: String; let action: Action }
public struct ScreenHeaderModel { let tile: TileModel; let title: TextModel; let subtitle: TextModel?; let spacing: Double }
extension MenuModel.Item { public let isDisabled: Bool; public let subtitle: String? }   // both with defaults in `init`
```

**Rules.**

- The check's colours are derived in `Color+Components.swift` from the tile's private base by the canvas's `paint()`: ring is the base mixed 20 % toward ink in light and 18 % toward white in dark; fill is the base in light and the base mixed 8 % toward white in dark; mark is white, or ink where white's WCAG contrast on the fill is under 3, which is amber alone; the eleven are held to the canvas's resolved hexes within `channelGap`, as the tile's are (`ChannelGap.swift`). A ring of an open check is the ring; a checked check draws the fill as ring and fill (canvas, section 8 of its numbers).
- The three colours and the four motions are static members in their files, since `Color.init(light:dark:)`, `RGB.init(hex:)` and `Animation.init` are internal or private; the new text styles are the existing seven, so `Font.TextStyle` and `Weight` gain no case.
- The seven icons name SF Symbols that exist on macOS 14, checked against `name_availability.plist` as the chrome's were (`Image+DesignSystem.swift:11`): `flag`, `number`, `note.text`, `arrow.up.left.and.arrow.down.right`, `rectangle.split.3x1`, `chevron.left`, `sun.max`; the exhaustive `systemName(for:)` gains the seven, `IconTests` counts 16 + 17, and `DesignSystemRenderersTests` asks `NSImage` for each.
- Models carry what a view draws and nothing it decides: every size is a `Double` in points the module chooses per width (Tasks 6, 8, 9), every string arrives finished, and the typed-text actions of the card's fields stay with the view's `changed: (String) -> Action` as `TitleField` has it (`TextFieldModel.swift:9`). A component holds no id of the store's: the module's `Row` carries the task's id beside the model. `ColumnModel` is the column's look; the cards in it are the module's rows, so the model holds none.
- `TaskRowModel` and `CardModel` are classes for the wasm32 stack, as `ListRowModel` is (`ListRowModel.swift:11`), with `==` over every stored property beginning `if lhs === rhs { return true }`, held by `ClassModelEqualityTests.expectEveryPropertyCompared` through `Mirror`.
- `MenuModel.Item` gains `isDisabled` and `subtitle` for Show as's disabled Columns with its explanation (spec section 5); `MenuItems` draws `.disabled(item.isDisabled)` and the subtitle under the title; the existing callers' `init` calls do not change.
- No new enum a view switches over is added here; `docs/style.md` does not change.

**Tests.**

- `CheckColorTests`: `everyTilesCheckMatchesTheCanvas`, the thirty-three hexes within `channelGap`; `amberAloneDrawsItsMarkInInk`; `theGlassTheLineAndTheFreshShadesAreTheCanvass`.
- `IconTests`: the count and the seven names; `FontTests`: the three new statics' style and weight; `AnimationTests`: the four motions' curve, duration and delay.
- `DesignSystemComponentsTests`: one value test per struct model building it and reading it back (`CheckModelTests`, `SwipeModelTests`, `PillModelTests`, `BlockHeaderModelTests`, `TagBarModelTests`, `AddRowModelTests`, `DoneStripModelTests`, `ColumnModelTests`, `EmptyStateModelTests`, `GlassButtonModelTests`, `FloatingButtonModelTests`, `ScreenHeaderModelTests`, `MenuModelTests` for the two new fields and their defaults); `ClassModelEqualityTests`: `aTaskRowModelComparesEveryProperty`, `aCardModelComparesEveryProperty`.
- `DesignSystemRenderersTests`: the seven symbols exist; the three fonts and four motions render as their SwiftUI values.

**Verified facts and traps.**

- `Tile` exposes `background` and `glyph` and keeps `base` private (`Color+Components.swift:14-33`); `RGB.init(hex:)` is internal (`Color.swift:77`), `Animation.init` and `Shadow.init` private (`Animation.swift:9-35`, `Shadow.swift:9-26`): every derivation lives in `Sources/DesignSystem`.
- Adding an `Icon` case breaks three places by design: `Image.systemName(for:)` (exhaustive, `Image+DesignSystem.swift:18`), `IconTests.swift:41` (16 + 10 today) and `DesignSystemRenderersTests.swift:63` (`NSImage(systemSymbolName:)` for every case). `.chevron` renders `chevron.down` alone (`:39`), hence `chevronLeft`.
- `Font.TextStyle` has `largeTitle, headline, body, callout, subheadline, footnote, caption` and no `title` (`Font.swift:11-51`); the canvas's 17 px block title is `sectionTitle` (headline heavy rounded), its 16.5 px row title `rowTitle`, its 17/600 card title `rowTitleEmphasized`, its 14/600 strip `barLabel`, its 13/500 date `areaLabel`, its 12.5/500 meta `meta`, all existing; 15/500, 15/400 and 13.5/600 are the three new ones.
- `Bar.glass(in:)` is `.regularMaterial` plus an ink 8 % hairline plus `.raised` (`Bar.swift:175-179`); `.glassEffect` is iOS 26 and macOS 26 API under targets of 17 and 14, so the glass button's view (Task 8) uses it behind `#available` and the material otherwise; the model carries the surface and the line for the fallback.
- Four class models exist with `Mirror`-checked `==` (`ClassModelEqualityTests.swift:24`); a property left out of `==` fails twice.
- The names above were probed free on 2026-11-01 (Global constraints): `TaskRowModel`, `CheckModel`, `CardModel`, `PillModel`, `BlockHeaderModel`, `TagChipModel`, `TagBarModel`, `AddRowModel`, `DoneStripModel`, `ColumnModel`, `EmptyStateModel`, `GlassButtonModel`, `FloatingButtonModel`, `SwipeModel`, `LiftModel`, `MetaItemModel`, `ScreenHeaderModel`, `SubtaskRowModel`; `Section` and `Group` are SwiftUI's and are never used (`docs/style.md`).

### Task 5: Spike: three drags on one screen

**Goal.** An answer to the spec's first risk before Task 8 builds on it: whether one SwiftUI screen on iPhone and iPad can hold a long press that lifts a task row in a vertical list, a swipe that slides a row to its Delete, and a card dragged across a board that scrolls sideways, with the drop read between blocks in list mode and between columns in columns mode, without the three gestures and the two scroll views taking each other's touches (spec, "Risks").

**Files.** A throwaway target or a branch of `Apps/Apple` that is not merged; the answer goes into the sub-issue, as #145's did.

**Interface.** None. The deliverable is the arrangement that works, written as the recognizers, their order and their coordinate spaces, and the fallback if one piece does not: the drag within a block and between columns alone, with the drop between blocks in list mode left out, which the owner decides on (spec, "Risks").

**Rules.**

- Start from what #145 settled: one `UILongPressGestureRecognizer` on the tree's own `UIScrollView`, enabled while a row is lifted or edit mode is on, frames reported in a named coordinate space through a preference into an unobserved class, a `CADisplayLink` for the auto-scroll (`ListsDragGesture.swift:416-430`, "approach B2"). The questions this spike answers: (1) a row's swipe as a `DragGesture` on the row inside the `ScrollView`, against the scroll view's pan and the long press, or `.swipeActions` on a `List` instead of the `ScrollView` + `VStack` the Lists screen chose, and what a `List` costs the lift; (2) the lift of a card inside a column that scrolls vertically inside a board that scrolls horizontally with `.scrollTargetBehavior(.viewAligned)`, and the drop read across columns; (3) whether the same arrangement serves the iPad with a pointer and the Mac's `DragGesture`, which #145 settled for the sidebar ("approach A").
- The spike measures nothing; it tries the arrangements on the iOS 26.3 simulator, an iPhone 17 and an iPad Pro 11-inch (M5), and records what each did with a short clip or screenshots in the sub-issue.
- Outside edit mode the Lists screen's long press is the context menu's (`ListsTree.swift:424`); the list screen has no edit mode, so the lift is a long press on a row with no menu, and the Mac's menu is a right click; the spike confirms the long press and `contextMenu` can coexist on one row on iPhone, where the spec wants no menu.

**Tests.** None; spike code is throwaway.

**Verified facts and traps.**

- No swipe action exists anywhere in `Apps/Apple`; the only `List` is `TaskListView.swift:22`, and `.swipeActions` does not apply inside a `ScrollView` + `VStack`.
- `ListsDragGesture` reads `recognizer.location(in: finder)` in the tree's content space and finds the scroll view by walking superviews (`ListsDragGesture.swift:447-454`, `:557-567`); `shouldReceive touch` refuses touches inside a `UITextInput` (`:500-507`), which the card's fields will need too.
- `LazyVStack` dropped a new row's field, which is why the tree is a plain `VStack` (`ListsTree.swift:93-98`); the list screen has the card's fields in the same position.

### Task 6: The module's page: blocks, rows, the tag bar, a list over a list, a group's screen

**Goal.** `TaskList` reads a view's page into blocks and rows as the spec draws them, in list and in columns layout, with the tag bar filtering, the folds and the layout kept per device, the day's formats, and a block's title opening a list inside or one of the list's own groups over this list; the route's head gains the group and its tail becomes two cases, and the window reads `view/a/view/b` and `view/a/day/+1`; the sidebar keeps its highlight on the base of the chain. The look is Task 8's; `TaskListView` is adapted so that the app compiles and a list still opens its tasks, in today's style (spec sections 1, 2, 5, 7, 8, 9).

**Files.** `Package.swift`; `Sources/Features/TaskList/TaskList.swift`; new `TaskList+Model.swift`, `TaskList+Page.swift`, `TaskList+Day.swift`, `TaskList+Components.swift`; `Sources/Features/App/AppModule+Routing.swift`; `Sources/WasmSizeProbe/main.swift`; `Apps/Apple/Sources/TodoAppleUI/TaskListView.swift`; `Tests/TaskListFeatureTests/TaskListTests.swift`, new `TaskListPageTests.swift`, `TaskListDayTests.swift`, `TaskListComponentsTests.swift`; `Tests/AppFeatureTests/RouteTests.swift`, `AppModuleTests.swift`; `CHANGELOG.md`.

**Interface.** Consumes Tasks 1 to 4 and 2b. Task 7 adds the actions, the card and the strip; Tasks 8 and 9 draw it.

```swift
public final class TaskList: Routable {
    public struct Route: RouteValue {
        /// What makes this list this one: the view, and on a group's screen the group of it shown.
        public struct Head: Hashable, Sendable {
            public let view: ViewID
            public let group: Group?
            public init(view: ViewID, group: Group? = nil)
        }
        /// One of the list's own groups as its address, a grouping and its key; a day is a distance from today.
        public enum Group: Hashable, Sendable {
            case day(Int32?)          // `day/+1`, `day/0`, `day/-2`, `day/none`: by the day of When
            case deadline(Int32?)     // `deadline/…`, the same keys: by the day of the deadline
            case tag(TagID?)          // `tag/<id>`, `tag/none`
            case parent(TaskID?)      // `parent/<id>`, `parent/none`
            case status(TaskStatus)   // `status/open`, `status/done`, `status/canceled`
        }
        public let head: Head
        public let over: Over?
        /// What the list declares over itself: the task screen, or another list, a list inside or one of this list's groups.
        public enum Over: RouteValue {
            case task(TaskScreen.Route)
            indirect case list(TaskList.Route)
            public enum Head: Equatable, Sendable { case task(TaskID); case list(ViewID) }
            public var head: Head
            /// What the screen over the list answers; both mean it asks to be closed.
            public enum Answer: Equatable, Sendable { case task(TaskScreen.Output); case list(TaskList.Output) }
        }
        public init(head: Head, over: Over? = nil)
        package init(reading path: inout ArraySlice<String>) throws(RouteError)
        package var segments: [String]
    }
    public struct Model: Equatable, Sendable {
        public let header: ScreenHeaderModel
        public let tagBar: TagBarModel<UserAction>?            // nil when no chip would show
        public let layout: Layout
        public let done: DoneStripModel<UserAction>?           // Task 7; nil here
        public let addTask: FloatingButtonModel<UserAction>?   // Task 7; nil here
        public let addList: AddRowModel<UserAction>?           // Task 7; nil here
        public let showAs: MenuButtonModel<UserAction>
        public let empty: EmptyScreenModel?
        public let problem: String?
        public enum Layout: Equatable, Sendable {
            case list([Block])
            case columns(Board)
            public enum Kind: String, Codable, Equatable, Sendable { case list, columns }
        }
        public struct Board: Equatable, Sendable {
            public let columns: [Block]                         // each with its `column` look
            public let addList: AddRowModel<UserAction>?        // Task 7; the dashed last column
            public let spacing, padding: Double
            public let snaps: Bool
        }
        public struct Block: Equatable, Sendable, Identifiable {
            public let id: BlockID
            public let header: BlockHeaderModel<UserAction>?    // nil for the own block of a list that groups by nothing
            public let rows: [Row]
            public let addTask: AddRowModel<UserAction>?        // Task 7; nil here
            public let isFolded: Bool
            public let column: ColumnModel<UserAction>?         // in columns layout
        }
        public enum Row: Equatable, Sendable, Identifiable {
            case task(TaskID, TaskRowModel<UserAction>)
            case card(TaskID, CardModel<UserAction>)            // Task 7
            public var id: TaskID
        }
        public enum BlockID: Hashable, Sendable {
            case own(GroupKey?)       // one of the list's own blocks, by its group's key
            case list(ViewID)         // the block of a list inside
        }
    }
    public enum UserAction: Equatable, Sendable {
        case rowTapped(TaskID)                      // pushes the task screen here; opens the card in Task 7
        case blockTitleTapped(Model.BlockID)
        case blockChevronTapped(Model.BlockID)
        case tagChipTapped(TagID)
        case showAsChosen(Model.Layout.Kind)
    }
    public enum Event: RoutedEvent {
        case action(UserAction)
        case changed(ChangeSet)
        case created
        case route(Route)
        case dayChanged(DeviceDay)
        case destinationAnswered(Route.Over.Answer)
        case uncovered
        case notOpened(StoreError, stillOpen: Route.Over?)
    }
    public enum Output: Equatable, Sendable { case closeRequested }
    public var model: Model { get }
    public var route: Route { get }
    public var destination: Destination<Route.Over> { get }
    public init(store: Store, route: Route, day: DeviceDay) throws(StoreError)
    public func send(_ event: Event) -> Output?
}
```

**Rules.**

- The route reads `view/<id>`, then `task/<id>` into `.task`, `view/…` into `.list`, a group's word and key into `.list` of a route whose head is this view with the group, or nothing; after a group only `task/<id>` or nothing, and `view` or a second group's word there is refused with `.segmentOutOfPlace`. The words are `day`, `deadline`, `tag`, `parent` and `status`. A distance is written `+n`, `0` or `-n` and read only so, so that a link has one spelling (`1`, `+0` and `-0` are refused), and must fit `Int32`; `none` is the group with no key; an id reads through the core as every id does; a status is its case's name. A key that does not read is refused with `.unknownSegment(key)`, an id with `.notAnID` as today; nothing reads the store. A group's route writes its word and key alone, since its view is its list's. Reading and writing a chain of lists are loops over the path and the chain, never a recursion over them: the reader collects every `view/<id>` and group into an array and folds it from the end, since a path is data from outside. `/view/a/view/b/task/t` reads as list a over which list b stands over which task t stands; `/view/a/day/+1/task/t` as list a over which its group of tomorrow stands over which task t stands (ADR-0009, amendment of 2026-11-02).
- `AppModule.Screen` maps the two-case tail: `destination` of a list is `list.destination.map { .task($0) or .list($0) }`; `route(over:)` puts whatever stands above into `over`; `take` hands `.destinationAnswered(.task(…))` and `.destinationAnswered(.list(…))` to the list as `Route.Over.Answer`, and `.notOpened`'s `stillOpen` as `Over?`; the base keeps `above?.list` as the chain's base. `Screen.Route.Head`'s `.list` case carries `TaskList.Route.Head`, so a group's screen and its list's have different heads and the stack pushes the one over the other. `Screen`, `ScreenModel`, `ScreenAction` and `RootView.screen(_:)` gain no case (spec section 12).
- The page is `store.page(of: head.view, today: day.day)`, read in `init`, on `.changed` when `rereads` holds (`TaskList.swift:259`), and on a new day. The blocks: one per group of the own section, `BlockID.own(key)`, headed by the day's title and date for a grouping by day and by nothing for a list that groups by nothing; then one per list child section, `BlockID.list(child.id)`, headed by the child's title in its colour and drawn when empty too. A group's screen reads the same page and draws one block, the own section's group whose key is the route's group at today, `.day(today + n)` for `day/+n` with the sum clamped as every day offset is, the others as they are; a group with no task today is that block empty, with the empty state; so the screen is exactly the block it was opened from, a task a list inside claims left out, and a new day moves the distance onto the new day. The group's word must be the list's grouping, `day` for `.whenDay`, `deadline` for `.deadlineDay`, `tag`, `parent` and `status` for theirs, and a tag or a parent must exist, or `init` refuses with `.invalid` or `.notFound` and the stack leaves the list open with `.notOpened` and its sentence (ADR-0009, amendment of 2026-11-02). A group's screen keeps no folds and no layout, has no lists inside, no Columns and no "+ Add list". The rows are `TaskRowModel`s built from the page's tasks: the check in the page view's colour for the own blocks and the child's for its block, the title struck when the task is not open, the meta line in the spec's order, deadline, tags, subtasks, notes, the deadline red from the day it is due.
- The tag bar's chips are the tags of the page's open tasks counted over every row, most used first and ties by title from `store.tags()`, a tag on every task dropped; a tap toggles a pick, picks are session state, and a picked set filters the rows of every block and column to the tasks carrying any of them; a block emptied by the filter keeps its header. The bar is nil when no chip would show.
- The folds are `store.deviceState("taskList.folded.<view>", as: [String].self)`, a block's key written as `day/<yyyy-mm-dd>`, `day/none`, or `view/<id>`, read when the module is made and written with `try?` on every chevron tap, as the sidebar's are (`TaskViewList.swift:534-559`); a folded block draws its header and no rows. The layout is `store.deviceState("taskList.layout.<view>", as: Model.Layout.Kind.self)`, `.list` when nothing is kept; `showAsChosen` writes it and rebuilds; in columns the folds are ignored and every block is a column with its `ColumnModel` look. Show as is a `MenuButtonModel` with two items, Columns disabled with the subtitle "Group the list in its settings to get columns" when the page has one block and no grouping (spec section 5).
- `blockTitleTapped(.list(id))` declares `.list(Route(head: .init(view: id)))`. `blockTitleTapped(.own(key))` declares `.list(Route(head: .init(view: head.view, group: g)))`, g the key as an address by the list's `groupBy`: `.day(d)` is `.day(d - today)` by `.whenDay` and `.deadline(d - today)` by `.deadlineDay`, a distance outside `Int32` clamped, `.day(nil)` is `.day(nil)` or `.deadline(nil)`, `.tag(t)` is `.tag(t)`, `.parent(p)` is `.parent(p)`, `.status(s)` is `.status(s)`; every group opens, the one with no tag included, since its screen reads the page and needs no condition. Nothing is written. On a group's screen its one block's title opens nothing. What the store refuses becomes the sentence, and the model's `problem`.
- The header: the tile in the view's colour and icon, the title, and a subtitle: on a group's screen, the list's tile, the group's name for its title, the day's name for a day, "Monday", "No date" for none, the tag's or the parent's title, "No tag", "No parent", the status's name, and for its subtitle the list's title and, for a day, the date the distance falls on today, "Upcoming · Oct 26"; for a list, the date of the one day its rule's When condition gives when that condition is `on` or `onOrBefore`, Today's "Saturday, October 24", and none otherwise (engineer's call: the canvas gives Today a subtitle and nothing names the built-in).
- `TaskList+Day` formats in English from `Day` and `Day.weekday`: the long date "Saturday, October 24"; the short date "Sat, Oct 24"; a block's title "Today", "Tomorrow", the weekday's name within six days, else "Mon, Oct 26", with the date under it "Sat, Oct 24" for today and tomorrow and "Oct 27" otherwise; the due text "Overdue 2 days", "Due today", "Due Tue" within six days, "Due Oct 30"; a group's screen's title above. No name of a day lives in the core.
- The sidebar's highlight stays the declared list's view, the base of the chain.
- The models are built in `TaskList+Components` by static builders over one `Metrics` per width and layout, as the sidebar's are (`TaskViewList+Components.swift`); this task carries the phone's list-layout metrics and the columns' and the Mac's follow in Tasks 8 and 9. The probe drives every new action, reads every model's blocks and sends the day. `TaskListView` draws the blocks as plain sections of titles and keeps its tap, the floating controls waiting for Task 8; the root view's `.list` toolbar button stays until Task 8.

**Tests.**

- `TaskListTests`: adapted to the model; `theRouteReadsAListOverAList`, `theRouteReadsATaskOverAListOverAList`, `theRouteRefusesAThirdWord`, `aChainOfListsIsReadAndWrittenWithoutRecursion`, a path of two hundred `view/` segments; `theRouteReadsAndWritesEveryGroupsAddress`, a table of the five words and their keys; `theRouteRefusesAGroupKeyThatDoesNotRead`, `day/1`, `day/+0`, `day/x`, a distance past `Int32`, `status/later`, `tag/` with no id; `onlyATaskFollowsAGroup`.
- `TaskListPageTests`: `theOwnBlocksComeFirstThenOneBlockPerListInside`; `aFolderInsideIsOneBlockOfItsListsTasks`; `aListInsideWithListsOfItsOwnIsOneBlockHere`; `anEmptyListInsideIsDrawnAsABlock`; `aGroupedListsOwnBlocksAreItsDays`; `aRowsMetaLineSaysDeadlineTagsSubtasksAndNotesInOrder`; `aDeadlineIsRedFromTheDayItIsDue`; `theTagBarCountsTheOpenTasksTagsAndDropsATagOnEveryOne`; `aPickedTagFiltersEveryBlock`; `twoPickedTagsShowATaskCarryingEither`; `theTagBarIsNilWhenNoChipWouldShow`; `aFoldHidesTheRowsAndIsReadBackByAModuleMadeAnew`; `theLayoutIsKeptPerListOnThisDevice`; `columnsIgnoreTheFolds`; `showAsDisablesColumnsForAListWithOneBlock`; `aBlockTitleOpensTheListInside`; `aDayBlocksTitleOpensItsGroupOverTheListAndWritesNothing`, the destination and the journal unchanged; `aGroupsScreenIsExactlyItsBlock`, a task a list inside claims left out; `aGroupsScreenIsOneBlockWithNoColumnsAndNoAddList`; `aGroupsScreenFollowsTheDay`, the same distance on the new day after `.dayChanged`; `aGroupsScreenIsTitledByTheDayWithItsListAndDateUnder`; `aGroupWhoseWordIsNotTheListsGroupingIsNotOpened`; `aGroupOfATagThatIsGoneIsNotOpened`; `todaysSubtitleIsItsDateAndUpcomingHasNone`; `aViewDeletedUnderTheListAsksToClose` kept; `aNewDayRereadsThePage`.
- `TaskListDayTests`: the long and short dates, the block titles across a week and beyond, the due texts at every distance, a group's screen's titles.
- `TaskListComponentsTests`: the check's colours follow the block's list, the struck title, the chip lit in the list's colour, the header's chevron rotation folded and open, the disabled Columns item.
- `RouteTests`: `/view/a/view/b/task/t` and `/view/a/day/+1/task/t` in the table; the refusal test `whatARouteRefusesInThePathIsWhatTheWindowRefuses` reworded for a third word. `AppModuleTests`: `aListOverAListStandsTwiceInTheStack`, `aGroupStandsOverItsList`, `theRouteIsWrittenFromWhatStands` with a chain, `closingTheInnerListUncoversTheOuter`.

**Verified facts and traps.**

- `TaskList` today reads `store.tasks(in:today:)` and never `page` (`TaskList.swift:274`); its `Route` has `task: TaskScreen.Route?` for its one tail (`:51`), `word` is `private` (`:59`), and a nested `view` is refused with `.segmentOutOfPlace("view")` (`:87`), asserted by `TaskListTests.swift:402` and `RouteTests.swift:68`, which both change.
- The stack hands a new element `.created` and its answer down as `.destinationAnswered` (`ScreenStack.swift:206-215`); two elements of one kind have distinct ids and models (`:199-200`; `theSameKindOfScreenCanStandTwice`). `Screen.Route.Head` is `{ list(ViewID), task(TaskID) }` (`AppModule+Routing.swift:52-55`): a list declaring its own view over itself would be kept, not pushed, which is why a group's screen carries its group in its head.
- `Screen.destination` for a list is `list.destination.map(Route.task)` and `route(over:)` hard-codes `task: above?.task` (`AppModule+Routing.swift:107`, `:144`); `Destination.map` keeps the mark (`Destination.swift:60-66`).
- The sidebar's highlight is `destination.pushed?.head` (`TaskViewList.swift:844` on `main` at 744779f), which becomes the head's view.
- Device-state keys in use: `"taskViewList.collapsed"` as `[String]` (`TaskViewList.swift:559`); a value that does not decode reads as nothing kept (ADR-0010, amendment of 2026-10-26).
- `store.tags()` returns every tag (`Store+Tags.swift:69`); a tag's title is read there once per page, not per row.
- The probe's `label(_:)` and `firstRow(of:)` read `TaskList.Model.rows` and `.title` (`main.swift:265-270`, `:416-420`) and must be rewritten with the blocks. `TaskListFeature` depends on `TodoCore, FeatureModule, TaskScreenFeature` alone (`Package.swift:79`); the sidebar's targets show the two dependencies to add (`:74-78`, `:113-119`).

### Task 7: The module's edits: completing, the card, adding, deleting, the reorder and the drop

**Goal.** Every write the screen makes goes through `TaskList`: a check completes and the Done strip reopens; a tap opens the task in place as a card whose title, notes and subtasks are edited and whose Open full screen pushes the task screen; "+" and "+ Add task" add a task that lands in its block by the rule's edits; "+ Add list" makes a manual list named inline; a swipe or the Mac's menu puts a task in the Trash; a drop reorders within a block by pins or moves a task into another block by the block's edits (spec sections 3, 4, 6).

**Files.** `Sources/Features/TaskList/TaskList.swift`, `TaskList+Model.swift`, `TaskList+Components.swift`; new `TaskList+Rule.swift`, `TaskList+Edits.swift`; `Sources/TodoCore/Storage/Store+Views.swift`, `Sources/TodoCore/Query/Store+Query.swift`; `Tests/TodoCoreTests/QueryTests.swift`; `Sources/WasmSizeProbe/main.swift`; `Apps/Apple/Sources/TodoAppleUI/TaskListView.swift`; `Tests/TaskListFeatureTests/TaskListRuleTests.swift`, `TaskListEditsTests.swift`; `Tests/TodoCoreTests/ViewTests.swift`; `CHANGELOG.md`.

**Interface.** Consumes Task 6; Tasks 8 and 9 draw it.

```swift
extension Store {
    /// Pins several tasks in a view's manual list in one transaction: the first at the placement, each next
    /// after the one before, so that a dropped task and the unpinned tasks above it land where they stood.
    public func pin(tasks: [TaskID], in view: ViewID, at placement: Placement) throws(StoreError)
}
extension GroupKey {
    /// The key a grouping puts a task under, the page's one rule (a task with several tags under the least),
    /// so that a group's screen keeps the strip's tasks of its group by the rule the page grouped them by.
    public init(of task: TodoTask, by groupBy: GroupBy)
}
extension TaskList.UserAction {   // the cases Task 7 adds to the enum
    case checkTapped(TaskID)                        // a row's or a strip row's check
    case rowTapped(TaskID)                          // now opens the card in place
    case backgroundTapped, escapeKeyPressed         // close the card, cancel a field
    case titleFieldChanged(String), titleFieldSubmitted, titleFieldCancelled, titleFieldLostFocus
    case notesFieldChanged(String), notesFieldLostFocus
    case subtaskCheckTapped(TaskID)
    case addSubtaskTapped
    case subtaskFieldChanged(String), subtaskFieldSubmitted, subtaskFieldCancelled, subtaskFieldLostFocus
    case openFullScreenTapped
    case addTaskButtonTapped                        // the floating "+"
    case addTaskRowTapped(in: Model.BlockID)        // "+ Add task"
    case addListTapped                              // "+ Add list", in both layouts
    case listNameFieldChanged(String), listNameFieldSubmitted, listNameFieldCancelled, listNameFieldLostFocus
    case doneStripTapped
    case deleteSwiped(TaskID), deleteMenuItemChosen(TaskID)
    case rowDropped(TaskID, in: Model.BlockID, after: TaskID?)
}
extension TaskList.Model {   // the members Task 7 adds, which Task 6 left out with no value to give them
    public let done: DoneStripModel<UserAction>?           // nil for Logbook, Trash and a day with nothing done
    public let addTask: FloatingButtonModel<UserAction>?   // the floating "+", nil where no task can be added
    public let addList: AddRowModel<UserAction>?           // "+ Add list", nil on a group's screen, in Logbook and Trash
    // in Board:  public let addList: AddRowModel<UserAction>?   the dashed last column
    // in Block:  public let addTask: AddRowModel<UserAction>?   "+ Add task", nil where the block's rule refuses
    //            public let drop: Bool?                         nil where the block takes no drop
    // in Row:    case card(TaskID, CardModel<UserAction>)       the open card in place of its row
}
// TaskList+Rule.swift, internal to the module
struct Edits: Equatable {
    var when: Day??          // nil: no edit; .some(nil): no day; .some(day): that day
    var deadline: Day??
    var addTags: Set<TagID>
    var removeTags: Set<TagID>
    var pinIn: ViewID?
    var unpinFrom: Set<ViewID>
    /// The edits a rule asks of a task, or nil for a rule the module cannot read as edits (spec section 4).
    static func of(_ filter: Filter, today: Day, day: Day??) -> Edits?
}
```

**Rules.**

- `Edits.of` walks the rule: `.when(c)` gives the day nearest today the condition allows, `today + n` for `.on(n)`, `min(today + n, today)` for `.onOrBefore(n)`, `max(today + n, today)` for `.onOrAfter(n)`, today clamped into the range for `.between`, no day for `.empty`, and the block's own day in a day block, handed in as `day`; `.deadline` the same; `.hasTag(t)` adds the tag; `.listedIn(v)` pins in v; `.not(.hasTag(t))` removes the tag and `.not(.listedIn(v))` unpins; `.status([.open])`, `.parent(nil)` and `.trashed(false)` ask nothing, since a task the screen adds or drags is open, at the root and out of the Trash; `.and` merges each, and two day edits that disagree refuse; `.or`, any other `.status`, `.parent(id)`, `.trashed(true)` and any other `.not` refuse with nil. An offset is clamped into `Int32` before it becomes a day. A folder's edits are its first list's; a folder with no lists has none.
- Adding: `addTaskButtonTapped` adds at the start of the first block, `addTaskRowTapped(in:)` at the end of that block; the block's edits give `NewTask(title: "", when:, deadline:, tags: addTags ∪ the picked tags)`, written with `createTask(_:at:)`, then `pin(task:in:at:)` when the edits pin, `.start` or `.end` by the control; the new task becomes the open card with the title field empty. A block whose edits are nil has no `addTask`; a list whose own edits are nil has no floating `addTask`, which is how Logbook and Trash have none (spec section 4).
- The card: `rowTapped(id)` on a row the model holds opens it and closes any other; opening reads `store.notes(of:)` and `store.children(of:)` once; `titleFieldSubmitted` and `titleFieldLostFocus` write `.title(draft)` when it changed; `notesFieldLostFocus` writes `.notes(draft)`; `backgroundTapped`, `escapeKeyPressed` and a tap on another row close the card, and a card closing with an empty title deletes its task with `store.delete(task:)` (spec section 4); `openFullScreenTapped` declares `.task(TaskScreen.Route(head: id))`. The subtask field opens on `addSubtaskTapped`; `subtaskFieldSubmitted` writes `NewTask(title:, parent: id)` at `.end` and opens the next empty field; `subtaskFieldLostFocus` writes what was typed if any and closes it; `subtaskCheckTapped` writes the subtask's status. Completing cascades nowhere (spec section 3, the owner's open question taken as no).
- Completing: `checkTapped(id)` writes `.status(.done)` for an open task and `.status(.open)` for one that is not, the strip's rows included; the module keeps no done task among its rows and no timer (spec section 3). The strip reads `store.doneTasks(in: head.view, since: day.began, today: day.day)` with the page and on a new day; `doneStripTapped` toggles it open, session state; it is nil for a view whose rules lift to nothing new, Logbook and Trash, and when nothing is done.
- A group's screen (Task 6): "+" and its block's "+ Add task" give what that block's "+ Add task" gives on the list's screen, the list's edits with the group's day; a reorder pins in the list's manual list within the day; the strip is the list's `doneTasks(in: head.view, …)` kept to the tasks whose `GroupKey(of:by:)` under the list's grouping is the group's, which `Store.group(_:by:manual:)` uses too, so that the two never disagree.
- "+ Add list": `addListTapped` calls `store.createManualList("New list", in: head.view, color: view.color)` and opens the name field in the new block's header with the draft "New list"; `listNameFieldSubmitted` and `listNameFieldLostFocus` write `update(view: id, [.title(trimmed)])` when it is not empty and changed, an empty name keeping the old; `listNameFieldCancelled` closes the field. Nil on a group's screen, in Logbook and in Trash (spec section 2).
- Deleting: `deleteSwiped(id)` and `deleteMenuItemChosen(id)` write `store.trash(task: id)`; a row of the Trash has neither control.
- `rowDropped(task, in: block, after: anchor)` in the task's own block is a reorder: the block's view is the list for an own block and the child for its block; the unpinned tasks that stand above the drop point in that group, in their order, and then the task are pinned by one `pin(tasks:in:at:)`, at `.after(the last pinned task above)` or `.start`; in a day block the sequence is the day's. In another block it is a move: the target block's `Edits`, with the block's day for a day block, applied through `update(task:)`, `add(tag:to:)`, `remove(tag:from:)`, `pin` and `unpin`, after which the source block's edits are reversed, its pin unpinned and its tags removed, so that the task leaves the block it came from (spec section 6's table, read as the source block's asks; a task two blocks both select is drawn in both and leaves only the one it was dragged from). A target whose edits are nil takes no drop: its `ColumnModel` does not tint and the view draws no slot, which the model says by `Block.drop == nil` (a `Bool` the view reads). The writes are several transactions; the pull request measures the rereads between them on the 50,000-task store and the remedy, one core call for the set, is built only if they show (spec section 6).
- The probe drives every write once; `TaskListView` gains plain controls for the check, the add rows and Delete so that `main` keeps working until Task 8.

**Tests.**

- `TaskListRuleTests`: one test per condition and per refusal: `aWhenOnGivesThatDay`, `aWhenOnOrBeforeGivesTodayAtTheLatest`, `aWhenOnOrAfterGivesTodayAtTheEarliest`, `aBetweenClampsToday`, `aWhenEmptyGivesNoDay`, `aDayBlockGivesItsOwnDay`, `aTagGivesTheTag`, `aManualListPins`, `aNegatedTagRemovesIt`, `aNegatedManualListUnpins`, `anOpenStatusARootAndNotTrashedAskNothing`, `aConjunctionGivesEach`, `twoDaysThatDisagreeRefuse`, `alternativesRefuse`, `aDoneStatusAParentAndTheTrashRefuse`, `anOffsetOutsideInt32IsClamped`, `aFoldersEditsAreItsFirstLists`; the five seeds: `theInboxAsksNoDayTodayAsksTodayUpcomingAsksTomorrow`, `logbookAndTrashRefuse`.
- `TaskListEditsTests`: `theFloatingPlusAddsAnEmptyTaskAtTheTopOfTheFirstBlockWithItsCardOpen`; `addTaskAtABlocksEndTakesTheBlocksEdits`, a day block's day and tag; `aPickedTagGoesOnANewTask`; `aNewTaskInAManualListIsPinnedLast`; `aCardClosingWithNoTitleDeletesTheTask`; `theTitleIsWrittenOnSubmitAndOnLeavingTheField`; `notesAreWrittenOnLeavingTheField`; `aSubtaskIsAddedOnReturnAndTheNextFieldOpens`; `leavingTheSubtaskFieldAddsWhatWasTyped`; `aSubtasksCheckWritesItsStatusAndCascadesNowhere`; `openFullScreenPushesTheTaskScreen`; `aCheckCompletesAndTheRowLeavesTheRows`; `theStripHoldsWhatThePagesRulesCompletedToday`; `theStripIsNilForLogbookTrashAndNothingDone`; `aStripRowsCheckReopensTheTask`; `aNewDayEmptiesTheStrip`; `addListMakesAManualListLastWithTheParentsColourAndOpensItsName`; `anEmptyNameKeepsTheOld`; `deleteSwipedTrashesTheTask`; `aTrashRowHasNoSwipeAndNoMenu`; `aReorderPinsTheTaskAndTheUnpinnedAbove`, the order read back; `aReorderInADayBlockStaysInTheDay`; `aDropIntoADayBlockSetsTheDayAndTheRulesTag`; `aDropIntoAManualListPinsLastAndLeavesTheSourcesPin`; `aDropIntoATagListSwapsTheTags`; `aDropIntoAFolderAsksItsFirstList`; `aDropIntoTheOwnBlockLeavesTheListInside`; `aBlockWhoseRuleRefusesTakesNoDrop`; `aGroupsScreenAddsWhatItsBlockAdds`; `aGroupsStripIsTheListsKeptToTheGroup`; `whatTheStoreRefusesBecomesTheSentence`.
- `QueryTests`: `aTasksKeyIsTheOneThePageGroupsItUnder`, every grouping, several tags under the least.
- `ViewTests`: `pinningSeveralTasksIsOneTransactionInOrder`; `pinningAfterATaskNotInTheListIsRefused`.

**Verified facts and traps.**

- `createTask` always writes status open and pins nothing (`Store+Tasks.swift:25-37`); `update(task:)` moves `completed_at` only across open and not-open (`:66-70`); `delete(task:)` tombstones (`:89`); `trash` follows the tree (`:76-89`); `add(tag:to:)` requires both to exist and `remove` only the task (`:120-132`).
- `pin` ranks among `pinnedItems(of:excluding: task)` and `Placement.after(anchor)` throws `.notFound(anchor)` when the anchor is not among them (`Store+Views.swift:151-167`, `Store+Tasks.swift:191-194`): the reorder's anchor must be a pinned task, which is why the unpinned above are pinned first, in the same call.
- The manual list applies within a group and pinned tasks come first in it (`manualFirst`, `Store+Query.swift:173-182`); no row says it is pinned, so the module intersects the block's rows with `store.manualList(of:)` to find the unpinned above (dossier, answer f).
- `TextFieldModel` carries no `changed` action (`TextFieldModel.swift:9`); the typed-text actions above are the view's `changed: (String) -> Action`, as `TitleField` has it.
- `TaskChange` has no parent or tag case (`TodoTask.swift:73-79`); a subtask is `NewTask(parent:)`; the five seeds' rules are at `TaskView.swift:119-139`.
- Every public write is one `apply`, one transaction and one `onChange` (`Store+Apply.swift:22-26`); a module never writes in answer to `.changed` (ADR-0009), and every write here answers an action.
- The strip's "since" is `DeviceDay.began` in the clock's milliseconds, the same scale as `completed_at` (`Store+Tasks.swift:69`).

### Task 8: The list screen on iPhone

**Goal.** The list screen as the canvas draws it on iPhone, in both layouts and both appearances, drawn from the module's models: the glass back and "…" over the content, the header, the tag bar, the blocks with their rows, the card in place with its fields and the keyboard, the Done strip, the add rows, the floating "+", the empty state, the swipe to Delete, the long press that lifts a row or a card and the drop between blocks and columns, the board that snaps (spec sections 1 to 7, 11; the spike's answer).

**Files.** New `Apps/Apple/Sources/TodoAppleUI/ListScreen/ListScreen.swift`, `BlockView.swift`, `TaskRowView.swift`, `TaskCardView.swift`, `TagBarView.swift`, `DoneStripView.swift`, `BoardView.swift`, `ColumnView.swift`, `GlassButton.swift`, `FloatingButton.swift`, `SwipeToDelete.swift`, `RowLiftGesture.swift`, `EmptyScreenView.swift`; new `Apps/Apple/Sources/TodoAppleUI/DesignSystem/DropIndicator.swift`, out of `ListsScreen/ListsDragGesture.swift`; `Apps/Apple/Sources/TodoAppleUI/RootView.swift`; `TaskListView.swift` deleted; `Sources/Features/TaskList/TaskList+Metrics.swift` for the columns' styles, carried by Task 6 and tuned by the hand check; new `Apps/Apple/Tests/TodoAppleUITests/RowLiftTests.swift`; `README.md`, `CHANGELOG.md`.

**Interface.** Everything is `internal` to `TodoAppleUI`; the module's model is the contract.

```swift
struct ListScreen: View { init(model: TaskList.Model, send: @escaping (TaskList.UserAction) -> Void, back: @escaping () -> Void) }
struct TaskRowView<Action: Equatable & Sendable>: View { init(_ model: TaskRowModel<Action>, send: @escaping (Action) -> Void) }
struct TaskCardView<Action: Equatable & Sendable>: View { init(_ model: CardModel<Action>, titleChanged: @escaping (String) -> Action, notesChanged: @escaping (String) -> Action, subtaskChanged: @escaping (String) -> Action, send: @escaping (Action) -> Void) }
struct GlassButton<Action: Equatable & Sendable>: View { init(_ model: GlassButtonModel<Action>, send: @escaping (Action) -> Void) }
/// The lift's step machine, platform-free and tested on the host as `ListsDrag` is: a point lifts the row whose frame holds it,
/// a move picks the slot between rows or the column under the point, a release is one `rowDropped`.
struct RowLift: Equatable { enum Phase { case began(CGPoint), changed(CGPoint), ended, cancelled }
    static func after(_ phase: Phase, from lift: RowLift?, among blocks: [TaskList.Model.Block], frames: [TaskID: CGRect], blockFrames: [TaskList.Model.BlockID: CGRect]) -> (lift: RowLift?, drop: TaskList.UserAction?) }
```

**Rules.**

- The screen hides the navigation bar as `ListsScreen` does (`ListsScreen.swift:27-31`) and draws its own back as a glass circle, which calls `back`, the closure `RootView` builds from the stack's path, `host.send(.wentBack(to:))` with this element dropped: the way back stays an action of the root (ADR-0009, amendment of 2026-10-22, point 4). The glass circles use `.glassEffect` behind `#available(iOS 26, *)` and its `GlassControlStyle`'s `surface` and `line` otherwise, named in a comment.
- The content is a `ScrollView` over a `VStack`, not a `List` and not a `LazyVStack` (spike #145, `ListsTree.swift:93-98`), unless Task 5 found the swipe needs a `List`; the blocks switch over `Row` to draw a row or a card, the one switch over a row's kind, and over `Layout` for the board; every other `if` is over a `Bool` or an optional of the model.
- The swipe, the lift and the drop are the spike's arrangement; `RowLift.after` reads the frames the rows and blocks report in a named space through a preference into an unobserved class, as `ListsDrag` does, and sends one `rowDropped(task, from: block, in: block, after:)` on release, `RowLift` carrying the block it lifted from, since a task two blocks draw leaves only the one it was dragged from (Task 7); a block whose `Block.takesDrop` is false gets no slot and no tint. The slot is the lift's `indicator`, a `DropIndicatorStyle`, the mark the sidebar's drag draws: its line and circle move out of `ListsDrag.Slot.indicatorMark` into one view, `DropIndicator`, placed from the edge its caller gives, the tile of the drop's depth in the tree and the rows' leading edge here. The auto-scroll is the `CADisplayLink` of `ListsDragGesture`.
- A row's `lift` and `fresh` are filled here, as fields of its `TaskRowStyle`, the table's `Row.style` taking what they depend on, having been nil since Task 7; a swipe's Delete reads "Delete <title>" aloud (canvas), which `SwipeModel` gains a field for here, a text and not a number, so beside its `style`. The Done strip's view, `DoneStripView`, draws the capsule, and `Model.doneRows` draws under it through the row's one switch, a row or the open card (Task 7). What the table gives and Task 7's models have no field for is added here as a field of the named component's style (#190), and so is any colour or motion the canvas gives it; a value that depends on the row makes that table entry a function of what it depends on. `Metrics.phone` and `Metrics.phoneColumns` fill them: the floating "+"'s 16 and 30 from the screen's edges on `FloatingButtonStyle`, the 6 pt between the capsule and its rows on `DoneStripStyle`, the card's subtasks 12 outside its body's leading edge and 4 under the notes on `CardStyle`, and the ring-only circle before the subtask's field on `CardStyle`, since a subtask's row exists only per stored subtask and the field is the card's.
- The card's fields are `TitleField`'s pattern with `changed` closures and `@FocusState`, a field's `changed` going only while it has the focus, since its echo after a card closes names no card and would land on the one opened since (Task 7's plain field does so); the title is focused when a card appears with an empty title, which is the view's own focus; Esc on an iPad keyboard sends `escapeKeyPressed` through `.onKeyPress(.escape)` (iOS 17); the subtask's field takes the focus back after Return, since on the Mac SwiftUI's `TextField` ends editing on a Return and the next empty field the module opens would close at once on the lost focus (Task 7's hand check; the module's "Return opens the next field"); and the hand check confirms that one Return writes one subtask: Task 7's driver's `AXConfirm` wrote it twice, `subtaskFieldSubmitted`, a late `changed` with the old text while still focused, then `subtaskFieldLostFocus`, where a real Return wrote once; a tap outside the card on the screen's background sends `backgroundTapped`. The keyboard rises with the field and the scroll view keeps the card in view, checked by hand (spec, "Risks").
- The board is a horizontal `ScrollView` with `.scrollTargetLayout()` and `.scrollTargetBehavior(.viewAligned)`, each column a vertical `ScrollView` of cards; a column's cards are the block's rows drawn in the card look, its `TaskRowModel` sized by the module for the column.
- Show as is a `Menu` from the glass "…" with `MenuItems`, which draws the disabled item and its subtitle; the canvas's own popover is not reproduced.
- Show as's "Show as" heading and the current item's check arrive here with their drawing: `MenuModel` gains a heading and `MenuModel.Item` a checked state, which Task 6's `showAs` fills (as #161 left the Mac capsule to Task 9).
- `RootView.screen(_:)` draws `.list` as `ListScreen` in the narrow layout and keeps `TaskListView`'s spot in the wide one for Task 9; the list's `.toolbar { quickEntryButton }` goes, since the screen's "+" adds inline and quick entry stays the Lists screen's (spec section 10).
- `GlassButtonModel` holds a `GlassControlStyle`, not named after its model because `GlassButtonStyle` is SwiftUI's own, and a lift is a `TaskLiftStyle` (#190). This task is the first to build both, and the table holds them per layout.
- The numbers are the canvas's (`Phone.dc.html`, 2026-11-01), carried into the module's `Metrics.phone` and `Metrics.phoneColumns` in `TaskList+Metrics.swift` as each component's style (#190: `ScreenHeaderStyle`, `TagBarStyle`, `TagChipStyle`, `BlockHeaderStyle`, `CheckStyle`, `SwipeStyle`, `TaskRowStyle`, `PillStyle`, `CardStyle`, `SubtaskRowStyle`, `AddRowStyle`, `DoneStripStyle`, `FloatingButtonStyle`, `EmptyScreenStyle` and `ColumnStyle`, each beside its model, which the table holds per layout and a builder hands to the model whole), a view reading them as `model.style` and holding none of its own:

| Part | Values |
| ---- | ------ |
| Glass buttons | 44 pt circles at the top corners, 14 pt from the edges, back chevron 24 pt stroke 2.2 set 2 pt left of centre, "…" 22 pt; a 108 pt fade of paper under them |
| Header | 20 pt side padding; tile 38 pt, radius 11, glyph 23; title `largeTitle`; subtitle `count` (14) in ink2, 6 pt under, indented 50 |
| Tag bar | 7 pt under the header; the bar 20 pt past the content's sides with its row padded 20; chips 30 pt high, padding 10 / 12, `pill` text, hash 13 pt 5 before the title, gap 6, a 44 pt tap target, fades 16 in and 28 out; lit: the list's check fill with its mark colour; unlit: fill with ink and ink2 |
| Block header | 44 pt, margins 6 6 2 12, a 1 pt rule of line under it; title `sectionTitle` in the list's glyph colour; subtitle `areaLabel` in ink2, the day's date, 8 after the title; header padding 13 8 0; chevron 18 pt in a 44 pt hit, turned −90° when folded, `fold` |
| Row | padding 0 12 0 8; check hit 44 pt, check 24 pt with a 1.75 pt ring, mark 15 pt stroke 2.8, `check`; title `rowTitle` with padding 11 4 11 2; meta `meta` in ink2, 3 pt under, gaps 3 and 10, icons 13 pt 3 before their text; struck title in ink2 with its line in ink3 |
| Swipe | threshold 40 pt leftward, the row shifts −88, `swipe`; Delete 78 pt wide, radius 12, inset 3 / 10, `barLabel` white on red |
| Lift and slot | scale 1.03, opaque, radius 14, surface, `lifted` shadow (a column's card instead dims to .35 where it is dragged from, with no indicator, since its column's tint marks the drop); the indicator 10 pt high, placed from the rows' leading edge: the circle 8 pt across, 52 after that edge, ringed 2 pt in the list's check fill and filled with the paper, which stands in for the canvas's unfilled dot, since the mark stands on the screen's paper and its line starts 2 after the dot, so the fill hides nothing; and the line 2 pt in the check fill, rounded 1, from 62 after that edge to 20 short of the right edge |
| Fresh | the `fresh` colour fading over the `fresh` motion, 1.6 s on CSS's `ease`, after a card lands |
| Card | margins 6 10 10, radius 18, surface, `raised` shadow, `cardOpens`; title field 44 pt `rowTitleEmphasized`; body padding 0 14 14 46; notes `notes` in ink2; subtask check 18 pt ring 1.5 mark 12 in a 40 × 44 hit, title `notes`; "Add subtask" 44 pt `notes` ink2 plus 17; pills 32 pt, radius 99, fill, `pill`, gap 6, 10 pt above, sun 16 flag 15 hash 14; Open full screen 19 pt in a 44 pt hit |
| Add rows | "+ Add task" 40 pt, `addRow` ink2, plus 18 in a 44 pt hit, radius 12; "+ Add list" 44 pt `barLabel` ink2 over a 1 pt rule, 4 under it, margins 10 6 0 12 |
| Board | gap 10, padding 0 16 24, snaps; column 296 pt, radius 18, fill; header padding 13 14 9; card radius 13, surface, a 0.5 pt glass line ring, the `resting` shadow; card check 22 in 42 × 44; card title `callout` size; column "+ Add task" 44 pt, radius 13, padding 11 / 12, the plus 6 before its title; "+ Add list" a 200 pt dashed column, 1.5 pt line, button 52 pt `barLabel`; drop target tinted with the list's `dropTint`, its colour at .1 / .2, and an inset 2 pt ring of its check fill |
| Done strip | padding 20 16 0 14; capsule 36 pt, radius 99, fill, `barLabel` ink2, glyph 18 in the list's glyph colour, chevron 15 turned 180° open, `fold`; its rows as the list's, struck |
| Empty state | padding 84 40 0; tile 64 pt radius 18 glyph 32; title `emptyScreenTitle`, 20 heavy rounded, 18 under the tile; text `notes` ink2, 6 under the title, 270 pt wide at most |
| Floating "+" | 48 pt accent circle, white plus 22 stroke 2.4, `raised` shadow, 16 pt from the right and 30 from the bottom |

**Tests.**

- `RowLiftTests`: as `ListsDragTests` drives `ListsDrag.after` on the host over a real module with synthetic frames: `aLongPressLiftsTheRowUnderThePoint`, `aMoveOverARowPicksTheSlotBeforeOrAfterIt`, `aMoveIntoAnotherBlockPicksItsEnd`, `aBlockThatTakesNoDropOffersNoSlot`, `aReleaseSendsOneDrop`, `aCancelDropsNothing`, `aMoveOverAColumnPicksTheColumn`.
- `DesignSystemRenderersTests` already hold the symbols; `TodoAppTests` keep passing with the screen in the stack.
- By hand on the iPhone 17 and the iPhone 17 Pro Max turned sideways, both appearances: every board of the canvas page, the card with the keyboard, the swipe, the lift and the drop, the board's snap; screenshots in the pull request.

**Verified facts and traps.**

- `RootView.screen(_:)` switches `host.model.screens[id]` and draws `.list` as `TaskListView` with `.toolbar { quickEntryButton }` (`RootView.swift:169-172`); the path binding sends `.wentBack(to:)` (`:198`).
- `ListsScreen` hides the navigation bar on iOS with `.toolbar(.hidden, for: .navigationBar)` behind `#if !os(macOS)` (`ListsScreen.swift:27-31`) and draws its bar in a bottom `safeAreaInset` over a fade (`:40-58`).
- No `.glassEffect` exists in the app; `Bar.glass(in:)` is the material fallback (`Bar.swift:175-179`); the deployment targets are iOS 17 and macOS 14 (`Apps/Apple/Package.swift:9`).
- `TodoAppleUI` compiles for watchOS 10 in CI (`ci.yml:134`): every `UIKit`, `Menu`, `contextMenu`, `onKeyPress` and `keyboardShortcut` use is fenced, as the Lists screen's are.
- The hand-check devices and the 34-shot harness are described at `docs/plans/lists-screen.md:45`, `:543`, `:596`; the harness is not in the repository and is rebuilt in the task if wanted.

### Task 9: The list pane on the Mac and the iPad

**Goal.** The same screen as the detail pane beside the sidebar on the Mac and the iPad, from the same models at the Mac's metrics: the glass back only once a block was opened, the glass capsule with "+" and "…", one click opening the card, the row's right-click menu with Delete, the pointer dragging rows, cards and a column's cards with the same slot, columns scrolling freely; the iPad with the phone's gestures (spec section 10).

**Files.** New `Apps/Apple/Sources/TodoAppleUI/ListScreen/ListPane.swift`; `Apps/Apple/Sources/TodoAppleUI/RootView.swift`, whose `wideScreen(_:)` draws `TaskListView` today and draws `ListPane` from here; `Sources/Features/TaskList/TaskList+Metrics.swift` for `Metrics.pane` and `Metrics.paneColumns` (#190); `TaskListView.swift` deleted here, Task 8 having kept it for the wide tree (R143), and `PlainField`, which Task 8 moved to `ListScreen/` and shared with it, stays; `README.md`, `CHANGELOG.md`.

**Interface.** `struct ListPane: View { init(model: TaskList.Model, send: @escaping (TaskList.UserAction) -> Void, showsBack: Bool) }`, `internal`; the module's `Metrics.pane` and `Metrics.paneColumns`, chosen by `WindowWidth.wide` and the layout.

**Rules.**

- The pane's numbers are two tables, `Metrics.pane` for the list and `Metrics.paneColumns` for the board, as the phone has `phone` and `phoneColumns`, since `Metrics.blocks` is one case and one table cannot hold both layouts; they hold the same styles and wrappers as the phone's (#190), `Metrics.of(_:)` takes the width beside the layout and picks one, and a view reads them as `model.style`; a number the Mac's canvas gives and a style has no field for is added to that component's style here, and a builder branches on no layout.
- The pane is drawn in the wide layout's detail `NavigationStack` from `RootView.splitView` (`RootView.swift:88`) by `wideScreen(_:)`; `showsBack` is false for the column's base screen and true for a list over it. The back is `model.back`, a `GlassButtonModel<UserAction>` that sends `backButtonTapped`, which the module answers `.closeRequested` after closing its card, as on the phone: every action goes through `send`, held by its control's model (the owner's review of #177, 2026-11-08). The capsule holds "+" and "…" as `Bar`'s glass does: "+" is a `GlassButtonModel<UserAction>` of its own that sends `addTaskButtonTapped`, which the module adds to its model at the pane's metrics, and "…" is `model.more`, a `GlassButtonLabelModel`, the label of `model.showAs`, a `MenuModel` that carries its heading and its checked item, drawn by `MenuItems`; there is no floating "+" in the pane. On iOS a screen that hides its navigation bar loses the edge swipe back, which `EdgeSwipeBack` (Task 8) answers for while the screen is on top and which answers `shouldBeRequiredToFailBy` so that a scroll view's pan waits for the swipe; a pane in the iPad's detail stack decides whether it needs it.
- The Mac's pointer drag and right click are this task's own: Task 8's `RowDrag.swift` is iOS alone (spike #174's y1 answer, the system's drag and drop and the system's context menu), so the Mac has neither yet. The pointer drags with `DragGesture` in the pane's named space through `.highPriorityGesture(_, including:)`, cancelled by `@GestureState`, as the sidebar's does (`ListsTree.swift:332-340`), and steps `RowLift` as Task 8 shipped it: `RowLift.after(_:from:among:frames:)` takes a `Phase` (`.began(task:block:session:at:)`, `.changed(_)`, `.ended`, `.cancelled`) and `RowLift.Frames`, the rows' frames by `BlockRowID` (a block and a task, since a task two blocks draw has a row in each), the blocks' and the columns' visible areas, in the content's own coordinates; `.began` names the task and the block it is dragged from, and a pointer drag gives a session token of its own. Task 8's views report the frames per row with `onGeometryChange` into `RowDragState`, unobserved, and the pane reuses `RowDragContent` for that or reports its own. The row's `.contextMenu { MenuItems }` holds Delete, which sends `deleteMenuItemChosen`, as it does on iPhone and the iPad; a click opens the card and Esc closes it through `.onExitCommand` on macOS (`TitleField.swift:32-35`). The iPad is y1 as the iPhone is: the system's drag and drop, the system's menu, and Task 8's swipe, chosen by `#if os(iOS)`. A lift is tied to its drag by a token the item provider carries in `suggestedName` (`RowDragSessions`), so a drag begun in another window of this app lifts nothing; what the iPad does with a drag between its windows is this task's to decide. `TaskLiftStyle.opacity` is the source's dim, .35 on a row and on a card (R173), which a pointer drag may read for its own source; the mark's colour is `Block.indicator`, not a field of `TaskLiftStyle`; and `scale` and `shadow`, which no iOS code reads, wait for the pointer drag's card.
- The board does not snap in the pane, by `Board.snaps` from the module (`Metrics.paneColumns`); the `Menu` for Show as is the system's.
- A card's entrance is `CardStyle.entrance`, an `EntranceStyle` (opacity, scale, offset, anchor, animation) that Task 8 made of the single `CardStyle.animation`; the pane's `Metrics.pane` fills it as the phone's does. A task's completing motion and a deleted row's leaving are `TaskLeavingStyle` on the row's and the card's style, the Done strip's rows come in on `DoneStripStyle.rowsEntrance`, and the count's bump is `DoneStripStyle.bump`.
- The Mac's numbers are the canvas's (`Mac.dc.html`, which predates the brainstorm's boards: it has no swipe, lift, "+ Add list" or row menu, so those take the phone's look at the pane's scale):

| Part | Values |
| ---- | ------ |
| Pane | content 780 pt wide at most, centred, padding 62 48 140; nav row 52 pt, padding 14, gap 8; back glass 34 pt chevron 19 stroke 2.2 set 1 pt left of centre; capsule 34 pt high radius 99 padding 3 with 30 × 28 items, "+" 17 stroke 2.1, a 1 × 16 divider, "…" 18 |
| Header | tile 40 pt radius 11 glyph 24; title 30 heavy rounded; subtitle 13.5 ink2 indented 52 |
| Tag bar | margins 10 −12 0 40, the row padded 12; chips 26 pt, padding 8 / 10, 12 pt text, hash 12, tap target 32; fades 12 / 24 |
| Block header | 34 pt, margins 14 0 2 4, padding 9 6 0, radius 7; title 15 heavy rounded; subtitle 12.5; chevron 15 in a 30 pt hit |
| Row | 36 pt, padding 0 10 0 4, radius 9, hover; check 18 pt ring 1.5 mark 12 in a 32 × 36 hit; title 14 in one line; meta trailing on the line, 12 medium ink2, gap 8: note 13, subtasks, tags as 20 pt capsules of fill padded 8, deadline |
| Add task | 32 pt, padding 0 12 0 4, radius 8, 13.5 medium, plus 15 in a 32 pt hit |
| Card | margins 6 0 10, radius 14; check hit 32 × 40; title field 40 pt 15 semibold; body padding 0 14 14 38; notes 13.5; subtask check 15 ring 1.5 mark 10 in a 30 pt hit, title 13.5; "Add subtask" 30 pt radius 7 13.5 plus 14; pills 26 pt gap 5 padding 8 / 10 12.5, sun 14 flag 13 hash 12 |
| Board | gap 12, padding 0 24 24, no snap; column 288 pt radius 14; header padding 11 12 7 title 14.5 subtitle 12; cards radius 10 with a hover shadow, check hit 34 × 36, title 13.5, meta 11.5 icons 12; column "+ Add task" 32 pt 13 |
| Done strip | padding 22 0 0 6; capsule 30 pt gap 7 padding 9 / 12, 13 semibold, glyph 16, chevron 13; rows 36 pt |
| Empty state | padding 90 40 0; tile 60 pt radius 17 glyph 30; title 19, 16 under the tile; text 14, 300 pt at most |

**Tests.**

- The host's `RowLiftTests` cover the pointer's reading through the same `RowLift.after` with the pane's `Frames`; `TodoAppTests` keep passing with the pane in the wide layout.
- By hand on the Mac and the iPad Pro 11-inch (M5), both appearances: the pane on a list and on a list over a list, the card, the right-click Delete, the pointer drag within a block, between blocks and between columns, the free board; the iPad's system drag, menu and swipe; and an iPhone Pro Max turned sideways, which is wide and draws this pane (R143), turned back with its path and its card as they were; screenshots in the pull request. A press on the iPhone that opens the menu and then moves is the one case the simulator cannot answer (R150), and nor can whether a still finger keeps calling the drop's delegate and a drop after a long still hold lands (R178): the iPad's device is where they are looked at.

**Verified facts and traps.**

- The wide layout is `NavigationSplitView` with `ListsSidebar` at 280 pt and a detail `NavigationStack` over `column.map(screen)` (`RootView.swift:88`); the column is never popped (`AppModule.swift:216-223`, `:362-367`).
- The Mac has no edit mode (`WindowView.hasEditMode`, `:94`); the sidebar's pointer drag starts past SwiftUI's default distance so that a click still chooses (`ListsTree.swift:332-340`), the rule the pane keeps so that one click opens the card.
- `Mac.dc.html` is in another session's scratchpad and predates the brainstorm boards (`canvas-numbers.md`, 2026-11-01); the owner's rule from the Lists screen holds the iPad to the Mac's layout with the phone's gestures (spec section 10).

## Self-review against the spec

Section by section of the spec, which task covers it.

| Spec section | Task |
| ------------ | ---- |
| 1. What the screen is | 6 (header, Show as, Logbook and Trash by their rules), 8, 9 |
| 2. Blocks | 1 (the page), 2 (the manual list; the group's row, removed by 2b), 6 (blocks, folds, a list over a list, a group's screen) |
| 3. Rows, the card, completing | 1 (the flags, the done read), 4 (the models), 7 (the card, completing, the strip), 8 |
| 4. Adding a task, a list | 2 (`createManualList`), 7 (`TaskEdit`, adding, naming) |
| 5. Columns | 6 (the layout per device, Show as), 8 (the board), 9 (no snap) |
| 6. Moving a task | 5 (the spike), 7 (`pin(tasks:)`, the reorder, the drop, deleting), 8, 9 |
| 7. The tag bar | 6 |
| 8. Today is the device's day | 1 (the weekday), 3 (the event), 6 (the formats) |
| 9. The module | 6, 7 |
| 10. The Mac and the iPad | 9 |
| 11. The design system | 4 |
| 12. What changes where | every row names a task above: the core's page, done read and manual list (1, 2, 7), the group's row removed (2b), the day (1, 3), `FeatureModule` gains nothing since the day is a value of `TodoCore` (3), `TaskList` (6, 7), `TaskScreen` untouched, `TaskViewList` (2, 3, 6), `AppModule` (3, 6), the design system (4), the Apple views (8, 9) |
| Testing, CI and the deliverable | each task's tests; the hand checks in 8 and 9; the budget re-measured in 1, 2, 6 and 7 |

Deviations and precisions, each stated where it happens and listed here for the owner's review:

1. **The group's id is derived from the list's id and the group's condition**, the distance written out, not the group's key, which is an absolute day (Task 2). The spec's "the group's key" and ADR-0004's wording are read so; a derivation from the key would make a row per date, which the owner rejected.
2. **The own section is present only for a view with a rule** and always then, so an empty list has a block to add into; the core appended it only when non-empty before (Task 1).
3. **A subtask is "done" when it is no longer open**, cancelled included, in the "2/4" of the meta line (Task 1).
4. **`.parent(nil)`, `.status([.open])` and `.trashed(false)` ask nothing** of a new or dropped task, since every task the screen adds or drags is open, at the root and out of the Trash; the spec's "a parent" that refuses is a parent task (Task 7).
5. **A drop reverses the source block's edits**, not every sibling's, since a task is drawn in the block that claims it and a task two blocks both select is drawn in both (Task 7).
6. **Adding a task in a manual list is two transactions**, the create and the pin, as a drop is several; measured, with one core call for the set as the remedy if the rereads show (Task 7).
7. **The day event's value is a type of `TodoCore`**, `DeviceDay`, since it carries a `Day` and `FeatureModule` does not import the core (Task 3); the spec's section 12 named `FeatureModule`.
8. **The subtitle rule**: a view of kind `group` reads its list's title and the day's date; any other view reads the date its When condition gives when it is `on` or `onOrBefore`, and none otherwise, so Today has its date and Upcoming none, since nothing may name a built-in (Task 6).
9. **Show as is a system `Menu`**, with `MenuModel.Item` gaining `isDisabled` and `subtitle` for the disabled Columns, not the canvas's popover (Tasks 4, 8).
10. **The back button is the root view's closure over the stack's path**, not a model of the list, since the way back is an action of the root (Task 8).
11. **The group row's stored title** is the distance in words; the command line prints it as it prints every view's title, and formats no day as "Tomorrow" itself (Task 6).
12. **The two open questions** are taken as the engineer recommended, no sixth seed and no cascade (Tasks 1 and 7); the owner may reverse either here.
13. **A group's row lives and dies with its list** (owner, 2026-11-02): both deletes take a list's groups with it, an orphan or a row with no filter reads as deleted and never as a list, and `groupView` takes the row with the derived id back whatever an older app did to it (Task 2). The spec's ADR note 2 says no screen deletes it; ADR-0004's amendment gains the sentence in Task 2's pull request, which also corrects its "the command line can" delete a group's row: the command line deletes tasks and no view (`CLI.swift:37`, `:259-270`).
14. **A group opened as a screen is no row** (owner, 2026-11-02, #182): the module derives it from its list's page and the group's key, and addresses it by the list's id and a word per grouping, `view/a/day/+1` (ADR-0004 and ADR-0009, amendments of 2026-11-02). Items 1, 11 and 13 describe the row Task 2 built and #182 removed, and item 8's "a view of kind `group`" now reads "a group's screen"; Tasks 6 and 7 above say what changed for them.
