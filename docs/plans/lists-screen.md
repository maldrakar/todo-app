# Plan: The Lists screen

- Status: Approved 2026-10-26, with the owner's word that a decision may move during implementation and be recorded in the task's pull request
- Spec: `docs/specs/lists-screen.md`, approved 2026-10-25
- Epic: #138

Written for the engineer and derived from the approved spec. The plan
fixes what the tasks are, in what order, and what each one promises to
the next. It does not carry the implementation: code appears only where
it already ran. A task section is 50 to 100 lines. Once a task ships its
section is history; a departure is stated in the task's pull request and
fixed forward into the sections that depend on it, never back into the
shipped one (`docs/process.md`, sections 6 and 7).

> Written by hand from `docs/plans/TEMPLATE.md`, its fourth use. Executed
> task by task, one sub-issue per branch and pull request, with
> superpowers:subagent-driven-development, each implementing and
> reviewing agent briefed with the spec, `docs/style.md`, ADR-0004,
> ADR-0006 and ADR-0009 with their amendments of 2026-10-25, ADR-0010,
> the task's section, and the shipped code of the tasks it depends on
> rather than their sections. The canvas is the mockup, section "Lists ·
> iteration 2" of https://claude.ai/artifact/WWLXn8c4CcV8VKHXwpMqtU; the
> numbers the Apple tasks need are carried below, read from the canvas's
> `Phone.dc.html`, `Mac.dc.html` and `Main.dc.html` on 2026-10-25, so an
> agent without the canvas has what it needs.

## Global constraints

The rules every task obeys, each with the spec section or ADR it comes
from.

- Toolchain: Swift 6.4.0 as `.swift-version` pins it, through swiftly (`export PATH="$HOME/.swiftly/bin:$PATH"`), with the wasm SDK `swift-6.4.0-RELEASE_wasm`; Xcode 27.1's toolchain is the same version (ADR-0008). A directory without the pin gets swiftly's default, which cannot import the 6.4 wasm SDK's modules: every command runs from the repository or a package inside it.
- The core is full Swift on the standard library and FoundationEssentials, built and tested with SwiftPM for the host and wasm32; no SwiftUI, Observation or Foundation proper in the root package, which the wasm32 build in CI enforces (ADR-0001). A feature target imports `TodoCore`, `FeatureModule` and the features whose routes its destination holds, and the design system's two targets when it builds a component's model, never a sibling or the root (ADR-0007, and its amendment of 2026-10-26).
- The core has three entities and no containers: an area is a view of kind `area`, never nested, never holding tasks (ADR-0004, amendment of 2026-10-25). A view's kind, colour and icon are nullable text columns and known journal fields, written at creation; a value this app does not know reads as absent, an area with a parent or a rule reads as a list, and the built-ins are ordinary views that nothing pins (spec section 2).
- A device's own UI state lives in the store's `device_state` table, outside the journal, read and written through the store and never synced; the folded branches are its first key, and a write of it reports no change set (ADR-0010).
- A module is a `final class` conforming to `FeatureModule`, its model computed from its state, `send` synchronous and never throwing, what the store refuses written into the model as a sentence (ADR-0006, `docs/style.md`). `TaskViewList` stays `Routable` with no head; its route, its destination, the window's route and its text form do not change (spec section 5).
- A dialog is the module's state and not a screen: the confirmation and the move picker are optionals of the model, never a destination, and neither survives a relaunch; edit mode is session state too (ADR-0009, amendment of 2026-10-25).
- A view holds no condition over a domain value. It may switch over three enums of its model and no others, the layout, the screens of a stack and the kind of a row, every case drawn with no `default` (`docs/style.md`, "Views"; ADR-0006, amendment of 2026-10-25). Every binding is read from the model and set only by sending an action: an alert's or a sheet's dismissal is the Cancel action of what it draws. A platform condition, `#if os(...)`, is allowed in a view where the platforms' APIs differ, each one named in a comment; a view decides nothing by the width, which the root's layout decides (navigation state spec, section 4).
- A user action names the control and the gesture, never what the module does about it (`docs/style.md`); events of the world are named for what happened.
- Everything from the store is data from outside: no trap, no recursion over data-shaped depth (`docs/style.md`). Every walk over the rows is one pass carrying the depths it has passed, as `TaskViewList.rows(of:)` walks today; an id or a depth a view sends is clamped or ignored, never trusted.
- The names the tasks add were probed on 2026-10-25 (Verified facts of Tasks 1 and 2); a name a task adds beyond these gets the same probe before it is fixed.
- The look is the canvas's; where the canvas and the spec differ, the canvas is right about the look and the spec about the behaviour (spec, introduction). The sizes in Tasks 1, 5, 7 and 8 are the canvas's; the type is text styles, whose sizes at the iPhone's default text size are the canvas's but for the large title, 34 pt against 32, and the meta, 12 against 12.5, the owner's choice on #151.
- Every merge leaves `main` working on every platform: a task that changes a module's model or actions adapts `Apps/Apple` in the same pull request, minimally where the look is a later task's (Tasks 5 and 6), and starts the macOS job from the Actions tab on its branch before asking for the merge (`docs/process.md`, section 10).
- Tests are swift-testing. A module test opens `makeStore` with the test clock, sends events and compares the model whole. The root package's suite runs green on the host with `swift test` and on wasm32 with `swift test --swift-sdk swift-6.4.0-RELEASE_wasm --disable-xctest`, and `scripts/wasm-size.sh` passes, before every PR; the budget is re-measured where the probe's code moves (Tasks 5 and 6).
- `Apps/Apple` is built and tested from its directory with the pinned toolchain, and each screen is checked by hand in the iOS 26.3 simulator on an iPhone 17, an iPhone 17 Pro Max turned sideways and an iPad Pro 11-inch (M5), and on the Mac, in both appearances, with screenshots in the pull request (spec, "Testing").
- Branch per task `<type>/<issue>-<slug>`, PR title in Conventional Commits with scope `core` or `apple`, body per template, `Closes #<sub-issue>`; squash merge; one line under `[Unreleased]` in `CHANGELOG.md` per task; commits end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Everything in English, and a string a person reads is English until the formatting service arrives. No `TODO` without a linked issue.

## File map

