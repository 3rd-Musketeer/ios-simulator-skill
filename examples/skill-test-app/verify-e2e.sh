#!/usr/bin/env bash
# Headless smoke: build → install → serve-sim tap → assert AX tree.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$ROOT/SkillTestApp.xcodeproj"
SCHEME="SkillTestApp"
BUNDLE_ID="com.mori.skilltest.app"
DERIVED="$ROOT/.derivedData"
APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/SkillTestApp.app"

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
  npx --yes serve-sim@latest --kill "$UDID" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM HUP
cleanup

echo "==> Starting serve-sim (detach)"
STREAM_JSON="$(npx --yes serve-sim@latest --detach -q "$UDID")"
STREAM_PORT="$(echo "$STREAM_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['port'])")"
AX_URL="http://127.0.0.1:${STREAM_PORT}/ax"

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

BEFORE="$(read_ax_label tap-count)"
echo "    tap-count before: ${BEFORE:-<missing>}"

if [[ "$BEFORE" != "Taps: 0" ]]; then
  echo "FAIL: expected tap-count 'Taps: 0' before tap, got '${BEFORE:-<missing>}'" >&2
  exit 1
fi

echo "==> Tapping via serve-sim"
npx --yes serve-sim@latest tap 0.5 0.646 -d "$UDID" >/dev/null
sleep 0.5

AFTER="$(read_ax_label tap-count)"
echo "    tap-count after:  ${AFTER:-<missing>}"

if [[ "$AFTER" != "Taps: 1" ]]; then
  echo "FAIL: expected tap-count 'Taps: 1', got '${AFTER:-<missing>}'" >&2
  exit 1
fi

echo "PASS: serve-sim tap + accessibility tree verified"
