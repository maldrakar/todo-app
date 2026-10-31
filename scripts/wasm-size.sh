#!/bin/sh
# Builds the wasm size probe in release mode and checks how large it is after gzip, which is what a browser
# downloads. The probe stands for the web client: it drives the root module, calls the public API of TodoCore
# and carries no demo code, so the number below is the root module and the core a client cannot dead-strip its
# way out of shipping (issue #23).
set -eu
cd "$(dirname "$0")/.."

# 6.6875 MiB. The probe measures 6,710,778 bytes with Swift 6.4.0 as this is written, so the budget is that with four
# percent to spare, rounded up to a whole 64 KiB. What has moved the reading since is the code: 6,605,543 bytes on the
# `main` this was measured beside, 023eeb2, and the other 105,235 once the sidebar built its screen's component models,
# its rows, its bar, the look of its drag and its dialogs, from the design system's components target, and the probe
# read them through the switches their views have (#161). The binary carries the path of the directory it was built in,
# so a reading moves by a few hundred bytes with the checkout's path, and the two above were taken in one. In #147 it
# was 6.5625 MiB over the 6,605,560 bytes the probe measured then, where #146 had put it, and the code moved the reading
# then too: 6,563,465 bytes on the `main` that was measured beside, aa85351, and the other 42,095 once the sidebar made
# its edits, edit mode, the confirmation of a delete, the move picker and the drop read into a parent and a place, and
# the probe drove the picker and a drop. In #146 it was 6.3125 MiB over the 6,362,344 bytes the probe measured in #92,
# and the code moved the reading then too: 6,492,550 bytes on the `main` that was measured beside, 34c7fee, and the
# other 69,773, to 6,562,323, once the sidebar drew its rows as areas and lists, with the tiles the design system's two
# targets build, which the probe links through it, the counts and the folds, and the probe drove the sidebar's new
# actions. Before that it was 6.25 MiB over the 6,275,518 bytes the probe measured when the pin moved to Swift 6.4.0,
# and what moved the reading from there was the code too: 6,286,422 bytes once the sidebar had its route (#89), and the
# rest once the window held the task list, opened by the sidebar, with the task screen inside it, and quick entry beside
# them, and every route came to read and write its part of the window's path, all of which the probe drives (#92).
# Before the pin moved it was 6.5625 MiB over the 6,595,141 bytes the probe measured with Swift 6.3.3, and what moved
# that is the toolchain, not the code: the pin went to the 6.4 that Xcode 27 ships (#88), whose release build of the
# same sources is smaller. It is not the 4.5 MiB the spec first named either, and that figure was never measured: it was
# the floor measured in #3 — 3,743,306 bytes of standard library, FoundationEssentials and SQLite with no core code
# reachable — plus half a megabyte of slack for the code the core would add. That code, with the JSON coding it pulls
# in, costs 2.8 MB instead. SQLite and FoundationEssentials sit inside the floor, on both sides of the comparison, so
# they are not what the difference is made of. Moving this number is a decision, so it lives here in one place and
# nowhere else.
BUDGET_BYTES=7012352
SDK=swift-6.4.0-RELEASE_wasm
PRODUCT=wasm-size-probe

swift build -c release --swift-sdk "$SDK" --product "$PRODUCT"
# Where SwiftPM 6.4 puts the product; 6.3 put it in `wasm32-unknown-wasip1/release/`, which 6.4 no longer makes.
WASM=".build/out/Products/Release-webassembly-wasm32/$PRODUCT.wasm"
[ -f "$WASM" ] || { echo "nothing to measure: no $WASM"; exit 1; }

RAW=$(wc -c < "$WASM" | tr -d ' ')
GZ=$(gzip -9 -c "$WASM" | wc -c | tr -d ' ')
# Both readings are the tail of a pipeline, where `set -e` sees the last command and not the one that read the
# file, so a gzip that failed would otherwise pass for a very small binary and the budget would hold over a
# measurement of nothing.
[ "$GZ" -gt 0 ] || { echo "measured nothing: $WASM read as ${RAW:-no} bytes"; exit 1; }

# Which gzip, because deflate is the implementation's own: the runner has GNU gzip and a Mac has Apple's, they
# disagree by far less than the headroom above, and the number of record is the one this job prints.
GZIP_ID=$(gzip --version 2>&1 | head -1)
echo "$PRODUCT.wasm: $RAW bytes raw, $GZ bytes after gzip -9, budget $BUDGET_BYTES bytes (${GZIP_ID:-unknown gzip})"

if [ "$GZ" -gt "$BUDGET_BYTES" ]; then
  echo "over budget by $((GZ - BUDGET_BYTES)) bytes"
  exit 1
fi
echo "under budget by $((BUDGET_BYTES - GZ)) bytes"
