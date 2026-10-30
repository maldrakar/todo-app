# Plan: The Lists screen

- Status: Approved 2026-10-26, with the owner's word that a decision may move during implementation and be recorded in the task's pull request; Task 8 added on 2026-10-30 at the owner's word, the sidebar renumbered 9; Task 9 fixed forward on 2026-10-30 against what Task 8 shipped (#161)
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
- The look is the canvas's; where the canvas and the spec differ, the canvas is right about the look and the spec about the behaviour (spec, introduction). The sizes in Tasks 1, 5, 7, 8 and 9 are the canvas's; the type is text styles, whose sizes at the iPhone's default text size are the canvas's but for the large title, 34 pt against 32, and the meta, 12 against 12.5, the owner's choice on #151.
- Every merge leaves `main` working on every platform: a task that changes a module's model or actions adapts `Apps/Apple` in the same pull request, minimally where the look is a later task's (Tasks 5 and 6), and starts the macOS job from the Actions tab on its branch before asking for the merge (`docs/process.md`, section 10).
- Tests are swift-testing. A module test opens `makeStore` with the test clock, sends events and compares the model whole. The root package's suite runs green on the host with `swift test` and on wasm32 with `swift test --swift-sdk swift-6.4.0-RELEASE_wasm --disable-xctest`, and `scripts/wasm-size.sh` passes, before every PR; the budget is re-measured where the probe's code moves (Tasks 5 and 6).
- `Apps/Apple` is built and tested from its directory with the pinned toolchain, and each screen is checked by hand in the iOS 26.3 simulator on an iPhone 17, an iPhone 17 Pro Max turned sideways and an iPad Pro 11-inch (M5), and on the Mac, in both appearances, with screenshots in the pull request (spec, "Testing").
- Branch per task `<type>/<issue>-<slug>`, PR title in Conventional Commits with scope `core` or `apple`, body per template, `Closes #<sub-issue>`; squash merge; one line under `[Unreleased]` in `CHANGELOG.md` per task; commits end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Everything in English, and a string a person reads is English until the formatting service arrives. No `TODO` without a linked issue.

## File map

