# HTTP endpoints (stream helper, default :3100)

Base URL from `npx serve-sim --list -q` → `url` or `streamUrl` host.

| Endpoint | Method | Returns |
|---|---|---|
| `/ax` | GET | Accessibility tree (axe-style JSON). `AXUniqueId` = SwiftUI `accessibilityIdentifier` |
| `/stream.mjpeg` | GET | Live MJPEG video stream |
| `/ws` | WebSocket | Binary touch/input channel (used by CLI internally) |
| `/` | GET | 404 on stream-only port; use **:3200** for preview HTML |

Preview UI (foreground serve-sim only):

| URL | Content |
|---|---|
| `http://127.0.0.1:3200/` | React simulator preview — use with agent-browser |

When `-p <port>` is passed, both surfaces shift (e.g. `-p 3399` → preview and stream on 3399).