| File | Task | Holds |
| ---- | ---- | ----- |
| `Package.swift`, `Sources/DesignSystem/DesignSystem.swift` | 1 | the `DesignSystem` and `DesignSystemComponents` targets, their products and their tests; the enum every type of the design system is nested in |
| `Sources/DesignSystem/Color.swift`, `ListColor.swift` | 1 | `RGB`, and `Color` with the named colours as its static members, a shade per appearance; the eleven list colours by the store's names, each with its base |
| `Sources/DesignSystem/Font.swift`, `Animation.swift`, `Icon.swift` | 1 | the fonts as text styles; the animations, each a curve, a duration and a delay; the icons by the names the store keeps |
| `Sources/DesignSystemComponents/TileModel.swift` | 1 | a list's tile: the sizes its caller gives, its tile and glyph by the shade rule, stone's for no colour, and its glyph's icon and weight |
| `Tests/DesignSystemTests/ColorTests.swift`, `ListColorTests.swift`, `FontTests.swift`, `AnimationTests.swift`, `IconTests.swift`, `Tests/DesignSystemComponentsTests/TileModelTests.swift` | 1 | the mix and the accent soft, the list colours against the store's, the four row titles, the delay, the store's icon names and unknown ones; the tile against the canvas, and the sizes it carries |
| `Apps/Apple/Package.swift`, `Apps/Apple/Sources/TodoAppleUI/DesignSystem/Color+DesignSystem.swift`, `Font+DesignSystem.swift`, `Animation+DesignSystem.swift`, `Image+DesignSystem.swift`, `ListTile.swift` | 1 | the dependencies on `DesignSystem` and `DesignSystemComponents`; the renderers, a `Color` that follows the appearance, a text-style `Font`, an `Animation` with its delay and an icon's SF Symbol with the default; the tile view, drawn from a `TileModel` |
| `Apps/Apple/Tests/TodoAppleUITests/DesignSystemRenderersTests.swift` | 1 | each renderer, and that every icon's symbol exists on the system |
| `Sources/TodoCore/Model/TaskView.swift` | 2 | `TaskViewKind`, `TaskViewColor`, the three fields, `NewTaskView`'s three parameters, the seed's tiles |
| `Sources/TodoCore/Storage/Schema.swift`, `Migrations.swift` | 2 | `version5` |
| `Sources/TodoCore/Storage/JournalOperation.swift` | 2 | the three fields in `FieldMap` |
| `Sources/TodoCore/Storage/Store+Views.swift` | 2, 3 | the three fields written, read and refused (2); `delete(viewTree:)` (3) |
| `Sources/TodoCore/Storage/Store+DeviceState.swift` | 2 | `deviceState(_:)`, `setDeviceState(_:_:)` |
| `Sources/TodoCore/Query/Store+Counts.swift` | 3 | `taskCounts(today:)` and its statement |
| `Tests/TodoCoreTests/ViewTests.swift`, `StoreOpenTests.swift`, `FieldMapTests.swift` | 2, 3 | the fields, the migration, the tree delete |
| `Tests/TodoCoreTests/DeviceStateTests.swift`, `CountTests.swift` | 2, 3 | new |
| `Package.swift` | 5 | `TaskViewListFeature` depends on `DesignSystem` and `DesignSystemComponents`, and so do `TaskViewListFeatureTests`, which spell `TileModel(…)` and compare `DesignSystem.Font`, and `AppFeatureTests`, which compare the sidebar's tiles; the feature targets' comment says when a feature imports the two |
| `Sources/Features/TaskViewList/TaskViewList.swift` | 5, 6 | the module's events |
| `Sources/Features/TaskViewList/TaskViewList+Model.swift` | 5, 6 | `Model` and its nested types |
| `Sources/Features/TaskViewList/TaskViewList+Rows.swift` | 5, 6 | the walk from the store's tree to the drawn rows, and each list row's tile and title font (5); the root rule and the drop's reading (6) |
| `Sources/Features/App/AppModule.swift` | 5 | reacts to `newTaskRequested`; hands the sidebar the window's width class |
| `Tests/TaskViewListFeatureTests/TaskViewListTests.swift`, `TaskViewListRowsTests.swift`, `TaskViewListEditsTests.swift` | 5, 6 | adapted; the rows; the edits |
| `Tests/AppFeatureTests/AppModuleTests.swift` | 5, 6 | quick entry from the sidebar and the sidebar's tiles following the width; the open list deleted |
| `Sources/WasmSizeProbe/main.swift`, `scripts/wasm-size.sh` | 5, 6 | the probe drives the new actions; the budget re-measured |
| `Apps/Apple/Sources/TodoAppleUI/TaskViewListView.swift` | 5, 6, 8 | adapted to the model (5, 6); deleted (8) |
| `Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsScreen.swift`, `ListRowView.swift`, `AreaLine.swift`, `ListsBottomBar.swift`, `MovePickerSheet.swift`, `ListsDragGesture.swift` | 7 | the phone's screen, rows, lines, bar, picker and drag |
| `Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsSidebar.swift` | 8 | the Mac's and the iPad's sidebar |
| `Apps/Apple/Sources/TodoAppleUI/RootView.swift` | 7, 8 | the narrow tree draws the screen (7), the wide tree the sidebar (8) |
| `Apps/Apple/Tests/TodoAppleUITests/TodoAppTests.swift` | 5, 6 | the model's new shape |
| `README.md`, `CHANGELOG.md` | every task | the changelog line; the README where behaviour a person sees changes (7, 8) |

## Tasks

| # | Issue | Title | Labels | Depends on |
| - | ----- | ----- | ------ | ---------- |
| 1 | #142 | The design foundations in `TodoAppleUI` | `feature`, `ui-apple` | 2 |
| 2 | #143 | A view's kind, colour and icon, and the device's own state | `feature`, `core` | |
| 3 | #144 | Counts and the tree delete | `feature`, `core` | 2 |
| 4 | #145 | Spike: the drag with a change of depth on iPhone and iPad | `spike`, `ui-apple` | |
| 5 | #146 | The module's rows: kinds, tiles, counts, folds, areas, new list and area | `feature`, `core`, `ui-apple` | 2, 3 |
| 6 | #147 | The module's edits: edit mode, delete, Move to… and the drop | `feature`, `core`, `ui-apple` | 5 |
| 7 | #148 | The Lists screen on iPhone | `feature`, `ui-apple` | 1, 4, 6 |
| 8 | #149 | The sidebar on the Mac and the iPad | `feature`, `ui-apple` | 7 |

The owner reviews this table and the interface of every task below.

The split leaves `main` working after every merge. Tasks 1 to 4 touch no
screen, and all but Task 1, whose test holds its list colours to Task 2's
`TaskViewColor`, can run beside each other. Tasks 5 and 6 change the module's
model and actions, so each adapts `TaskViewListView` in the same pull
request just far enough that the app compiles and works, with today's
look; the look arrives in Task 7 for the phone and in Task 8 for the Mac
and the iPad, where the adapted view goes. Task 4 answers the one
question the spec names as a risk before Task 7 builds on it.

### Task 1: The design foundations in `TodoAppleUI`

**Goal.** The canvas's foundations exist in `TodoAppleUI` for every screen after this one: the palette with a shade per appearance, the accent, the eleven list colours with their tile and glyph shades, the tile view, the icon set, the type and the motion constants (spec section 9). Nothing on screen changes in this task; Tasks 7 and 8 are the callers, which the pull request says (`docs/style.md`, "No API without a caller").

**Files.** New `Apps/Apple/Sources/TodoAppleUI/Foundations/Palette.swift`, `ListColorShades.swift`, `ListTile.swift`, `IconSet.swift`, `Typography.swift`, `Motion.swift`; `Apps/Apple/Tests/TodoAppleUITests/FoundationsTests.swift`; `CHANGELOG.md`.

**Interface.** Everything is `internal` to `TodoAppleUI`.

