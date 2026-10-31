# Code rules

Rules the owner's reviews have established, written down so that a diff
meets them before the owner sees it. They bind the engineer and every
agent that implements or reviews a diff, and both get this file before
they start. The owner edits it directly. A rule that a review
establishes twice is added here in the pull request that got the review.
Each rule names the review that set it.

## Surface

- **Tightest visibility by default.** Every member starts `private` and
  widens only when a call site forces it. When something outside needs
  a private member, expose the operation, not the member:
  `Connection.lastError(code:)` rather than the raw handle. `internal`
  only where another file of the same module genuinely reads it.
  (PR #27, #31, #35)
- **No API without a caller.** A member, an accessor, an overload or a
  protocol conformance is added in the task whose code first calls it.
  One kept for a later task says in the pull request which task.
  (PR #27, #35, #36)
- **A lower layer holds no policy of its client.** Configuration comes
  in as a parameter from the caller, `Connection.open(path:pragmas:)`,
  never as a default chosen inside the layer, so changing the policy
  never means editing the layer below. (PR #27)
- **One way to build a value.** A default argument over a factory:
  `EntityID()` mints and `EntityID(raw)` wraps, and a `generate()` next
  to `init` is redundant. (PR #31)
- **A name says what it holds and whose it is.** A type, a property
  or a case is named for what it carries and for its owner, not for
  its part in a mechanism: `Destination`, held in a screen's
  `destination`, and not `Slot`; `.destinationAnswered` and not
  `.answered`, which says neither whose answer it is nor to what;
  `setDestination(_:)` and not `declare(_:)`. (PR #120, #125)
- **A name the core exports is a name its consumers lose.** No exported
  type takes a name a module the consumers import already owns:
  `TodoTask` and not `Task`, which shadowed `_Concurrency.Task`;
  `TaskView` and not `View`, and `TaskViewPage.Section` and
  `TaskViewPage.Group` and not `Section` and `TaskGroup`, which SwiftUI
  and the standard library own; `JournalOperation` and not `Operation`,
  which is Foundation's and reaches every Apple consumer through
  Foundation and through SwiftUI. The collision is invisible here,
  because the core imports neither, and it costs every file in the app:
  an ambiguous type is an error at each use, and a shadowed one fails
  with something that does not name the cause. A candidate is settled by
  a compiler probe against the real modules, and the name a consumer
  needs is held by a test that spells it. (#42, PR #46, #49)

## Shape

- **A value type is immutable unless something mutates it.** Fields are
  `let`. A test that needs a different value builds one instead of
  editing one. (PR #36)
- **One shape everywhere it fits.** Logic that exists in two places is
  collected into one function that both call. A write that mirrors
  another write is shaped like it, `writePairRow` like `writeEntityRow`.
  A result callers usually drop is `@discardableResult`. (PR #36)
- **Two statements where one would do get questioned.** A repeated
  string literal becomes a constant. A value is assigned after the write
  that persists it, not before. A nested `switch` is worse than repeating
  the write per case. (PR #35, #36)
- **A failure says what failed.** Input from a person, a file or another
  device is parsed with a typed throw that carries the offending value,
  not with a failable initializer that answers `nil`. (PR #31)

## Data from outside

Everything in a database file, in the journal or from another device was
written by a version of the app that may be newer, older or wrong, and a
value a peer wrote is as arbitrary as one a person typed.

- **A trap is a bug.** No `precondition`, force unwrap or narrowing
  conversion such as `Int32(_:)` on such data. A value the type cannot
  hold reads as absent, the way an unusable parent link reads as no
  link. A stored value that traps does so on every later read, so the
  process dies on every open until the file is deleted. (#34, PR #40)
- **No recursion over data-shaped depth.** A chain thousands deep
  arrives from sync as easily as a shallow one, and the wasm32 stack is
  64 KiB. Walks over the data are iterative. (PR #38, #40)

## Modules

- **A module's model is computed from its state, never stored.**
  What a module's events move is held in one private `State`, and
  the model is read from it:
  `public var model: Model { state.model }`. A model kept beside the
  state is a second copy of the same values, and the two disagree
  the moment one is moved without the other. (PR #77, #101)
- **A user action names the control and the gesture, never what the
  module does about it.** `rowTapped(id)`, `quickEntryButtonTapped`
  and `wentBack(to:)`, not `openTask(id)` or `taskScreenDismissed`:
  the view reports what the person did, and what that means, opening
  a task or closing a screen, is the module's to decide. (PR #66, #101)

## Views

- **A view holds no condition over a domain value and formats
  nothing.** Every `if` in it is over a `Bool` or an optional of the
  model, and every string about the data arrives finished from its
  module. Its own labels, a button's title or an empty pane's
  placeholder, are its vocabulary, localised by the platform, where no
  component's model gives them: a component's model carries its own
  words (ADR-0007, amendment of 2026-10-30). It keeps
  only what only it can know, such as focus, scroll, hover, the
  window's width, which it reports (below), or a drag in progress.
  (ADR-0006, spec section 2)
- **A view reports the width of its window and decides nothing by
  it.** It hands the width class, narrow or wide, to the host's
  entrance for events of the world, as it hands a link, and draws the
  layout its model gives it: it chooses no tree of containers by the
  width, assembles no path, and reads no route to decide what to
  draw. (Owner, 2026-10-22, #117; ADR-0006, amendment of 2026-10-22)
- **A view may switch over three enums of its model, three of its
  components' models, and no others.** The shape of its layout; the
  screens of a stack, in one place per stack, to pick a view per case;
  and the kind of a row, to pick the row to draw. Of a component's
  model: what a button stands on, `ButtonLabelModel.Fill`; what stands
  on a bar, `BarModel.Item`; and what stands at a row's right,
  `AccessoryModel`. It is dispatch and not a condition over data: every
  case is drawn, with no `default`, so a screen added to a stack and
  not drawn stops the view compiling. (Navigation state spec, sections
  4 and 6, #117; ADR-0006, amendments of 2026-10-22 and 2026-10-25;
  the row's kind is the owner's call on the Lists screen spec, #138;
  the components' enums are the Lists screen plan's Task 8, #161, as
  the owner's review of #163 shaped them, and ADR-0007, amendment of
  2026-10-30)

## In a review thread

- A language question is settled by a compiler probe pasted into the
  thread, not by memory of the language. (PR #35)
- A cost question is answered with numbers from a release build, since a
  debug build is four to six times slower here, and with the named
  alternatives. (PR #35, #38)
- A timing assertion is refused when the gap it must resolve is below
  the noise of a shared runner; a deterministic count goes in instead,
  such as rows written or statements run. (PR #38)
- Every comment gets a reaction, and a counter-argument goes into the
  thread under 👀 before any code changes (`docs/process.md`, section 6).
