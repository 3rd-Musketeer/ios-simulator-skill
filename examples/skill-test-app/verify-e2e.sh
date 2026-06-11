#!/usr/bin/env bash
# Headless smoke: build → install → serve-sim tap → assert AX tree.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$ROOT/../.." && pwd)"
PROJECT="$ROOT/SkillTestApp.xcodeproj"
SCHEME="SkillTestApp"
BUNDLE_ID="com.mori.skilltest.app"
DERIVED="$ROOT/.derivedData"
APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/SkillTestApp.app"

serve_sim() {
  local bin="$REPO_ROOT/node_modules/.bin/serve-sim"
  if [[ -x "$bin" ]]; then
    "$bin" "$@"
  else
    npx --yes serve-sim@latest "$@"
  fi
}

UDID="${SIM_UDID:-}"
if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ && !/unavailable/ {print $2; exit}')"
fi
if [[ -z "$UDID" ]]; then
  echo "No available iPhone simulator." >&2
  exit 1
fi

echo "==> Building ($UDID)"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null

echo "==> Installing and launching"
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
sleep 1

cleanup() {
  serve_sim --kill "$UDID" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM HUP
cleanup

echo "==> Starting serve-sim (detach)"
STREAM_JSON="$(serve_sim --detach -q "$UDID" 2>/dev/null | tail -1)"
STREAM_PORT="$(echo "$STREAM_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['port'])")"
AX_URL="http://127.0.0.1:${STREAM_PORT}/ax"

wait_for_ax() {
  for _ in $(seq 1 30); do
    if curl -fsS "$AX_URL" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "FAIL: serve-sim /ax not ready at $AX_URL" >&2
  exit 1
}

read_ax_label() {
  local id="$1"
  curl -fsS "$AX_URL" | python3 -c "
import json, sys
target = sys.argv[1]

def walk(node):
    if isinstance(node, list):
        for item in node:
            found = walk(item)
            if found is not None:
                return found
    elif isinstance(node, dict):
        if node.get('AXUniqueId') == target:
            return node.get('AXLabel') or ''
        for child in node.get('children', []):
            found = walk(child)
            if found is not None:
                return found
    return None

result = walk(json.load(sys.stdin))
print(result if result is not None else '')
" "$id"
}

tap_by_ax_id() {
  local id="$1"
  local coords
  coords="$(curl -fsS "$AX_URL" | python3 -c "
import json, sys
target = sys.argv[1]
data = json.load(sys.stdin)
app = data[0]
sw, sh = app['frame']['width'], app['frame']['height']

def find(node):
    if isinstance(node, list):
        for item in node:
            r = find(item)
            if r:
                return r
    elif isinstance(node, dict):
        if node.get('AXUniqueId') == target:
            f = node['frame']
            return (f['x'] + f['width'] / 2) / sw, (f['y'] + f['height'] / 2) / sh
        for child in node.get('children', []):
            r = find(child)
            if r:
                return r
    return None

pt = find(data)
if not pt:
    raise SystemExit(f'element not found: {target}')
print(f'{pt[0]:.4f} {pt[1]:.4f}')
" "$id")"
  echo "    tap $id at $coords"
  read -r TX TY <<<"$coords"
  serve_sim tap "$TX" "$TY" -d "$UDID" >/dev/null
}

echo "==> Waiting for serve-sim /ax"
wait_for_ax

BEFORE="$(read_ax_label tap-count)"
echo "    tap-count before: ${BEFORE:-<missing>}"

if [[ "$BEFORE" != "Taps: 0" ]]; then
  echo "FAIL: expected tap-count 'Taps: 0' before tap, got '${BEFORE:-<missing>}'" >&2
  exit 1
fi

echo "==> Tapping via serve-sim (coords from /ax)"
tap_by_ax_id tap-button

AFTER=""
for _ in $(seq 1 10); do
  sleep 1
  AFTER="$(read_ax_label tap-count)"
  [[ "$AFTER" == "Taps: 1" ]] && break
done
echo "    tap-count after:  ${AFTER:-<missing>}"

if [[ "$AFTER" != "Taps: 1" ]]; then
  echo "FAIL: expected tap-count 'Taps: 1', got '${AFTER:-<missing>}'" >&2
  exit 1
fi

echo "PASS: serve-sim tap + accessibility tree verified"