| File | Task | Holds |
| ---- | ---- | ----- |
| `Package.swift`, `Sources/DesignSystem/DesignSystem.swift` | 1 | the `DesignSystem` and `DesignSystemComponents` targets, their products and their tests; the enum every type of the design system is nested in |
| `Sources/DesignSystem/Color.swift`, `Color+Components.swift` | 1 | `RGB`, and `Color` with the named colours as its static members, a shade per appearance; `Color.Components.Tile`, the tile's eleven colours by the store's names, each a background and a glyph colour drawn from a base nothing outside sees by the canvas's rule |
| `Sources/DesignSystem/Font.swift`, `Animation.swift`, `Icon.swift` | 1 | the fonts as text styles; the animations, each a curve, a duration and a delay; the icons by the names the store keeps, the default glyph `bullets` among them |
| `Sources/DesignSystemComponents/TileModel.swift` | 1 | a list's tile as plain data: the tile colour, the icon and the sizes its caller gives, and its glyph's medium weight |
| `Tests/DesignSystemTests/ColorTests.swift`, `TileColorTests.swift`, `ChannelGap.swift`, `FontTests.swift`, `AnimationTests.swift`, `IconTests.swift`, `Tests/DesignSystemComponentsTests/TileModelTests.swift` | 1 | the mix and the accent soft, the tile colours against the canvas and their names against the store's, a derived colour compared with the canvas's, the four row titles, the delay, the store's icon names and unknown ones; what the tile carries |
| `Apps/Apple/Package.swift`, `Apps/Apple/Sources/TodoAppleUI/DesignSystem/Color+DesignSystem.swift`, `Font+DesignSystem.swift`, `Animation+DesignSystem.swift`, `Image+DesignSystem.swift`, `ListTile.swift` | 1 | the dependencies on `DesignSystem` and `DesignSystemComponents`; the renderers, a `Color` that follows the appearance, a text-style `Font`, an `Animation` with its delay and every icon's SF Symbol; the tile view, drawn from a `TileModel` |
| `Apps/Apple/Tests/TodoAppleUITests/DesignSystemRenderersTests.swift` | 1 | each renderer, and that every icon's symbol exists on the system |
| `Sources/TodoCore/Model/TaskView.swift` | 2 | `TaskViewKind`, `TaskViewColor`, the three fields, `NewTaskView`'s three parameters, the seed's tiles |
| `Sources/TodoCore/Storage/Schema.swift`, `Migrations.swift` | 2 | `version5` |
| `Sources/TodoCore/Storage/JournalOperation.swift` | 2 | the three fields in `FieldMap` |
| `Sources/TodoCore/Storage/Store+Views.swift` | 2, 3 | the three fields written, read and refused (2); `delete(viewTree:)` (3) |
| `Sources/TodoCore/Storage/Store+DeviceState.swift` | 2 | `deviceState(_:)`, `setDeviceState(_:_:)` |
| `Sources/TodoCore/Query/Store+Counts.swift` | 3 | `taskCounts(today:)` and its statement |
| `Tests/TodoCoreTests/ViewTests.swift`, `StoreOpenTests.swift`, `FieldMapTests.swift` | 2, 3 | the fields, the migration, the tree delete |
| `Tests/TodoCoreTests/DeviceStateTests.swift`, `CountTests.swift` | 2, 3 | new |
| `Sources/DesignSystem/Icon.swift`, `Font.swift`, `Color.swift`, `Shadow.swift` | 8 | the chrome's glyphs as icons; the bold weight and three fonts; the colour on the accent; the lifted card's shadow |
| `Sources/DesignSystemComponents/*Model.swift` | 8 | the models of the screen's components, from the icon, the text and the line up to the bar, the picker and the confirmation |
| `Tests/DesignSystemComponentsTests/IndentModelTests.swift` | 8 | the indent |
| `Sources/DesignSystemComponents/FillModel.swift`, `ListRowModel.swift`, `SearchFieldModel.swift`, `MenuModel.swift`, `DragModel.swift`, `ButtonModel.swift`; `Sources/FeatureModule/WindowCapabilities.swift` | 9 | the fill two models share, the row's radius, the search field's fill, a menu item's shortcut, the drop indicator; what the window's platform offers |
| `Package.swift` | 5 | `TaskViewListFeature` depends on `DesignSystem` and `DesignSystemComponents`, and so do `TaskViewListFeatureTests`, which spell `TileModel(…)` and compare `DesignSystem.Font`, and `AppFeatureTests`, which compare the sidebar's tiles; the feature targets' comment says when a feature imports the two |
| `Sources/Features/TaskViewList/TaskViewList.swift` | 5, 6, 8, 9 | the module's events (5, 6); `supportsMultipleWindows` (8), which `WindowCapabilities` replaces (9) |
| `Sources/Features/TaskViewList/TaskViewList+Model.swift` | 5, 6, 8 | `Model` and its nested types, whose rows, bar and dialogs are component models (8) |
| `Sources/Features/TaskViewList/TaskViewList+Components.swift` | 8, 9 | the phone's numbers and the builders of the component models (8); the metrics of each width (9) |
| `Sources/Features/TaskViewList/TaskViewList+Rows.swift` | 5, 6 | the walk from the store's tree to the drawn rows, and each list row's tile and title font (5); the root rule and the drop's reading (6) |
| `Sources/Features/App/AppModule.swift` | 5, 8, 9 | reacts to `newTaskRequested`; hands the sidebar the window's width class (5), whether a window can open beside it (8), and then all the window's platform offers (9) |
| `Tests/TaskViewListFeatureTests/TaskViewListTests.swift`, `TaskViewListRowsTests.swift`, `TaskViewListEditsTests.swift` | 5, 6, 8 | adapted; the rows; the edits |
| `Tests/TaskViewListFeatureTests/TaskViewListComponentsTests.swift` | 8 | the component models the module builds |
| `Tests/AppFeatureTests/AppModuleTests.swift` | 5, 6, 8 | quick entry from the sidebar and the sidebar's tiles following the width; the open list deleted |
| `Sources/WasmSizeProbe/main.swift`, `scripts/wasm-size.sh` | 5, 6, 8 | the probe drives the new actions and models; the budget re-measured |
| `Apps/Apple/Sources/TodoAppleUI/TaskViewListView.swift` | 5, 6, 8, 9 | adapted to the model (5, 6, 8); deleted (9) |
| `Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsScreen.swift`, `ListRowView.swift`, `AreaLine.swift`, `ListsBottomBar.swift`, `MovePickerSheet.swift`, `ListsDragGesture.swift` | 7, 8 | the phone's screen, rows, lines, bar, picker and drag (7), drawn from the component models (8) |
| `Apps/Apple/Sources/TodoAppleUI/DesignSystem/Image+DesignSystem.swift`, `Font+DesignSystem.swift`, `Shadow+DesignSystem.swift`, `TodoApp.swift`, `WindowView.swift` | 8 | the new icons' symbols, the bold weight and the shadow; `supportsMultipleWindows` read and handed to the root |
| `Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsSidebar.swift` | 9 | the Mac's and the iPad's sidebar |
| `Apps/Apple/Sources/TodoAppleUI/RootView.swift` | 7, 9 | the narrow tree draws the screen (7), the wide tree the sidebar (9) |
| `Apps/Apple/Tests/TodoAppleUITests/TodoAppTests.swift` | 5, 6 | the model's new shape |
| `Apps/Apple/Tests/TodoAppleUITests/DesignSystemRenderersTests.swift`, `ListsDragTests.swift` | 8 | the new icons' symbols; the drag over the new model |
| `docs/style.md`, `docs/adr/0007-feature-modules-are-shared-code-and-hosts-live-under-apps.md` | 8 | a view may switch over a component model's enums; the amendment of 2026-10-30 |
| `README.md`, `CHANGELOG.md` | every task | the changelog line; the README where behaviour a person sees changes (7, 9) |

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
| 8 | #161 | The Lists screen's component models | `arch`, `core`, `ui-apple` | 7 |
| 9 | #149 | The sidebar on the Mac and the iPad | `feature`, `core`, `ui-apple` | 8 |