```swift
enum Palette {
    static let paper, surface, sidebar, fill, line, ink, ink2, ink3, red, accent, accentSoft: Color
    /// One Color that resolves to the light or the dark shade with the appearance; the one platform condition here.
    static func dynamic(light: RGB, dark: RGB) -> Color
}
struct RGB: Equatable { let red, green, blue: Double; let opacity: Double
    init(hex: UInt32, opacity: Double = 1)
    func mixed(toward other: RGB, by amount: Double) -> RGB
}
struct ListColorShades: Equatable { let tile: Color; let glyph: Color
    static let byName: [TaskViewColor: ListColorShades]   // all eleven
    static let none: ListColorShades                      // a list with no colour
    static func shades(of color: TaskViewColor?) -> ListColorShades
    static func tile(_ base: RGB, dark: Bool) -> RGB      // the canvas's rule, tested
    static func glyph(_ base: RGB, dark: Bool) -> RGB
}
struct ListTile: View { init(color: TaskViewColor?, icon: String?, size: CGFloat, radius: CGFloat, glyph: CGFloat) }
enum IconSet { static func symbol(_ name: String?) -> String }
enum Typography {
    static let largeTitle, sectionTitle, meta, count: Font
    static func rowTitle(depth: Int, hasChildren: Bool) -> Font
}
enum Motion {
    static let check, rowLeaves, pushPop, popover, quickEntry: Animation
    static let rowLeavesAfter: Duration
}
```

**Rules.**

- The palette, light and dark (`Phone.dc.html`, `Main.dc.html`): paper `#FAF7F2` / `#1A1917`; surface `#FFFFFF` / `#24221F`; sidebar `#F2EDE5` / `#1F1E1B`; fill `#F0EBE3` / `#2E2B27`; line `#E8E2D8` / `#35322D`; ink `#1F1D1A` / `#EEEAE3`; ink2 `#625C53` / `#ABA498`; ink3 `#A39C90` / `#6F6A62`; red `#C2362B` / `#F07468`; accent `#3653C9` in both; accent soft `#E7EAF9` light, and in the dark the accent at 24 % over the paper.
- The eleven list colours' base hex (`Phone.dc.html`, `COLORS`): blue `#3E6EC5`, amber `#D49408`, rose `#D2455A`, green `#36925C`, stone `#8A847A`, indigo `#5B55D8`, teal `#168985`, pink `#C64C88`, orange `#D7652C`, violet `#8452C8`, sky `#2A86B9`. The shades are the canvas's `paint` rule and not eleven more literals: the tile is the base at 15 % opacity in the light and 24 % in the dark; the glyph is the base mixed 20 % toward the ink `#1F1D1A` in the light and 30 % toward white in the dark. A list with no colour draws stone's shades.
- The tile: a rounded square of the tile shade with the glyph in the glyph shade, sizes the caller's: on the phone 30 pt, radius 8, glyph 19 at the root and 26, 7, 16 nested (`Phone.dc.html`, `tileSize`); in the sidebar 20, 6, 13 (the Mac board's 30 pt row).
- The icon set is the canvas's names to SF Symbols: tray `tray`, sun `sun.max`, calendar `calendar`, week `calendar.badge.clock`, logbook `text.book.closed`, trash `trash`, briefcase `briefcase`, house `house`, hourglass `hourglass`, pen `pencil`, bag `bag`, wrench `wrench`, book `book`, folder `folder`, list `checklist`; nil and any other name draw `list.bullet`. The implementer checks each symbol exists on iOS 17 and macOS 14 in the SF Symbols app, since a missing one draws nothing and says nothing.
- Type (`Main.dc.html`): large title rounded 32 heavy; section title rounded 17 heavy; a row's title 17 at the root and 16 nested, semibold when the row has children and regular otherwise; meta 12.5 medium; count 15 regular. Rounded is `.system(size:weight:design: .rounded)`; the rest is the system face.
- Motion (`Main.dc.html`): check, a spring of 0.45 s; a done row leaves over 0.32 s ease-in, 0.7 s after; push and pop 0.32 s on the curve (.2, .8, .2, 1); popover, a spring of 0.2 s; quick entry, a spring of 0.42 s. Reduce Motion is the views' to honour by reading `accessibilityReduceMotion` and passing `nil`.
- `Palette.dynamic` is the foundations' one platform condition: `UIColor(dynamicProvider:)` where UIKit is imported and `NSColor(name:dynamicProvider:)` on the Mac, each noted. On watchOS, where there is no light appearance, the dark shade stands if the provider is unavailable there; the file is typechecked for watchOS 10 before the PR.

**Tests.**

- `everyListColourHasItsShades`: `byName` holds a shade for every case of `TaskViewColor`.
- `aListWithNoColourDrawsStonesShades`.
- `theLightGlyphOfBlueIsTheCanvassBlue`: `glyph(RGB(hex: 0x3E6EC5), dark: false)` is `#385EA3` within one unit per channel, the number `Main.dc.html` shows for the Inbox's glyph, so the rule is the canvas's.
- `theDarkTileIsTheBaseAtTwentyFourPercent`.
- `anUnknownIconNameAndNoNameDrawTheDefaultGlyph`, `theFiveBuiltInIconsResolve`.
- `rowTitleIsHeavierWithChildrenAndSmallerNested`.

**Verified facts and traps.**

- 2026-10-25, Xcode 27.1 (swiftlang-6.4.0.34.1): `Palette`, `ListColorShades`, `ListTile`, `IconSet`, `Typography`, `Motion`, `ListsBottomBar`, `AreaLine`, `MovePickerSheet` and `ListRowView`, each alone in a file importing SwiftUI, Foundation and Observation, are unresolved for macOS 14, iOS 17 and watchOS 10, so free. `RGB` is nested or probed the same way before it is fixed.
- The numbers above were read from the canvas on 2026-10-25; the mix for blue, 0.8 × #3E6EC5 + 0.2 × #1F1D1A, comes out at #385EA3, the glyph `Main.dc.html` draws.
- Trap: `Color(_:)` from a hex is a literal with no appearance; only the dynamic helper follows the theme. A colour defined once per appearance in a view would be a condition in the view.

### Task 2: A view's kind, colour and icon, and the device's own state

**Goal.** The core's view carries a kind, a colour and an icon, written at creation, read by the spec's rules and refused where the spec refuses them; the built-ins wear the canvas's tiles; the store keeps a device's own state in `device_state`; schema version 5 carries both (spec sections 2 and 5; ADR-0004 amendment; ADR-0010).

**Files.** `Sources/TodoCore/Model/TaskView.swift`; `Sources/TodoCore/Storage/Schema.swift`, `Migrations.swift`, `JournalOperation.swift`, `Store+Views.swift`, new `Store+DeviceState.swift`; `Tests/TodoCoreTests/ViewTests.swift`, `StoreOpenTests.swift`, new `DeviceStateTests.swift`; `CHANGELOG.md`.

**Interface.**

```swift
public enum TaskViewKind: String, Equatable, Sendable { case list, area }
public enum TaskViewColor: String, Equatable, Sendable, CaseIterable {
    case blue, amber, rose, green, stone, indigo, teal, pink, orange, violet, sky
}
public struct TaskView {  // beside its fields of today
    public let kind: TaskViewKind
    public let color: TaskViewColor?
    public let icon: String?
}
public struct NewTaskView {
    public init(title: String, parent: ViewID? = nil, kind: TaskViewKind = .list, color: TaskViewColor? = nil,
                icon: String? = nil, filter: Filter? = nil, sort: [SortKey] = [], groupBy: GroupBy? = nil)
}
extension Store {
    public func deviceState(_ key: String) throws(StoreError) -> String?
    public func setDeviceState(_ key: String, _ value: String?) throws(StoreError)   // nil removes the row
}
// Schema.version5; Migrations.steps gains (5, Schema.version5). TaskViewChange gains no case: nothing calls one.
```

