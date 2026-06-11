---
name: ios-simulator
description: Drive and visually verify iOS Simulator apps via serve-sim and agent-browser. Use when the user wants to run, test, screenshot, or automate an iOS app in the simulator — including SwiftUI, morii-ios, Expo, or native iOS projects. Triggers include "iOS simulator", "serve-sim", "simulator preview", "test on simulator", "screenshot the app", "tap in simulator", or verifying mobile UI without Xcode.
license: MIT
---

# iOS Simulator

Drive a booted Apple Simulator from an agent: stream it in a browser, screenshot the UI, read the accessibility tree, and send taps — without opening Xcode.

Built on [serve-sim](https://github.com/EvanBacon/serve-sim) (stream + control) and [agent-browser](https://github.com/vercel-labs/agent-browser) (visual verification). Works in Cursor, Claude Code, Codex, and any host that supports the [Agent Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview) standard.

## Prerequisites

Run `scripts/check-prereqs.sh` first. If it exits non-zero, tell the user what to install.

| Requirement | Check |
|---|---|
| macOS | `uname -s` → Darwin |
| Xcode CLI | `xcrun simctl list` |
| Node ≥ 18 | `node --version` |
| agent-browser | `agent-browser --version` (for screenshots) |

Boot at least one simulator: `xcrun simctl list devices booted`, or `xcrun simctl boot <udid>`.

## Mental model

serve-sim runs **two surfaces** — do not confuse them:

| Port | Mode | What it is | Use for |
|---|---|---|---|
| **3200** | foreground `npx serve-sim` | React preview UI (full simulator in browser) | Human review, **agent-browser screenshots** |
| **3100** | always (stream helper) | MJPEG + WebSocket + `/ax` | CLI taps, accessibility tree, headless |

**Critical:** `npx serve-sim --detach` starts only the stream helper (~3100). It does **not** start the preview UI on 3200. For visual verification, run foreground serve-sim (see workflow below).

```text
Simulator ──simctl io──► serve-sim-bin (:3100 /ax, /stream.mjpeg, /ws)
                              ▲
foreground serve-sim CLI ─────┘──► React preview (:3200) ──► agent-browser screenshot
```

## Quick start

```bash
# 1. Boot simulator + build/install app (see workflows.md for morii-ios)
xcrun simctl boot <udid>
xcodebuild -project App.xcodeproj -scheme App -destination "id=<udid>" build
xcrun simctl install <udid> path/to/App.app
xcrun simctl launch <udid> <bundle-id>

# 2. Start preview (background foreground — keeps :3200 alive)
npx serve-sim@latest <udid> &

# 3. Visual verify (agent-browser)
agent-browser open http://127.0.0.1:3200
agent-browser screenshot /tmp/sim.png
# Read the screenshot file to inspect UI

# 4. Headless verify (CLI)
curl -s http://127.0.0.1:3100/ax | head
npx serve-sim@latest tap 0.5 0.65 -d <udid>

# 5. Cleanup
npx serve-sim@latest --kill <udid>
agent-browser close --all
```

## Choose a verification path

| Goal | Path |
|---|---|
| See if UI looks right | foreground serve-sim → `agent-browser screenshot` |
| Assert text/state changed | `curl :3100/ax` or `serve-sim tap` + re-read `/ax` |
| Click a known button by id | `/ax` → compute normalized center from `frame` → `serve-sim tap` |
| Click inside canvas visually | `agent-browser screenshot` → pixel coords → `mouse move/down/up` |
| No browser available | `xcrun simctl io <udid> screenshot out.png` |

## Common operations

| Goal | Command |
|---|---|
| List simulators | `xcrun simctl list devices available` |
| Start preview | `npx serve-sim@latest <udid>` (foreground; prints `http://localhost:3200`) |
| Start stream only | `npx serve-sim@latest --detach -q <udid>` |
| List streams | `npx serve-sim@latest --list -q` |
| Accessibility tree | `curl -s http://127.0.0.1:3100/ax` |
| Tap (normalized 0..1) | `npx serve-sim@latest tap <x> <y> -d <udid>` |
| Screenshot via browser | `agent-browser open http://127.0.0.1:3200 && agent-browser screenshot out.png` |
| Screenshot via simctl | `xcrun simctl io <udid> screenshot out.png` |
| Stop | `npx serve-sim@latest --kill <udid>` |

Coordinates are **normalized 0..1** (top-left origin). Never pass pixel coords to `serve-sim tap`.

## SwiftUI tip

Add `accessibilityIdentifier` to views you want agents to find in `/ax`:

```swift
Button("Tap Me") { ... }
    .accessibilityIdentifier("tap-button")
```

`AXUniqueId` in `/ax` JSON matches these identifiers.

## Critical gotchas

1. **Preview needs foreground serve-sim.** `--detach` alone → no :3200 → `agent-browser open` gets 404.
2. **Prefer `serve-sim tap` over `gesture` for single taps.** Back-to-back `gesture` begin/end registers as long-press.
3. **Simulator canvas is not in agent-browser's AX tree.** Snapshot shows toolbar buttons only; use screenshot for app content.
4. **Do not parse non-`-q` serve-sim output.** Use `--list -q` and `--detach -q` for JSON.
5. **This is agent automation, not lldb debugging.** No breakpoints or Instruments.

## Example harness

This repo includes a minimal test app and smoke script:

```bash
cd examples/skill-test-app
./verify-e2e.sh      # build → tap → assert AX tree
./run-skill-test.sh  # interactive preview
```

## Reference

- [references/workflows.md](references/workflows.md) — morii-ios build, full verify loop, coordinate math
- [references/endpoints.md](references/endpoints.md) — HTTP surface on :3100
- Upstream: [serve-sim skill](https://github.com/EvanBacon/serve-sim/tree/main/skills/serve-sim) for camera, permissions, rotation, CA debug
