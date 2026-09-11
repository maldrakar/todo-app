# ADR-0002: Persist the core's data in vendored SQLite on every platform

- Status: Accepted
- Date: 2026-09-11
- Related: `docs/specs/core-storage-and-search.md` (approved 2026-09-11), #4, amends ADR-0001

## Context

The core needs one storage implementation for iOS, macOS, iPadOS, watchOS and the web, within ADR-0001: full Swift, standard library and FoundationEssentials, no ICU. Task notes are Markdown and can reach megabytes in total, so list queries must not load them, and search over titles and notes has to fold case and diacritics in Russian and English without ICU. The web target has no file system of its own; durability there goes through JavaScript. The discussion is in the spec's "Storage engine" and "Persistence per platform" sections.

## Decision

The core stores its data in SQLite compiled from the amalgamation as a C target of the package, with one version and one set of compile flags on every target: FTS5 on, threads, extension loading and deprecated APIs off. It is the only C dependency of the core and its only runtime dependency outside the standard library and FoundationEssentials, which amends the dependency rule of ADR-0001. On Apple platforms the database is a file in WAL mode at a path the platform supplies, one connection per process. On the web the database lives in memory: the page passes the bytes of the previous snapshot at open and the core restores them with `sqlite3_deserialize`; after changes the page asks for a snapshot through `sqlite3_serialize` and stores it in IndexedDB. Notes are the last column of the tasks table and list queries never read them. Search uses two FTS5 indexes maintained by triggers: `trigram` over titles for substring quick find and `unicode61` over notes for word and prefix search ranked by bm25.

Alternatives. State in memory with a snapshot and journal file in pure Swift lost because notes would be loaded for every list and Unicode-aware search would be hand-written. A repository port with SQLite on Apple and an own format on the web lost because every query and test would exist twice. The system SQLite on Apple platforms lost because it does not guarantee the trigram tokenizer with diacritic removal and would split behaviour between targets.

## Consequences

Easier: one code path and one test suite on the host and on wasm32; indexed queries and transactions; full-text search without ICU; the database file can be opened with standard tools; notes stay out of list queries by construction.

Harder: the web bundle grows by about half a megabyte after gzip, counted in the M1 size budget; the amalgamation is a large file in the repository that compiles once per clean build; the browser persists by whole-file snapshot, so a tab that dies before the delayed snapshot loses the last seconds of edits; a schema change is a migration.

Constrained: no system SQLite anywhere; every core query is SQL against this schema; the web target must supply the snapshot bridge. Reversing this decision means rewriting the store, the search and the migrations against another engine and converting users' files; the operation journal of ADR-0003 would survive such a move, since it is engine-independent data.
