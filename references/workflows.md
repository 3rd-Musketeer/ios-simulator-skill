# Workflows

## Full visual verify loop

Copy and track:

```
- [ ] Boot simulator
- [ ] Build + install + launch app
- [ ] Start foreground serve-sim (port 3200)
- [ ] agent-browser open + screenshot
- [ ] Perform action (tap via CLI or mouse)
- [ ] Re-screenshot or re-read /ax
- [ ] Cleanup serve-sim + agent-browser
```

### Start serve-sim for agent-browser

```bash
UDID="$(xcrun simctl list devices booted | awk -F '[()]' '/Booted/ {print $2; exit}')"
npx serve-sim@latest --kill "$UDID" 2>/dev/null || true
npx serve-sim@latest "$UDID" > /tmp/serve-sim.log 2>&1 &

# Wait for preview UI
for i in $(seq 1 15); do
  curl -sf http://127.0.0.1:3200/ >/dev/null && break
  sleep 1
done
```

### Screenshot and inspect

```bash
agent-browser close --all 2>/dev/null || true
agent-browser open http://127.0.0.1:3200
agent-browser screenshot /tmp/sim.png
# Agent: read /tmp/sim.png to see the UI
```

### Tap via accessibility tree

```bash
# Fetch tree, find element by AXUniqueId, compute normalized center:
#   x_norm = (frame.x + frame.width/2) / screen_width
#   y_norm = (frame.y + frame.height/2) / screen_height
# screen dimensions come from the root Application node's frame.

curl -s http://127.0.0.1:3100/ax | python3 -c "
import json, sys
TARGET = 'tap-button'
def walk(n, sw, sh):
    if isinstance(n, list):
        for i in n: walk(i, sw, sh)
    elif isinstance(n, dict):
        if n.get('AXUniqueId') == TARGET:
            f = n['frame']
            print((f['x']+f['width']/2)/sw, (f['y']+f['height']/2)/sh)
            return
        for c in n.get('children', []): walk(c, sw, sh)
data = json.load(sys.stdin)
app = data[0]
sw, sh = app['frame']['width'], app['frame']['height']
walk(data, sw, sh)
"
# Then: npx serve-sim@latest tap <x> <y> -d "$UDID"
```

### Tap via agent-browser mouse (pixel coords)

When `/ax` is insufficient, screenshot first, pick pixel coords on the simulator canvas, then:

```bash
agent-browser mouse move <px> <py>
agent-browser mouse down
agent-browser mouse up
```

Coords are relative to the browser viewport, not normalized.

## morii-ios

```bash
cd morii-ios
open morii-ios.xcodeproj
# Pick simulator UDID
UDID="$(xcrun simctl list devices booted | awk -F '[()]' '/Booted/ {print $2; exit}')"

xcodebuild \
  -project morii-ios.xcodeproj \
  -scheme morii-ios \
  -configuration Debug \
  -destination "id=$UDID" \
  -derivedDataPath .derivedData \
  build

APP=".derivedData/Build/Products/Debug-iphonesimulator/morii-ios.app"
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" <bundle-id-from-Info.plist>

npx serve-sim@latest "$UDID" &
# → agent-browser on :3200
```

BLE features need a real device; Chat/memory/search work on simulator.

## Headless smoke (no browser)

Use the repo's `verify-e2e.sh` as a template:

1. `xcodebuild` → `simctl install` → `simctl launch`
2. `npx serve-sim --detach -q`
3. Read `/ax` for initial state
4. `serve-sim tap`
5. Re-read `/ax` for expected change
6. `serve-sim --kill`

## Cleanup

```bash
npx serve-sim@latest --kill
agent-browser close --all
```
