# todo-app

A reminders app in the spirit of Things 3, with one shared core and native UI per platform.

- Target platforms: iOS, macOS, iPadOS, watchOS, and the web via WASM.
- The shared core is written in Swift and restricted to the standard library and FoundationEssentials, so that it compiles for every target above (ADR-0001).
- UI is platform-specific: the Apple apps are built in SwiftUI, and React is the likely choice for the web, decided when the web client is built.

## Status

Milestones `M0 Process`, `M1 Core architecture`, `M2 Feature-module architecture` and `M3 Navigation` are complete,
the last three released as `v0.1.0`, `v0.2.0` and `v0.3.0`. The core stores tasks, tags and views, resolves the tree
their parent links describe, filters, sorts and groups them into pages, searches titles and notes, and exchanges a
journal with another copy of itself; it builds and passes its suite on the host and on wasm32, and `todo` drives all
of it from a command line. M2 built the module contract in the shared core, the list of views and the root module
over it, which pass their suites on the host and on wasm32 as the core does, and the macOS app in `Apps/Apple` that
hosts them. M3 built the screens below the sidebar, the list of a view's tasks and a task's own screen, each
declared by the screen that opens it and standing in the window's one stack, and quick entry, which the root holds
(ADR-0009); a route for every screen, and one text form for a window's route, which is the link and what the window
is restored from; a layout, one stack or a split view, that the root module decides from the width its window
reports; and a host per window over one store per process. Its modules pass their suites on the host and on wasm32
as M2's do, the macOS app opens more than one window, and the iPhone and iPad app, built from the Xcode project in
`Apps/Apple` over the same views, takes links and restores its windows. Product functionality, `M4`, is next.

## Documents

- [`docs/brief.md`](docs/brief.md): the original project brief.
- [`docs/process.md`](docs/process.md): how the project is run, from backlog to release.
- [`docs/adr/`](docs/adr/): architecture decision records.
- [`docs/specs/`](docs/specs/): design specs. [`docs/plans/`](docs/plans/): implementation plans.
- [`CHANGELOG.md`](CHANGELOG.md): what changed in each version.

## Building