The owner reviews this table and the interface of every task below.

Task 8 was added on 2026-10-30, after Task 7 had shipped, at the owner's word: the design decisions Task 7's views hold move into component models before the sidebar draws them a second time. The sidebar, Task 8 when Tasks 1 to 7 were written, is Task 9; the shipped sections keep the old number.

The split leaves `main` working after every merge. Tasks 1 to 4 touch no
screen, and all but Task 1, whose test holds its tile colours to Task 2's
`TaskViewColor`, can run beside each other. Tasks 5 and 6 change the module's
model and actions, so each adapts `TaskViewListView` in the same pull
request just far enough that the app compiles and works, with today's
look; the look arrives in Task 7 for the phone, moves into component
models in Task 8, and arrives in Task 9 for the Mac and the iPad, where
the adapted view goes. Task 4 answers the one
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
- A list row's tile and title font are the Lists screen's layout, built in `TaskViewList+Rows.swift` from the read row and the width the module holds whenever the model is computed (ADR-0007, amendment of 2026-10-26). The colour is `DesignSystem.Color.Components.Tile(rawValue:)` of the `TaskViewColor`'s raw value, `.stone` for none or a name it does not know, and the icon `DesignSystem.Icon(rawValue:)` of its text, `.bullets` for none or a name it does not know. The sizes are constants cited to the canvas: narrow, side 30, radius 8 and glyph 19 at drawn depth 0 and 26, 7 and 16 deeper (`Phone.dc.html`, `tileSize`); wide, 20, 6 and 13 for every row (`Mac.dc.html`, the 30 pt row). The title, narrow, is `.rowTitle` at drawn depth 0 and `.nestedRowTitle` deeper, and wide `.rowTitle` at every depth, the body being the system's sidebar size, 13 pt on the Mac and 17 on the iPad; each is `Emphasized` when the row has children. `widthChanged` moves the width alone, so the tiles follow it with no read of the store.
- `countText` is the count's decimal for a count above zero and `""` otherwise; an area's line has none. The counts come from `taskCounts(today:)` beside every read of the rows, with `today` the UTC day of `Store.systemNow()`, as the task list reads it; one `reread` reads both and throws as today's does.
- `.changed`: a change naming a view rereads rows and counts; one naming only tasks or tags rereads the counts alone; a draft and the sentence stay, since a change answers nobody (spec section 4).
- The folds are the device's (ADR-0010, amendment of 2026-10-26): `init` reads `deviceState("taskViewList.collapsed", as: [String].self)`, the folded ids' raw values, dropping anything that does not read as an id or that no row holds; `disclosureTapped` on a row with children toggles it and writes the set back the same way, an empty list when nothing is folded; on a leaf or an area's line it moves nothing. A write of the device state that fails leaves the fold on screen and says nothing, the engineer's call (Self-review).
- `newListMenuItemChosen(in:)` creates `NewTaskView(title: "New list", parent:, kind: .list, color:, icon: "list")` at `.end`: under the list named, with that list's colour; under the area named, with none; with nil, in the last area of the root, or at the root's end when there is no area, with none (spec section 3). Then the parent is unfolded and written, the rows reread, and the field opens on the new row with its title as the draft, on a row the reread holds, as `createFolder` does today. The new list is not declared over the sidebar: the highlight stays where it was (Self-review).
- `newAreaMenuItemChosen` creates `NewTaskView(title: "", kind: .area)` at the root's `.end` and opens the field on its line with the empty draft; `commit` accepts the empty title for an area and refuses it for a list with today's sentence (spec section 3).
- `newTaskMenuItemChosen` answers `.newTaskRequested` and moves nothing.
- `rowSelected` and `openInNewWindowMenuItemChosen` on an area's line move nothing, since an area never opens; `renameMenuItemChosen` on it opens the field with its name. `Kind.area(label:)` is the title when it is not empty and nil otherwise.
- `TaskViewListView` adapts and no more: one switch over `kind`, a line as a `Divider` with its label beside it, a list as today's row; the toolbar's New Folder becomes New List sending `newListMenuItemChosen(in: nil)`; the wasm probe drives the four new actions, its width change now reaches the sidebar, and the budget is re-measured with the two design targets the sidebar links.

**Tests.**

