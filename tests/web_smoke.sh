#!/usr/bin/env bash
# Boots the exported Web build in headless Chromium and checks the console.
#
#   godot --headless --path . --export-release "Web" export/web/index.html
#   tests/web_smoke.sh [export/web] [seconds]
#
# Passes when the title screen autostarts a campaign and Main prints its
# LEVEL READY line with a railway and a train, and no Godot script error is
# logged. Chromium is found via $CHROME_BIN or the Playwright browser cache.
set -u
WEB_DIR="${1:-export/web}"
# Booting a 20 MB pack plus the WASM under software rendering is slow on a busy
# machine; too small a budget screenshots a blank page and looks like a failure.
WAIT_SECONDS="${2:-150}"
PORT="${PORT:-8123}"
CHROME_BIN="${CHROME_BIN:-$(ls -d "$HOME"/.cache/ms-playwright/chromium_headless_shell-*/chrome-linux/headless_shell 2>/dev/null | sort | tail -1)}"
if [ -z "$CHROME_BIN" ] || [ ! -x "$CHROME_BIN" ]; then
	echo "web_smoke: no headless Chromium found; set CHROME_BIN" >&2
	exit 2
fi
if [ ! -f "$WEB_DIR/index.html" ]; then
	echo "web_smoke: $WEB_DIR/index.html missing; export the Web build first" >&2
	exit 2
fi
LOG="$(mktemp)"
SHOT="${SCREENSHOT:-/tmp/battle-stations-web-smoke.png}"
python3 -m http.server "$PORT" --directory "$WEB_DIR" --bind 127.0.0.1 >/dev/null 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null' EXIT
sleep 1
# --virtual-time-budget keeps old-headless alive past the page's load event
# until the engine has booted; --timeout alone screenshots before the WASM runs.
"$CHROME_BIN" --headless --disable-gpu --use-angle=swiftshader --enable-unsafe-swiftshader \
	--no-sandbox --enable-logging=stderr --v=0 --window-size=1280,720 \
	--virtual-time-budget="$((WAIT_SECONDS * 1000))" --timeout="$((WAIT_SECONDS * 1000))" \
	--screenshot="$SHOT" "http://127.0.0.1:$PORT/index.html?autostart" >/dev/null 2>"$LOG"
grep -o 'CONSOLE[^"]*"[^"]*"' "$LOG" | sed 's/^CONSOLE[^"]*"//; s/"$//' | grep -v "GL Driver Message" > "$LOG.console" || true
echo "--- browser console ---"
cat "$LOG.console"
STATUS=0
if ! grep -q "LEVEL READY" "$LOG.console"; then
	echo "web_smoke: FAIL — Main never reported LEVEL READY (build did not reach the level)"
	STATUS=1
elif ! grep "LEVEL READY" "$LOG.console" | grep -Eq "\| [1-9][0-9]* routes \| [1-9][0-9]* trains"; then
	echo "web_smoke: FAIL — level started without a railway or a train"
	STATUS=1
fi
if grep -Eq "SCRIPT ERROR|Failed to load script|Parse Error|Could not preload|Compile Error" "$LOG.console"; then
	echo "web_smoke: FAIL — script errors in the exported build"
	STATUS=1
fi
[ "$STATUS" -eq 0 ] && echo "web_smoke: PASS (screenshot: $SHOT)"
rm -f "$LOG" "$LOG.console"
exit "$STATUS"