**Rules.**

- Version 5 is one step: `ALTER TABLE views ADD COLUMN kind TEXT`, `color TEXT`, `icon TEXT`, and `CREATE TABLE device_state (key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID`. `FieldMap.known[.view]` and `nullable[.view]` gain the three names, since `FieldMapTests` walks `PRAGMA table_info` and holds the map to the schema.
- `createView` writes the three fields in the same transaction as the rest, absent as null. It refuses an area under a parent with `.invalid("an area cannot be nested")` and an area with a filter with `.invalid("an area has no rule")`. `move(view:to:at:)` refuses an area moved under anything with the first sentence; it reads the kind where it reads the row.
- Reading, in `views()`: the kind column `"area"` reads as `.area` only when the effective parent is nil and the filter column is null, and as `.list` otherwise; any other text or null reads as `.list`; the colour reads through `TaskViewColor(rawValue:)` and anything else as nil; the icon reads as its text or nil. A view written before this version reads as a plain list (spec section 2).
- The seed gives the built-ins their tiles at clock zero: Inbox blue and `tray`, Today amber and `sun`, Upcoming rose and `calendar`, Logbook green and `logbook`, Trash stone and `trash`, eleven fields per view, so a store opened by this version shows the tiles at once and a person's later choice outranks them as a rename does.
- `deviceState` and `setDeviceState` are an upsert and a delete on the table inside `sql`, never journaled, never reported through `onChange`, never seen by `receive`; `snapshot()` carries the table, since it is the file's (ADR-0010).

**Tests.**

- `ViewTests`: `aViewCarriesItsKindColourAndIcon`; `anAreaIsNeverNestedAndHasNoRule`, the three refusals and the tree unchanged; `anAreaThatArrivesNestedReadsAsAList`, from operations applied with a parent; `anAreaWithARuleReadsAsAList`; `anUnknownKindOrColourReadsAsAbsent`, from operations with `cabinet` and `mauve`; `aViewMadeBeforeTheFieldsReadsAsAPlainList`; `builtInViewsAreSeededOnceAndUserEditsSurviveReopen` now expects 55 seed operations and checks the Inbox's colour and icon.
- `StoreOpenTests`: `freshStoreIsAtTheCurrentSchemaVersionWithAllTables` lists `device_state`; `aStoreAtVersionFourGainsTheColumnsAndTheTable`, from a snapshot taken at version 4 as `aStoreAtAnEarlierVersionMigratesTheRestOfTheWay` takes one.
- `DeviceStateTests`: `deviceStateRoundTripsAndNilRemovesTheRow`; `aDeviceStateWriteReportsNoChangeAndJournalsNothing`, `onChange` not called and the operations count unchanged; `deviceStateSurvivesASnapshot`.

**Verified facts and traps.**