- `theRowsCarryTheirKindTileAndCount`: in a narrow window the built-ins' tiles, the Inbox's `TileModel(color: .blue, icon: .tray, side: 30, cornerRadius: 8, glyphSize: 19)`, Inbox counting two open tasks and Logbook `""`; a list made with an icon this app does not know has a tile with the bullets icon, and one with no colour a stone tile.
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
- Task 5 shipped `ReadRow` without `parent` or the tree depth, since nothing there read them (#146). This task adds `parent` with its first readers, the picker's current parent and `isTopLevelCurrent` and the drop's walk up the parents below, and reads depths as the drawn ones `ReadRow.depth` holds.
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

### Task 8: The Lists screen's component models

**Goal.** Every design decision of the Lists screen moves out of the Apple views into component models in `DesignSystemComponents`, which `TaskViewList` builds, so that the sidebar of Task 9 and every later platform draw the same components and no decision stays behind on one platform (the owner, 2026-10-30). A model describes all its platform needs to render the component; the platform decides only its container, its gestures and the drag, scrolling, focus and Reduce Motion. The screen looks and behaves as Task 7 left it.

**Files.** `Sources/DesignSystem/Icon.swift`, `Font.swift`, `Color.swift`, new `Shadow.swift`; new in `Sources/DesignSystemComponents/`: `IconModel.swift`, `TextModel.swift`, `StrokeModel.swift`, `IndentModel.swift`, `FieldModel.swift`, `ListRowModel.swift`, `AreaLineModel.swift`, `MenuModel.swift`, `ButtonModel.swift`, `SearchFieldModel.swift`, `BarModel.swift`, `DragModel.swift`, `ChoiceModel.swift`, `PickerModel.swift`, `ConfirmationModel.swift`; `Sources/Features/TaskViewList/TaskViewList.swift`, `TaskViewList+Model.swift`, `TaskViewList+Rows.swift`, new `TaskViewList+Components.swift`; `Sources/Features/App/AppModule.swift`; `Sources/WasmSizeProbe/main.swift`, `scripts/wasm-size.sh`; the tests of `DesignSystem`, `DesignSystemComponents`, `TaskViewListFeature` (new `TaskViewListComponentsTests.swift`) and `AppFeature`; in `Apps/Apple`, `DesignSystem/Image+DesignSystem.swift`, `Font+DesignSystem.swift`, new `Shadow+DesignSystem.swift`, every file of `ListsScreen/`, `TaskViewListView.swift`, `TodoApp.swift`, `WindowView.swift`, `RootView.swift`, and `DesignSystemRenderersTests.swift`, `ListsDragTests.swift`, `TodoAppTests.swift`; `docs/style.md`; ADR-0007; `CHANGELOG.md`.

**Interface.** Consumes Task 7's views as shipped (31b733c) and the module of Tasks 5 and 6. Every model is plain data, `Equatable` and `Sendable` with a public memberwise `init`, and generic over `Action: Equatable & Sendable` where it carries an action. Produces:

```swift
// DesignSystem: the chrome's glyphs join the lists' icons, named for what they draw.
enum DesignSystem.Icon { /* the 16 of Task 1 */ case ellipsis, plus, check, chevron, grip, magnifier, microphone, newWindow, checkCircle, divider }
enum DesignSystem.Font.Weight { /* … */ case bold }
extension DesignSystem.Font { static let barLabel, hint, search }       // subheadline semibold, footnote, body
extension DesignSystem.Color { static let onAccent }                     // white in both appearances
struct DesignSystem.Shadow { let opacity, radius, y: Double; static let lifted }

// DesignSystemComponents
struct IconModel { icon: DesignSystem.Icon; size: Double; weight: DesignSystem.Font.Weight; color: DesignSystem.Color }
struct TextModel { text: String; font: DesignSystem.Font; color: DesignSystem.Color }
struct StrokeModel { color: DesignSystem.Color; width: Double; dash: [Double] }
struct IndentModel { start, step: Double; func leading(atDepth depth: Int) -> Double }
struct FieldModel { text, placeholder: String; font: DesignSystem.Font; color, background: DesignSystem.Color
                    minimumWidth, height, padding, cornerRadius: Double; ring: StrokeModel }
struct ListRowModel<Action> {
    struct Chevron { icon: IconModel; rotation: Double; animation: DesignSystem.Animation; accessibilityLabel: String; action: Action }
    struct Accessories { count: TextModel; countMinimumWidth: Double; chevron: Chevron?; grip: IconModel?
                         cellWidth, fadeWidth, endGap, width: Double }
    height, leading: Double; tile: TileModel; tileToTitle: Double; title: TextModel; field: FieldModel?; need: Double
    background: DesignSystem.Color; guides, childGuides: [Double]; guide: StrokeModel; accessories: Accessories
    tap: Action; menu: MenuModel<Action>?
}
struct AreaLineModel<Action> { height, leading, trailing, spacing: Double; label: TextModel?; field: FieldModel?
                               line: StrokeModel; grip: IconModel?; tap: Action; menu: MenuModel<Action>? }
struct MenuModel<Action> { struct Item { title: String; icon: DesignSystem.Icon; isDestructive: Bool; action: Action }
                           struct Section { items: [Item] }; sections: [Section] }
struct ButtonModel<Action> { enum Press { case action(Action), menu(MenuModel<Action>) }
                             enum Fill { case container, color(DesignSystem.Color) }
                             icon: IconModel; title: TextModel?; accessibilityLabel: String; fill: Fill; press: Press }
struct SearchFieldModel { placeholder: TextModel; leadingIcon, trailingIcon: IconModel
                          trailingCell, spacing, leadingPadding, trailingPadding: Double }
struct BarModel<Action> { enum Item { case button(ButtonModel<Action>), search(SearchFieldModel), group([ButtonModel<Action>]) }
                          items: [Item]; controlHeight, spacing, padding, groupButtonHeight, groupButtonSpacing, groupPadding, groupDividerHeight: Double
                          groupDivider: StrokeModel }
struct DragModel { struct Slot { height, inset, trailingGap, verticalInset, cornerRadius: Double; fill: DesignSystem.Color; stroke: StrokeModel }
                   struct Card { raise, scale, rotation: Double; shadow: DesignSystem.Shadow; background: DesignSystem.Color
                                 grip: IconModel; gripCell, minimumWidth: Double
                                 listHeight, listInset, listPadding, listTrailingGap, listCornerRadius: Double
                                 lineHeight, lineInset, lineTrailingGap, lineCornerRadius: Double }
                   indent: IndentModel; animation: DesignSystem.Animation; slot: Slot; card: Card }
struct ChoiceModel<Action> { title: String; isDestructive: Bool; action: Action }
struct PickerModel<Row, Action> {
    struct TopLevel { icon: IconModel; tileSide, tileCornerRadius: Double; tileColor: DesignSystem.Color; title: TextModel
                      leading, height: Double; isChecked: Bool; action: Action }
    struct Option { row: Row; isDisabled, isChecked: Bool }
    title: String; hint: TextModel; cancel: ChoiceModel<Action>; topLevel: TopLevel; options: [Option]
    check: IconModel; checkTrailing, hintGap, minimumOptionHeight, disabledOpacity: Double
}
struct ConfirmationModel<Action> { title, message: String; confirm, cancel: ChoiceModel<Action> }

// TaskViewList: ListRow, Confirmation and MovePicker go; Row loses its draft, which is the kind's field's text.
struct TaskViewList.Model { struct Row { id: ViewID; depth: Int; kind: Kind }
                            enum Kind { case area(AreaLineModel<UserAction>), list(ListRowModel<UserAction>) }
                            rows: [Row]; selection, renaming: ViewID?; isEditing: Bool; bar: BarModel<UserAction>; drag: DragModel
                            confirmation: ConfirmationModel<UserAction>?; movePicker: PickerModel<Kind, UserAction>?; problem: String? }
TaskViewList.init(store: Store, route: Route, width: WindowWidth, supportsMultipleWindows: Bool) throws(StoreError)
AppModule.init(store: Store, route: Route = .default, width: WindowWidth, supportsMultipleWindows: Bool) throws(StoreError)
```

**Rules.**

- A model holds every value its platform needs to draw its component: each size, gap, radius and line in points, each colour, font, icon, animation and shadow as a token of the design system, each word as finished text, and each control's action as a value. A view reads them and decides nothing but what is the platform's (the owner, 2026-10-30): on iOS the glass under the bar's controls with its hairline and shadow, the sheet and the alert, the fades under the status bar and over the bar, the long press and the drag, the sideways scroll with its pinned accessories and the scroll to an open field, focus, and Reduce Motion, which passes `nil` for every animation a model gives. The glass or a toolbar is the platform's choice, and `ButtonModel.Fill.container` says a control stands on it.
- `DesignSystemComponents` knows no domain and no screen, and depends on `DesignSystem` alone. `TaskViewList` builds every model in `TaskViewList+Components.swift` with the numbers Task 7's views hold today (Verified facts); for a wide window it builds the same models with the sidebar's tiles and fonts, as now, and Task 9 gives them the sidebar's numbers.
- Every word the screen shows or reads aloud is the model's, in English: the placeholders "Title", "Area name" and "Search", the menus' items, the bar's labels and accessibility labels, "Top level", "Choose where it goes.", "Cancel", "Delete", "Expand" and "Collapse".
- The menus come from the module, one per row kind: a list's Rename, New List, Open in New Window, Move to… and, after a divider, Delete; a line's Rename, New List and, after a divider, Delete Area. In edit mode no row has a menu, every row and line has a grip, and the counts are empty; `isEditing` stays for the drag alone. Open in New Window is in the menu only where `supportsMultipleWindows`, which `WindowView` reads from SwiftUI's environment and hands `makeWindow`, the root and the module when the window is made; it does not change while the app runs.
- The picker's options are the tree's rows of the same kinds, built as the screen's but with no menu, no count, no chevron, no grip and no highlight, and with `movePickerRowTapped` as their tap; "Top level" is its own model, as the canvas draws it apart.
- `renaming` names the row whose field is open, and nil when none is, and the screen scrolls to it instead of searching the rows (the owner's 👍 on #160's thread r4415002151).
- The drag stays the platform's (the owner, 2026-10-30): `ListsDrag`, with the lifted block, the slot's place and depth and an area's slots, stays in `TodoAppleUI`. It reads the indent from `model.drag.indent`, a slot's guides from the row before it (`childGuides`), and draws `DragModel.Slot` and `DragModel.Card`.
- The field's four actions stay the field view's to send, as today: `titleFieldChanged` carries the typed text, and a closure that makes one is no value a model can hold.
- A view may switch over a component model's enums too, every case drawn and no `default`: `ButtonModel.Press`, `ButtonModel.Fill` and `BarModel.Item`. `docs/style.md`, "Views", says so in this pull request, and ADR-0007 gains an amendment of 2026-10-30 for the rule of the first bullet.
- No user action, event or route changes. A chrome icon's name read from the store reads as that glyph, as every icon's name reads as its own; nothing writes one. The sentence (`problem`) stays a string drawn in the strip that every module's sentence shares, whose look is out of this task.

**Tests.**

- `DesignSystemTests`: the new icons, with the lists' icons still reading the store's names as before; the bold weight; the three fonts; `onAccent`; `Shadow.lifted`. `IndentModelTests`: the leading at depths 0, 1 and 13.
- `TaskViewListComponentsTests`: a root and a nested list's row whole with the phone's numbers; a branch folded and unfolded (the chevron's rotation and label); an area's line unnamed, named, renaming and in edit mode; the menus of a list and a line with and without `supportsMultipleWindows`, and none in edit mode; the bar in and out of edit mode; the picker and the confirmation whole; `renaming`. The other feature and app tests are adapted to the shape and assert what they asserted.
- `DesignSystemRenderersTests`: every new icon's symbol exists and the bold weight renders. `ListsDragTests` over the new model; `TodoAppTests` as Task 7 left them unless the shape forces a change.
- The probe drives the new models, and the budget is re-measured.
- By hand: the states of Task 7's screenshots page retaken on an iPhone 17 in both appearances, compared with those of 31b733c; any difference is named in the pull request.

**Verified facts and traps.**

- The fifteen names of `DesignSystemComponents` above were probed free on 2026-10-30 against SwiftUI, Foundation and Observation for macOS 14, iOS 17 and watchOS 10 with Xcode 27.1.
- The new icons' SF Symbols, found in `name_availability.plist` on 2026-10-30 from the 2019, 2020 and 2021 releases: `ellipsis`, `plus`, `checkmark`, `chevron.down`, `line.3.horizontal`, `magnifyingglass`, `mic`, `macwindow.badge.plus`, `checkmark.circle`, `rectangle.split.1x2`. Rename keeps `pen` ("pencil"), Move to… `folder`, Delete `trash` and the "+" menu's New List `list` ("checklist").
- Task 7's numbers, read from its views on 2026-10-30: a row 46 high, its tile at 20 + 22 × depth, 12 to the title, its need 140 of title and 72 of accessories (a fade of 10, a count of at least 20, the chevron's cell of 36, 4 at the end and 2 to spare, and the grip's cell of 36 more in edit mode), the chevron 13 semibold in ink2 turned −90° when folded, the grip 18 in ink3, guides 1.5 in the line colour, the selected row on the fill colour; the row's field 34 high, padding 10, radius 10, the surface with a 2 pt accent ring; an area's line 17 alone and 36 labelled, 20 in, 12 after the grip or 20, 10 between its parts, its field 160 by 28, padding 8, radius 8; the bar's controls 48, 10 apart and 16 in, their glyphs 20 semibold (Done's bold) in ink or `onAccent`, the search's glyphs 17 with the microphone in a 36 cell and 15 and 6 of padding, the group's buttons 40 high, a plus 6 before the word in `barLabel` in the accent, with 4 of padding and a 1 by 22 divider; the slot 52 with 44 drawn, 6 before its tile, 12 short of the edge, radius 13, the accent's soft fill, a 1.5 accent stroke dashed 5 and 4; the card raised 6, scaled 1.03, turned −1.5°, the lifted shadow (22 %, 18, 10), a list's 50 high, 2 before its tile, 12 of padding, a 40 grip cell in ink2, 6 short of the edge, radius 14, at least 120 wide, a line's 36 high, 8 in, 16 short, radius 12; the picker's check 15 bold in the accent 20 from the edge, "Top level" a 15 divider glyph in ink2 on a 30 tile of the fill colour with radius 8, a line's option at least 36 high, a disabled option at 35 %, the hint in ink2 8 above the rows; the lift, the release and a move of the slot on the popover's motion.
- The container's values stay in the views: the glass is the regular material with a hairline of ink at 8 % and 0.5 pt and a shadow of black at 12 %, radius 12 and 5 down, under every control of the bar; the fades are 4 pt under the status bar, paper to 55 %, and 52 pt over the bar, paper from 72 %.
- `supportsMultipleWindows` is false on iPhone with or without multiple scenes, and true on the Mac and on the iPad with the declaration (`TaskViewListView`, 2026-10-18).
- The wasm probe measured 6,605,560 bytes against a budget of 6,881,280 at Task 6.
- Trap: the edit bar's plus is a glyph of 15 pt where Task 7 sized it by the label's text style; the two are the same at the default text size, and the plus no longer grows with a larger one. Named in the pull request.
- Trap: `Color.resolve(in:)` on a dynamic `NSColor` hangs `swift test` off the main actor (Task 1); a renderer's test resolves on the main actor.

### Task 9: The sidebar on the Mac and the iPad

**Goal.** The wide window's sidebar as the canvas's Mac board, with the phone's gestures on the iPad; the adapted `TaskViewListView` goes (spec section 8). It draws Task 8's component models, which the module builds for the wide window with the sidebar's numbers, so the sidebar decides nothing the phone's views do not.

**Files.** In `Sources/DesignSystemComponents/`, `ListRowModel.swift`, `SearchFieldModel.swift`, `MenuModel.swift`, `DragModel.swift` and `ButtonModel.swift`, with a new `FillModel.swift`; new `Sources/FeatureModule/WindowCapabilities.swift`; `Sources/Features/TaskViewList/TaskViewList.swift`, `TaskViewList+Components.swift` and `TaskViewList+Rows.swift`; `Sources/Features/App/AppModule.swift`; their tests, `TaskViewListComponentsTests.swift` among them; `Sources/WasmSizeProbe/main.swift` and `scripts/wasm-size.sh`; new `Apps/Apple/Sources/TodoAppleUI/ListsScreen/ListsSidebar.swift`; `RootView.swift`, `WindowView.swift` and `TodoApp.swift`; `TaskViewListView.swift`, deleted; `TodoAppTests.swift`; `README.md`; `CHANGELOG.md`.

**Interface.** Consumes Task 7's views and Task 8's component models as shipped (#161). Produces:

```swift
// DesignSystemComponents: what the sidebar draws and the phone does not.
struct ListRowModel { /* Task 8's */ cornerRadius: Double }          // the background's radius: 0 on the phone, 7 on the sidebar
enum FillModel { case container, color(DesignSystem.Color) }        // ButtonModel.Fill of Task 8, lifted out so that two models share it
struct ButtonModel { /* Task 8's, with */ fill: FillModel }
struct SearchFieldModel { /* Task 8's */ fill: FillModel }          // .container on the phone (the glass), .color(.fill) on the sidebar
struct MenuModel.Item { /* Task 8's */ shortcut: Shortcut? }
struct MenuModel.Item.Shortcut { key: Character; modifiers: [Modifier]; enum Modifier { case command, shift } }
struct DragModel { /* Task 8's */ indicator: Indicator }
struct DragModel.Indicator { line: StrokeModel; circleDiameter: Double }   // the Finder's line and circle

// FeatureModule: what the window's platform offers, read by the view once when the window is made.
struct WindowCapabilities { opensWindowsBeside: Bool; hasEditMode: Bool }
TaskViewList.init(store: Store, route: Route, width: WindowWidth, capabilities: WindowCapabilities) throws(StoreError)
AppModule.init(store: Store, route: Route = .default, width: WindowWidth, capabilities: WindowCapabilities) throws(StoreError)
struct ListsSidebar: View { init(model: TaskViewList.Model, send: @escaping (TaskViewList.UserAction) -> Void) }
// RootView.splitView draws ListsSidebar in the sidebar column.
```

`WindowCapabilities` replaces Task 8's `supportsMultipleWindows: Bool` at both `init`s and `makeWindow`, so that the second fact the module builds by, edit mode, does not become a second `Bool` threaded the same way (the final review of #161). `opensWindowsBeside` is SwiftUI's `supportsMultipleWindows`; `hasEditMode` is false on the Mac alone, a platform condition in `WindowView`, named in a comment.

**Rules.**

- The sidebar's numbers are the module's, built for the wide width into Task 8's models: `TaskViewList+Components.swift`'s `Phone` becomes one value of metrics per width, picked once by `WindowWidth`, with `RowSize`'s choice of tile and title font folded into it, so that no builder branches on the width. The canvas's Mac board (`Mac.dc.html`): the column `navigationSplitViewColumnWidth(min: 280, ideal: 280)`, rows 30 pt with a background radius of 7, the tile at 20, 6 and 13, the title at the system's sidebar size, the count in ink2 and the disclosure chevron at the right, pinned while the tree scrolls sideways past a title of 90 pt; an area's line 15 pt alone and 28 pt while renaming, its name always on it when it has one (the spec over the Mac board's hover). The drag's indicator and the bar's sizes are read from the same board on the day and listed in the pull request.
- The views draw what Task 8's draw: the title from `row.title` with the `Text` renderer, the tile with `ListTile(row.tile)`, each menu from `row.menu`, the bar from `model.bar`, the dialogs through `ListsDialogs`. A view switches over the six enums `docs/style.md` allows and over `FillModel`, which takes `ButtonModel.Fill`'s place there.
- Without edit mode (the Mac) the module builds no "…", no edit items and no grips, and the drag runs at any time; with it (the iPad) the bar of Tasks 7 and 8 stands at the bottom of the column with edit mode as on the phone, and the long press opens the menus. Open in New Window where `opensWindowsBeside`.
- At the bottom of the Mac's column: the search field, inert, on the fill colour; a 30 pt round "+" in the accent, a `Menu` with New Task `⌘N`, New List `⇧⌘N` and New Area, the shortcuts from the items' `shortcut` through `keyboardShortcut`. The toolbar's New Folder is gone; the list's Quick Entry button stays.
- The words are Title Case, as the phone's: New List, Delete Area, New Task (Task 7's call, which Task 8's models carry); the spec writes them in sentence case in its prose.
- The Mac's drag reuses `ListsDrag`'s reading of a slot's place and depth with the pointer, since a `List` with `onMove` offers no depth (spike #145, approach A), and draws `DragModel.Indicator` for a drop between rows and into a parent, sending the same `rowDropped`.
- The one platform condition in the sidebar, `#if os(macOS)`, is the right click that opens a row's menu; the iPad's long press is the phone's. A Plus or Max iPhone turned sideways reports the regular class and gets this sidebar, as it gets the split view today; nothing here reads the device.
- `ChoiceModel` gets one renderer once the sidebar draws the dialogs a third time (#161's review); the sidebar's sentence under the rows, and on the pane while the column is hidden, as today.

**Tests.** `TaskViewListComponentsTests`: the wide window's rows, lines, bar and drag whole with the sidebar's numbers, with and without edit mode; the menus with each capability. The other feature tests and `AppModuleTests` take `WindowCapabilities`. `TodoAppTests`: `makeWindow` passes both capabilities through, at one width. The probe drives the wide models; the budget is re-measured. By hand on the Mac in both appearances, on an iPad Pro 11-inch (M5) in both orientations, and on an iPhone 17 Pro Max turned sideways, with screenshots in the pull request; the phone's 34 shots retaken with Task 8's harness and compared.

**Verified facts and traps.**

- The Mac's `horizontalSizeClass` is nil and reads as wide; the iPad's regular class and a Plus or Max iPhone's sideways class read as wide (`WindowView`).
- `supportsMultipleWindows` is true on the Mac and on the iPad with the multiple-scenes declaration (`TaskViewListView`, 2026-10-18), and is available on watchOS from 9 in Xcode 27.1's SDK (#161).
- Trap: a root whose body reads the split view's column visibility redraws the stack and loses the pushed task's background (`HiddenSidebarStrip`, #133); the sidebar reads nothing of the split view.
- Trap: the Accessibility API's `AXShowMenu` is unsupported on a SwiftUI sidebar's outline rows (`-25206`, macOS, 2026-10-30), so a hand check of the Mac's menus needs a real right click, the owner's mouse: ask first.
- `FillModel`, `WindowCapabilities` and `Shortcut`'s nesting: the two top-level names get the probe of Task 8's names before they are fixed.

## Self-review against the spec

- Problem and goals: Tasks 5 to 9 replace the scaffold; the non-goals have no task, the badge included.
- Section 1: Task 5 draws the rows and lines, Task 7 the screen, Task 9 the sidebar; Logbook and Trash stand where the seed ranks them, nothing names them. Section 2: Task 2. Section 3: Task 5's placements and the area's name, Task 6's root rule and the area's deletion. Section 4: Task 3's counts and Task 5's reread; the badge is out of the epic. Section 5: Task 5's model and Task 6's dialogs and drop; the route unchanged; the folds in Task 2's table through Task 5. Section 6: Tasks 5 and 6. Section 7: Task 4's spike, Task 6's edit mode and area drop, Task 7's screen. Section 8: Task 9. Section 9: Task 1, Task 5's tiles and title fonts, and Task 8's component models. Section 10: every row has a task. Testing: each task's tests and hand checks. Risks: the drag is Task 4; the wide tree is Task 7's sideways scroll; the counts' cost is Task 3's measurement; midnight is accepted; the area's two writes are Task 6; the marked text is the field's as today; a deleted Inbox leaves quick entry to say so, as today; the wasm budget is Tasks 5 and 6.
- Deviations, each the engineer's call, for the owner's review:
  - A new list is not declared over the sidebar when it is made: today's folder declares its list, and on a narrow window that would push the list over the sidebar while the name field is open. The field opens; the highlight stays.
  - `taskCounts(today:)` where the spec says `counts(today:)`, since the number is a count of tasks; `countStatement` beside `viewStatement` so that the plan test explains the statement itself.
  - `PickerRow` carries the row and two flags where the spec says "rows of the same shape", so that the picker's view switches over the same `Kind` and reads two Bools.
  - The drop's depth is clamped to what the rows allow, since the view's slot offers only those and the module trusts nothing a view sends.
  - A fold whose device-state write fails stays folded and says nothing: the fold is on screen, the next fold writes the set again, and the module's sentences stay for the data a person edits.
  - A list with no colour draws stone's tile colour; the canvas gives a new list blue, the spec gives it none, and the spec wins for the behaviour while the look of "none" is stone's, which the module picks as it picks the bullets glyph for no icon (Task 5).
  - The foundations come before their callers, as the spec orders the epic; the pull request names Task 5, which builds the tiles and chooses the fonts, and Tasks 7 and 9, which draw them.
  - `TaskViewListView` is adapted twice before the look arrives, as the navigation plan adapted the root view, so that every merge works.
