#!/bin/bash
# Run ONN against a local fake Statuspage, for demoing without waiting for the
# real internet to break.
#
#   scripts/demo.sh              # outages escalate to "down AGAIN" on the first hit
#   TIER=fresh scripts/demo.sh   # first-outage messages
#   TIER=notnews scripts/demo.sh # straight to "this isn't even news anymore"
#   UP=10 DOWN=20 scripts/demo.sh
#
# Ctrl-C stops the app and the mock server together.
set -euo pipefail
cd "$(dirname "$0")/.."

UP="${UP:-20}"
DOWN="${DOWN:-25}"
TIER="${TIER:-repeat}"
PORT=8787

# mock-config.json thresholds: repeatOffender at 2, notEvenNews at 5. record()
# appends before counting, so the live outage is itself part of the count.
case "$TIER" in
    fresh)   SEED=0 ;;
    repeat)  SEED=1 ;;
    notnews) SEED=4 ;;
    *) echo "TIER must be fresh, repeat or notnews (got '$TIER')" >&2; exit 2 ;;
esac

# A previous demo that was killed rather than Ctrl-C'd leaves the port bound,
# and the app then polls a dead endpoint and silently shows nothing.
if lsof -ti "tcp:$PORT" >/dev/null 2>&1; then
    echo "port $PORT still bound by an earlier run — reclaiming it"
    lsof -ti "tcp:$PORT" | xargs kill 2>/dev/null || true
    sleep 1
fi

# Seed outage history so the escalation tier is visible immediately. Swift's
# default JSONEncoder writes Dates as seconds since 2001-01-01, not the epoch.
python3 - "$SEED" <<'PY'
import json, sys, time
seed = int(sys.argv[1])
now = time.time() - 978307200          # -> seconds since 2001-01-01
events = [{"site": s, "startedAt": now - (i + 1) * 3600}
          for s in ("MockHub", "MockHouse") for i in range(seed)]
json.dump(events, open("scripts/history.json", "w"))
print(f"seeded {len(events)} past outages")
PY

python3 scripts/mock-status-server.py --port "$PORT" --up "$UP" --down "$DOWN" &
MOCK=$!
trap 'kill $MOCK 2>/dev/null; pkill -f "NEWSTICKER_CONFIG" 2>/dev/null; exit 0' INT TERM

sleep 1
kill -0 $MOCK 2>/dev/null || { echo "mock server failed to start" >&2; exit 1; }

APP="/Applications/ONN.app/Contents/MacOS/ONN"
echo
echo "MockHub and MockHouse cycle ${UP}s up / ${DOWN}s down. Ctrl-C to stop."
echo
if [ -x "$APP" ]; then
    NEWSTICKER_CONFIG=scripts/mock-config.json "$APP"
else
    NEWSTICKER_CONFIG=scripts/mock-config.json swift run
fi
