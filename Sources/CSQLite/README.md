# CSQLite

The vendored SQLite amalgamation (ADR-0002). `sqlite3.c` and `include/sqlite3.h` are copied from the
upstream release archive unchanged; the only project-specific part is the compile-time configuration,
which lives in `Package.swift`.

| | |
| --- | --- |
| Version | 3.53.4 (`SQLITE_VERSION_NUMBER` 3053004) |
| Source id | `2026-07-24 19:02:57 bf7c7f30031888f4e796e429ab3978879485813aaca6f641c7b33e4e09459bcc` |
| Source archive | <https://sqlite.org/2026/sqlite-amalgamation-3530400.zip> |
| SHA-256 of the archive | `1e71ddf93849c6a6ecf58b827c0692073d2dd7ee40196158068f7b29f422e87d` |
| Vendored on | 2026-09-11 |

The two files are byte-identical to their copies inside that archive.

## Upgrading

1. Download the new amalgamation, verify its SHA-256 against the one published on <https://sqlite.org/download.html>.
2. Replace `sqlite3.c` and `include/sqlite3.h` with the archive's copies, unchanged.
3. Update the table above: version, source id, archive URL, checksum, date.
4. Update the expected version string in `Tests/SQLiteKitTests/ConnectionTests.swift` and
   `Tests/TodoCoreTests/SmokeTests.swift`. Both assert `sqlite3_libversion()`, so the sources cannot
   change without the tests being updated in the same commit.
5. Add a `CHANGELOG.md` entry and re-run `swift test` on the host and on wasm32.