- 2026-10-25: `TaskViewKind` and `TaskViewColor` are unresolved in a file importing SwiftUI, Foundation and Observation for macOS 14, iOS 17 and watchOS 10 (Task 1's probe), so free; both carry the `TaskView` prefix the core's exported names carry (`docs/style.md`).
- `ViewTests` counts 40 seed operations today, eight fields for five views; with the three fields it is 55.
- `applyToState` refuses a null for a column the map says is NOT NULL and applies one for a nullable column: the three are nullable, so an older device's null applies and nothing is refused.
- Trap: the generated `title_fold` columns are `VIRTUAL` and absent from `PRAGMA table_info`; the three new columns are real and the map must name them, or `FieldMapTests` fails.

### Task 3: Counts and the tree delete

**Goal.** The store answers every view's count of open tasks in one call, a folder as the union of its children, and deletes a list with everything under it in one transaction (spec sections 4 and 6).

**Files.** `Sources/TodoCore/Storage/Store+Views.swift`; new `Sources/TodoCore/Query/Store+Counts.swift`; `Tests/TodoCoreTests/ViewTests.swift`, new `CountTests.swift`; `CHANGELOG.md`.

**Interface.** Consumes Task 2's `TaskView.kind`.

```swift
extension Store {
    public func delete(viewTree id: ViewID) throws(StoreError)
    /// A count for every view that has one; absent for an area, a view this app cannot read, and a folder with nothing to count.
    public func taskCounts(today: Day) throws(StoreError) -> [ViewID: Int]
    static func countStatement(where fragment: String) -> String   // beside `viewStatement`, for the plan test
}
```

**Rules.**

- `delete(viewTree:)` requires the view, takes its ids from `views()` in tree order, the view and the rows after it with a greater depth until one with a depth not greater, one pass and no recursion, and applies one `deleted = true` operation per id under one stamp in one `apply`, which is one transaction. The tasks are untouched; the manual lists stop being read as today.
- `taskCounts(today:)` reads `views()` once and builds one SQL fragment per view from the leaves up, in one pass over the tree order reversed: a view with a filter has `FilterCompiler.compile(filter, today:)`; a list with no filter has the disjunction of its children's fragments, a child with none contributing nothing, and none when no child has one; an area has none; a view with `needsNewerApp` has none and contributes nothing. Each fragment is text built from the children's text, so the depth of the tree is the depth of the expression and never of the call stack.
- One statement per view with a fragment: `SELECT count(*) FROM tasks t JOIN task_tree tt ON tt.id = t.id WHERE t.deleted = 0 AND t.status = 0 AND tt.trashed = 0 AND (<fragment>)`, assembled by `countStatement`. `compile` and not `whereClause`: the count carries its own trashed and status conditions, so that Trash and Logbook count nothing. A zero is present as 0; a view with no fragment is absent.
- The cost is measured in a release build at 50,000 tasks, the number in the pull request (spec, "Risks"): the remedy, should it show, is one statement over all views, and is not built here.

**Tests.**

- `CountTests`: `aListCountsTheOpenTasksItsRuleSelects`, two open and one done in the Inbox; `logbookAndTrashCountNothing`; `aFolderCountsTheUnionOfItsChildrenOnce`, two children whose rules share a task; `aFolderOfFoldersCountsItsGrandchildren`; `aViewTheAppCannotReadCountsNothingAndContributesNothing`; `anAreaHasNoCountAndItsListsHaveTheirs`; `anEmptyFolderHasNoCount`; `theCountStatementUsesTheIndexes`, by `EXPLAIN QUERY PLAN` over `countStatement` as `builtInViewsUseIndexes` explains `viewStatement`.
- `ViewTests`: `deletingATreeTombstonesEveryViewUnderItInOneTransaction`, the lists gone, nothing surfaced at the root, the operations under one stamp; `deletingATreeLeavesTheTasks`.

**Verified facts and traps.**

- `apply(_:)` wraps `applyRows` in `db.transaction`, so one `apply` is one transaction (`Store+Apply.swift`).
- `FilterCompiler.whereClause` appends `tt.trashed = 0` only when the filter does not mention trash; a count built on it would count the Trash's tasks. `compile` yields the bare fragment over `tasks t JOIN task_tree tt`.
- `Package.swift` builds SQLite with `SQLITE_MAX_EXPR_DEPTH` 0, so a deep folder chain's expression is not refused by depth.

### Task 4: Spike: the drag with a change of depth on iPhone and iPad

**Goal.** An answer to the spec's first risk before Task 7 builds on it: whether a row can be lifted and dropped after another row at a depth the finger chooses, with the slot drawn at that depth and the tree scrolling sideways past a depth while the counts stay at the right, in SwiftUI on iOS 17, and with what. The answer goes into the issue with the limits of what worked; the code is a throwaway and ships nothing.

**Files.** None in the repository; a throwaway app in the session's scratchpad. The issue carries the answer and a short recording from the simulator.

**Interface.** Produces the shape Task 7 builds `ListsDragGesture` on: a gesture over the rows that reports `(after: ViewID?, depth: Int)` on release, with the depth bounded by the row below's depth and the row above's depth plus one.

**Rules.**

- Three approaches, tried in order until one meets the goal: a `List` with `onMove` for the order and a horizontal `DragGesture` on the lifted row for the depth, the slot drawn by the row itself; a `ScrollView` of a `LazyVStack` with a long press that becomes a drag, hit-testing by row frames collected through a preference, the slot a row of its own; and `UICollectionView` with its drag and drop delegate in a representable.
- What each has to show: the lift (scale 1.03, a tilt of −1.5°, the canvas), the slot dashed at the chosen depth, 52 pt high, the depth bounded as above, the drop reported once, and the sideways scroll with the counts pinned, on an iPhone 17 and an iPad Pro 11-inch (M5) in the iOS 26.3 simulator.
- The fallback the spec names, a drag that changes the order alone with Move to… for the depth, is the answer if none of the three works within the day the spike is given; the owner decides in chat whether that ships (spec, "Risks").

**Tests.** None; a spike.

**Verified facts and traps.**

- SwiftUI's `List` moves a row up and down a flat list and knows nothing of depth (spec section 7); the Mac's `List` cannot drop its own highlight (`TaskViewListView`).
- Trap: a horizontal `ScrollView` around the rows takes the list's own gestures (spec, "Risks"): the sideways scroll and the drag have to share one gesture recognizer or the rows.

### Task 5: The module's rows: kinds, tiles, counts, folds, areas, new list and area

**Goal.** `TaskViewList` draws rows of two kinds with tiles, counts and folds remembered per device, areas with optional names, makes lists and areas where the spec says, and asks the root for quick entry; the Apple view adapts to the model so that the app keeps working, with the look left to Task 7 (spec sections 1, 3, 4, 5 and 6).

**Files.** `Package.swift`; `Sources/Features/TaskViewList/TaskViewList.swift`, new `TaskViewList+Model.swift`, `TaskViewList+Rows.swift`; `Sources/Features/App/AppModule.swift`; `Tests/TaskViewListFeatureTests/TaskViewListTests.swift`, new `TaskViewListRowsTests.swift`; `Tests/AppFeatureTests/AppModuleTests.swift`; `Sources/WasmSizeProbe/main.swift`, `scripts/wasm-size.sh`; `Apps/Apple/Sources/TodoAppleUI/TaskViewListView.swift`; `Apps/Apple/Tests/TodoAppleUITests/TodoAppTests.swift`; `CHANGELOG.md`; ADR-0007 if the width's type goes into `FeatureModule` (Interface).

**Interface.** Consumes Task 2's fields and Task 3's `taskCounts(today:)`. Produces:

```swift
extension TaskViewList {
    public struct Model: Equatable, Sendable {
        public struct Row: Equatable, Sendable, Identifiable {
            public let id: ViewID
            public let depth: Int          // the drawn depth: an area's lists at 0, their lists at 1
            public let kind: Kind
            public let draft: String?
        }
        public enum Kind: Equatable, Sendable {
            case area(label: String?)      // nil for an unnamed area outside edit mode
            case list(ListRow)
        }
        public struct ListRow: Equatable, Sendable {
            public let title: String
            public let tile: TileModel                // built for the window's width class (Rules)
            public let titleFont: DesignSystem.Font   // chosen by the width, the drawn depth and the children
            public let countText: String              // "" for zero and for a view with no count
            public let hasChildren: Bool
            public let isCollapsed: Bool
            public let isSelected: Bool
        }
        public let rows: [Row]
        public let selection: ViewID?
        public let problem: String?
    }
    // init(store:route:) gains width:, the window's width class, with no default, as the root's own init has it;
    // Event gains widthChanged(_:), an event of the world. The width's type is one both the root and this module can
    // name, since a child never imports the root (ADR-0007): a type in FeatureModule that AppModule.Width becomes,
    // which then joins ADR-0007's list of that target's contents and the target's comment in Package.swift, or this
    // module's own, onto which the root maps its own. The pull request picks one and says why.
    // UserAction gains disclosureTapped(ViewID), newListMenuItemChosen(in: ViewID?), newAreaMenuItemChosen,
    // newTaskMenuItemChosen, and loses createFolderButtonTapped. Output gains newTaskRequested.
}
// AppModule: init hands the sidebar the width the window is made with, and .widthChanged hands it the new width
// besides moving the layout. react(to: TaskViewList.Output) gains the arm for .newTaskRequested, which opens quick
// entry as quickEntryButtonTapped does and leaves the root's sentence, since the gesture is the sidebar's.
```

**Rules.**

- The walk (`TaskViewList+Rows.swift`) is one pass over `views()`: each read row keeps the id, the title, the kind, the colour, the icon, the parent, the tree depth, whether it has children, and the drawn depth, one less than the tree depth under an area. A row under a collapsed ancestor is left out: the walk carries the depth below which rows are hidden, and clears it when a row at or above that depth arrives. The store reads a nested area as a list, so the walk never meets one.
- A list row's tile and title font are the Lists screen's layout, built in `TaskViewList+Rows.swift` from the read row and the width the module holds whenever the model is computed (ADR-0007, amendment of 2026-10-26). The colour is `DesignSystem.ListColor(rawValue:)` of the `TaskViewColor`'s raw value and the icon `DesignSystem.Icon(rawValue:)` of its text, a name either does not know reading as no colour, drawn as stone's, or no icon. The sizes are constants cited to the canvas: narrow, side 30, radius 8 and glyph 19 at drawn depth 0 and 26, 7 and 16 deeper (`Phone.dc.html`, `tileSize`); wide, 20, 6 and 13 for every row (`Mac.dc.html`, the 30 pt row). The title, narrow, is `.rowTitle` at drawn depth 0 and `.nestedRowTitle` deeper, and wide `.rowTitle` at every depth, the body being the system's sidebar size, 13 pt on the Mac and 17 on the iPad; each is `Emphasized` when the row has children. `widthChanged` moves the width alone, so the tiles follow it with no read of the store.
- `countText` is the count's decimal for a count above zero and `""` otherwise; an area's line has none. The counts come from `taskCounts(today:)` beside every read of the rows, with `today` the UTC day of `Store.systemNow()`, as the task list reads it; one `reread` reads both and throws as today's does.
- `.changed`: a change naming a view rereads rows and counts; one naming only tasks or tags rereads the counts alone; a draft and the sentence stay, since a change answers nobody (spec section 4).
- The folds are the device's (ADR-0010, amendment of 2026-10-26): `init` reads `deviceState("taskViewList.collapsed", as: [String].self)`, the folded ids' raw values, dropping anything that does not read as an id or that no row holds; `disclosureTapped` on a row with children toggles it and writes the set back the same way, an empty list when nothing is folded; on a leaf or an area's line it moves nothing. A write of the device state that fails leaves the fold on screen and says nothing, the engineer's call (Self-review).
- `newListMenuItemChosen(in:)` creates `NewTaskView(title: "New list", parent:, kind: .list, color:, icon: "list")` at `.end`: under the list named, with that list's colour; under the area named, with none; with nil, in the last area of the root, or at the root's end when there is no area, with none (spec section 3). Then the parent is unfolded and written, the rows reread, and the field opens on the new row with its title as the draft, on a row the reread holds, as `createFolder` does today. The new list is not declared over the sidebar: the highlight stays where it was (Self-review).
- `newAreaMenuItemChosen` creates `NewTaskView(title: "", kind: .area)` at the root's `.end` and opens the field on its line with the empty draft; `commit` accepts the empty title for an area and refuses it for a list with today's sentence (spec section 3).
- `newTaskMenuItemChosen` answers `.newTaskRequested` and moves nothing.
- `rowSelected` and `openInNewWindowMenuItemChosen` on an area's line move nothing, since an area never opens; `renameMenuItemChosen` on it opens the field with its name. `Kind.area(label:)` is the title when it is not empty and nil otherwise.
- `TaskViewListView` adapts and no more: one switch over `kind`, a line as a `Divider` with its label beside it, a list as today's row; the toolbar's New Folder becomes New List sending `newListMenuItemChosen(in: nil)`; the wasm probe drives the four new actions, its width change now reaches the sidebar, and the budget is re-measured with the two design targets the sidebar links.

**Tests.**

- `theRowsCarryTheirKindTileAndCount`: in a narrow window the built-ins' tiles, the Inbox's `TileModel(color: .blue, icon: .tray, side: 30, cornerRadius: 8, glyphSize: 19)`, Inbox counting two open tasks and Logbook `""`; a list made with an icon this app does not know has a tile with no icon.
- `aWideWindowsRowsCarryTheSidebarsTiles`: made wide, every row's tile is 20, 6 and 13 at any depth; `widthChanged(.narrow)` gives the narrow sizes by drawn depth, and a view written with no change sent stays out of the rows; `AppModuleTests.theSidebarsTilesFollowTheWindowsWidth`, a root made narrow and told wide.
- `aRowsTitleFontFollowsItsDepthAndChildren`: narrow, a root list with children and a root leaf, a nested parent and a nested leaf take the four fonts, and an area's list at drawn depth 0 the root's; wide, the nested rows take the root's two.
- `anAreaIsALineAndItsListsStandAtTheRootsDepth`: an area with two lists, one nested, at depths 0, 0, 1; a named line's label; an unnamed line's nil.
- `aFoldHidesTheBranchAndIsReadBackByAModuleMadeAnew`; `aFoldOnALeafOrALineMovesNothing`; `aFoldOnAnIdNoRowHoldsIsDropped`, from a stale device state.
- `newListFromPlusGoesIntoTheLastAreaOrToTheEndOfTheRoot`; `newListFromAListsMenuGoesInsideItWithItsColourAndUnfoldsIt`; `newListInAnAreaHasNoColour`; `aNewListOpensItsFieldAndDeclaresNoList`.
- `aNewAreaGoesToTheEndOfTheRootWithItsNameFieldOpen`; `anAreaAcceptsTheEmptyNameAndAListRefusesIt`.
- `aTapOrOpenInNewWindowOnAnAreasLineMovesNothing`.
- `newTaskAsksTheRootForQuickEntry`; `AppModuleTests.theSidebarsNewTaskRequestOpensQuickEntry`.
- `aChangeToATaskRereadsTheCountsAndNotTheRows`: the count moves, a draft survives.
- Every existing sidebar test reads titles through one helper of the test file over `kind`.

**Verified facts and traps.**

- `createFolder` declares the new folder's list today, which on a narrow window pushes the list over the sidebar while the name field is open: the reason the new list declares nothing.
- `Day(millisSinceEpoch:)` is `package`, callable from the feature; `TaskList.rows(of:in:)` reads today the same way.
- Trap: a `TextField` writes the text it holds back through its binding twice per keystroke (`TaskViewList`); the area's field goes through the same `titleFieldChanged` rule, a text equal to the draft moving nothing.
- Trap: the model's `Row` loses `title` and `isSelected`; `TodoAppTests` and the probe read them through `kind`.
- The root reaches the sidebar only through `state.stack.send(_:)`, which walks the stack after every event (`ScreenStack`, 2026-10-26): `widthChanged` leaves the destination alone, so the walk after it moves nothing. The probe sends `.widthChanged(.narrow)` to the root already (`main.swift`).

### Task 6: The module's edits: edit mode, delete, Move to… and the drop

**Goal.** Edit mode, the confirmation and what it deletes, the move picker, and the drop read into a parent and a placement, all in the module; the Apple view adapts to the model with the look left to Task 7 (spec sections 3, 5, 6 and 7).

**Files.** `Sources/Features/TaskViewList/TaskViewList.swift`, `TaskViewList+Model.swift`, `TaskViewList+Rows.swift`; `Tests/TaskViewListFeatureTests/TaskViewListTests.swift`, new `TaskViewListEditsTests.swift`; `Tests/AppFeatureTests/AppModuleTests.swift`; `Sources/WasmSizeProbe/main.swift`, `scripts/wasm-size.sh`; `Apps/Apple/Sources/TodoAppleUI/TaskViewListView.swift`; `Apps/Apple/Tests/TodoAppleUITests/TodoAppTests.swift`; `CHANGELOG.md`.

**Interface.** Consumes Task 5's model and Task 3's `delete(viewTree:)`. Produces:

```swift
extension TaskViewList.Model {
    public struct Confirmation: Equatable, Sendable { public let title: String; public let message: String }
    public struct MovePicker: Equatable, Sendable {
        public let title: String                   // Move “X” to…
        public let isTopLevelCurrent: Bool
        public let rows: [PickerRow]
    }
    public struct PickerRow: Equatable, Sendable, Identifiable {
        public var id: ViewID { row.id }
        public let row: Row                        // the same row, drawn the same way
        public let isDisabled: Bool                // the list being moved and everything in it
        public let isCurrent: Bool                 // its present parent
    }
    public let isEditing: Bool
    public let confirmation: Confirmation?         // nil when none is up; the buttons are Delete and Cancel
    public let movePicker: MovePicker?             // nil when closed
}
// UserAction gains editMenuItemChosen, doneButtonTapped, moveToMenuItemChosen(ViewID), deleteMenuItemChosen(ViewID),
// deleteConfirmed, deleteCancelled, movePickerRowTapped(ViewID?), movePickerCancelled,
// rowDropped(ViewID, after: ViewID?, depth: Int).
```

**Rules.**

- Edit mode: `editMenuItemChosen` sets it, `doneButtonTapped` commits an open field as Return does and leaves it, and a refused name keeps the field and the mode. While editing, every `countText` is `""`, an unnamed area's label is `"Area"`, and `rowSelected` on any row opens its field instead of declaring a list (spec section 7).
- Delete asks first (spec section 6). `deleteMenuItemChosen(id)` on a list puts up `Confirmation(title: "Delete “X”?", message:)` with `"No task is deleted."`, `"One list inside it goes with it. No task is deleted."` or `"N lists inside it go with it. No task is deleted."`; on an area, `"Delete the “X” area?"`, or `"Delete the area?"` unnamed, with `"Its lists stay."`; on an id no row holds, nothing. `deleteConfirmed` deletes a list with `delete(viewTree:)`, and an area by moving each of its lists in rank order, `move(view:to:at: .end)` under the area above or by the root rule when there is none, then `delete(view:)`; the confirmation closes either way, a refusal says `couldNotSave`, and the rows are reread. `deleteCancelled` closes it; with none up both move nothing, which is where the alert's write after a close the model drove lands.
- The root rule, in `TaskViewList+Rows.swift`: a list put at the root goes `.after` the last list of the root that stands before the first area, or `.start` when none does; it serves Top level, the lists of a deleted first area, and nothing else (spec section 3).
- Move to…: `moveToMenuItemChosen(id)` on a list opens `MovePicker` over the whole tree in tree order with folds ignored, the lines, the drawn depths and each list row's tile and title font as the screen's, built by Task 5's rule for the width the module holds, the list and its descendants disabled and its parent current, `isTopLevelCurrent` when it stands at the root; on an area or an id no row holds, nothing. `movePickerRowTapped(nil)` moves by the root rule; a line or a list moves the list `.end` under it; a disabled row moves nothing. After a move the destination is unfolded, the rows reread and the picker closed; a refusal says `couldNotSave`. `movePickerCancelled` closes it; with none up both move nothing.
- The drop, `rowDropped(id, after:, depth:)`: an id or an `after` no row holds moves nothing. For a list, the depth is clamped between the drawn depth of the row that follows `after` once the moved list and its descendants are skipped, or 0 when none follows, and the depth of `after` plus one, or 0 when `after` is nil or an area's line. Then `after` nil is the root at `.start`; an area's line is that area at `.start`; `after`'s depth plus one is `after` at `.start`; `after`'s depth is `after`'s parent `.after(after)`; a shallower depth is the ancestor of `after` at that drawn depth, found by walking parents while the drawn depth is greater, placed `.after` it under its parent (spec section 5). For an area, `after` nil is the root at `.start`, and otherwise the root `.after` the root item of `after`'s block, its topmost ancestor (spec section 7). The store's refusals say `couldNotSave`; after a write the new parent is unfolded and the rows reread.
- `TaskViewListView` adapts and no more: `.alert` over `confirmation` with Delete and Cancel sending `deleteConfirmed` and `deleteCancelled`, `.sheet` over `movePicker` with a plain `List` of the rows sending `movePickerRowTapped` and a Cancel sending `movePickerCancelled`, both dismissals sending the Cancel; the context menu gains New list, Move to… and Delete; Edit and Done on the toolbar. The probe drives the picker and a drop; the budget is re-measured.

**Tests.**

- `editModeHidesCountsLabelsEveryAreaAndATapRenames`; `doneKeepsTheOpenNameAndLeavesEditMode`; `aRefusedNameKeepsEditMode`.
- `deleteAsksFirstAndCancelDeletesNothing`; `theConfirmationNamesHowManyListsGo`, for none, one and three; `deletingAListTakesTheListsInsideItAndNoTask`; `deletingAnAreaMovesItsListsToTheAreaAboveOrAboveTheFirstArea`; `aBuiltInMovesAndDeletesLikeAnyList`; `AppModuleTests.deletingTheOpenListClosesItAndLeavesNothingChosen`.
- `movePickerShowsTheWholeTreeWithTheListAndItsSubtreeDisabledAndItsParentCurrent`; `aFoldedBranchIsStillInThePicker`; `aTapInThePickerMovesTheListLastUnfoldsTheDestinationAndClosesIt`; `topLevelPutsTheListAboveTheFirstArea`; `aTapOnADisabledRowMovesNothing`.
- `aDropDeeperMakesTheRowTheFirstChildOfTheRowAbove`; `aDropAtTheSameDepthMakesItTheNextSibling`; `aDropShallowerMakesItTheNextSiblingOfTheAncestorAtThatDepth`; `aDropUnderAnAreasLineGoesIntoTheArea`; `aDropAtTheTopGoesToTheStartOfTheRoot`; `aDepthOutsideWhatTheRowsAllowIsClamped`; `anAreaDropsAfterTheBlockOfTheRowAbove`; `aDropOfOrOntoARowTheModuleDoesNotHoldMovesNothing`.
- `aDialogActionWithNoDialogUpMovesNothing`.

**Verified facts and traps.**

- `move(view:to:at:)` refuses a move under the view's own descendant with `.invalid`; the picker's disabled rows and the drop's skipped descendants keep that from arising, and the sentence covers a peer's change in between.
- Trap: SwiftUI writes a dismissal into an alert's or a sheet's binding after a close the model drove (`RootView.isQuickEntryUp`); the Cancel actions with no dialog up move nothing for that reason.
- Trap: a `switch` expression whose arms are optional calls and `nil` does not typecheck; its arms `return` (navigation plan, Task 1).

### Task 7: The Lists screen on iPhone

**Goal.** The Lists screen on iPhone as the canvas draws it, in both appearances: the tree with tiles, counts, chevrons, guides and areas, the long-press menus, the bottom bar with "…", the inert capsule and "+", edit mode with grips and the drag of Task 4, Move to… as a sheet and the confirmation as an alert (spec sections 1, 6 and 7).

**Files.** New `Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsScreen.swift`, `ListRowView.swift`, `AreaLine.swift`, `ListsBottomBar.swift`, `MovePickerSheet.swift`, `ListsDragGesture.swift`; `Apps/Apple/Sources/TodoAppleUI/RootView.swift`; `README.md`; `CHANGELOG.md`.

**Interface.** Consumes Task 1's foundations, Task 4's answer and Task 6's model. Produces:

```swift
struct ListsScreen: View { init(model: TaskViewList.Model, send: @escaping (TaskViewList.UserAction) -> Void) }
// RootView.narrowStack draws ListsScreen at the root of the narrow tree; the wide tree keeps TaskViewListView until Task 8.
```

**Rules.**

- The rows (`Phone.dc.html`): 46 pt high; the tile's leading edge at 20 + 22 × depth pt; the tile through `ListTile(row.tile)`, which the module built at the canvas's 30, 8 and 19 at the root and 26, 7 and 16 nested, with no `TileModel` built and no `init(rawValue:)` in the view; the title in `Font(row.titleFont)`, ink, one line, at least 140 pt wide; the count in `Font(.count)`, ink2, at the right edge, with the chevron beside it, both pinned while the tree scrolls sideways past the depth at which 20 + 22 × depth + the tile + 12 + 140 + 72 exceeds the width; guides of 1.5 pt in the line colour down each ancestor level under its tile's centre; the chevron rotates on fold with `Animation(.popover)`.
- An area's line (`AreaLine`): a 1 pt line in the line colour across the tree, 17 pt tall alone, and 36 pt with the label in ink2 in `Font(.areaLabel)` sitting on the line, which while renaming becomes the field; a grip at the right in edit mode.
- The bar (`ListsBottomBar`), on `.regularMaterial`: a 48 pt round "…" at the left, a `Menu` holding Edit, and +List, +Area and a Done check in edit mode; the capsule in the middle, 48 pt high, radius 24, the magnifier and "Search" in ink2, a view that sends nothing; a 48 pt round "+" in the accent at the right, a `Menu` holding New task, New list and New area. No title, as the canvas has none.
- The long press is `.contextMenu` behind `#if !os(watchOS)` as today: Rename, New list, Move to…, Delete on a list; Rename, New list, Delete area on a line; Open in New Window on a list where `supportsMultipleWindows`. Not shown in edit mode, which `isEditing` says.
- Edit mode: grips at the right, a tap on a row sends `rowSelected`, and the drag, `ListsDragGesture`, built as Task 4 answered: the lifted row scaled 1.03 and tilted −1.5°, the slot 52 pt dashed at the chosen depth, the depth bounded as Task 4 bounds it, one `rowDropped` on release.
- The alert from `confirmation` with Delete, destructive, and Cancel; `MovePickerSheet` from `movePicker`: "Top level" first, then `ListRowView` and `AreaLine` over `PickerRow`, disabled rows dimmed, the current one checked, Cancel in its bar; both dismissals send the Cancel action.
- The sidebar's sentence stays under the rows as today, and the root's strip under it; the sheet for quick entry stays the root's. Reduce Motion passes `nil` animations.
- `README.md` describes the screen where it describes the sidebar and New Folder.

**Tests.** `TodoAppTests` as Task 6 left them; the screen is checked by hand on an iPhone 17 in both appearances, every flow of spec sections 1, 6 and 7 once, with screenshots in the pull request.

**Verified facts and traps.**

- The sizes are the canvas's of 2026-10-25: `.vrow` 46 px, `tileLeft(d) = 20 + 22d`, `tileSize(d)` 30 or 26, a title's `need` of 140, the bar's 48 px glass buttons, the slot's 52 px, the area's 36 or 17 px.
- `supportsMultipleWindows` is false on iPhone with or without the multiple-scenes declaration (`TaskViewListView`, 2026-10-18).
- Trap: a `List` cannot be the tree (Task 4); the screen is built on what the spike answered, and if the fallback was taken, the drag changes the order alone and the depth goes through Move to….

### Task 8: The sidebar on the Mac and the iPad

**Goal.** The wide window's sidebar as the canvas's Mac board, with the phone's gestures on the iPad; the adapted `TaskViewListView` goes (spec section 8).

**Files.** New `Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsSidebar.swift`; `RootView.swift`; `TaskViewListView.swift` deleted; `README.md`; `CHANGELOG.md`.

**Interface.** Consumes Task 7's views. Produces:

```swift
struct ListsSidebar: View { init(model: TaskViewList.Model, send: @escaping (TaskViewList.UserAction) -> Void) }
// RootView.splitView draws ListsSidebar in the sidebar column.
```

**Rules.**

- The column: `navigationSplitViewColumnWidth(min: 280, ideal: 280)`; rows 30 pt, radius 7, the tile through `ListTile(row.tile)`, which the module built at the canvas's 20, 6 and 13, the title in `Font(row.titleFont)`, which the module chose for the wide window and which renders at the system's sidebar size, the count ink2 and the disclosure chevron at the right, pinned while the tree scrolls sideways past a title of 90 pt (`Mac.dc.html`); an area's line 15 pt alone and 28 pt while renaming, its name always on it when it has one (the spec over the Mac board's hover).
- At the bottom: the search field, 30 pt, in the fill colour, inert; a 30 pt round "+" in the accent, a `Menu` with New task, `⌘N`, New list, `⇧⌘N`, and New area, the shortcuts through `keyboardShortcut`. The toolbar's New Folder is gone; the list's Quick Entry button stays.
- The drag at any time, with the line-and-circle indicator for a drop between rows and into a parent, sending the same `rowDropped`.
- The one platform condition, `#if os(macOS)`: the Mac's right click opens the menus, Rename, New list, Open in New Window, Move to…, Delete on a list and Rename, New list, Delete area on a line, and the Mac has no edit mode, no "…" and no edit items; on the iPad the long press opens the menus, "…" holds Edit, and the bar of Task 7 stands at the bottom of the column with edit mode as on the phone (spec section 8). Open in New Window where `supportsMultipleWindows`.
- A Plus or Max iPhone turned sideways reports the regular class and gets this sidebar, as it gets the split view today; nothing here reads the device.
- The sidebar's sentence under the rows, and on the pane while the column is hidden, as today.

