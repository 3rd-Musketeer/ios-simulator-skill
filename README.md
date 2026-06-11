# ios-simulator-skill

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)]()

Portable [Agent Skill](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview) for driving and visually verifying iOS Simulator apps — without opening Xcode.

Works in **Cursor**, **Claude Code**, **Codex**, and any host that supports the Agent Skills standard.

Built on [serve-sim](https://github.com/EvanBacon/serve-sim) (stream + control) and [agent-browser](https://github.com/vercel-labs/agent-browser) (screenshots).

## Install

Point your agent host at this repository root (the folder containing `SKILL.md`):

```bash
git clone https://github.com/3rd-Musketeer/ios-simulator-skill.git
ln -sf "$(pwd)/ios-simulator-skill" ~/.cursor/skills/ios-simulator
# Claude Code: ~/.claude/skills/ios-simulator
```

## Prerequisites

```bash
./scripts/check-prereqs.sh
```

Requires macOS, Xcode CLI tools (`simctl`), Node.js ≥ 18, and [agent-browser](https://github.com/vercel-labs/agent-browser) for visual verification.

## Quick verify

```bash
cd examples/skill-test-app
./verify-e2e.sh          # headless: build → serve-sim tap → assert /ax
./run-skill-test.sh      # interactive: Simulator + browser preview
```

## Architecture

serve-sim exposes two surfaces — do not confuse them:

| Port | What | Use for |
|------|------|---------|
| **3200** | React preview UI (foreground `npx serve-sim`) | Browser view, **agent-browser screenshots** |
| **3100** | MJPEG stream + `/ax` + WebSocket | CLI taps, headless automation |

`npx serve-sim --detach` starts only the stream helper (~3100), **not** the preview on 3200.

```text
Simulator ──simctl io──► serve-sim-bin (:3100)
                              ▲
foreground serve-sim ─────────┘──► React preview (:3200) ──► agent-browser
```

## Repository layout

```text
SKILL.md              Agent skill entrypoint
references/           Detailed workflows and HTTP endpoints
scripts/              Prerequisite checks
evals/                Skill trigger eval cases
examples/skill-test-app/   Minimal SwiftUI smoke harness
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Run `examples/skill-test-app/verify-e2e.sh` before opening a PR.

## License

[MIT](LICENSE) — Copyright 2026 Haoyang

## Credits

- [serve-sim](https://github.com/EvanBacon/serve-sim) by Evan Bacon
- [agent-browser](https://github.com/vercel-labs/agent-browser) by Vercel Labs
