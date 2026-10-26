# ADR-0010: Keep a device's own UI state in the store, outside the journal

- Status: Accepted
- Date: 2026-10-25
- Related: `docs/specs/lists-screen.md` (approved 2026-10-25), `docs/specs/feature-module-architecture.md` (approved 2026-09-20), #138, ADR-0002, ADR-0003, ADR-0005, ADR-0009

## Context

Some of what a screen shows is neither the data nor the window's address: which branches of the sidebar are folded, and, later, which tasks a list has shown on this device. The feature-module spec left where such state lives to the first module that needs it, and the Lists screen is that module. The owner wants folds kept per device and not synced (2026-10-25): a person who folds a branch on the phone has not folded it on the Mac. A route is the window's address and a relaunch's state, so it is not the place; the journal of ADR-0003 syncs everything in it, so it is not the place either; and every platform, the web through WASM included, has to keep the state the same way, which rules out a platform's own storage behind a protocol of its own. The store of ADR-0002 is already one file per device on every platform. The spec's section 5 holds the discussion.

## Decision

The store keeps a device's own UI state in a table of its own, `device_state(key, value)` (working name, settled in the plan), outside the journal: never journaled, never synced, never pushed to a peer. It is read and written through the store like everything else, `Store.deviceState(_:)` and `Store.setDeviceState(_:_:)`, and it is part of the schema, so a version bump carries it and every platform's tests cover it. A key is a module's own, named for the module and what it keeps, and its value is text the module encodes and decodes; the first key holds the sidebar's folded branches. Whether a write to a key reports a change set is the key's own rule, written where the key is defined: the folds report none, since the fold is one screen's own and two windows of one Mac that share the row learn of each other's fold at their next reread. A backup of the file carries the table, since it is the file's, so a restored copy starts with the folds the original had, which is harmless and accepted. The state is the kind a person made on this device's screen that no other device should repeat and no link addresses: folds, what a list has shown, the width of a column. Not the selection, which is the route's, and not session state such as an open rename, edit mode or a dialog, which a relaunch loses by design (ADR-0009, amendment of 2026-10-25).

Alternatives. Folds in the window's route lost: two windows would fold independently and a link would carry a fold. Folds in the journal lost: the owner wants them per device. `UserDefaults` behind a protocol the platform implements lost: more plumbing for one set of ids, and the web would need an implementation of its own, when the store is already there on every platform.

## Consequences

Easier: every platform keeps the state the same way, and the host and wasm32 test it; a module that needs such state names a key and nothing else. Harder: the store's API gains a key-value corner beside its typed reads, and a module decides for itself how to encode what it keeps, so a key's format is the module's to keep stable across its own versions. Constrained: per-device UI state lives here and nowhere else, not in the route, not in the journal, not in a platform's storage; nothing in this table is ever sent to another device. Reversing this decision means moving the keys into the journal, with a migration that writes them as operations, or into each platform's storage, which the web would have to grow.
