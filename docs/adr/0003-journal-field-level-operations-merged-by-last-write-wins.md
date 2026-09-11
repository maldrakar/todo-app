# ADR-0003: Journal every change as a field-level operation and merge by last write wins per field

- Status: Accepted
- Date: 2026-09-11
- Related: `docs/specs/core-storage-and-search.md` (approved 2026-09-11), #4, ADR-0002

## Context

The owner uses several devices, and sync arrives after M1. A data format that ignores sync forces a migration of users' data when sync is added, so the format must be ready now while the transport stays open. Concurrent edits on offline devices must merge without asking the user. The spec's "Sync model" and "State is primary, the journal serves sync" sections hold the discussion and a worked example.

## Decision

Every change to the core's data is an operation: entity kind, entity id, field, value, clock, device. Creating an entity is a batch of operations with one clock; a row appears at the first operation for an unknown id; deletion is the operation `deleted = true`, a tombstone that keeps the row. Set-like data such as a task's tags and a view's manual list are entities keyed by the pair. The clock is a hybrid logical clock, wall-clock milliseconds plus a counter in one `Int64`, with the device id as tie-break; the device id is generated at first open and stored in the database. The state tables are the truth for reading and the journal is the truth for sync: for every (entity, field) the store keeps the clock of the last write, and an operation applies only if its clock is later, otherwise it stays in the journal unapplied. Local edits and remote operations go through the same apply path. An operation for a field the schema does not know yet is kept and replayed by the migration that adds the field. A parent link that a merge made circular or dangling is ignored when reading; nothing is rejected at apply time.

Alternatives. Event sourcing with the journal as the source of truth lost because the journal could never be compacted and every schema change would replay history. An own CRDT lost because no library exists under ADR-0001 and writing one is out of proportion. Sync through an own backend or CloudKit from M1 lost because either is a system of its own, and both remain possible as transports over this journal.

## Consequences

Easier: any transport later, since it moves journal rows and nothing else; one apply path for local and remote changes; concurrent edits of different fields both survive; the data lost by last write wins is still in the journal, so a better merge for notes can be added later and applied to old conflicts; migrations that add fields are safe for devices that lag behind.

Harder: every write is two writes, to the state and to the journal, and one clock comparison per field; the journal grows for as long as there is no transport to acknowledge delivery; identity of views and other fixed rows must be stable across devices, which is why built-in views have fixed ids.

Constrained: no code path may modify state tables except apply; journal compaction and tombstone purge are designed together with the transport; two devices that change the same field offline keep the later one, and the text of one note is one field. Reversing this decision means dropping the journal and the field clocks, which is cheap before sync exists and a data migration afterwards.
