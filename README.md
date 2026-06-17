# Agent Island

A macOS notch overlay that does two things:

1. **Usage island** — a Dynamic-Island-style floating panel that shows your live Claude and Codex 5-hour / weekly usage, cost, and reset countdowns.
2. **Auto-Trigger** — when a provider's 5-hour window resets, automatically resume a Claude Code or Codex session with a message (e.g. `继续` / `OK`) so an unattended task keeps going instead of stalling while you're away. Also supports a fixed every-N-hours schedule. Configure it in **Settings → Triggers**: pick any Claude or Codex session, set the message, choose *After reset* or *Every Nh*, enable.

Native Swift + SwiftUI. Runs as a menu-bar-less accessory app (`LSUIElement`), floats above all spaces.

## Build

```sh
./build.sh          # universal (arm64 + x86_64) build → build/AgentIsland.app
open build/AgentIsland.app
```

macOS 13+. Auto-update (Sparkle) is disabled in this build (`SU_FEED_URL` empty).

## How Auto-Trigger fires

The app already fetches the real reset time from each provider's usage API. When `fiveHour.resetAt` advances, the window has reset, and the engine runs:

- Claude: `claude --resume <session> -p "<message>" --dangerously-skip-permissions`
- Codex: `codex exec resume <session> "<message>" --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check`

Run logs land in `~/Library/Application Support/AgentIsland/trigger-runs/`. Note: the Mac must be awake for a trigger to fire, and each fire spends tokens.

## Credits & license

Agent Island is a fork of **[codex-island](https://github.com/ericjypark/codex-island)** by **Eric Park**, with the Auto-Trigger feature added and the project rebranded. The original usage-island and cost-tracking work is his.

MIT licensed — see [LICENSE](LICENSE) (Copyright © 2026 Eric Park). This fork retains that copyright notice as required.
