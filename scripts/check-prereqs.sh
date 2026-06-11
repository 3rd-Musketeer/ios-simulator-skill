#!/usr/bin/env bash
set -euo pipefail

fail() { echo "ios-simulator prereq: $*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "macOS required"

command -v xcrun >/dev/null || fail "install Xcode CLI tools (xcode-select --install)"
xcrun simctl list devices >/dev/null 2>&1 || fail "simctl unavailable"

command -v node >/dev/null || fail "Node.js required (>= 18)"
NODE_MAJOR="$(node -p "process.versions.node.split('.')[0]")"
[[ "$NODE_MAJOR" -ge 18 ]] || fail "Node >= 18 required (found $(node --version))"

BOOTED="$(xcrun simctl list devices booted | grep -c Booted || true)"
if [[ "$BOOTED" -eq 0 ]]; then
  echo "ios-simulator prereq: no booted simulator (will need: xcrun simctl boot <udid>)"
fi

if command -v agent-browser >/dev/null; then
  echo "ios-simulator prereqs: OK (agent-browser $(agent-browser --version 2>/dev/null || echo present))"
elif [[ "${IOS_SIMULATOR_SKIP_BROWSER:-}" == "1" ]]; then
  echo "ios-simulator prereqs: OK (agent-browser skipped; headless only)"
else
  echo "ios-simulator prereq: agent-browser not installed (visual verify unavailable; install: npm i -g agent-browser && agent-browser install)"
  exit 1
fi
