#!/usr/bin/env bash
# The store the walks walk over, written through the command-line tool. Every walk starts from a copy of it.
# usage: seed.sh <todo> <store>    <todo> is the built `todo` tool, <store> a path where no store is yet.
# It prints the id of the list Project, which no screen shows and a walk's link to one of its groups names.
#
# Days are counted from the Mac's today, the simulator's too, so a run that crosses midnight walks a store seeded the
# day before. Tag ids are read with `sqlite3`, since the tool prints none and a filter names a tag by its id; nothing
# is written but through the tool.
set -euo pipefail
todo=$1
export TODO_DB=$2
n=0

day() { date -v"$1"d +%F; }
task() { "$todo" add "$@" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1; }
tag() { sqlite3 "$TODO_DB" "select id from tags where title = '$1'"; }
has() { echo "{\"kind\":\"has_tag\",\"tag\":\"$(tag "$1")\"}"; }

# Today: one block, a row of two lines among them, long enough to scroll; two done today, for the Done strip.
task "Alpha today" --when "$(day +0)" --tag home >/dev/null
task "Bravo today" --when "$(day +0)" --tag work --notes "A note." >/dev/null
task "Charlie today" --when "$(day +0)" >/dev/null
task "Delta today" --when "$(day +0)" >/dev/null
task "Echo today" --when "$(day +0)" >/dev/null
task "Foxtrot today, a title long enough to run onto a second line of the row" --when "$(day +0)" >/dev/null
for i in $(seq 1 14); do task "Filler $i" --when "$(day +0)" >/dev/null; done
"$todo" done "$(task "Water the plants" --when "$(day +0)" --tag home)" >/dev/null
"$todo" done "$(task "Pay the invoice" --when "$(day +0)")" >/dev/null

# Upcoming, a block per day: a task with notes, a deadline and subtasks for the card, and a few on each day after.
spec=$(task "Review the list screen spec" --when "$(day +1)" --deadline "$(day +1)" --tag work --tag design \
  --notes "The card opens in place.")
task "Find the coupon" --parent "$spec" >/dev/null
task "Print the boarding pass" --parent "$spec" >/dev/null
for i in 1 1 2 2 3 3 4 5 6; do task "Day +$i task $((++n))" --when "$(day +$i)" >/dev/null; done

# A list with lists inside, for drops between blocks and for columns: its own tasks first, then a block per list.
task "Own one" --tag proj >/dev/null
task "Own two" --tag proj >/dev/null
for i in $(seq 1 12); do task "Core $i" --tag core >/dev/null; done
task "Design one" --tag design2 >/dev/null
task "Design two" --tag design2 >/dev/null
task "Ops one" --tag ops >/dev/null
task "Docs one" --tag docs >/dev/null
task "Both one" --tag design2 --tag ops >/dev/null
task "Either one" --tag either1 >/dev/null
task "Wk one" --when "$(day +1)" --tag wk >/dev/null
task "Wk two" --when "$(day +2)" --tag wk >/dev/null
task "Wk three" --when "$(day +2)" --tag wk >/dev/null
project=$("$todo" view add "Project" --filter "$(has proj)" | grep -oE '[0-9a-f-]{36}')
"$todo" view add "Core" --parent Project --filter "$(has core)" >/dev/null
"$todo" view add "Design" --parent Project --filter "$(has design2)" >/dev/null
"$todo" view add "Ops" --parent Project --filter "$(has ops)" >/dev/null
"$todo" view add "Docs" --parent Project --filter "$(has docs)" >/dev/null
# A rule of alternatives, which takes no drop.
"$todo" view add "Either" --parent Project \
  --filter "{\"kind\":\"or\",\"filters\":[$(has either1),$(has home)]}" >/dev/null
# A list that groups by day, last among Project's lists.
"$todo" view add "Weekly" --parent Project --filter "$(has wk)" --group when_day >/dev/null

# Another root list, for the Lists screen's own drag.
"$todo" view add "Spare" >/dev/null

echo "$project"
