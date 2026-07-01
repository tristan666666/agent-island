<div align="center">

# Agent Island

**A status companion for Claude Code and Codex — usage, session state, and the moment it is your turn.**

[简体中文](README.zh-CN.md)

[![Listed in awesome-mac](https://img.shields.io/badge/listed%20in-awesome--mac-0969da?style=for-the-badge)](https://github.com/jaywcjlove/awesome-mac/blob/master/README.md#menu-bar-tools)
[![Listed in awesome-swift-macos-apps](https://img.shields.io/badge/listed%20in-awesome--swift--macOS-f97316?style=for-the-badge)](https://github.com/jaywcjlove/awesome-swift-macos-apps/blob/main/README.md#ai)
[![Listed in awesome-codex-cli](https://img.shields.io/badge/listed%20in-awesome--codex--cli-10b981?style=for-the-badge)](https://github.com/milisp/awesome-codex-cli)
[![Listed in awesome-coding-agents](https://img.shields.io/badge/listed%20in-awesome--coding--agents-7c3aed?style=for-the-badge)](https://github.com/kailiu42/awesome-coding-agents)
[![Listed in awesome-claude-code-and-skills](https://img.shields.io/badge/listed%20in-awesome--claude--code--and--skills-8b5cf6?style=for-the-badge)](https://github.com/GetBindu/awesome-claude-code-and-skills)
[![Listed in awesome-vibe-coding-resources](https://img.shields.io/badge/listed%20in-awesome--vibe--coding--resources-ec4899?style=for-the-badge)](https://github.com/acvnace/awesome-vibe-coding-resources#desktop-apps)

<a href="https://www.producthunt.com/products/agent-island-2?embed=true&utm_source=badge-featured&utm_medium=badge&utm_campaign=badge-agent-island-2">
  <img src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=1175477&theme=light" alt="Agent Island - status companion for Claude Code and Codex | Product Hunt" width="250" height="54">
</a>

<video src="https://github.com/user-attachments/assets/d69b41e0-9298-4f17-b6c9-6014f3bd956b" controls width="900"></video>

<p>
  <a href="#quick-start"><strong>Quick start</strong></a> ·
  <a href="https://github.com/tristan666666/agent-island/releases/latest">Latest release</a> ·
  <a href="CONTRIBUTING.md">Contribute</a>
</p>

<p><strong>If Agent Island saves you a stalled overnight Claude/Codex run, star it so more Mac users can find it.</strong></p>

<img src="Assets/agent-island-auto-trigger.png" alt="Agent Island auto-resume sessions view" width="900">
<img src="Assets/agent-island-usage.png" alt="Agent Island usage planning view" width="900">

</div>

Agent Island lives in your MacBook notch. It is a small native macOS companion for Claude Code and Codex runs:

- **Auto-resume** a chosen session when it can continue.
- Show each session's **live state** right on the provider logo.

Usage and reset timing are included for planning, but the main point is simpler: keep agent work visible, and know when the next move is yours without opening every terminal.

## Why

Heavy Claude / Codex use has two quiet time-sinks:

- A long-running task pauses while you're away, and you have to come back just to type `continue`.
- You cannot tell at a glance whether a session is still running, waiting for you, or stuck.

Agent Island handles both from the notch. Usage and reset timing are there to help you plan work precisely; they are not the product's main point.

## Features

### Keep long runs moving

Agent Island can auto-send a message (`继续`, `OK`, whatever you set) to a chosen Claude or Codex session so the task keeps going — no babysitting. You can trigger it from the provider's real reset timing, or run it on a fixed every-N-hours schedule in **Settings → 自动触发**.

### ⚡ Live session state, on your logos

The provider logos react to what your Claude/Codex sessions are actually doing:

| State | How it's detected | The cue |
|---|---|---|
| **Working** | transcript still growing | logo rotates + soft glow |
| **Your turn** | turn finished + stopped | foreground alarm window opens and keeps ringing until dismissed |
| **Needs attention** | limit, login, network, or provider error | **red** alarm pulse on the affected provider logo |

### 📊 Usage island

Live Claude & Codex 5-hour / weekly usage, cost, and reset countdowns — swipeable pages in the notch.

## What's different from Codex Island

Codex Island is a **passive meter** — it shows your usage. Agent Island is **active** — it watches your sessions and acts on them. Everything below the first row is new here:

| | Codex Island | Agent Island |
|---|:---:|:---:|
| Usage / cost / reset in the notch | ✅ | ✅ *(inherited)* |
| **Auto-resume** a chosen long-running session | — | ✅ Claude & Codex |
| **Logo reacts to session state** — rotate (working), alarm popup (your turn), red pulse (needs attention) | — | ✅ |
| **Auto-Trigger** page inside the island | — | ✅ |
| **Status-guide** settings tab (live legend + alarm sound controls) | — | ✅ |
| Cross-tool session picker with real thread titles, archived filtered out | — | ✅ |

In short: Codex Island tells you *how much you've used*; Agent Island keeps session state, usage, and the handoff moment in view.

## Quick start

Download the current DMG, drag AgentIsland into Applications, then open it:

[**Download AgentIsland-1.2.4.dmg**](https://github.com/tristan666666/agent-island/releases/download/v1.2.4/AgentIsland-1.2.4.dmg)

macOS 13+. Universal binary (Apple Silicon + Intel).

If macOS blocks the first launch because the app is not notarized, right-click AgentIsland in Finder and choose **Open** once.

Source build:

```sh
git clone https://github.com/tristan666666/agent-island.git
cd agent-island
./scripts/verify.sh
open build/AgentIsland.app
```

## How it works

- **Reset times** come from each provider's real usage API.
- **Session state** is read from the transcript files: mtime (is it still producing output?) plus the turn-complete markers — Claude's `stop_reason: end_turn`, Codex's `task_complete` event.
- **Resume** runs `claude --resume … -p "<msg>" --dangerously-skip-permissions` or `codex exec resume … "<msg>" --dangerously-bypass-approvals-and-sandbox`. Run logs land in `~/Library/Application Support/AgentIsland/trigger-runs/`.
- The Mac must be awake for a trigger to fire, and each fire spends tokens.
- ⚠️ A trigger resumes the agent **unattended with permission checks off** (the `--dangerously-*` flags above). Only attach triggers to sessions you trust. Everything runs locally as you; nothing is sent anywhere.

Deeper implementation write-up: [How Agent Island detects Claude Code and Codex session state](docs/how-agent-island-detects-session-state.md).

## Repository layout

- `Sources/` — the native macOS app.
- `Resources/` — app-bundled icons, logos, and localization files.
- `Assets/` — public README and release-page images.
- `docs/` — public architecture, release, and contributor notes.
- `scripts/`, `build.sh`, `release.sh` — local build, Sparkle, and release tooling.

The landing website is intentionally kept outside this app repository. If it is published, it should use its own deploy project or repository.

## Credits & license

Agent Island is a fork of **[codex-island](https://github.com/ericjypark/codex-island)** by **Eric Park** — the usage-island and cost-tracking foundation are his work. Agent Island adds auto-trigger, live session-state animations, and its own product direction.

MIT licensed — © 2026 Eric Park. This fork retains that notice. See [LICENSE](LICENSE).
