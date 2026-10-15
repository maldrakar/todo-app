#!/bin/sh
# Builds the wasm size probe in release mode and checks how large it is after gzip, which is what a browser
# downloads. The probe stands for the web client: it drives the root module, calls the public API of TodoCore
# and carries no demo code, so the number below is the root module and the core a client cannot dead-strip its
# way out of shipping (issue #23).
set -eu
cd "$(dirname "$0")/.."

# 6.25 MiB. The probe measures 6,275,518 bytes with Swift 6.4.0 as this is written, so the budget is that with
# four percent to spare, rounded up to a whole 64 KiB. It was 6.5625 MiB over the 6,595,141 bytes the same
# probe measured with Swift 6.3.3, and what moved it is the toolchain, not the code: the pin went to the 6.4
# that Xcode 27 ships (#88), whose release build of the same sources is smaller. It is not the 4.5 MiB the spec
# first named either, and that figure was never measured: it was the floor measured in #3 — 3,743,306 bytes of
# standard library, FoundationEssentials and SQLite with no core code reachable — plus half a megabyte of slack
# for the code the core would add. That code, with the JSON coding it pulls in, costs 2.8 MB instead. SQLite
# and FoundationEssentials sit inside the floor, on both sides of the comparison, so they are not what the
# difference is made of. Moving this number is a decision, so it lives here in one place and nowhere else.
BUDGET_BYTES=6553600
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