**Tests.** `TodoAppTests` unchanged; checked by hand on the Mac in both appearances, on an iPad Pro 11-inch (M5) in both orientations, and on an iPhone 17 Pro Max turned sideways, with screenshots in the pull request.

**Verified facts and traps.**

- The Mac's `horizontalSizeClass` is nil and reads as wide; the iPad's regular class and a Plus or Max iPhone's sideways class read as wide (`WindowView`).
- `supportsMultipleWindows` is true on the Mac and on the iPad with the multiple-scenes declaration (`TaskViewListView`, 2026-10-18).
- Trap: a root whose body reads the split view's column visibility redraws the stack and loses the pushed task's background (`HiddenSidebarStrip`, #133); the sidebar reads nothing of the split view.

## Self-review against the spec

- Problem and goals: Tasks 5 to 8 replace the scaffold; the non-goals have no task, the badge included.
- Section 1: Task 5 draws the rows and lines, Task 7 the screen, Task 8 the sidebar; Logbook and Trash stand where the seed ranks them, nothing names them. Section 2: Task 2. Section 3: Task 5's placements and the area's name, Task 6's root rule and the area's deletion. Section 4: Task 3's counts and Task 5's reread; the badge is out of the epic. Section 5: Task 5's model and Task 6's dialogs and drop; the route unchanged; the folds in Task 2's table through Task 5. Section 6: Tasks 5 and 6. Section 7: Task 4's spike, Task 6's edit mode and area drop, Task 7's screen. Section 8: Task 8. Section 9: Task 1, and Task 5's tiles and title fonts. Section 10: every row has a task. Testing: each task's tests and hand checks. Risks: the drag is Task 4; the wide tree is Task 7's sideways scroll; the counts' cost is Task 3's measurement; midnight is accepted; the area's two writes are Task 6; the marked text is the field's as today; a deleted Inbox leaves quick entry to say so, as today; the wasm budget is Tasks 5 and 6.
- Deviations, each the engineer's call, for the owner's review:
  - A new list is not declared over the sidebar when it is made: today's folder declares its list, and on a narrow window that would push the list over the sidebar while the name field is open. The field opens; the highlight stays.
  - `taskCounts(today:)` where the spec says `counts(today:)`, since the number is a count of tasks; `countStatement` beside `viewStatement` so that the plan test explains the statement itself.
  - `PickerRow` carries the row and two flags where the spec says "rows of the same shape", so that the picker's view switches over the same `Kind` and reads two Bools.
  - The drop's depth is clamped to what the rows allow, since the view's slot offers only those and the module trusts nothing a view sends.
  - A fold whose device-state write fails stays folded and says nothing: the fold is on screen, the next fold writes the set again, and the module's sentences stay for the data a person edits.
  - A list with no colour draws stone's shades; the canvas gives a new list blue, the spec gives it none, and the spec wins for the behaviour while the look of "none" is the foundations'.
  - The foundations come before their callers, as the spec orders the epic; the pull request names Task 5, which builds the tiles and chooses the fonts, and Tasks 7 and 8, which draw them.
  - `TaskViewListView` is adapted twice before the look arrives, as the navigation plan adapted the root view, so that every merge works.
