#!/usr/bin/env bash
# Runs the list screen's walks, the UI-test target `TodoUITests` of Apps/Apple/Todo.xcodeproj, on a simulator of its
# own (#197). It creates a new device, never touching one that exists, builds the command-line tool and the app with
# its walks, seeds a store through the tool, runs the walks named or all of them, and deletes the device on every
# exit. Each walk launches the app over a fresh copy of that store.
#
# usage: scripts/ui-walks.sh [--device TYPE] [--runtime ID] [--record] [CLASS[/TEST] ...]
#   CLASS[/TEST]  a walk class of Apps/Apple/UITests, DropWalks, or one walk, DropWalks/testDropInsideABlock;
#                 none runs them all
#   --device      the simulator's device type, "iPhone 17" unless given
#   --runtime     the iOS runtime's id, the newest installed unless given
#   --record      records the device's screen to walks.mp4, for what a walk cannot assert, such as a tint
#
# Xcode 27.1 is the Xcode it runs with, as `xcode-select` or DEVELOPER_DIR names it. What the run keeps is in a new
# directory under TMPDIR, which the run prints: the log, the result bundle, the store of each walk and the video.
set -euo pipefail
cd "$(dirname "$0")/.."

device="iPhone 17"
runtime=""
record=""
walks=()
while [ $# -gt 0 ]; do
  case $1 in
    --device) device=$2; shift 2 ;;
    --runtime) runtime=$2; shift 2 ;;
    --record) record=1; shift ;;
    -h | --help) sed -n '2,16p' "$0" | cut -c3-; exit 0 ;;
    -*) echo "ui-walks: unknown option $1" >&2; exit 2 ;;
    *) walks+=("$1"); shift ;;
  esac
done

pin=$(cat .swift-version)
case "$(xcrun swift --version 2>&1)" in
  *"swiftlang-$pin."*) ;;
  *)
    echo "ui-walks: Xcode's toolchain is not Swift $pin, which .swift-version pins; set DEVELOPER_DIR to Xcode 27.1's" \
      "Developer directory" >&2
    exit 1
    ;;
esac
if [ -z "$runtime" ]; then
  runtime=$(xcrun simctl list runtimes available | awk '/^iOS / { id = $NF } END { print id }')
fi

tmp=${TMPDIR:-/tmp}
out=$(mktemp -d "${tmp%/}/ui-walks.XXXXXX")
udid=""
recorder=""
cleanup() {
  status=$?
  if [ -n "$recorder" ]; then kill -INT "$recorder" 2>/dev/null || true; wait "$recorder" 2>/dev/null || true; fi
  if [ -n "$udid" ]; then
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$udid" >/dev/null 2>&1 && echo "ui-walks: deleted the device $udid"
  fi
  # The builds are half a gigabyte a run and the next run makes its own.
  rm -rf "$out/build" "$out/cli"
  echo "ui-walks: what the run keeps is in $out"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

udid=$(xcrun simctl create "ui-walks-$$" "$device" "$runtime")
echo "ui-walks: a new $device on $runtime, $udid"
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b >/dev/null
# The software keyboard stays up for a typed text only with this off, and the setting is read at boot.
xcrun simctl spawn "$udid" defaults write com.apple.keyboard.preferences AutomaticMinimizationEnabled -bool false
xcrun simctl shutdown "$udid"
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b >/dev/null

echo "ui-walks: building the command-line tool, the app and its walks"
cli=$(xcrun swift build --product todo --scratch-path "$out/cli" --show-bin-path)
xcrun swift build --product todo --scratch-path "$out/cli" >"$out/cli.log" 2>&1 \
  || { tail -20 "$out/cli.log" >&2; exit 1; }
xcodebuild build-for-testing -project Apps/Apple/Todo.xcodeproj -scheme Todo \
  -destination "platform=iOS Simulator,id=$udid" -derivedDataPath "$out/build" >"$out/build.log" 2>&1 \
  || { grep -E "error:" "$out/build.log" | head -20 >&2; exit 1; }
xctestrun=$(ls "$out"/build/Build/Products/*.xctestrun | head -1)

mkdir "$out/store"
Apps/Apple/UITests/seed.sh "$cli/todo" "$out/store/todo.sqlite"

if [ -n "$record" ]; then
  xcrun simctl io "$udid" recordVideo --codec h264 --force "$out/walks.mp4" 2>/dev/null &
  recorder=$!
fi

only=()
for walk in ${walks[@]+"${walks[@]}"}; do only+=("-only-testing:TodoUITests/$walk"); done
echo "ui-walks: walking ${walks[*]:-every walk}"
status=0
TEST_RUNNER_WALK_STORE="$out/store/todo.sqlite" xcodebuild test-without-building -xctestrun "$xctestrun" \
  -destination "platform=iOS Simulator,id=$udid" ${only[@]+"${only[@]}"} -resultBundlePath "$out/walks.xcresult" \
  >"$out/walks.log" 2>&1 || status=$?
grep -E "^Test Case .*(passed|failed|skipped)|: error: " "$out/walks.log" | sed -E 's/^Test Case //' || true
echo "ui-walks: $(grep -cE "^Test Case .* passed" "$out/walks.log" || true) passed," \
  "$(grep -cE "^Test Case .* failed" "$out/walks.log" || true) failed; the log is $out/walks.log," \
  "the results $out/walks.xcresult"
exit "$status"
