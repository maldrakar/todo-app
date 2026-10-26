# ADR-0010: Keep a device's own UI state in the store, outside the journal

- Status: Accepted
- Date: 2026-10-25
- Related: `docs/specs/lists-screen.md` (approved 2026-10-25), `docs/specs/feature-module-architecture.md` (approved 2026-09-20), #138, ADR-0002, ADR-0003, ADR-0005, ADR-0009, PR #150
- Amended: 2026-10-26, after the owner's review of PR #150 (see the end)

## Context

Some of what a screen shows is neither the data nor the window's address: which branches of the sidebar are folded, and, later, which tasks a list has shown on this device. The feature-module spec left where such state lives to the first module that needs it, and the Lists screen is that module. The owner wants folds kept per device and not synced (2026-10-25): a person who folds a branch on the phone has not folded it on the Mac. A route is the window's address and a relaunch's state, so it is not the place; the journal of ADR-0003 syncs everything in it, so it is not the place either; and every platform, the web through WASM included, has to keep the state the same way, which rules out a platform's own storage behind a protocol of its own. The store of ADR-0002 is already one file per device on every platform. The spec's section 5 holds the discussion.

## Decision

The store keeps a device's own UI state in a table of its own, `device_state(key, value)` (working name, settled in the plan), outside the journal: never journaled, never synced, never pushed to a peer. It is read and written through the store like everything else, `Store.deviceState(_:)` and `Store.setDeviceState(_:_:)`, and it is part of the schema, so a version bump carries it and every platform's tests cover it. A key is a module's own, named for the module and what it keeps, and its value is text the module encodes and decodes; the first key holds the sidebar's folded branches. Whether a write to a key reports a change set is the key's own rule, written where the key is defined: the folds report none, since the fold is one screen's own and two windows of one Mac that share the row learn of each other's fold at their next reread. A backup of the file carries the table, since it is the file's, so a restored copy starts with the folds the original had, which is harmless and accepted. The state is the kind a person made on this device's screen that no other device should repeat and no link addresses: folds, what a list has shown, the width of a column. Not the selection, which is the route's, and not session state such as an open rename, edit mode or a dialog, which a relaunch loses by design (ADR-0009, amendment of 2026-10-25).

Alternatives. Folds in the window's route lost: two windows would fold independently and a link would carry a fold. Folds in the journal lost: the owner wants them per device. `UserDefaults` behind a protocol the platform implements lost: more plumbing for one set of ids, and the web would need an implementation of its own, when the store is already there on every platform.

## Consequences

Easier: every platform keeps the state the same way, and the host and wasm32 test it; a module that needs such state names a key and nothing else. Harder: the store's API gains a key-value corner beside its typed reads, and a module decides for itself how to encode what it keeps, so a key's format is the module's to keep stable across its own versions. Constrained: per-device UI state lives here and nowhere else, not in the route, not in the journal, not in a platform's storage; nothing in this table is ever sent to another device. Reversing this decision means moving the keys into the journal, with a migration that writes them as operations, or into each platform's storage, which the web would have to grow.

## Amendment, 2026-10-26

Made in the owner's review of PR #150, which built the table and its two calls (#143). The decision said a key's value is text the module encodes and decodes. The owner wants the store to keep the module's own value instead, since a module's state will grow beyond text, and a module that writes text has to invent and parse a format of its own for every shape it keeps.

**The store keeps a key's value as JSON of a `Codable` type the module names, and a value that does not decode as that type reads as nothing kept.** `Store.setDeviceState(_:_:)` takes a value of any `Encodable` type and keeps its JSON in the same text column, written by the encoder the core already uses for a view's filter, so the schema stays as it is and no second encoder is linked into the bundle; `Store.deviceState(_:as:)` decodes it as the type the module asks for. A value that is not text, that nests deeper than the core reads, or that does not decode as the type reads as nothing kept, the way a value the type cannot hold reads as absent everywhere (`docs/style.md`), and a value the store could not read back is refused at the write with a sentence. Writing no value no longer removes a key, since nothing calls for it: the sidebar writes an empty list when nothing is folded.

Consequences. Easier: a module keeps a list or a struct as it is, and its format is the type's `Codable` form. Harder: a module that changes its type so that the old JSON no longer decodes loses what it kept, once, which is accepted for state a person rebuilds with a tap. Constrained: a key's value is JSON of the one type its module names; the table's schema does not change.