The core is a SwiftPM package built with the swift.org toolchain pinned in `.swift-version` and installed through [swiftly](https://www.swift.org/install/); Xcode 27.1 supplies the Apple SDKs, and its own toolchain is the same Swift 6.4.0. Installing the pin needs swiftly 1.1.4 or later, because from 6.4 on swift.org names a release with its `.0`, and an older swiftly looks for `swift-6.4-RELEASE` and gets a 404.

```sh
swiftly install                      # reads .swift-version
swift build
swift test                           # host
swift test --swift-sdk swift-6.4.0-RELEASE_wasm --disable-xctest   # the same suite on wasm32 under WasmKit
swift run todo --help                # command-line demo
scripts/wasm-size.sh                 # release wasm build, measured against the size budget
```

The WebAssembly SDK is installed once with `swift sdk install <url> --checksum <sha256>`; the URL and checksum are in `.github/workflows/ci.yml`.

`--disable-xctest` skips nothing, since every test here is swift-testing. It keeps the wasm32 run working on macOS when `--filter` is added: without it, a filtered run there calls Xcode's `swiftpm-xctest-helper` on the test bundle, which cannot load one built for wasm32 (#76).

## Trying the core

`todo` is the command-line demo of the core and the runnable part of `M1`: every command goes through the
public API of `TodoCore` and prints one fact per line.

```sh
export TODO_DB=/tmp/demo.sqlite
swift run todo add "Write the plan" --when 2026-09-11 --tag work --notes "before the review"
swift run todo list Today
swift run todo find plan
swift run todo --help                # every command, with its options
```

A task is named by any prefix of its id that names a single task and a view by its title or by a prefix of
its id, and every line that names one of them ends with the id to type next; a tag is named by its name. An
option a command does not take, one with no value, and a word left over from a value that lost its quotes
are all refused by name rather than folded into a title. `TODO_DB` says which database to open and
`--db PATH` outranks it; without either, the demo opens `todo.sqlite` in the working directory.
`TODO_TODAY=YYYY-MM-DD` says what day the query is made on, so that `Today` and `Upcoming` answer the same
thing when the demo is run again tomorrow. A command the demo refuses exits 2, one the core refuses exits 1.

Beside the database the demo keeps one more file, `<database>.device`, holding the device this copy writes
under. It is not in the database on purpose: a database carries its contents to every machine it is copied
to, and the journal needs two copies of one database to be two devices, or they stop seeing each other's
edits. So copy `demo.sqlite` on its own and the copy becomes a device of its own; copy the pair and both
machines claim one identity. `TODO_DEVICE` names it instead, which is how one machine plays two.

## Running the app

`todo-mac` is the macOS app, the runnable part of `M2` and, beside the iPhone and iPad app below, of `M3`. It lives
in `Apps/Apple`, a package of its own beside the root one, because the root package is built on Linux and for
wasm32, where there is no SwiftUI (ADR-0007); swiftly finds the root's `.swift-version` from there, so it builds
with the same pinned toolchain.

```sh
cd Apps/Apple
swift run todo-mac
# in a second terminal, also in Apps/Apple: another database, another device
TODO_DB=/tmp/second.sqlite swift run todo-mac
# the first window opens on a route, here a task in Today
TODO_ROUTE=/view/00000000-0000-4000-8000-000000000002/task/<task id> swift run todo-mac
```

It opens a window: the list of views in a sidebar, and beside it the tasks of the view chosen there. The sidebar is
the canvas's: each list a row with its tile, its title and the number of its open tasks, a chevron on a list with
lists inside it that folds the branch, guides down the levels, and each area a line across the column with its name
on it in capitals; a tree too deep for the column scrolls sideways, and the counts and chevrons stay at its right
edge. A click chooses a list. A right click opens Rename, New List, Open in New Window, Move to… and Delete on a list,
and Rename, New List and Delete Area on an area's line. Rename opens a field on the row: Return or a click away keeps
the new title, a blank one is refused with a sentence under the rows, and Esc keeps the old title. Move to… opens a
sheet of the whole tree to choose the new parent from, and Delete always asks. A row can be dragged at any time, a list
with the lists inside it or an area with its lists, to a new place, and sideways for a new level, a line with a circle
marking where it lands; the Mac has no edit mode. At the bottom of the sidebar the search field does nothing yet, and
the + holds New Task, which opens quick entry, New List, which adds a list at the end of the last area, or of the tree
when there is no area, with its field open and the highlight where it was, and New Area, which adds an unnamed area at
the end, a line with its name field open. The File menu holds the same three for the window in front, New Task on ⌘N
and New List on ⇧⌘N, the keys the + shows beside them, and New Window on ⌥⌘N, which opens another window on the Inbox.
A click on a task pushes its screen, which shows its title,
over the list, and the back button returns to the list. Quick Entry, the + on the list's toolbar, opens a sheet with
a title field: Return or Add puts the task in the Inbox and closes the sheet, a blank title is refused with a
sentence in the sheet, and Cancel or Esc closes it and writes nothing.

Open in New Window, in a list's context menu, opens that view in a window of its own, every time, on the view a window
shows too; every window shows what the others write.
`TODO_ROUTE` is the route the first window opens, in the text form a link carries after `todo://`: a path,
`/view/<id>` or `/view/<id>/task/<id>`, with a list opened over the list before the task, `/view/<id>/view/<id>`, or
one of the list's own groups, `/view/<id>/day/+1` (`day` and `deadline` with a distance from today, `+1`, `0`, `-2`
or `none`; `tag` and `parent` with an id or `none`; `status` with `open`, `done` or `canceled`), and `?quick-entry`
after it to open quick entry too. One that does not read opens the Inbox, as no `TODO_ROUTE` does, one naming a view
that is gone opens no list and says so under the sidebar, and a group its list is not grouped by opens the list and
says so under it. The executable has no bundle, so no `todo://` link reaches it while it runs, and macOS does not
restore its windows after a relaunch. No bundled Mac app exists in this milestone: the Xcode shell (#96) builds the
iPhone and iPad app, and the Mac stays on `todo-mac`.

`TODO_DB` is the database's whole path and `TODO_DEVICE` the device it is written under, each read as unset when
it is exported empty. Without `TODO_DB` the app opens `~/Library/Application Support/todo/todo.sqlite`, and the
first launch creates the directory and the database; the directory is named for the app because the app has no
bundle whose identifier could name it. Without `TODO_DEVICE` the device is the one kept in `<database>.device`
beside the database, the same file the demo keeps, and a launch that finds none there mints one and keeps it. So
two copies of the app on one machine, each over a database of its own as above, are two devices. A launch that
fails, for example over a path that cannot be opened, stops the process with "The app could not launch:" and the
reason.

## Running on iPhone and iPad

The iPhone and iPad app is the Xcode project `Apps/Apple/Todo.xcodeproj`: one app target whose `@main`, in
`Apps/Apple/Sources/todo-ios`, opens the same scene from `TodoAppleUI`, with an Info.plist that registers the `todo`
scheme and lets the iPad open more than one window (ADR-0008). Its file, `project.xcproj`, is the JSON project file
that Xcode 27 is the first to read. Open the project in Xcode, choose the scheme `Todo`, the app's and not `todo`, the
command-line demo's, which Xcode lists beside it, choose a simulator, and run; or, from the repository's root:

```sh
xcodebuild -project Apps/Apple/Todo.xcodeproj -scheme Todo -destination 'generic/platform=iOS Simulator' \
  -configuration Debug -derivedDataPath /tmp/todo-ios CODE_SIGNING_ALLOWED=NO build
xcrun simctl boot 'iPhone 17' && open -a Simulator
xcrun simctl install booted /tmp/todo-ios/Build/Products/Debug-iphonesimulator/Todo.app
xcrun simctl launch booted dev.maldrakar.todo
# a link into the running app, here a task in Today
xcrun simctl openurl booted 'todo:///view/00000000-0000-4000-8000-000000000002/task/<task id>'
```

The app keeps its database in its own container, at `Library/Application Support/todo/todo.sqlite` under the
directory `xcrun simctl get_app_container booted dev.maldrakar.todo data` prints, made by the app's first launch. The
demo fills it with `TODO_DB` set to that path, once the app is stopped:

```sh
xcrun simctl terminate booted dev.maldrakar.todo
CONTAINER="$(xcrun simctl get_app_container booted dev.maldrakar.todo data)"
TODO_DB="$CONTAINER/Library/Application Support/todo/todo.sqlite" swift run todo add "Buy milk"
```

The window holds the Mac's views. iPhone shows them as one stack, the Lists screen, a view's list over it and a task
over the list, and the back button or a swipe from the left edge goes back one screen; back on the Lists screen, the
list is closed and no view stays highlighted. The list is titled by its view and the task by its own title, so the back
button's long-press menu over a task names its list; the Lists screen has no title, and its row in that menu is blank.
A link to a view that is gone leaves the screens as they were, and "The list could not be opened." stands at the bottom
of the screen on top, a task's included; in a wide iPad window it stands at the bottom of the pane while the sidebar
is hidden, and under the sidebar's rows while it shows. A swipe down closes quick entry's sheet as Cancel does. On the
iPad, Open in New Window, in a sidebar row's context menu, opens that view in a window of its own. A link opens its
view or task in the window it reaches, and one that does not read, `todo://view/<id>` one slash short among them,
leaves the window as it was and says "The link could not be opened." across its bottom, until the Quick Entry button
or a link that reads takes the sentence away.

The Lists screen on iPhone is the canvas's: each list a row with its tile, its title and the number of its open tasks,
a chevron on a list with lists inside it that folds the branch, guides down the levels, and each area a line across
the tree, with its name on it when it has one; a tree too deep for the screen's width scrolls sideways, and the counts
and chevrons stay at its right edge. A tap opens a list, and a long press opens Rename, New List, Move to… and Delete
on a list, and Rename, New List and Delete Area on an area's line. At the bottom, "…" holds Edit, the search capsule
does nothing yet, and "+" holds New Task, which opens quick entry, New List, which adds a list at the end of the last
area, or of the tree when there is no area, and New Area, which adds a line at the end; each opens its name field on
the new row, scrolled into view. Edit mode takes the counts away and gives every row a grip: a tap on a row or a line
opens its name field, a long press lifts a row, a list with the lists inside it or an area with its lists, and carries
it to a new place, sideways for a new level, and the bar holds + List, + Area and Done. Move to… opens a sheet of the
whole tree to choose the new parent from, and Delete always asks. A wide window, the iPad's and that of an iPhone Plus
or Pro Max turned sideways, draws the same tree as the Mac's sidebar with the phone's gestures: a long press opens a
row's menu, the bar at the bottom of the column holds "…", the search capsule and "+", and in edit mode a long press
lifts a row, a line with a circle marking where it lands.

The list screen on iPhone is the canvas's too, in a narrow window; a wide one, the iPad's or that of an iPhone Plus or
Pro Max turned sideways, draws the pane of the Mac and the iPad, below. The glass back
and "…" float at the top corners over the list, which scrolls under them, and under them the list's tile, its title, the
day it shows when its rule names one, and a bar of the tags its open tasks carry: a tap lights a tag and the list or the
board shows the tasks that carry any tag lit. The list's own tasks come first, then a block for each list inside it, or
for each day or group its rule makes; a block's chevron folds it and a tap on its title opens it as a screen of its own,
and each block ends with "+ Add task", which opens a new task's card in place with the keyboard up. "+ Add list" ends
the screen and names a list in a field of its own, and the round "+" at the bottom right adds a task at the top of the
first block. A tap on a task opens its card where its row stood, with its title, notes, subtasks, the pills for its day,
deadline and tags, and an arrow for its full screen; Return in a subtask's field writes the subtask and opens the next,
and a tap on the screen's background closes the card. A tap on a task's circle completes it: the row holds for a moment
with its check filled and its title struck, then leaves, and the strip "Done today" under the blocks counts it and opens
to show it. A swipe to the left on a row slides out Delete, which puts the task in the Trash; a press that holds still
opens a menu with Delete, and a press that moves lifts the row, with a line and a circle marking where it would land in
its block, and another block or on a board a column tinted where it would go, since the block puts it in its own order;
a task that lands in a list is tinted for a moment, and on a board it springs into its place. "…" opens Show as, where
Columns, when the list offers them, turns the blocks into a board of columns that snap one at a time, and where Columns
is greyed with its reason when it does not. A swipe from the left edge, or the back circle, goes back one screen. The
screen's own "+" adds inline, so no Quick Entry button stands on it; quick entry stays the Lists screen's.

On the Mac and in a wide iPad window the same screen is the detail pane beside the sidebar, at the Mac's numbers: the
content stands at most 780 points wide in the middle of the pane, rows are 36 points high with their notes, subtasks,
tags and deadline on the title's line, and a board's columns are 288 wide and scroll freely sideways, with no snap. The
capsule with "+" and "…" stands at the right of the window's bar, and the bar has no title over the list's own. Only a list
opened over another has a way back, since the sidebar is the way back to any other list: on the iPad the glass back,
beside the button that shows the sidebar, and on the Mac the toolbar's own back, as on a task opened full screen. A
click opens a task's card where its row stood, Esc on the Mac closes it unless text is being typed in the window, where
Esc is the field's first, ⌘. closes it too, and the right click opens the row's menu with Delete. A list chosen
in the sidebar opens at its top. The Mac's pointer drags a row of a list or a card of a column the way a finger
does on the iPhone, with the line, the circle and the tint, carrying a copy of the row under the pointer; it scrolls
nothing by itself, and a release outside the part of the list in sight puts the row down where it was. The iPad drags
with the system's drag and drop, opens the system's menu on a press that holds still and slides out Delete on a swipe,
as the iPhone does. Under the pointer a row, a block's header, "+ Add task", the Done strip, a tag's chip and the
capsule's buttons are tinted. In portrait the bar's button shows the sidebar over the list and the same button in the
sidebar hides it, and a wide iPad window in landscape opens on the pane alone, the same button bringing the sidebar.
The Mac keeps its window title in the toolbar on macOS 14.

iOS asks "Open in “Todo”?" before it hands the app a link from `simctl openurl`. After the system ends the app in
the background, the next launch opens the window on the route it showed.

A device needs signing: copy `Apps/Apple/Signing.xcconfig.example` to `Apps/Apple/Signing.xcconfig`, which git
ignores, put the Team ID of your Apple developer account in it, sign in to that account under Xcode's Settings >
Accounts, and Xcode signs the app automatically under that team. The team goes in `Signing.xcconfig` and never
through the target's Signing & Capabilities editor, where Xcode's error without a team points: the editor writes the
team into `project.xcproj`, which is committed. A personal team's app does not launch on the phone until the phone
trusts its developer, under Settings > General > VPN & Device Management. A checkout without `Signing.xcconfig`
builds for the simulator unsigned.

`project.xcproj` is written by hand and kept in the form Apple's `xcprojformatter` writes: `swift test` in
`Apps/Apple` fails when it is not, and the formatter puts it right.

```sh
cd Apps/Apple
swift run xcprojformatter --update Todo.xcodeproj
```

### Walking the list screen

The list screen's walks are XCUITest walks over the real app: a drop within a block, into another block, into a column
and across columns, the swipe and its Delete, the still hold's menu, completing, the card's fields, Show as, going
back with a card open, and the sentence strip under the floating "+". They are `TodoUITests`, the second target of
`Todo.xcodeproj`, with their sources and their seed in `Apps/Apple/UITests`, and one script runs them:

```sh
scripts/ui-walks.sh                                   # every walk, on a new iPhone 17
scripts/ui-walks.sh DropWalks SwipeWalks/testSwipeRules
scripts/ui-walks.sh --device "iPhone 17 Pro Max" --record BackWalks
```

The script creates a simulator device of its own, so it never touches one that is running, builds the `todo` tool and
the app with its walks, seeds a store through the tool, runs the walks named or all of them, and deletes the device
on every exit, a failure or Ctrl-C included. Each walk launches the app over a fresh copy of that store and asserts
what can be read from outside the app: an order of rows by their frames, an element and its label, a title still
there after the app is launched again. What it cannot read, a drag's tint or its drop line, it names in its comment,
and `--record` films the device's screen for a person to look at. The run prints each walk's result and the directory
that keeps its log, its result bundle with a screenshot of every failure, each walk's store and the film. It runs
with Xcode 27.1, as `xcode-select` or `DEVELOPER_DIR` names it; a run of every walk takes about WALK_MINUTES minutes.

A pull request that changes the list screen runs the walks before it opens (`docs/process.md`, section 6). Xcode's
Test action on the scheme `Todo` skips every walk, since only the script seeds the store they walk over, and CI
builds the walks but runs none.

## Continuous integration

Every pull request runs two jobs. The first, on Linux, runs build, the suite on the host, the same suite on
wasm32 under WasmKit, and a release wasm build measured against a size budget.

What that last step measures is `wasm-size-probe`, an executable that exists to be measured and is no part of
the product. The budget is about what a web client downloads, and the `todo` demo is the wrong stand-in for
one: it carries an argument parser, a formatter and a usage text no browser will ever load. The probe instead
does what a web entry point will: it builds the root module over a store in memory and drives it — choose a
view, rename it, make a list, a list inside it and an area, fold a branch, ask the sidebar for a new task, follow
a link with `?quick-entry`, file a task through quick entry, push the task and go back, open quick entry again and
cancel it, choose Open in New Window on a view — and beside it calls the public API of `TodoCore` directly — write
through a store, read a page, search, exchange a journal, take a snapshot — because the linker keeps what a client
calls, and a number measured on calls that were dead-stripped is a number for a binary nobody ships.

The budget is 7.3125 MiB after `gzip -9` and lives in one place, `scripts/wasm-size.sh`, which is the command
CI runs and the command to run locally. It is the root module and the core as they stand with four percent to
spare, rounded up to a whole 64 KiB: a guard against growing sideways, not a target to shrink towards. The
4.5 MiB the spec first named was never measured — it is the floor measured in the toolchain spike, 3,743,306
bytes of standard library, FoundationEssentials and SQLite with no core code reachable, plus half a megabyte of
slack for the code the core would add. That code, with the JSON coding it pulls in, costs 2.8 MB instead, and
SQLite and FoundationEssentials are inside the floor on both sides of the comparison rather than the difference
between them. The ceiling that means something arrives with the web client, measured on its bundle.

A second job, on GitHub's `xcode-27` macOS runner and with Xcode 27.1, the Xcode the app is built with, for
every step, first checks that Xcode's own toolchain is the version `.swift-version` pins, since the image is a
preview whose Xcode can change under the job. It then compiles `TodoCore`, and `TodoAppleUI` from `Apps/Apple`,
against the iOS and watchOS SDKs, builds and tests `Apps/Apple` with the pinned toolchain, and builds the root
package and `Apps/Apple` with Xcode's toolchain too. Those two builds stay because Apple accepts store
builds from Xcode's toolchain, and because they are what shows that, from Xcode 27 on, the pinned toolchain and
Xcode's are one version (ADR-0008). Its last step builds the iPhone and iPad app from `Apps/Apple/Todo.xcodeproj`
for the simulator, unsigned, with the `xcodebuild` command "Running on iPhone and iPad" gives, as
`build-for-testing` so that the list screen's walks are built with it though none runs, and the derived data under
the runner's temporary directory. The job runs on every pull request, because GitHub-hosted runners cost
nothing on a public repository. If the repository goes private again, the job goes back to `main` and on demand,
because macOS minutes cost tenfold there.
