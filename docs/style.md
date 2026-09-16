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
