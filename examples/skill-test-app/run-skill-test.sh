#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$ROOT/../.." && pwd)"
PROJECT="$ROOT/SkillTestApp.xcodeproj"
SCHEME="SkillTestApp"
BUNDLE_ID="com.mori.skilltest.app"

serve_sim() {
  local bin="$REPO_ROOT/node_modules/.bin/serve-sim"
  if [[ -x "$bin" ]]; then
    "$bin" "$@"
  else
    npx --yes serve-sim@latest "$@"
  fi
}

echo "==> Listing simulators"
xcrun simctl list devices available

UDID="${SIM_UDID:-}"
if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ && !/unavailable/ {print $2; exit}')"
fi
if [[ -z "$UDID" ]]; then
  echo "No available iPhone simulator. Install iOS runtime first." >&2
  exit 1
fi
echo "==> Using simulator $UDID"

echo "==> Booting simulator"
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator

echo "==> Building app"
DERIVED="$ROOT/.derivedData"
set +e
BUILD_LOG="$(mktemp)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build >"$BUILD_LOG" 2>&1
BUILD_STATUS=$?
set -e
if [[ $BUILD_STATUS -ne 0 ]]; then
  if command -v xcbeautify >/dev/null 2>&1; then
    xcbeautify <"$BUILD_LOG" || cat "$BUILD_LOG"
  else
    cat "$BUILD_LOG"
  fi
  rm -f "$BUILD_LOG"
  exit "$BUILD_STATUS"
fi
rm -f "$BUILD_LOG"

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/SkillTestApp.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app not found: $APP_PATH" >&2
  exit 1
fi

echo "==> Installing and launching"
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl launch "$UDID" "$BUNDLE_ID"

cleanup_serve_sim() {
  serve_sim --kill "$UDID" >/dev/null 2>&1 || true
}
trap cleanup_serve_sim EXIT INT TERM HUP
cleanup_serve_sim

echo "==> Starting serve-sim (watch this output for the preview URL)"
serve_sim "$UDID"
